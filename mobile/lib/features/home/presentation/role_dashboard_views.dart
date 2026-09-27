import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../delivery/presentation/reconciliation_screen.dart';
import '../../purchasing/presentation/purchase_order_detail_screen.dart';
import '../../warehouse_context/presentation/warehouse_overview_screen.dart'
    show countryLabel;
import '../application/role_dashboard_providers.dart';
import '../domain/role_dashboards.dart';
import 'dashboard_charts.dart' show chartNeutralColor, chartSlotColor;
import 'manual_inbound_list_screen.dart';

final _day = DateFormat('yyyy-MM-dd');
final _num = NumberFormat.decimalPattern();

class _Label extends StatelessWidget {
  const _Label(this.text, {this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant, letterSpacing: 0.4)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A figure with its label, for the rows of totals at the top of each view.
class _Figure extends StatelessWidget {
  const _Figure({super.key, required this.label, required this.value, this.caption, this.tone});

  final String label;
  final String value;
  final String? caption;
  final StatusTone? tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.xs),
            Text(value, style: theme.textTheme.headlineSmall),
            if (caption != null) ...[
              const SizedBox(height: AppSpacing.xs),
              tone == null
                  ? Text(caption!,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant))
                  : StatusPill(tone: tone!, label: caption!, dense: true),
            ],
          ],
        ),
      ),
    );
  }
}

Widget _figures(List<Widget> children) => LayoutBuilder(builder: (context, c) {
      final perRow = c.maxWidth >= 720 ? children.length : 2;
      final w = (c.maxWidth - AppSpacing.md * (perRow - 1)) / perRow;
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    });

Widget _asyncView<T>(
  AsyncValue<T> value,
  VoidCallback retry,
  Widget Function(T data) builder,
) =>
    value.when(
      data: builder,
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SizedBox(
        height: 360,
        child: ErrorStateView(message: '$e', onRetry: retry),
      ),
    );

// ---------------------------------------------------------------------------
// Inspection: what is coming in, and when
// ---------------------------------------------------------------------------

class InspectionDashboardView extends ConsumerWidget {
  const InspectionDashboardView({
    super.key,
    this.onOpenFeature,
    this.canCreateList = false,
  });

  /// Opens a catalog feature by id ('inspection', 'bulk_inspection', …).
  final void Function(String featureId)? onOpenFeature;

