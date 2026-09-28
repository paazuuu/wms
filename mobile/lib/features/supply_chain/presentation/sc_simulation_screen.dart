import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/responsive.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/supply_chain_providers.dart';
import '../domain/supply_chain.dart';
import 'sc_labels.dart';
import 'sc_widgets.dart';

/// 利益シミュレーション (§6–7, §14–16, §20, §23): change the suppliers,
/// 掛率, freight, duty, customs, warehouse, labour, FX, price or volume —
/// any of them together — and see the profit next to the current one.
/// Nothing real changes (rule 3); each run is kept (rule 4). Up to five
/// scenarios can be compared side by side, and the choice stays with the
/// user (§16).
class ScSimulationScreen extends ConsumerStatefulWidget {
  const ScSimulationScreen({super.key, this.initialParams, this.initialName, this.scenarioId});

  final ScScenarioParams? initialParams;
  final String? initialName;
  final int? scenarioId;

  @override
  ConsumerState<ScSimulationScreen> createState() => _ScSimulationScreenState();
}

/// The ±% fields, in the order shown.
enum _Change { price, freight, sea, air, tariff, customs, warehouse, labor, overhead, fx, salesPrice, volume }

class _ScSimulationScreenState extends ConsumerState<ScSimulationScreen> {
  late final _name = TextEditingController(text: widget.initialName ?? '');
  late final Map<_Change, TextEditingController> _changes = {
    for (final c in _Change.values) c: TextEditingController(),
  };
  final Map<int, TextEditingController> _rates = {};
  String _routeMode = 'current';
  String _supplierChoice = 'current';
  Set<int>? _enabled;
  final List<ScSupplyTerm> _added = [];
  bool _applyRisk = false;
  int? _scenarioId;

  bool _busy = false;
  ScComparison? _result;
  final List<(String, ScScenarioParams)> _compare = [];
  ScMultiComparison? _multi;

  @override
  void initState() {
    super.initState();
    _scenarioId = widget.scenarioId;
    final p = widget.initialParams;
    if (p != null) _load(p);
  }

  void _load(ScScenarioParams p) {
    String pct(double? m) => scPercentFromMultiplier(m);
    _changes[_Change.price]!.text = pct(p.supplierPriceMultiplier);
    _changes[_Change.freight]!.text = pct(p.freightMultiplier);
    _changes[_Change.sea]!.text = pct(p.seaFreightMultiplier);
    _changes[_Change.air]!.text = pct(p.airFreightMultiplier);
    _changes[_Change.tariff]!.text = pct(p.tariffMultiplier);
    _changes[_Change.customs]!.text = pct(p.customsCostMultiplier);
    _changes[_Change.warehouse]!.text = pct(p.warehouseCostMultiplier);
    _changes[_Change.labor]!.text = pct(p.laborCostMultiplier);
    _changes[_Change.overhead]!.text = pct(p.overheadMultiplier);
    _changes[_Change.fx]!.text = pct(p.fxMultiplier);
    _changes[_Change.salesPrice]!.text = pct(p.salesPriceMultiplier);
    _changes[_Change.volume]!.text = pct(p.volumeMultiplier);
    for (final e in p.discountRates.entries) {
      _rates.putIfAbsent(e.key, TextEditingController.new).text = scFieldText(e.value * 100);
    }
    _routeMode = p.routeMode;
    _supplierChoice = p.supplierChoice;
    _enabled = p.enabledSuppliers == null ? null : {...p.enabledSuppliers!};
    _added
      ..clear()
      ..addAll(p.addedSuppliers);
    _applyRisk = p.applyRiskEvents;
  }

  @override
  void dispose() {
    _name.dispose();
    for (final c in [..._changes.values, ..._rates.values]) {
      c.dispose();
    }
    super.dispose();
  }

