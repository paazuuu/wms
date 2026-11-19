import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../../warehouse_context/presentation/warehouse_overview_screen.dart' show countryLabel;
import '../application/report_providers.dart';
import '../domain/report.dart';
import '../../warehouse_context/domain/warehouse.dart' show Warehouse;
import '../domain/report_table.dart';
import 'report_period.dart';
import 'report_view.dart';

/// Custom/saved report builder (spec §46 checklist item 10, 0037) — pick a
/// fixed data source, filter it, run it, and optionally save the
/// source+filters combination by name for reuse. Never arbitrary SQL: each
/// source is one of the fixed set the server defines.
///
/// With warehouses in more than one country, a country can be picked too
/// (0093): the warehouse list narrows to it and every row names its country,
/// so a column summed afterwards is never a cross-border total by accident.
class ReportBuilderScreen extends ConsumerStatefulWidget {
  const ReportBuilderScreen({super.key, this.embedded = false});

  /// Inside the レポート tabs: no bar of its own.
  final bool embedded;

  @override
  ConsumerState<ReportBuilderScreen> createState() => _ReportBuilderScreenState();
}

class _ReportBuilderScreenState extends ConsumerState<ReportBuilderScreen> {
  /// The data picked, any number at once; run each, shown one after another.
  final Set<ReportSource> _sources = {ReportSource.stockMovements};
  int? _warehouseId;
  String? _countryCode;
  final _status = TextEditingController();
  final _janCode = TextEditingController();
  final _category = TextEditingController();
  /// 入出庫履歴 (0218): the 識別コード, and words of the memo written when the
  /// stock's file was taken in.
  final _classCode = TextEditingController();
  final _note = TextEditingController();
  /// Null: every date.
  ReportPeriod? _period;

  DateTime? get _dateFrom => _period?.from;
  DateTime? get _dateTo => _period?.to;

  bool _running = false;
  List<ReportResult> _results = const [];

  /// The picked data in the order they are offered.
  List<ReportSource> get _picked => [for (final s in ReportSource.values) if (_sources.contains(s)) s];

  @override
  void dispose() {
    _status.dispose();
    _janCode.dispose();
    _category.dispose();
    _classCode.dispose();
    _note.dispose();
    super.dispose();
  }