  /// Whether this user may write an inbound list by hand.
  final bool canCreateList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return _asyncView(
      ref.watch(inboundScheduleProvider),
      () => ref.invalidate(inboundScheduleProvider),
      (s) {
        final today = s.today ?? DateUtils.dateOnly(DateTime.now());
        final groups = <String, List<InboundPlan>>{};
        String keyFor(InboundPlan p) {
          final d = p.expectedOn;
          if (d == null) return 'none';
          final diff = DateUtils.dateOnly(d).difference(DateUtils.dateOnly(today)).inDays;
          if (diff < 0) return 'overdue';
          if (diff == 0) return 'today';
          if (diff == 1) return 'tomorrow';
          return _day.format(d);
        }

        for (final p in s.plans) {
          groups.putIfAbsent(keyFor(p), () => []).add(p);
        }
        // Late first, then today, tomorrow and on by date, undated last.
        int rank(String k) => switch (k) {
              'overdue' => 0,
              'today' => 1,
              'tomorrow' => 2,
              'none' => 4,
              _ => 3,
            };
        final keys = groups.keys.toList()
          ..sort((a, b) {
            final r = rank(a).compareTo(rank(b));
            return r != 0 ? r : a.compareTo(b);
          });
        String title(String k) => switch (k) {
              'overdue' => l10n.dashDayOverdue,
              'today' => '${l10n.dashDayToday}（${_day.format(today)}）',
              'tomorrow' =>
                '${l10n.dashDayTomorrow}（${_day.format(today.add(const Duration(days: 1)))}）',
              'none' => l10n.dashDayNone,
              _ => k,
            };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AwaitingCard(schedule: s, onOpenFeature: onOpenFeature),
            if (canCreateList) ...[
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const ValueKey('dash-create-manual-list'),
                  icon: const Icon(Icons.playlist_add),
                  label: Text(l10n.dashCreateManualList),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const ManualInboundListScreen())),
                ),
              ),
            ],
            _Label(l10n.dashIncomingTitle),
            if (s.plans.isEmpty)
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(l10n.dashIncomingEmpty),
                ),
              ),
            for (final k in keys) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm, top: AppSpacing.sm),
                child: Text(title(k),
                    key: ValueKey('dash-day-$k'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: k == 'overdue' ? Theme.of(context).colorScheme.error : null)),
              ),
              for (final p in groups[k]!) _PlanCard(plan: p),
            ],
            if (s.unplannedOrders.isNotEmpty) ...[
              _Label(l10n.dashUnplannedTitle),
              Text(l10n.dashUnplannedBody,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.sm),
              for (final o in s.unplannedOrders)
                Card(
                  key: ValueKey('dash-unplanned-${o.id}'),
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text(o.poNumber),
                    subtitle: Text([
                      if (o.supplierName != null) o.supplierName!,
                      if (o.expectedDate != null) _day.format(o.expectedDate!),
                      l10n.dashPlanSummary(o.lineCount, o.outstandingUnits),
                    ].join(' · ')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => PurchaseOrderDetailScreen(purchaseOrderId: o.id))),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _AwaitingCard extends StatelessWidget {
  const _AwaitingCard({required this.schedule, this.onOpenFeature});

  final InboundSchedule schedule;
  final void Function(String featureId)? onOpenFeature;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final any = schedule.awaitingLines > 0;
    return Card(
      margin: EdgeInsets.zero,
      color: any ? scheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fact_check_outlined,
                    color: any ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.dashAwaitingInspection, style: theme.textTheme.titleMedium),
                      Text(
                        any
                            ? l10n.dashAwaitingBody(schedule.awaitingInspections,
                                schedule.awaitingLines, schedule.awaitingUnits)
                            : l10n.dashAwaitingNone,
                        key: const ValueKey('dash-awaiting'),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (onOpenFeature != null) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  FilledButton.tonal(
                    onPressed: () => onOpenFeature!('inspection'),
                    child: Text(l10n.dashOpenInspections),
                  ),
                  FilledButton.tonal(
                    onPressed: () => onOpenFeature!('bulk_inspection'),
                    child: Text(l10n.dashBulkInspection),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});

  final InboundPlan plan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shown = plan.preview.take(3).toList();
    return Card(
      key: ValueKey('dash-plan-${plan.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => ReconciliationScreen(planId: plan.id))),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(plan.supplierName ?? plan.deliveryNumber,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (plan.manual)
                    StatusPill(tone: StatusTone.info, label: l10n.dashManualBadge, dense: true),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                [
                  plan.deliveryNumber,
                  if (plan.poNumber != null) plan.poNumber!,
                  l10n.dashPlanSummary(plan.lineCount, plan.outstandingUnits),
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (shown.isNotEmpty) const SizedBox(height: AppSpacing.sm),
              for (final line in shown)
                Row(
                  children: [
                    Expanded(
                      child: Text(line.name.isEmpty ? line.jan : line.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Text(l10n.dashUnitsCount(line.quantity)),
                  ],
                ),
              if (plan.lineCount > shown.length)
                Text(l10n.dashMoreLines(plan.lineCount - shown.length),
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Purchasing: stock as it stands, and what is on its way
// ---------------------------------------------------------------------------

class PurchasingDashboardView extends ConsumerStatefulWidget {
  const PurchasingDashboardView({super.key, this.onOpenDemand});

  final VoidCallback? onOpenDemand;

  @override
  ConsumerState<PurchasingDashboardView> createState() => _PurchasingDashboardViewState();
}

class _PurchasingDashboardViewState extends ConsumerState<PurchasingDashboardView> {
  late final _search = TextEditingController(text: ref.read(stockOverviewSearchProvider));

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(stockOverviewProvider);
    final country = async.valueOrNull?.countryCode ?? ref.watch(stockOverviewCountryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final c in const ['JP', 'CN'])
              ChoiceChip(
                key: ValueKey('stock-country-$c'),
                label: Text(countryLabel(l10n, c)),
                selected: country == c,
                onSelected: (_) => ref.read(stockOverviewCountryProvider.notifier).state = c,
              ),
            if (widget.onOpenDemand != null)
              TextButton.icon(
                onPressed: widget.onOpenDemand,
                icon: const Icon(Icons.assignment_late_outlined),
                label: Text(l10n.dashOpenDemand),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const ValueKey('stock-search'),
          controller: _search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: l10n.dashStockSearch,
          ),
          onSubmitted: (v) => ref.read(stockOverviewSearchProvider.notifier).state = v,
        ),
        const SizedBox(height: AppSpacing.lg),
        _asyncView(async, () => ref.invalidate(stockOverviewProvider), (p) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _figures([
                _Figure(label: l10n.dashStockUsable, value: _num.format(p.usable)),
                _Figure(label: l10n.dashStockQcPending, value: _num.format(p.qcPending)),
                _Figure(label: l10n.dashStockHeld, value: _num.format(p.held)),
                _Figure(label: l10n.dashStockIncoming, value: _num.format(p.incoming)),
              ]),
              _Label(l10n.dashStockProducts(p.productCount)),
              if (p.products.isEmpty)
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(l10n.dashStockEmpty),
                  ),
                ),
              for (final row in p.products) _StockRowCard(row: row),
            ],
          );
        }),
      ],
    );
  }
}

class _StockRowCard extends StatelessWidget {
  const _StockRowCard({required this.row});