  ScScenarioParams get _params {
    double? m(_Change c) => scMultiplierFromPercent(_changes[c]!.text);
    return ScScenarioParams(
      supplierPriceMultiplier: m(_Change.price),
      discountRates: {
        for (final e in _rates.entries)
          if (scParse(e.value) != null) e.key: scParse(e.value)! / 100,
      },
      freightMultiplier: m(_Change.freight),
      seaFreightMultiplier: m(_Change.sea),
      airFreightMultiplier: m(_Change.air),
      tariffMultiplier: m(_Change.tariff),
      customsCostMultiplier: m(_Change.customs),
      warehouseCostMultiplier: m(_Change.warehouse),
      laborCostMultiplier: m(_Change.labor),
      overheadMultiplier: m(_Change.overhead),
      fxMultiplier: m(_Change.fx),
      salesPriceMultiplier: m(_Change.salesPrice),
      volumeMultiplier: m(_Change.volume),
      routeMode: _routeMode,
      supplierChoice: _supplierChoice,
      enabledSuppliers: _enabled,
      addedSuppliers: _added,
      applyRiskEvents: _applyRisk,
    );
  }

  String get _scenarioName {
    final n = _name.text.trim();
    return n.isEmpty ? AppLocalizations.of(context).scScenario : n;
  }

