import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../admin/data/menu_visibility_repository.dart' show showPricesProvider;
import '../../stock_import/presentation/stock_import_calendar_screen.dart' show calendarMaxWidth, calendarSideBySide;
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/outbound_file_repository.dart';
import 'outbound_file_detail_screen.dart';
import 'outbound_file_screen.dart' show outboundKg, outboundMoney;

/// 出庫カレンダー on its own (現場作業): what left the warehouse, by day.
class OutboundCalendarScreen extends StatelessWidget {
  const OutboundCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context).featOutboundCalendar)),
        body: const OutboundCalendarTab(),
      );
}

/// 出庫カレンダー (0188): the lists shipped in a month, by the day they went
/// out — the month at once, a day to narrow it — each opening its rows and
/// its file. Both kinds are here — taken out of stock and 代理出荷 (0189) —
/// told apart and narrowed to one; [proxyOnly] shows the 代理出荷 alone.
class OutboundCalendarTab extends ConsumerStatefulWidget {
  const OutboundCalendarTab({super.key, this.proxyOnly = false});

  final bool proxyOnly;

  @override
  ConsumerState<OutboundCalendarTab> createState() => _OutboundCalendarTabState();
}

class _OutboundCalendarTabState extends ConsumerState<OutboundCalendarTab> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _day;

  /// null: both kinds; else 'stock' or 'proxy'.
  String? _kind;

  OutboundMonthAsk get _ask => (year: _month.year, month: _month.month, warehouseId: ref.watch(activeWarehouseIdProvider));

  void _shift(int by) => setState(() {
        _month = DateTime(_month.year, _month.month + by);
        _day = null;
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final async = ref.watch(outboundFilesProvider(_ask));
    final kind = widget.proxyOnly ? 'proxy' : _kind;
    bool keep(OutboundFileSummary f) => switch (kind) {
          null => true,
          'planned' => f.planned,
          _ => f.kind == kind,
        };
    final files = [for (final f in async.valueOrNull ?? const <OutboundFileSummary>[]) if (keep(f)) f];
    final byDay = <DateTime, int>{};
    for (final f in files) {
      byDay[f.shippedOn] = (byDay[f.shippedOn] ?? 0) + 1;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final shown = [for (final f in files) if (_day == null || f.shippedOn == _day) f];

    final calendar = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: calendarMaxWidth),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          IconButton(key: const ValueKey('of-cal-prev'), onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: Center(
              child: Text(DateFormat('y/MM').format(_month), key: const ValueKey('of-cal-month'), style: theme.textTheme.titleMedium),
            ),
          ),
          IconButton(key: const ValueKey('of-cal-next'), onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
        ]),
        _DayGrid(month: _month, byDay: byDay, selected: _day, today: today, onDay: (d) => setState(() => _day = _day == d ? null : d)),
        if (!widget.proxyOnly)
          Wrap(spacing: AppSpacing.sm, children: [
            for (final (k, label) in [
              (null, l10n.ofCalKindAll),
              ('planned', l10n.ofCalKindPlanned),
              ('stock', l10n.ofCalKindStock),
              ('proxy', l10n.ofCalKindProxy),
            ])
              ChoiceChip(
                key: ValueKey('of-cal-kind-${k ?? 'all'}'),
                label: Text(label),
                selected: _kind == k,
                onSelected: (_) => setState(() => _kind = k),
              ),
          ]),
        if (_day != null)
          TextButton(
            key: const ValueKey('of-cal-all'),
            onPressed: () => setState(() => _day = null),
            child: Text(l10n.ofCalMonthAll),
          ),
      ]),
    );

    final list = async.when(
      loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.lg), child: LinearProgressIndicator()),
      error: (e, _) => ErrorStateView(
          message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => ref.invalidate(outboundFilesProvider(_ask))),
      data: (_) => shown.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(_day == null ? l10n.ofCalEmpty : l10n.ofEmptyDay, key: const ValueKey('of-cal-empty')),
            )
          : Column(children: [
              for (final f in shown) _FileCard(file: f),
            ]),
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(outboundFilesProvider(_ask));
        ref.invalidate(outboundUndecidedProvider);
      },
      child: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= calendarSideBySide;
        return ListView(
          key: const ValueKey('of-calendar'),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Only lists with a day are here; those with none yet (未定) are
            // in 出荷手配 (出荷明細の取込 / 在庫外出荷) and on the dashboard.
            if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: calendarMaxWidth, child: calendar),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: list),
              ])
            else ...[
              Center(child: calendar),
              const SizedBox(height: AppSpacing.md),
              list,
            ],
          ],
        );
      }),
    );
  }
}