  final StockOverviewRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget cell(String label, int value, {bool strong = false, Color? color}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
            Text(_num.format(value),
                style: (strong ? theme.textTheme.titleMedium : theme.textTheme.bodyLarge)
                    ?.copyWith(color: color)),
          ],
        );
    return Card(
      key: ValueKey('stock-row-${row.productId}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(row.productName.isEmpty ? row.janCode : row.productName,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                if (row.shortfall > 0)
                  StatusPill(
                    tone: StatusTone.danger,
                    label: '${l10n.dashStockShortfall} ${_num.format(row.shortfall)}',
                    dense: true,
                  ),
              ],
            ),
            Text(row.janCode,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.sm,
              children: [
                cell(l10n.dashStockUsable, row.usable, strong: true),
                cell(l10n.dashStockQcPending, row.qcPending),
                cell(l10n.dashStockHeld, row.held),
                cell(l10n.dashStockReserved, row.reserved),
                cell(l10n.dashStockIncoming, row.incoming),
                if (row.backordered > 0) cell(l10n.dashBackordered, row.backordered),
              ],
            ),
            if (row.nextExpected != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.dashStockNext(_day.format(row.nextExpected!)),
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sales: a year of orders, and what they still need bought
// ---------------------------------------------------------------------------

class SalesDashboardView extends ConsumerWidget {
  const SalesDashboardView({super.key, this.onOpenDemand});

  final VoidCallback? onOpenDemand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final country = ref.watch(salesCycleCountryProvider);
    final pct = NumberFormat.decimalPercentPattern(decimalDigits: 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final c in const ['CN', 'JP', ''])
              ChoiceChip(
                key: ValueKey('sales-country-${c.isEmpty ? 'all' : c}'),
                label: Text(c.isEmpty ? l10n.dashSalesAllCountries : countryLabel(l10n, c)),
                selected: country == c,
                onSelected: (_) => ref.read(salesCycleCountryProvider.notifier).state = c,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _asyncView(ref.watch(salesCycleProvider), () => ref.invalidate(salesCycleProvider), (s) {
          final change = s.change;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _figures([
                _Figure(
                  key: const ValueKey('sales-units'),
                  label: l10n.dashSalesUnits(s.months.isEmpty ? 12 : s.months.length),
                  value: _num.format(s.totalUnits),
                  caption: change == null
                      ? l10n.dashSalesNoCompare
                      : l10n.dashSalesVsLastYear('${change >= 0 ? '+' : ''}${pct.format(change)}'),
                  tone: change == null
                      ? null
                      : (change >= 0 ? StatusTone.success : StatusTone.warning),
                ),
                _Figure(label: l10n.dashSalesOrders, value: _num.format(s.totalOrders)),
              ]),
              _Label(l10n.dashSalesMonthly),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: s.totalUnits == 0 && s.prevTotalUnits == 0
                      ? Text(l10n.dashSalesEmpty)
                      : _MonthlyChart(cycle: s),
                ),
              ),
              _Label(l10n.dashSalesToPurchase,
                  trailing: onOpenDemand == null
                      ? null
                      : TextButton(onPressed: onOpenDemand, child: Text(l10n.dashOpenDemand))),
              Card(
                margin: EdgeInsets.zero,
                child: s.toPurchase.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(l10n.dashSalesToPurchaseEmpty),
                      )
                    : Column(
                        children: [
                          for (final p in s.toPurchase)
                            ListTile(
                              key: ValueKey('sales-purchase-${p.jan}'),
                              title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                  '${p.jan} · ${l10n.dashBackordered} ${_num.format(p.backordered)}'
                                  ' · ${l10n.dashStockIncoming} ${_num.format(p.incoming)}'),
                              trailing: StatusPill(
                                tone: StatusTone.danger,
                                label: '${l10n.dashStockShortfall} ${_num.format(p.shortfall)}',
                                dense: true,
                              ),
                            ),
                        ],
                      ),
              ),
              if (s.topProducts.isNotEmpty) ...[
                _Label(l10n.dashSalesTop),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final p in s.topProducts)
                        ListTile(
                          dense: true,
                          title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(p.jan),
                          trailing: Text(l10n.dashUnitsCount(p.units)),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          );
        }),
      ],
    );
  }
}

/// This year's months against the same months a year before: paired bars,
/// this year in the first palette slot, last year in the neutral.
class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.cycle});

  final SalesCycle cycle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final b = theme.brightness;
    final now = chartSlotColor(0, b);
    final prev = chartNeutralColor(b);
    final peak = cycle.months.fold<int>(1, (m, e) => [m, e.units, e.prevUnits].reduce((a, c) => a > c ? a : c));
    const barMax = 120.0;

    Widget legend(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: AppSpacing.xs),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: AppSpacing.lg, children: [
          legend(now, l10n.dashSalesThisYear),
          legend(prev, l10n.dashSalesLastYear),
        ]),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: barMax + 40,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final m in cycle.months)
                Expanded(
                  child: Tooltip(
                    message: '${m.month}: ${_num.format(m.units)} / ${_num.format(m.prevUnits)}',
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _bar(prev, m.prevUnits / peak * barMax),
                            const SizedBox(width: 2),
                            _bar(now, m.units / peak * barMax),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          m.month.length >= 7 ? '${int.tryParse(m.month.substring(5, 7)) ?? m.month}' : m.month,
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bar(Color c, double h) => Flexible(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 12),
          height: h < 1 && h > 0 ? 1 : h,
          decoration: BoxDecoration(
            color: c,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
          ),
        ),
      );
}
