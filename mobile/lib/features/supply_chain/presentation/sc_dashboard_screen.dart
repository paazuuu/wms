import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../application/supply_chain_providers.dart';
import '../domain/supply_chain.dart';
import 'sc_labels.dart';
import 'sc_product_sheet.dart';
import 'sc_widgets.dart';

/// 収益ダッシュボード (§4): what is left after every cost, for the warehouse
/// in the header — totals, what the cost is made of, what needs attention,
/// and each product's profit.
class ScDashboardScreen extends ConsumerStatefulWidget {
  const ScDashboardScreen({super.key});

  @override
  ConsumerState<ScDashboardScreen> createState() => _ScDashboardScreenState();
}

class _ScDashboardScreenState extends ConsumerState<ScDashboardScreen> {
  bool _busy = false;

  void _snack(String m, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m), backgroundColor: danger ? Theme.of(context).colorScheme.error : null));
  }

  Future<void> _snapshot() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final r = await ref.read(supplyChainRepositoryProvider).dashboard(warehouseId: ref.read(scWarehouseIdProvider), save: true);
    if (!mounted) return;
    setState(() => _busy = false);
    r.when(
      success: (_) {
        _snack(l10n.scSnapshotSaved);
        ref.invalidate(scResultsProvider);
      },
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  Future<void> _seed() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final r = await ref.read(supplyChainRepositoryProvider).seedFromHistory();
    if (!mounted) return;
    setState(() => _busy = false);
    r.when(
      success: (m) {
        _snack(l10n.scSeeded((m['from_purchase_orders'] as num?)?.toInt() ?? 0, (m['from_documents'] as num?)?.toInt() ?? 0));
        refreshSupplyChain(ref);
      },
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(scDashboardProvider);
    final canManage = ref.watch(scCanManageProvider);
    final warehouse = ref.watch(activeWarehouseProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.featScDashboard),
        actions: [
          IconButton(
            tooltip: l10n.scRecalculate,
            onPressed: () => ref.invalidate(scDashboardProvider),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            key: const ValueKey('sc-snapshot'),
            tooltip: l10n.scSnapshot,
            onPressed: _busy ? null : _snapshot,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: humanizeApiErrorMessage(l10n, '$e'),
          onRetry: () => ref.invalidate(scDashboardProvider),
        ),
        data: (run) {
          if (run.products.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                SizedBox(
                  height: 260,
                  child: EmptyStateView(icon: Icons.stacked_line_chart, title: l10n.scNoData, message: l10n.scNoDataBody),
                ),
                if (canManage)
                  Center(
                    child: FilledButton.icon(
                      key: const ValueKey('sc-seed'),
                      onPressed: _busy ? null : _seed,
                      icon: const Icon(Icons.download_outlined),
                      label: Text(l10n.scSeed),
                    ),
                  ),
              ],
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(scDashboardProvider),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(warehouse?.name ?? l10n.scAllWarehouses,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.sm),
                ScKpiGrid(summary: run.summary),
                const SizedBox(height: AppSpacing.md),
                ScSection(title: l10n.scCostBreakdown, child: ScCostBreakdownBar(lines: run.summary.lines)),
                _Alerts(run: run),
                ScSection(
                  title: l10n.scProductsTitle,
                  trailing: canManage
                      ? TextButton.icon(onPressed: _busy ? null : _seed, icon: const Icon(Icons.download_outlined, size: 18), label: Text(l10n.scSeed))
                      : null,
                  child: _ProductTable(products: run.products),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Alerts extends StatelessWidget {
  const _Alerts({required this.run});

  final ScRun run;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final over = run.bottlenecks.where((b) => b.status == LoadStatus.exceeded || b.status == LoadStatus.stopped).length;
    final high = run.risks.where((r) => r.level == RiskLevel.high || r.level == RiskLevel.critical).length;
    final noSupply = run.products.where((p) => !p.supplied).length;
    final loss = run.products.where((p) => p.supplied && p.profitPerUnit < 0).length;
    final notes = <String>{for (final p in run.products) ...p.notes.where((n) => n.startsWith('no_') && n != 'no_supplier')};
    if (over == 0 && high == 0 && noSupply == 0 && loss == 0 && notes.isEmpty) return const SizedBox.shrink();
    return ScSection(
      title: l10n.scAlerts,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          if (loss > 0) StatusPill(tone: StatusTone.danger, label: l10n.scAlertLoss(loss), dense: true),
          if (over > 0) StatusPill(tone: StatusTone.danger, label: l10n.scAlertBottlenecks(over), dense: true),
          if (high > 0) StatusPill(tone: StatusTone.warning, label: l10n.scAlertRisks(high), dense: true),
          if (noSupply > 0) StatusPill(tone: StatusTone.warning, label: l10n.scAlertNoSupply(noSupply), dense: true),
          for (final n in notes) StatusPill(tone: StatusTone.neutral, label: scNoteLabel(l10n, n), dense: true),
        ],
      ),
    );
  }
}

class _ProductTable extends StatelessWidget {
  const _ProductTable({required this.products});

  final List<ScProduct> products;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodySmall?.copyWith(fontFamily: AppFonts.mono);
    final sorted = [...products]..sort((a, b) => a.profitPerUnit.compareTo(b.profitPerUnit));
    return Column(
      children: [
        for (final p in sorted)
          InkWell(
            key: ValueKey('sc-product-${p.productId}'),
            onTap: () => showScProductSheet(context, p.productId),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: theme.textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(
                          p.supplied
                              ? p.chosen
                                  .map((c) => '${c.partnerName}${c.routeName != null ? ' / ${c.routeName}' : ' / ${l10n.scNoRoute}'}')
                                  .join(', ')
                              : l10n.scNoTerms,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${scUnitMoney(p.unit.landed)} → ${scUnitMoney(p.salesPrice)}', style: mono),
                        Text(
                          '${scUnitMoney(p.profitPerUnit)} · ${scPercent(p.margin)}',
                          style: mono?.copyWith(
                              fontWeight: FontWeight.w700, color: p.profitPerUnit < 0 ? AppColors.danger : AppColors.success),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 110,
                    child: Text(scMoney(p.profitTotal), textAlign: TextAlign.right, style: mono),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