  void _snack(String m, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m), backgroundColor: danger ? Theme.of(context).colorScheme.error : null));
  }

  Future<void> _run() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final r = await ref.read(supplyChainRepositoryProvider).run(
          warehouseId: ref.read(scWarehouseIdProvider),
          params: _params,
          name: _scenarioName,
          scenarioId: _scenarioId,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    r.when(
      success: (c) {
        setState(() => _result = c);
        ref.invalidate(scResultsProvider);
      },
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final r = await ref.read(supplyChainRepositoryProvider).saveScenario(
          id: _scenarioId,
          name: _scenarioName,
          warehouseId: ref.read(scWarehouseIdProvider),
          params: _params,
        );
    if (!mounted) return;
    r.when(
      success: (id) {
        setState(() => _scenarioId = id);
        ref.invalidate(scScenariosProvider);
        _snack(l10n.scScenarioSaved);
      },
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  void _addToCompare() {
    final l10n = AppLocalizations.of(context);
    if (_compare.length >= 5) {
      _snack(l10n.scCompareFull, danger: true);
      return;
    }
    setState(() => _compare.add((_scenarioName, _params)));
  }

  Future<void> _runCompare() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final r = await ref.read(supplyChainRepositoryProvider).compare(warehouseId: ref.read(scWarehouseIdProvider), scenarios: _compare);
    if (!mounted) return;
    setState(() => _busy = false);
    r.when(
      success: (m) {
        setState(() => _multi = m);
        ref.invalidate(scResultsProvider);
      },
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  Future<void> _addSupplier(ScModel model) async {
    final t = await showDialog<ScSupplyTerm>(context: context, builder: (_) => _AddSupplierDialog(model: model));
    if (t != null) setState(() => _added.add(t));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canManage = ref.watch(scCanManageProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.featScSimulation)),
      body: ref.watch(scModelProvider).when(
            loading: () => LoadingView(message: l10n.loading),
            error: (e, _) => ErrorStateView(message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => ref.invalidate(scModelProvider)),
            data: (model) {
              final editor = _editor(context, l10n, model, canManage);
              final result = _results(context, l10n);
              if (isWideLayout(context)) {
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 440, child: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [editor])),
                  const VerticalDivider(width: 1),
                  Expanded(child: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: result)),
                ]);
              }
              return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [editor, ...result]);
            },
          ),
    );
  }

  Widget _editor(BuildContext context, AppLocalizations l10n, ScModel model, bool canManage) {
    final theme = Theme.of(context);
    final partners = model.partners;
    final labels = {
      _Change.price: l10n.scPriceChange,
      _Change.freight: l10n.scFreightChange,
      _Change.sea: l10n.scSeaChange,
      _Change.air: l10n.scAirChange,
      _Change.tariff: l10n.scTariffChange,
      _Change.customs: l10n.scCustomsChange,
      _Change.warehouse: l10n.scWarehouseChange,
      _Change.labor: l10n.scLaborChange,
      _Change.overhead: l10n.scOverheadChange,
      _Change.fx: l10n.scFxChange,
      _Change.salesPrice: l10n.scSalesPriceChange,
      _Change.volume: l10n.scVolumeChange,
    };
    double? currentRate(int partnerId) {
      final rates = model.terms.where((t) => t.partnerId == partnerId && t.discountRate != null).map((t) => t.discountRate!).toSet();
      return rates.length == 1 ? rates.first : null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(key: const ValueKey('sc-sim-name'), controller: _name, decoration: InputDecoration(labelText: l10n.scScenarioName, hintText: l10n.scCurrentConditions)),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.scSuppliersUsed, style: theme.textTheme.labelLarge),
        for (final p in partners)
          CheckboxListTile(
            key: ValueKey('sc-sim-supplier-${p.id}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _enabled == null || _enabled!.contains(p.id),
            title: Text(p.name),
            onChanged: (v) => setState(() {
              final all = {for (final x in partners) x.id};
              final next = {...(_enabled ?? all)};
              v == true ? next.add(p.id) : next.remove(p.id);
              _enabled = next.length == all.length ? null : next;
            }),
          ),
        for (final t in _added)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.add_business_outlined),
            title: Text('${t.partnerName} (${l10n.scHypothetical})'),
            subtitle: Text('${model.products.where((p) => p.id == t.productId).firstOrNull?.name ?? '#${t.productId}'} · ${scNumber(t.unitPrice ?? 0)} ${t.currency ?? ''}'),
            trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _added.remove(t))),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('sc-sim-add-supplier'),
            onPressed: () => _addSupplier(model),
            icon: const Icon(Icons.add),
            label: Text(l10n.scAddSupplier),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.scRouteChoice, style: theme.textTheme.labelLarge),
        Wrap(spacing: AppSpacing.xs, children: [
          for (final (v, label) in [
            ('current', l10n.scRouteCurrent),
            ('sea', l10n.scModeSea),
            ('air', l10n.scModeAir),
            ('cheapest', l10n.scRouteCheapest),
            ('fastest', l10n.scRouteFastest),
          ])
            ChoiceChip(
              key: ValueKey('sc-sim-route-$v'),
              label: Text(label),
              selected: _routeMode == v,
              onSelected: (_) => setState(() => _routeMode = v),
            ),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.scSupplierChoice, style: theme.textTheme.labelLarge),
        Wrap(spacing: AppSpacing.xs, children: [
          for (final (v, label) in [
            ('current', l10n.scChoiceCurrent),
            ('cheapest', l10n.scChoiceCheapest),
            ('fastest', l10n.scChoiceFastest),
          ])
            ChoiceChip(
              key: ValueKey('sc-sim-choice-$v'),
              label: Text(label),
              selected: _supplierChoice == v,
              onSelected: (_) => setState(() => _supplierChoice = v),
            ),
        ]),
        if (partners.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(l10n.scRatesBySupplier, style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
            for (final p in partners)
              ScNumberField(
                controller: _rates.putIfAbsent(p.id, TextEditingController.new),
                label: p.name,
                hint: currentRate(p.id) == null ? null : l10n.scRateNow(scRate(currentRate(p.id))),
                suffix: '%',
                width: 200,
                fieldKey: ValueKey('sc-sim-rate-${p.id}'),
              ),
          ]),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(l10n.scChanges, style: theme.textTheme.labelLarge),
        Text(l10n.scChangeHint, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.xs),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          for (final c in _Change.values)
            ScNumberField(controller: _changes[c]!, label: labels[c]!, suffix: '%', width: 130, fieldKey: ValueKey('sc-sim-${c.name}')),
        ]),
        SwitchListTile(
          key: const ValueKey('sc-sim-apply-risk'),
          contentPadding: EdgeInsets.zero,
          value: _applyRisk,
          title: Text(l10n.scApplyRiskEvents),
          onChanged: (v) => setState(() => _applyRisk = v),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton.icon(
          key: const ValueKey('sc-sim-run'),
          onPressed: _busy ? null : _run,
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.play_arrow),
          label: Text(l10n.scRun),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(spacing: AppSpacing.sm, children: [
          if (canManage)
            OutlinedButton.icon(key: const ValueKey('sc-sim-save'), onPressed: _busy ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(l10n.scSaveScenario)),
          OutlinedButton.icon(
            key: const ValueKey('sc-sim-add-compare'),
            onPressed: _busy ? null : _addToCompare,
            icon: const Icon(Icons.playlist_add),
            label: Text('${l10n.scAddToCompare} (${_compare.length}/5)'),
          ),
        ]),
      ],
    );
  }

  List<Widget> _results(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final r = _result;
    return [
      if (r != null) ...[
        ScSection(
          key: const ValueKey('sc-sim-result'),
          title: l10n.scResultTitle(r.scenario.name),
          subtitle: l10n.scSimulatedValues,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScCompareTable(current: r.baseline.summary, simulated: r.scenario.summary),
              const SizedBox(height: AppSpacing.md),
              Row(children: [
                Expanded(child: Text(l10n.scDifference, style: theme.textTheme.titleSmall)),
                Text(
                  scSigned(r.deltaProfit),
                  key: const ValueKey('sc-sim-delta'),
                  style: theme.textTheme.titleLarge?.copyWith(
                      fontFamily: AppFonts.mono, color: r.deltaProfit < 0 ? AppColors.danger : AppColors.success, fontWeight: FontWeight.w700),
                ),
              ]),
              if (r.deltaLeadTime != null && r.deltaLeadTime != 0)
                Text('${l10n.scLeadTime}: ${l10n.scDays(scNumber(r.baseline.summary.leadTimeDays ?? 0))} → ${l10n.scDays(scNumber(r.scenario.summary.leadTimeDays ?? 0))}',
                    style: theme.textTheme.bodySmall),
              if (r.drivers.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(l10n.scDrivers, style: theme.textTheme.labelLarge),
                ScDriversList(drivers: r.drivers),
              ],
            ],
          ),
        ),
        ScSection(title: l10n.scProductChanges, child: _ProductChanges(comparison: r)),
      ],
      if (_compare.isNotEmpty)
        ScSection(
          title: l10n.scCompare,
          subtitle: l10n.scNotBest,
          trailing: Wrap(children: [
            TextButton(onPressed: () => setState(() {
                  _compare.clear();
                  _multi = null;
                }), child: Text(l10n.scClearCompare)),
            FilledButton.tonal(key: const ValueKey('sc-sim-run-compare'), onPressed: _busy ? null : _runCompare, child: Text(l10n.scRunCompare)),
          ]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(spacing: AppSpacing.xs, children: [
                for (var i = 0; i < _compare.length; i++)
                  InputChip(label: Text(_compare[i].$1), onDeleted: () => setState(() => _compare.removeAt(i))),
              ]),
              if (_multi != null) _MultiTable(multi: _multi!),
            ],
          ),
        ),
    ];
  }
}

