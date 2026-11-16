import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../admin/data/menu_visibility_repository.dart' show showPricesProvider;
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/work_log_repository.dart';
import '../domain/report_table.dart';
import 'report_period.dart';
import 'report_view.dart';

/// The kinds of work, in the order they are offered.
const workLogKinds = ['receipt', 'unplanned', 'outbound', 'proxy', 'memo'];

String workLogKindLabel(AppLocalizations l10n, String kind) => switch (kind) {
      'receipt' => l10n.wlKindReceipt,
      'unplanned' => l10n.wlKindUnplanned,
      'outbound' => l10n.wlKindOutbound,
      'proxy' => l10n.wlKindProxy,
      _ => l10n.wlKindMemo,
    };

String _status(AppLocalizations l10n, WorkLogEntry e) {
  final s = switch ((e.kind, e.status)) {
    (_, 'awaiting_inspection') => l10n.wlStAwaiting,
    (_, 'stock_done') => l10n.wlStDone,
    (_, 'planned') => l10n.wlStPlanned,
    ('proxy', 'shipped') => l10n.wlStRecorded,
    (_, 'shipped') => l10n.wlStShipped,
    _ => e.status ?? '',
  };
  return [s, if (e.short != null) l10n.wkShort(e.short!)].where((t) => t.isNotEmpty).join(' / ');
}

final _num = NumberFormat('#,##0');
final _day = DateFormat('y/MM/dd');

String _money(double v, String? currency) =>
    (currency == null || currency.toUpperCase() == 'JPY') ? '¥${_num.format(v)}' : '${currency.toUpperCase()} ${_num.format(v)}';

/// The month's work as a table for [ReportView]: 日付, 区分, 倉庫, 取引先,
/// ファイル, 行数, 数量, 状態, 担当 and the memos in full; 金額 too when
/// [amounts].
ReportTable workLogTable(AppLocalizations l10n, List<WorkLogEntry> entries, {bool amounts = false}) {
  final cols = [
    ReportColumn('day', l10n.wlColDay, flex: 1.25),
    ReportColumn('kind', l10n.wlColKind, flex: 1.2),
    ReportColumn('warehouse', l10n.wlColWarehouse, flex: 0.85),
    ReportColumn('partner', l10n.wlColPartner, flex: 1.8),
    ReportColumn('file', l10n.wlColFile, flex: 1.3),
    ReportColumn('lines', l10n.wlColLines, numeric: true, flex: 0.55),
    ReportColumn('qty', l10n.wlColQty, numeric: true, flex: 0.7),
    ReportColumn('status', l10n.wlColStatus, flex: 0.95),
    ReportColumn('by', l10n.wlColBy, flex: 1.0),
    if (amounts) ReportColumn('amount', l10n.wlColAmount, flex: 1.2, wrap: true),
    ReportColumn('note', l10n.wlColNote, flex: 2.25, wrap: true),
  ];
  return ReportTable(columns: cols, rows: [
    for (final e in entries)
      [
        _day.format(e.day),
        workLogKindLabel(l10n, e.kind),
        e.warehouseName ?? '',
        e.partner ?? '',
        e.fileName ?? '',
        e.lines == null ? '' : _num.format(e.lines),
        e.quantity == null ? '' : _num.format(e.quantity),
        _status(l10n, e),
        e.by ?? '',
        if (amounts)
          [
            if (e.amount != null) _money(e.amount!, e.currency),
            if (e.fee != null) l10n.wlFee(_money(e.fee!, null)),
            if (e.freight != null) l10n.wlFreight(_money(e.freight!, null)),
          ].join('\n'),
        [
          if (e.note != null) e.note!,
          if (e.docDay != null) l10n.wlDocDay(_day.format(e.docDay!)),
          if (e.cartons != null && e.cartons! > 0) l10n.wlCartons(e.cartons!),
        ].join(' / '),
      ],
  ]);
}

/// 作業実績 (0215): a month's receipts (with their suppliers), shipments
/// (where they went), 在庫外出荷 and the warehouse memos, each with what was
/// written on it — as A4 pages to keep, narrowed by any column (supplier,
/// warehouse, ship-to …), saved as Excel or PDF. Amounts are left out unless
/// asked for: a record like this is often handed on.
class WorkLogScreen extends ConsumerStatefulWidget {
  const WorkLogScreen({super.key, this.embedded = false});

  /// Inside the レポート tabs: no bar of its own.
  final bool embedded;

  @override
  ConsumerState<WorkLogScreen> createState() => _WorkLogScreenState();
}

class _WorkLogScreenState extends ConsumerState<WorkLogScreen> {
  ReportPeriod _period = ReportPeriod.month(DateTime.now());
  int? _warehouseId;
  final Set<String> _kinds = {...workLogKinds};
  bool _amounts = false;
  bool _loading = false;
  List<WorkLogEntry>? _entries;
  String? _error;
  int _run = 0;

