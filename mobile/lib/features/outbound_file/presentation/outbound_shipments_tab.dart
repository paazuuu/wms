import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../packing/presentation/packing_screen.dart';
import '../../stock_import/presentation/stock_import_calendar_screen.dart' show calendarMaxWidth, calendarSideBySide;
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/outbound_file_repository.dart';
import 'outbound_calendar_tab.dart' show OutboundDayGrid;
import 'outbound_file_detail_screen.dart';

/// Where a list stands, for the 出庫 tab's filter.
enum ShipmentState {
  /// Out of the warehouse (or, for a 在庫外出荷, recorded with its day).
  shipped,

  /// 出庫予定 with a day.
  planned,

  /// No day yet (出庫予定日 未定): a 出庫予定 or a 在庫外出荷.
  undecided,

  /// Taken back.
  undone;

  static ShipmentState of(OutboundFileSummary f) {
    if (f.undone) return ShipmentState.undone;
    if (f.undecided) return ShipmentState.undecided;
    if (f.planned) return ShipmentState.planned;
    return ShipmentState.shipped;
  }
}

/// 出荷手配 › 出庫: every list of the month on a calendar, and beside it the
/// lists themselves — 出庫済み, 出庫予定 (with a day) and those with no day
/// yet (未定, listed apart: they are on no day) — narrowed by where they
/// stand, kind and warehouse; each opened to be put right (its rows, the
/// warehouse, the 出荷先, the gross weight), given a day or moved.
class OutboundShipmentsTab extends ConsumerStatefulWidget {
  const OutboundShipmentsTab({super.key});

  @override
  ConsumerState<OutboundShipmentsTab> createState() => _OutboundShipmentsTabState();
}

class _OutboundShipmentsTabState extends ConsumerState<OutboundShipmentsTab> with AutomaticKeepAliveClientMixin {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _day;

  /// null: all.
  ShipmentState? _state;

  /// null: both; 'stock' or 'proxy'.
  String? _kind;

  /// null: all warehouses.
  int? _warehouseId;

  @override
  bool get wantKeepAlive => true;

  OutboundMonthAsk get _ask => (year: _month.year, month: _month.month, warehouseId: _warehouseId);

  void _shift(int by) => setState(() {
        _month = DateTime(_month.year, _month.month + by);
        _day = null;
      });

  void _refresh([int? fileId]) {
    ref.invalidate(outboundFilesProvider);
    ref.invalidate(outboundUndecidedProvider);
    ref.invalidate(outboundCancelledUndatedProvider);
    if (fileId != null) ref.invalidate(outboundFileDetailProvider(fileId));
  }

