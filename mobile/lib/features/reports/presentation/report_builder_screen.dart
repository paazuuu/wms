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
  const ReportBuilderScreen({super.key});

  @override
  ConsumerState<ReportBuilderScreen> createState() => _ReportBuilderScreenState();
}

class _ReportBuilderScreenState extends ConsumerState<ReportBuilderScreen> {
  ReportSource _source = ReportSource.stockMovements;
  int? _warehouseId;
  String? _countryCode;
  final _status = TextEditingController();
  final _janCode = TextEditingController();
  final _category = TextEditingController();
  DateTime? _dateFrom;
  DateTime? _dateTo;

  /// The month picked ('YYYY-MM'), which sets both dates; null when the
  /// dates were picked by hand.
  String? _month;

  bool _running = false;
  ReportResult? _result;

  @override
  void dispose() {
    _status.dispose();
    _janCode.dispose();
    _category.dispose();
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
        // From the day's start to its very end, in this device's time, so
        // the last day is in the report.
        if (_dateFrom != null)
          'date_from': DateTime(_dateFrom!.year, _dateFrom!.month, _dateFrom!.day).toUtc().toIso8601String(),
        if (_dateTo != null)
          'date_to': DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day, 23, 59, 59, 999).toUtc().toIso8601String(),
      };

  void _pickMonth(String? m) => setState(() {
        _month = m;
        if (m == null) return;
        final y = int.parse(m.substring(0, 4)), mo = int.parse(m.substring(5));
        _dateFrom = DateTime(y, mo);
        _dateTo = DateTime(y, mo + 1, 0);
      });

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
      ];

  Future<void> _run() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _running = true);
    final result = await ref
        .read(reportRepositoryProvider)
        .run(_source, filters: _filters());
    if (!mounted) return;
    setState(() => _running = false);
    result.when(
      success: (r) => setState(() => _result = r),
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
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
          source: _source,
          filters: _filters(),
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
      _source = def.source;
      _warehouseId = def.filters['warehouse_id'] == null
          ? null
          : int.tryParse('${def.filters['warehouse_id']}');
      final country = (def.filters['country_code'] ?? '').toString();
      _countryCode = country.isEmpty ? null : country;
      _status.text = (def.filters['status'] ?? '').toString();
      _janCode.text = (def.filters['jan_code'] ?? '').toString();
      _category.text = (def.filters['category'] ?? '').toString();
      _dateFrom = DateTime.tryParse('${def.filters['date_from']}')?.toLocal();
      _dateTo = DateTime.tryParse('${def.filters['date_to']}')?.toLocal();
      _month = null;
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

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _dateFrom : _dateTo) ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _month = null;
      if (isFrom) {
        _dateFrom = picked;
      } else {
        _dateTo = picked;
      }
    });
  }

  String _fmtDate(DateTime? d) =>
      d == null ? '—' : '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final warehouseAsync = ref.watch(warehouseOverviewProvider);
    final savedAsync = ref.watch(savedReportListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reportTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          DropdownButtonFormField<ReportSource>(
            initialValue: _source,
            decoration: InputDecoration(labelText: l10n.reportSource),
            items: [
              for (final s in ReportSource.values)
                DropdownMenuItem(value: s, child: Text(_sourceLabel(l10n, s))),
            ],
            onChanged: (v) => setState(() => _source = v ?? _source),
          ),
          const SizedBox(height: AppSpacing.lg),
          warehouseAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (overview) {
              final countries = {for (final w in overview.warehouses) w.countryCode}.toList();
              final warehouses = [
                for (final w in overview.warehouses)
                  if (_countryCode == null || w.countryCode == _countryCode) w,
              ];
              return Column(
                children: [
                  if (countries.length > 1) ...[
                    DropdownButtonFormField<String?>(
                      key: const ValueKey('report-country'),
                      initialValue: _countryCode,
                      decoration: InputDecoration(labelText: l10n.reportCountry),
                      items: [
                        DropdownMenuItem(value: null, child: Text(l10n.reportAllCountries)),
                        for (final c in countries)
                          DropdownMenuItem(value: c, child: Text(countryLabel(l10n, c))),
                      ],
                      onChanged: (v) => setState(() {
                        _countryCode = v;
                        // A warehouse from another country would match nothing.
                        final keep = overview.warehouses
                            .any((w) => w.id == _warehouseId && (v == null || w.countryCode == v));
                        if (!keep) _warehouseId = null;
                      }),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  DropdownButtonFormField<int?>(
                    // Rebuilt when the country changes so a cleared choice shows.
                    key: ValueKey('report-warehouse-${_countryCode ?? ''}'),
                    initialValue: _warehouseId,
                    decoration: InputDecoration(labelText: l10n.reportWarehouse),
                    items: [
                      DropdownMenuItem(value: null, child: Text(l10n.reportAllWarehouses)),
                      for (final w in warehouses)
                        DropdownMenuItem(value: w.id, child: Text(w.name)),
                    ],
                    onChanged: (v) => setState(() => _warehouseId = v),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _status,
            decoration: InputDecoration(labelText: l10n.reportFilterStatus),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _janCode,
            decoration: InputDecoration(labelText: l10n.reportFilterJan),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _category,
            decoration: InputDecoration(labelText: l10n.reportFilterCategory),
          ),
          const SizedBox(height: AppSpacing.lg),
          // A month at once: the 1st to its last day.
          DropdownButtonFormField<String?>(
            key: ValueKey('report-month-$_month'),
            initialValue: _month,
            decoration: InputDecoration(labelText: l10n.reportMonth, prefixIcon: const Icon(Icons.calendar_month_outlined)),
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.reportMonthAny)),
              for (var i = 0; i < 24; i++)
                () {
                  final d = DateTime(DateTime.now().year, DateTime.now().month - i);
                  final v = '${d.year}-${d.month.toString().padLeft(2, '0')}';
                  return DropdownMenuItem(value: v, child: Text('${d.year}/${d.month.toString().padLeft(2, '0')}'));
                }(),
            ],
            onChanged: _pickMonth,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(isFrom: true),
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: l10n.reportDateFrom),
                    child: Text(_fmtDate(_dateFrom)),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(isFrom: false),
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: l10n.reportDateTo),
                    child: Text(_fmtDate(_dateTo)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _running ? null : _run,
                  icon: _running
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.play_arrow_outlined),
                  label: Text(l10n.reportRun),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: _result == null ? null : _saveCurrent,
                icon: const Icon(Icons.save_outlined),
                label: Text(l10n.reportSave),
              ),
            ],
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
                            subtitle: Text(_sourceLabel(l10n, def.source)),
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
          if (_result != null)
            ReportView(
              key: ValueKey(_result),
              result: _result!,
              title: l10n.reportDocTitle(_sourceLabel(l10n, _result!.source)),
              conditions: _conditions(l10n, warehouseAsync.valueOrNull?.warehouses ?? const []),
            ),
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