  void _snack(String message, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: danger ? Theme.of(context).colorScheme.error : null,
      ));
  }

  Map<String, dynamic> _filters() => {
        if (_warehouseId != null) 'warehouse_id': _warehouseId,
        if (_countryCode != null) 'country_code': _countryCode,
        if (_status.text.trim().isNotEmpty) 'status': _status.text.trim(),
        if (_janCode.text.trim().isNotEmpty) 'jan_code': _janCode.text.trim(),
        if (_category.text.trim().isNotEmpty) 'category': _category.text.trim(),
        if (_classCode.text.trim().isNotEmpty) 'class_code': _classCode.text.trim().toUpperCase(),
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
        // The days in Japan's time, for 入出庫履歴 (0218): a day is a JST day
        // wherever the report is run.
        if (_dateFrom != null) 'day_from': _ymd(_dateFrom!),
        if (_dateTo != null) 'day_to': _ymd(_dateTo!),
        // From the day's start to its very end, in this device's time, so
        // the last day is in the report.
        if (_dateFrom != null)
          'date_from': DateTime(_dateFrom!.year, _dateFrom!.month, _dateFrom!.day).toUtc().toIso8601String(),
        if (_dateTo != null)
          'date_to': DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day, 23, 59, 59, 999).toUtc().toIso8601String(),
      };

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 状態・JAN・カテゴリ・識別コード・入荷時メモ, typed (or picked) in a
  /// dialog from the ⋮ menu.
  Future<void> _editConditions() async {
    final codes = await ref.read(reportClassCodesProvider.future).catchError((_) => const <String>[]);
    final notes = await ref.read(reportImportNotesProvider.future).catchError((_) => const <String>[]);
    if (!mounted) return;
    final r = await showDialog<List<String>>(
      context: context,
      builder: (_) => _ConditionsDialog(
        values: [_status.text, _janCode.text, _category.text, _classCode.text, _note.text],
        codes: codes,
        notes: notes,
      ),
    );
    if (r == null || !mounted) return;
    setState(() {
      _status.text = r[0];
      _janCode.text = r[1];
      _category.text = r[2];
      _classCode.text = r[3];
      _note.text = r[4];
    });
  }

  Future<void> _more(Object v) async {
    if (v is PeriodChoice) {
      final p = await choosePeriod(context, v, _period);
      if (p != null && mounted) setState(() => _period = p);
    } else if (v == 'conditions') {
      await _editConditions();
    }
  }

  /// The conditions as lines for the page, the Excel and the PDF.
  List<String> _conditions(AppLocalizations l10n, List<Warehouse> warehouses) => [
        if (_dateFrom != null || _dateTo != null) l10n.reportCondPeriod(_fmtDate(_dateFrom), _fmtDate(_dateTo)),
        l10n.reportCondItem(
            l10n.reportWarehouse,
            _warehouseId == null
                ? l10n.reportAllWarehouses
                : warehouses.where((w) => w.id == _warehouseId).map((w) => w.name).firstOrNull ?? '$_warehouseId'),
        if (_countryCode != null) l10n.reportCondItem(l10n.reportCountry, countryLabel(l10n, _countryCode!)),
        if (_status.text.trim().isNotEmpty) l10n.reportCondItem(l10n.reportFilterStatus, _status.text.trim()),
        if (_janCode.text.trim().isNotEmpty) l10n.reportCondItem(l10n.reportFilterJan, _janCode.text.trim()),
        if (_category.text.trim().isNotEmpty) l10n.reportCondItem(l10n.reportFilterCategory, _category.text.trim()),
        if (_classCode.text.trim().isNotEmpty) l10n.reportCondItem(l10n.lgClassCode, _classCode.text.trim().toUpperCase()),
        if (_note.text.trim().isNotEmpty) l10n.reportCondItem(l10n.reportFilterNote, _note.text.trim()),
      ];

  Future<void> _run() async {
    final l10n = AppLocalizations.of(context);
    if (_sources.isEmpty) {
      _snack(l10n.reportSourcesNone);
      return;
    }
    setState(() => _running = true);
    final out = <ReportResult>[];
    for (final s in _picked) {
      final result = await ref.read(reportRepositoryProvider).run(s, filters: _filters());
      if (!mounted) return;
      result.when(
        success: out.add,
        failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
      );
    }
    setState(() {
      _running = false;
      _results = out;
    });
  }

  Future<void> _saveCurrent() async {
    final l10n = AppLocalizations.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(title: l10n.reportSaveTitle),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;

    final result = await ref.read(reportRepositoryProvider).save(
          name: name.trim(),
          source: _picked.first,
          filters: {..._filters(), 'sources': [for (final s in _picked) s.wire]},
        );
    if (!mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(savedReportListProvider);
        _snack(l10n.reportSaved);
      },
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  Future<void> _loadSaved(ReportDefinition def) async {
    setState(() {
      final wires = def.filters['sources'];
      _sources
        ..clear()
        ..addAll(wires is List && wires.isNotEmpty ? [for (final w in wires) ReportSource.parse('$w')] : [def.source]);
      _warehouseId = def.filters['warehouse_id'] == null
          ? null
          : int.tryParse('${def.filters['warehouse_id']}');
      final country = (def.filters['country_code'] ?? '').toString();
      _countryCode = country.isEmpty ? null : country;
      _status.text = (def.filters['status'] ?? '').toString();
      _janCode.text = (def.filters['jan_code'] ?? '').toString();
      _category.text = (def.filters['category'] ?? '').toString();
      _classCode.text = (def.filters['class_code'] ?? '').toString();
      _note.text = (def.filters['note'] ?? '').toString();
      final from = DateTime.tryParse('${def.filters['date_from']}')?.toLocal();
      final to = DateTime.tryParse('${def.filters['date_to']}')?.toLocal();
      _period = from == null || to == null
          ? null
          : ReportPeriod(DateTime(from.year, from.month, from.day), DateTime(to.year, to.month, to.day));
    });
    await _run();
  }

  Future<void> _deleteSaved(ReportDefinition def) async {
    final l10n = AppLocalizations.of(context);
    final result = await ref.read(reportRepositoryProvider).delete(def.id);
    if (!mounted) return;
    result.when(
      success: (_) => ref.invalidate(savedReportListProvider),
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  String _sourceLabel(AppLocalizations l10n, ReportSource source) => switch (source) {
        ReportSource.stockMovements => l10n.reportSourceStockMovements,
        ReportSource.inspections => l10n.reportSourceInspections,
        ReportSource.transfers => l10n.reportSourceTransfers,
        ReportSource.shipments => l10n.reportSourceShipments,
        ReportSource.purchaseOrders => l10n.reportSourcePurchaseOrders,
        ReportSource.salesOrders => l10n.reportSourceSalesOrders,
        ReportSource.workOrders => l10n.reportSourceWorkOrders,
        ReportSource.auditLog => l10n.reportSourceAuditLog,
        ReportSource.products => l10n.reportSourceProducts,
      };

  String _sourceHelp(AppLocalizations l10n, ReportSource source) => switch (source) {
        ReportSource.stockMovements => l10n.reportSourceHelpStockMovements,
        ReportSource.inspections => l10n.reportSourceHelpInspections,
        ReportSource.transfers => l10n.reportSourceHelpTransfers,
        ReportSource.shipments => l10n.reportSourceHelpShipments,
        ReportSource.purchaseOrders => l10n.reportSourceHelpPurchaseOrders,
        ReportSource.salesOrders => l10n.reportSourceHelpSalesOrders,
        ReportSource.workOrders => l10n.reportSourceHelpWorkOrders,
        ReportSource.auditLog => l10n.reportSourceHelpAuditLog,
        ReportSource.products => l10n.reportSourceHelpProducts,
      };

  String _fmtDate(DateTime? d) =>
      d == null ? '—' : '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final warehouseAsync = ref.watch(warehouseOverviewProvider);
    final savedAsync = ref.watch(savedReportListProvider);

    final scheme = theme.colorScheme;
    // Conditions set behind ⋮, shown so they are not forgotten.
    final hidden = [
      (l10n.reportFilterStatus, _status),
      (l10n.reportFilterJan, _janCode),
      (l10n.reportFilterCategory, _category),
      (l10n.lgClassCode, _classCode),
      (l10n.reportFilterNote, _note),
    ].where((e) => e.$2.text.trim().isNotEmpty).toList();

    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: Text(l10n.reportTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // The data, side by side, any number at once; what each is on hover.
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(l10n.reportSource, style: theme.textTheme.labelLarge),
            for (final s in ReportSource.values)
              Tooltip(
                message: _sourceHelp(l10n, s),
                waitDuration: const Duration(milliseconds: 300),
                child: FilterChip(
                  key: ValueKey('report-source-${s.wire}'),
                  visualDensity: VisualDensity.compact,
                  label: Text(_sourceLabel(l10n, s)),
                  selected: _sources.contains(s),
                  onSelected: (v) => setState(() => v ? _sources.add(s) : _sources.remove(s)),
                ),
              ),
          ]),
          const SizedBox(height: AppSpacing.md),
          // The conditions in one row; the rarer ones behind ⋮.
          Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md, crossAxisAlignment: WrapCrossAlignment.center, children: [
            ...warehouseAsync.when(
              loading: () => const <Widget>[],
              error: (_, __) => const <Widget>[],
              data: (overview) {
                final countries = {for (final w in overview.warehouses) w.countryCode}.toList();
                final warehouses = [
                  for (final w in overview.warehouses)
                    if (_countryCode == null || w.countryCode == _countryCode) w,
                ];
                return [
                  if (countries.length > 1)
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String?>(
                        key: const ValueKey('report-country'),
                        initialValue: _countryCode,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: l10n.reportCountry, isDense: true),
                        items: [
                          DropdownMenuItem(value: null, child: Text(l10n.reportAllCountries)),
                          for (final c in countries) DropdownMenuItem(value: c, child: Text(countryLabel(l10n, c))),
                        ],
                        onChanged: (v) => setState(() {
                          _countryCode = v;
                          // A warehouse from another country would match nothing.
                          final keep = overview.warehouses
                              .any((w) => w.id == _warehouseId && (v == null || w.countryCode == v));
                          if (!keep) _warehouseId = null;
                        }),
                      ),
                    ),
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<int?>(
                      // Rebuilt when the country changes so a cleared choice shows.
                      key: ValueKey('report-warehouse-${_countryCode ?? ''}'),
                      initialValue: _warehouseId,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l10n.reportWarehouse, isDense: true),
                      items: [
                        DropdownMenuItem(value: null, child: Text(l10n.reportAllWarehouses)),
                        for (final w in warehouses) DropdownMenuItem(value: w.id, child: Text(w.name)),
                      ],
                      onChanged: (v) => setState(() => _warehouseId = v),
                    ),
                  ),
                ];
              },
            ),
            ReportPeriodField(period: _period, allowNone: true, onChanged: (p) => setState(() => _period = p)),
            PopupMenuButton<Object>(
              key: const ValueKey('report-more'),
              tooltip: l10n.rpMore,
              icon: const Icon(Icons.more_vert),
              onSelected: _more,
              itemBuilder: (_) => [
                ...periodMenuItems(l10n, days: true),
                const PopupMenuDivider(),
                PopupMenuItem(
                    value: 'conditions', key: const ValueKey('report-conditions'), child: Text(l10n.rpConditions)),
              ],
            ),
            FilledButton.icon(
              key: const ValueKey('report-run'),
              onPressed: _running ? null : _run,
              icon: _running
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_arrow_outlined),
              label: Text(l10n.reportRun),
            ),
            // The conditions kept by name — not the contents (that is the download).
            Tooltip(
              message: l10n.reportSaveHint,
              child: OutlinedButton.icon(
                key: const ValueKey('report-save'),
                onPressed: _sources.isEmpty ? null : _saveCurrent,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: Text(l10n.reportSave),
              ),
            ),
          ]),
          if (hidden.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
                for (final (label, c) in hidden)
                  InputChip(
                    key: ValueKey('report-cond-$label'),
                    label: Text(l10n.reportCondItem(label.replaceAll(RegExp(r'（.*?）'), ''), c.text.trim())),
                    onPressed: _editConditions,
                    onDeleted: () => setState(c.clear),
                    deleteIconColor: scheme.onSurfaceVariant,
                  ),
              ]),
            ),
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.reportSavedTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          savedAsync.when(
            // LoadingView/ErrorStateView are built for a full-page Expanded
            // slot (one is a bare ListView) — inside this screen's own
            // outer ListView they'd get unbounded height, so both are
            // capped in a fixed-height box instead.
            loading: () => SizedBox(height: 120, child: LoadingView(message: l10n.loading)),
            error: (e, _) => SizedBox(
              height: 160,
              child: ErrorStateView(
                message: '$e',
                onRetry: () => ref.invalidate(savedReportListProvider),
              ),
            ),
            data: (defs) => defs.isEmpty
                ? Text(l10n.reportSavedEmpty,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant))
                : Column(
                    children: [
                      for (final def in defs)
                        Card(
                          child: ListTile(
                            title: Text(def.name),
                            subtitle: Text(() {
                              final wires = def.filters['sources'];
                              final list = wires is List && wires.isNotEmpty
                                  ? [for (final w in wires) ReportSource.parse('$w')]
                                  : [def.source];
                              return list.map((s) => _sourceLabel(l10n, s)).join('・');
                            }()),
                            onTap: () => _loadSaved(def),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteSaved(def),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Each kind of data picked, one after another.
          for (final r in _results) ...[
            if (_results.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(l10n.reportDocTitle(_sourceLabel(l10n, r.source)),
                    key: ValueKey('report-section-${r.source.wire}'), style: theme.textTheme.titleMedium),
              ),
            ReportView(
              key: ValueKey(r),
              table: reportTable(r),
              title: l10n.reportDocTitle(_sourceLabel(l10n, r.source)),
              conditions: _conditions(l10n, warehouseAsync.valueOrNull?.warehouses ?? const []),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ],
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title});

  final String title;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _name,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.reportName),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _name.text),
          child: Text(l10n.reportSave),
        ),
      ],
    );
  }
}