class _FileCard extends ConsumerWidget {
  const _FileCard({required this.file});

  final OutboundFileSummary file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return Card(
      key: ValueKey('of-file-${file.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OutboundFileDetailScreen(fileId: file.id))),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(children: [
            Icon(file.planned ? Icons.event_available_outlined : (file.proxy ? Icons.edit_note_outlined : Icons.description_outlined),
                color: file.undone ? scheme.onSurfaceVariant : scheme.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(file.fileName,
                    style: theme.textTheme.titleSmall?.copyWith(decoration: file.undone ? TextDecoration.lineThrough : null),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  [
                    DateFormat('y/MM/dd').format(file.shippedOn),
                    if (file.warehouseName != null) file.warehouseName!,
                    if (file.destination != null) file.destination!,
                    if (file.proxy || file.planned)
                      l10n.prCardLines(file.lineCount, file.quantityTotal)
                    else
                      l10n.ofCardLines(file.lineCount, file.shippedTotal),
                  ].join(' · '),
                  style: muted,
                ),
                Wrap(spacing: AppSpacing.md, children: [
                  if (file.planned)
                    Text(l10n.ofPlanned,
                        key: ValueKey('of-planned-${file.id}'),
                        style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
                  // Its day has passed and it has not gone out: held for a
                  // shortage by the night run, or not run yet (0201).
                  if (file.overdue(DateTime.now()))
                    Tooltip(
                      message: file.autoHoldShort != null
                          ? '${l10n.ofOverdueHint} · ${l10n.ofCardShort(file.autoHoldShort!)}'
                          : l10n.ofOverdueHint,
                      child: Text(l10n.ofOverdueBadge,
                          key: ValueKey('of-overdue-${file.id}'),
                          style: TextStyle(color: scheme.error, fontWeight: FontWeight.w800)),
                    ),
                  if (file.autoShipped && !file.undone)
                    Icon(Icons.schedule_send_outlined, size: 16, color: scheme.onSurfaceVariant,
                        semanticLabel: l10n.ofStatusAutoShipped(DateFormat('y/MM/dd').format(file.shippedOn), '')),
                  if (file.proxy)
                    Text(l10n.prBadge,
                        key: ValueKey('of-proxy-${file.id}'),
                        style: TextStyle(color: scheme.tertiary, fontWeight: FontWeight.w600)),
                  if (file.principal != null) Text(l10n.prPrincipalLabel(file.principal!), style: muted),
                  if (file.shortTotal > 0) Text(l10n.ofCardShort(file.shortTotal), style: TextStyle(color: scheme.error)),
                  if (file.amountTotal != null && ref.watch(showPricesProvider))
                    Text(l10n.ofSummaryAmount(outboundMoney(file.amountTotal)), style: muted),
                  if ((file.weightG ?? 0) > 0) Text(l10n.ofSummaryWeight(outboundKg(file.weightG!)), style: muted),
                  if (file.undone) Text(l10n.ofUndone, style: TextStyle(color: scheme.error)),
                ]),
              ]),
            ),
            const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }
}

class _DayGrid extends StatelessWidget {
  const _DayGrid({required this.month, required this.byDay, required this.selected, required this.today, required this.onDay});