class _ProductChanges extends StatelessWidget {
  const _ProductChanges({required this.comparison});

  final ScComparison comparison;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final before = {for (final p in comparison.baseline.products) p.productId: p};
    final rows = [
      for (final p in comparison.scenario.products)
        if (before[p.productId] != null) (before[p.productId]!, p),
    ]..sort((a, b) => (a.$2.profitTotal - a.$1.profitTotal).compareTo(b.$2.profitTotal - b.$1.profitTotal));
    final changed = rows.where((r) => (r.$2.profitPerUnit - r.$1.profitPerUnit).abs() >= 0.005 || r.$1.chosen.firstOrNull?.key != r.$2.chosen.firstOrNull?.key).toList();
    if (changed.isEmpty) return Text(l10n.scNoChange);
    return Column(
      children: [
        for (final (a, b) in changed.take(20))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(b.name),
            subtitle: Text([
              '${a.chosen.map((c) => c.partnerName).join('/')} → ${b.chosen.map((c) => c.partnerName).join('/')}',
              '${l10n.scLandedCost} ${scUnitMoney(a.unit.landed)} → ${scUnitMoney(b.unit.landed)}',
              '${l10n.scMargin} ${scPercent(a.margin)} → ${scPercent(b.margin)}',
            ].join(' · ')),
            trailing: Text(scSigned(b.profitTotal - a.profitTotal),
                style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: AppFonts.mono, color: b.profitTotal < a.profitTotal ? AppColors.danger : AppColors.success)),
          ),
      ],
    );
  }
}

/// 現在 and up to five scenarios in columns (§16).
class _MultiTable extends StatelessWidget {
  const _MultiTable({required this.multi});