/// 状態・JAN・カテゴリ: the conditions used now and then.
class _ConditionsDialog extends StatefulWidget {
  const _ConditionsDialog({required this.values, this.codes = const [], this.notes = const []});

  final List<String> values;

  /// What 識別コード and 入荷時メモ can be picked from (0218).
  final List<String> codes;
  final List<String> notes;

  @override
  State<_ConditionsDialog> createState() => _ConditionsDialogState();
}

class _ConditionsDialogState extends State<_ConditionsDialog> {
  late final _c = [for (final v in widget.values) TextEditingController(text: v)];

  @override
  void dispose() {
    for (final c in _c) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget field(String key, int i, String label, {List<String> pick = const [], String? helper}) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: TextField(
            key: ValueKey(key),
            controller: _c[i],
            decoration: InputDecoration(
              labelText: label,
              helperText: helper,
              helperMaxLines: 2,
              // Typed, or picked from what is there.
              suffixIcon: pick.isEmpty
                  ? null
                  : PopupMenuButton<String>(
                      key: ValueKey('$key-pick'),
                      tooltip: l10n.reportPick,
                      icon: const Icon(Icons.arrow_drop_down),
                      onSelected: (v) => setState(() => _c[i].text = v),
                      itemBuilder: (_) => [
                        for (final v in pick)
                          PopupMenuItem(
                            value: v,
                            key: ValueKey('$key-pick-$v'),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 320),
                              child: Text(v, maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        );
    return AlertDialog(
      title: Text(l10n.rpMore),
      content: SizedBox(
        width: 360,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          field('report-status', 0, l10n.reportFilterStatus),
          field('report-jan', 1, l10n.reportFilterJan),
          field('report-category', 2, l10n.reportFilterCategory),
          field('report-class-code', 3, l10n.lgClassCode, pick: widget.codes, helper: l10n.reportOnlyMovements),
          field('report-note', 4, l10n.reportFilterNote, pick: widget.notes, helper: l10n.reportNoteHelp),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('report-conditions-ok'),
          onPressed: () => Navigator.pop(context, [for (final c in _c) c.text.trim()]),
          child: Text(l10n.rpApply),
        ),
      ],
    );
  }
}