  DateTime get _from => _period.from;
  DateTime get _to => _period.to;

  /// The ⋮ menu: other periods, and the amounts.
  Future<void> _more(Object v) async {
    if (v is PeriodChoice) {
      final p = await choosePeriod(context, v, _period);
      if (p != null && mounted) _change(() => _period = p);
    } else if (v == 'amounts') {
      _change(() => _amounts = !_amounts);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await ref.read(workLogRepositoryProvider).list(
          from: _from,
          to: _to,
          warehouseId: _warehouseId,
          amounts: _amounts && ref.read(showPricesProvider),
        );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _run++;
      switch (r) {
        case ApiSuccess(:final data):
          _entries = data;
        case ApiFailure(:final message):
          _error = humanizeApiErrorMessage(l10n, message);
      }
    });
  }

  void _change(VoidCallback f) {
    setState(f);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final warehouses = ref.watch(warehouseOverviewProvider).valueOrNull?.warehouses ?? const [];
    final prices = ref.watch(showPricesProvider);
    final shown = [for (final e in _entries ?? const <WorkLogEntry>[]) if (_kinds.contains(e.kind)) e];
    int count(String k) => shown.where((e) => e.kind == k).length;
    final monthLabel = _period.label;

    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: Text(l10n.featWorkLog)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md, crossAxisAlignment: WrapCrossAlignment.center, children: [
            ReportPeriodField(period: _period, onChanged: (p) => _change(() => _period = p ?? _period)),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<int?>(
                key: const ValueKey('wl-warehouse'),
                initialValue: _warehouseId,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.reportWarehouse, isDense: true),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.reportAllWarehouses)),
                  for (final w in warehouses) DropdownMenuItem(value: w.id, child: Text(w.name)),
                ],
                onChanged: (v) => _change(() => _warehouseId = v),
              ),
            ),
            // Used now and then: kept behind ⋮ — 3/6/12 months, a span, the amounts.
            PopupMenuButton<Object>(
              key: const ValueKey('wl-more'),
              tooltip: l10n.rpMore,
              icon: const Icon(Icons.more_vert),
              onSelected: _more,
              itemBuilder: (_) => [
                ...periodMenuItems(l10n),
                if (prices) ...[
                  const PopupMenuDivider(),
                  CheckedPopupMenuItem(
                    key: const ValueKey('wl-amounts'),
                    value: 'amounts',
                    checked: _amounts,
                    child: Text(l10n.wlAmounts),
                  ),
                ],
              ],
            ),
            // What is on but out of sight, shown so it is not forgotten.
            if (prices && _amounts)
              InputChip(
                key: const ValueKey('wl-amounts-on'),
                avatar: const Icon(Icons.currency_yen, size: 16),
                label: Text(l10n.wlAmounts),
                onDeleted: () => _change(() => _amounts = false),
              ),
            // Which kinds of work are in it.
            for (final k in workLogKinds)
              FilterChip(
                key: ValueKey('wl-kind-$k'),
                visualDensity: VisualDensity.compact,
                label: Text(workLogKindLabel(l10n, k)),
                selected: _kinds.contains(k),
                onSelected: (v) => setState(() => v ? _kinds.add(k) : _kinds.remove(k)),
              ),
          ]),
          if (prices && _amounts)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(l10n.wlAmountsHint, style: theme.textTheme.bodySmall?.copyWith(color: scheme.warning)),
            ),
          const SizedBox(height: AppSpacing.lg),
          if (_loading && _entries == null)
            const LinearProgressIndicator()
          else if (_error != null)
            Text(_error!, key: const ValueKey('wl-error'), style: TextStyle(color: scheme.error))
          else if (_kinds.isEmpty)
            Text(l10n.wlNoKinds, style: theme.textTheme.bodyMedium)
          else if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Text(l10n.wlEmpty, key: const ValueKey('wl-empty'), textAlign: TextAlign.center),
            )
          else ...[
            if (_loading) const LinearProgressIndicator(),
            ReportView(
              key: ValueKey('wl-$_run-${_kinds.join()}'),
              table: workLogTable(l10n, shown, amounts: _amounts && prices),
              title: l10n.wlDocTitle(monthLabel),
              conditions: [
                l10n.reportCondPeriod(DateFormat('y/MM/dd').format(_from), DateFormat('y/MM/dd').format(_to)),
                l10n.reportCondItem(
                    l10n.reportWarehouse,
                    _warehouseId == null
                        ? l10n.reportAllWarehouses
                        : warehouses.where((w) => w.id == _warehouseId).map((w) => w.name).firstOrNull ?? ''),
                if (_kinds.length < workLogKinds.length)
                  l10n.reportCondItem(l10n.wlKinds, [for (final k in workLogKinds) if (_kinds.contains(k)) workLogKindLabel(l10n, k)].join('、')),
                l10n.wlSummary(count('receipt') + count('unplanned'), count('outbound'), count('proxy'), count('memo')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