  final DateTime month;
  final Map<DateTime, int> byDay;
  final DateTime? selected;
  final DateTime today;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = DateTime(month.year, month.month).weekday % 7;
    final weekdays = [l10n.calSun, l10n.calMon, l10n.calTue, l10n.calWed, l10n.calThu, l10n.calFri, l10n.calSat];
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.15,
      mainAxisSpacing: 3,
      crossAxisSpacing: 3,
      children: [
        for (final (i, w) in weekdays.indexed)
          Center(
            child: Text(w,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: i == 0 ? scheme.error : (i == 6 ? scheme.primary : scheme.onSurfaceVariant))),
          ),
        for (var i = 0; i < lead; i++) const SizedBox.shrink(),
        for (var d = 1; d <= days; d++)
          () {
            final date = DateTime(month.year, month.month, d);
            final n = byDay[date] ?? 0;
            return InkWell(
              key: ValueKey('of-day-$d'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => onDay(date),
              child: Container(
                decoration: BoxDecoration(
                  color: selected == date ? scheme.primaryContainer : (n > 0 ? scheme.secondaryContainer.withValues(alpha: 0.6) : null),
                  borderRadius: BorderRadius.circular(8),
                  border: date == today ? Border.all(color: scheme.primary) : null,
                ),
                padding: const EdgeInsets.all(2),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('$d', style: theme.textTheme.bodySmall?.copyWith(fontWeight: n > 0 ? FontWeight.bold : null)),
                  if (n > 0)
                    Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.outbox_outlined, size: 11, color: scheme.primary),
                      Text('$n', key: ValueKey('of-count-$d'), style: theme.textTheme.labelSmall),
                    ]),
                ]),
              ),
            );
          }(),
      ],
    );
  }
}

/// 出庫日 未定 (0197): the planned lists with no day yet, each with
/// 「日程を入れる」 — on the 出庫カレンダー beside the days and on the
/// dashboard, until a day is set. Nothing at all when there are none (or
/// they cannot be read), so it takes no room.
class OutboundUndecidedCard extends ConsumerWidget {
  const OutboundUndecidedCard({super.key, this.compact = false, this.kind});

  /// The dashboard's: the first few, without the hint.
  final bool compact;

  /// 'stock' or 'proxy' (在庫外出荷, 0198) alone; null: both.
  final String? kind;

  Future<void> _setDay(BuildContext context, WidgetRef ref, OutboundFileSummary f, int? warehouseId) async {
    final l10n = AppLocalizations.of(context);
    final day = await showDatePicker(
        context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (day == null || !context.mounted) return;
    final r = await ref.read(outboundFileRepositoryProvider).reschedule(f.id, day);
    if (!context.mounted) return;
    switch (r) {
      case ApiSuccess():
        ref.invalidate(outboundUndecidedProvider(warehouseId));
        ref.invalidate(outboundFilesProvider);
        ref.invalidate(outboundFileDetailProvider(f.id));
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.ofRescheduled(DateFormat('y/MM/dd').format(day)))));
      case ApiFailure(:final message):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final warehouseId = ref.watch(activeWarehouseIdProvider);
    final files = [
      for (final f in ref.watch(outboundUndecidedProvider(warehouseId)).valueOrNull ?? const <OutboundFileSummary>[])
        if (kind == null || f.kind == kind) f,
    ];
    if (files.isEmpty) return const SizedBox.shrink();
    final shown = compact ? files.take(5).toList() : files;
    return Card(
      key: const ValueKey('of-undecided'),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.event_busy_outlined, color: theme.colorScheme.onTertiaryContainer),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(l10n.ofUndecidedTitle(files.length),
                  style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onTertiaryContainer)),
            ),
          ]),
          if (!compact) Text(l10n.ofUndecidedHint, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          for (final f in shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(key: ValueKey('of-undecided-${f.id}'), children: [
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => OutboundFileDetailScreen(fileId: f.id))),
                    child: Text(
                      [
                        if (kind == null && f.proxy) l10n.prBadge,
                        f.fileName,
                        if (f.shipTo != null) f.shipTo!.nameEn ?? f.shipTo!.name else if (f.destination != null) f.destination!,
                        l10n.prCardLines(f.lineCount, f.quantityTotal),
                        if (f.warehouseName != null) f.warehouseName!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: ValueKey('of-undecided-set-${f.id}'),
                  onPressed: () => _setDay(context, ref, f, warehouseId),
                  icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                  label: Text(l10n.ofSetDay),
                ),
              ]),
            ),
          if (compact && files.length > shown.length) Text(l10n.ofUndecidedMore(files.length - shown.length)),
        ]),
      ),
    );
  }
}