  Future<void> _open(OutboundFileSummary f) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => OutboundFileDetailScreen(fileId: f.id)));
    if (mounted) _refresh(f.id);
  }

  Future<void> _packing(OutboundFileSummary f) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PackingScreen(fileId: f.id)));
    if (mounted) _refresh(f.id);
  }

  Future<void> _setDay(OutboundFileSummary f) async {
    final l10n = AppLocalizations.of(context);
    final day = await showDatePicker(
        context: context,
        initialDate: f.undecided ? DateTime.now() : f.shippedOn,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));
    if (day == null || !mounted) return;
    final r = await ref.read(outboundFileRepositoryProvider).reschedule(f.id, day);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess():
        _refresh(f.id);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.ofRescheduled(DateFormat('y/MM/dd').format(day)))));
      case ApiFailure(:final message):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
  }

  bool _keep(OutboundFileSummary f) =>
      (_state == null || ShipmentState.of(f) == _state) &&
      (_kind == null || f.kind == _kind) &&
      (_warehouseId == null || f.warehouseId == _warehouseId);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final monthAsync = ref.watch(outboundFilesProvider(_ask));
    final undecidedAsync = ref.watch(outboundUndecidedProvider(null));
    // Taken back while they had no day (0203): on no day, shown as 取り消し.
    final cancelledUndated = ref.watch(outboundCancelledUndatedProvider(null)).valueOrNull ?? const <OutboundFileSummary>[];
    final warehouses = ref.watch(warehouseOverviewProvider).valueOrNull?.warehouses ?? const [];

    final dated = [for (final f in monthAsync.valueOrNull ?? const <OutboundFileSummary>[]) if (_keep(f)) f];
    final undecided = [
      for (final f in [...?undecidedAsync.valueOrNull, ...cancelledUndated]) if (_keep(f)) f,
    ];
    final byDay = <DateTime, int>{};
    final cancelledByDay = <DateTime, int>{};
    for (final f in dated) {
      byDay[f.shippedOn] = (byDay[f.shippedOn] ?? 0) + 1;
      if (f.undone) cancelledByDay[f.shippedOn] = (cancelledByDay[f.shippedOn] ?? 0) + 1;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final shownDated = [for (final f in dated) if (_day == null || f.shippedOn == _day) f];
    // Lists with no day are on no day of the calendar: shown while no day is picked.
    final shownUndecided = _day == null ? undecided : const <OutboundFileSummary>[];

    final calendar = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: calendarMaxWidth),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          IconButton(key: const ValueKey('sh-prev'), onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: Center(
              child: Text(DateFormat('y/MM').format(_month), key: const ValueKey('sh-month'), style: theme.textTheme.titleMedium),
            ),
          ),
          IconButton(key: const ValueKey('sh-next'), onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
        ]),
        OutboundDayGrid(
            month: _month,
            byDay: byDay,
            cancelledByDay: cancelledByDay,
            selected: _day,
            today: today,
            onDay: (d) => setState(() => _day = _day == d ? null : d)),
        if (_day != null)
          TextButton(
            key: const ValueKey('sh-month-all'),
            onPressed: () => setState(() => _day = null),
            child: Text(l10n.ofCalMonthAll),
          ),
      ]),
    );

    final filters = Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
      for (final (s, label) in [
        (null, l10n.ofUdKindAll),
        (ShipmentState.shipped, l10n.shStateShipped),
        (ShipmentState.planned, l10n.shStatePlanned),
        (ShipmentState.undecided, l10n.shStateUndecided),
        (ShipmentState.undone, l10n.shStateUndone),
      ])
        ChoiceChip(
          key: ValueKey('sh-state-${s?.name ?? 'all'}'),
          label: Text(label),
          selected: _state == s,
          onSelected: (_) => setState(() => _state = s),
        ),
      const SizedBox(width: AppSpacing.sm),
      DropdownButton<String?>(
        key: const ValueKey('sh-kind'),
        value: _kind,
        isDense: true,
        items: [
          DropdownMenuItem<String?>(value: null, child: Text(l10n.shKindAll)),
          DropdownMenuItem<String?>(value: 'stock', child: Text(l10n.ofUdKindStock)),
          DropdownMenuItem<String?>(value: 'proxy', child: Text(l10n.obHubProxy)),
        ],
        onChanged: (v) => setState(() => _kind = v),
      ),
      const SizedBox(width: AppSpacing.sm),
      DropdownButton<int?>(
        key: const ValueKey('sh-warehouse'),
        value: _warehouseId,
        isDense: true,
        items: [
          DropdownMenuItem<int?>(value: null, child: Text(l10n.ofUdAllWarehouses)),
          for (final w in warehouses) DropdownMenuItem<int?>(value: w.id, child: Text(w.name)),
        ],
        onChanged: (v) => setState(() => _warehouseId = v),
      ),
    ]);

    final loading = monthAsync.isLoading || undecidedAsync.isLoading;
    final error = monthAsync.error ?? undecidedAsync.error;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final list = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (loading) const LinearProgressIndicator(),
      if (error != null)
        ErrorStateView(message: humanizeApiErrorMessage(l10n, '$error'), onRetry: _refresh)
      else ...[
        if (shownUndecided.isNotEmpty) ...[
          Text(l10n.shUndecidedHeading(shownUndecided.length),
              key: const ValueKey('sh-undecided-heading'),
              style: theme.textTheme.titleSmall?.copyWith(color: scheme.warning)),
          const SizedBox(height: AppSpacing.xs),
          for (final f in shownUndecided) _row(context, f),
          const SizedBox(height: AppSpacing.md),
        ],
        if (!(_state == ShipmentState.undecided)) ...[
          Text(
              _day == null
                  ? l10n.shMonthHeading(DateFormat('y/MM').format(_month), shownDated.length)
                  : l10n.shMonthHeading(DateFormat('y/MM/dd').format(_day!), shownDated.length),
              key: const ValueKey('sh-month-heading'),
              style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          for (final f in shownDated) _row(context, f),
        ],
        if (!loading && shownDated.isEmpty && shownUndecided.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(l10n.shEmpty, key: const ValueKey('sh-empty'), style: muted),
          ),
      ],
    ]);

    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= calendarSideBySide;
        return ListView(
          key: const ValueKey('sh-list'),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(children: [
              Expanded(child: Text(l10n.obHelpShipments, style: muted)),
              IconButton(tooltip: l10n.pkReload, icon: const Icon(Icons.refresh), onPressed: _refresh),
            ]),
            const SizedBox(height: AppSpacing.xs),
            filters,
            const SizedBox(height: AppSpacing.md),
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

  /// One list: a framed tile that opens it, its state as a badge, and what
  /// can be done to it where it stands.
  Widget _row(BuildContext context, OutboundFileSummary f) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final state = ShipmentState.of(f);
    final (badge, color) = switch (state) {
      ShipmentState.shipped => (l10n.shStateShipped, scheme.success),
      ShipmentState.planned => (l10n.shStatePlanned, scheme.primary),
      ShipmentState.undecided => (l10n.shStateUndecided, scheme.warning),
      ShipmentState.undone => ('✕ ${l10n.shStateUndone}', scheme.error),
    };
    final overdue = f.overdue(DateTime.now());
    final canDay = !f.undone && (f.planned || f.proxy);
    return Padding(
      key: ValueKey('sh-row-${f.id}'),
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10), side: BorderSide(color: scheme.outline.withValues(alpha: 0.6))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('sh-open-${f.id}'),
          mouseCursor: SystemMouseCursors.click,
          onTap: () => _open(f),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  key: ValueKey('sh-badge-${f.id}'),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: color.withValues(alpha: 0.6)),
                  ),
                  child: Text(badge, style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
                ),
                if (overdue) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Tooltip(
                    message: l10n.ofOverdueHint,
                    child: Text(l10n.ofOverdueBadge,
                        key: ValueKey('sh-overdue-${f.id}'),
                        style: theme.textTheme.labelMedium?.copyWith(color: scheme.error, fontWeight: FontWeight.w800)),
                  ),
                ],
                if (f.proxy) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(l10n.prBadge, style: theme.textTheme.labelMedium?.copyWith(color: scheme.tertiary)),
                ],
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    f.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                      decorationColor: scheme.primary.withValues(alpha: 0.5),
                      decoration: f.undone ? TextDecoration.lineThrough : TextDecoration.underline,
                    ),
                  ),
                ),
                Text(l10n.ofUdOpen, style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary)),
                Icon(Icons.chevron_right, color: scheme.primary),
              ]),
              const SizedBox(height: 4),
              Text(
                [
                  if (state == ShipmentState.undecided)
                    '${f.planned ? l10n.ofPlannedOn : l10n.ofShippedOn}: ${l10n.ofUndecided}'
                  else
                    '${f.planned ? l10n.ofPlannedOn : l10n.ofShippedOn}: ${DateFormat('y/MM/dd').format(f.shippedOn)}',
                  l10n.ofWarehouseFrom(f.warehouseName ?? '#${f.warehouseId}'),
                  if (f.shipTo != null) f.shipTo!.nameEn ?? f.shipTo!.name else if (f.destination != null) f.destination!,
                  if (f.planned || f.proxy) l10n.prCardLines(f.lineCount, f.quantityTotal) else l10n.ofCardLines(f.lineCount, f.shippedTotal),
                ].join(' · '),
                style: theme.textTheme.bodyMedium,
              ),
              if (f.createdByName != null && f.createdAt != null)
                Text(l10n.ofUdCreated(f.createdByName!, DateFormat('y/MM/dd HH:mm').format(f.createdAt!)), style: muted),
              if (!f.undone) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
                  if (canDay)
                    OutlinedButton.icon(
                      key: ValueKey('sh-set-day-${f.id}'),
                      onPressed: () => _setDay(f),
                      icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                      label: Text(f.undecided ? l10n.ofSetDay : l10n.ofReschedule),
                    ),
                  if (f.warehouseMovable)
                    OutlinedButton.icon(
                      key: ValueKey('sh-warehouse-${f.id}'),
                      onPressed: () async {
                        if (await changeOutboundWarehouse(context, ref, f) && mounted) _refresh(f.id);
                      },
                      icon: const Icon(Icons.warehouse_outlined, size: 18),
                      label: Text(l10n.ofWarehouseChange),
                    ),
                  OutlinedButton.icon(
                    key: ValueKey('sh-packing-${f.id}'),
                    onPressed: () => _packing(f),
                    icon: const Icon(Icons.scale_outlined, size: 18),
                    label: Text(l10n.ofUdPacking),
                  ),
                ]),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