  final ScMultiComparison multi;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cols = [multi.baseline, ...multi.scenarios];
    DataRow row(String label, String Function(ScCompareColumn) f) =>
        DataRow(cells: [DataCell(Text(label)), for (final c in cols) DataCell(Text(f(c)))]);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        key: const ValueKey('sc-multi-table'),
        columns: [
          const DataColumn(label: SizedBox()),
          DataColumn(label: Text(l10n.scCurrent), numeric: true),
          for (final s in multi.scenarios) DataColumn(label: Text(s.name), numeric: true),
        ],
        rows: [
          row(l10n.scRevenue, (c) => scMoney(c.summary.revenue)),
          row(l10n.scTotalCost, (c) => scMoney(c.summary.totalCost)),
          row(l10n.scProfit, (c) => scMoney(c.summary.profit)),
          row(l10n.scMargin, (c) => scPercent(c.summary.margin)),
          row(l10n.scLeadTime, (c) => c.summary.leadTimeDays == null ? '—' : l10n.scDays(scNumber(c.summary.leadTimeDays!))),
          row(l10n.scDifference, (c) => identical(c, multi.baseline) ? '—' : scSigned(c.deltaProfit)),
          row(l10n.scHighRisks, (c) => '${c.risksHigh}'),
          row(l10n.scOverCapacity, (c) => '${c.bottlenecksExceeded}'),
        ],
      ),
    );
  }
}

/// A supplier that does not supply us yet, with the terms it offers (§6).
class _AddSupplierDialog extends StatefulWidget {
  const _AddSupplierDialog({required this.model});

  final ScModel model;

  @override
  State<_AddSupplierDialog> createState() => _AddSupplierDialogState();
}

class _AddSupplierDialogState extends State<_AddSupplierDialog> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _currency = TextEditingController();
  final _lead = TextEditingController();
  final _moq = TextEditingController();
  int? _productId;
  int? _partnerId;

  @override
  void initState() {
    super.initState();
    // The save button depends on the name and price as they are typed.
    for (final c in [_name, _price]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _price, _currency, _lead, _moq]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = widget.model;
    return AlertDialog(
      title: Text(l10n.scAddSupplier),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md, children: [
            SizedBox(
              width: 460,
              child: DropdownButtonFormField<int?>(
                initialValue: _partnerId,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.scAddedSupplier),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('—')),
                  for (final p in m.partners) DropdownMenuItem<int?>(value: p.id, child: Text(p.name)),
                ],
                onChanged: (v) => setState(() => _partnerId = v),
              ),
            ),
            if (_partnerId == null)
              SizedBox(width: 460, child: TextField(key: const ValueKey('sc-added-name'), controller: _name, decoration: InputDecoration(labelText: l10n.scSupplier))),
            SizedBox(
              width: 460,
              child: DropdownButtonFormField<int>(
                key: const ValueKey('sc-added-product'),
                initialValue: _productId,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.scProduct),
                items: [for (final p in m.products) DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis))],
                onChanged: (v) => setState(() => _productId = v),
              ),
            ),
            ScNumberField(controller: _price, label: l10n.scUnitPrice, fieldKey: const ValueKey('sc-added-price')),
            SizedBox(width: 140, child: TextField(controller: _currency, decoration: InputDecoration(labelText: l10n.scCurrency, hintText: 'JPY', isDense: true))),
            ScNumberField(controller: _lead, label: l10n.scLeadTimeDays, width: 140),
            ScNumberField(controller: _moq, label: l10n.scMoq, width: 140),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('sc-added-save'),
          onPressed: _productId == null || scParse(_price) == null || (_partnerId == null && _name.text.trim().isEmpty)
              ? null
              : () {
                  // A supplier not on file yet gets a stand-in id the engine
                  // never confuses with a real one.
                  final id = _partnerId ?? -(DateTime.now().millisecondsSinceEpoch % 1000000);
                  Navigator.pop(
                    context,
                    ScSupplyTerm(
                      partnerId: id,
                      productId: _productId!,
                      unitPrice: scParse(_price),
                      currency: _currency.text.trim().isEmpty ? null : _currency.text.trim().toUpperCase(),
                      leadTimeDays: scParse(_lead),
                      moq: int.tryParse(_moq.text.trim()),
                    ).withName(_partnerId == null ? _name.text.trim() : m.partnerName(_partnerId!)),
                  );
                },
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
