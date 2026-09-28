import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../partners/application/trading_partner_providers.dart';
import '../../partners/domain/trading_partner.dart';
import '../application/supply_chain_providers.dart';
import '../domain/supply_chain.dart';
import 'sc_labels.dart';
import 'sc_widgets.dart';

// The master editors shared by the screens. Each saves through its own RPC
// (0107), shows the server's refusal as words, and refreshes what reads it.

/// Runs [save]; on success refreshes the supply chain reads and pops true.
Future<void> scSaveAndClose(BuildContext context, WidgetRef ref, Future<dynamic> Function() save,
    void Function(String) onError) async {
  final l10n = AppLocalizations.of(context);
  final r = await save();
  if (!context.mounted) return;
  r.when(
    success: (_) {
      refreshSupplyChain(ref);
      Navigator.pop(context, true);
    },
    failure: (f) => onError(humanizeApiErrorMessage(l10n, f.message)),
  );
}

final _suppliersProvider = FutureProvider.autoDispose<List<TradingPartner>>((ref) async {
  final r = await ref.watch(tradingPartnerRepositoryProvider).list();
  return r.when(
    success: (d) => d.where((p) => p.kind != PartnerKind.customer).toList(),
    failure: (f) => throw Exception(f.message),
  );
});

/// A product from a supplier: price, 掛率, currency, MOQ, lead time, route.
class ScTermDialog extends ConsumerStatefulWidget {
  const ScTermDialog({super.key, required this.productId, this.term, required this.model});

  final int productId;
  final ScSupplyTerm? term;
  final ScModel model;

  @override
  ConsumerState<ScTermDialog> createState() => _ScTermDialogState();
}

class _ScTermDialogState extends ConsumerState<ScTermDialog> {
  late int? _partnerId = widget.term?.partnerId;
  late final _list = TextEditingController(text: scFieldText(widget.term?.listPrice));
  late final _rate = TextEditingController(text: widget.term?.discountRate == null ? '' : scFieldText(widget.term!.discountRate! * 100));
  late final _unit = TextEditingController(text: scFieldText(widget.term?.unitPrice));
  late final _currency = TextEditingController(text: widget.term?.currency ?? '');
  late final _moq = TextEditingController(text: widget.term?.moq?.toString() ?? '');
  late final _lot = TextEditingController(text: widget.term?.orderLot?.toString() ?? '');
  late final _lead = TextEditingController(text: scFieldText(widget.term?.leadTimeDays));
  late final _terms = TextEditingController(text: widget.term?.paymentTerms ?? '');
  late final _sku = TextEditingController(text: widget.term?.supplierSku ?? '');
  late int? _routeId = widget.term?.defaultRouteId;
  late bool _primary = widget.term?.isPrimary ?? false;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_list, _rate, _unit, _currency, _moq, _lot, _lead, _terms, _sku]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_partnerId == null) return;
    setState(() => _busy = true);
    final rate = scParse(_rate);
    final term = ScSupplyTerm(
      id: widget.term?.id,
      partnerId: _partnerId!,
      productId: widget.productId,
      supplierSku: _sku.text.trim().isEmpty ? null : _sku.text.trim(),
      listPrice: scParse(_list),
      discountRate: rate == null ? null : rate / 100,
      unitPrice: scParse(_unit),
      currency: _currency.text.trim().isEmpty ? null : _currency.text.trim().toUpperCase(),
      moq: int.tryParse(_moq.text.trim()),
      orderLot: int.tryParse(_lot.text.trim()),
      leadTimeDays: scParse(_lead),
      paymentTerms: _terms.text.trim().isEmpty ? null : _terms.text.trim(),
      defaultRouteId: _routeId,
      isPrimary: _primary,
    );
    await scSaveAndClose(context, ref, () => ref.read(supplyChainRepositoryProvider).saveTerm(term), (m) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = m;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final partners = ref.watch(_suppliersProvider).valueOrNull ?? const <TradingPartner>[];
    final ids = partners.map((p) => p.id).toSet();
    final routes = widget.model.routes;
    return AlertDialog(
      title: Text(l10n.scSupplyTerms),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              SizedBox(
                width: 520,
                child: DropdownButtonFormField<int>(
                  key: const ValueKey('sc-term-partner'),
                  initialValue: ids.contains(_partnerId) ? _partnerId : null,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.scSupplier),
                  items: [for (final p in partners) DropdownMenuItem(value: p.id, child: Text(p.name))],
                  onChanged: widget.term == null ? (v) => setState(() => _partnerId = v) : null,
                ),
              ),
              ScNumberField(controller: _list, label: l10n.scListPrice, fieldKey: const ValueKey('sc-term-list')),
              ScNumberField(controller: _rate, label: l10n.scDiscountRate, suffix: '%', fieldKey: const ValueKey('sc-term-rate')),
              ScNumberField(controller: _unit, label: l10n.scUnitPrice, fieldKey: const ValueKey('sc-term-unit')),
              SizedBox(
                width: 160,
                child: TextField(controller: _currency, decoration: InputDecoration(labelText: l10n.scCurrency, hintText: 'JPY / USD / CNY', isDense: true)),
              ),
              ScNumberField(controller: _moq, label: l10n.scMoq),
              ScNumberField(controller: _lot, label: l10n.scOrderLot),
              ScNumberField(controller: _lead, label: l10n.scLeadTimeDays, fieldKey: const ValueKey('sc-term-lead')),
              SizedBox(width: 160, child: TextField(controller: _sku, decoration: const InputDecoration(labelText: 'SKU', isDense: true))),
              SizedBox(width: 336, child: TextField(controller: _terms, decoration: InputDecoration(labelText: l10n.scPaymentTerms, isDense: true))),
              SizedBox(
                width: 520,
                child: DropdownButtonFormField<int?>(
                  initialValue: routes.any((r) => r.id == _routeId) ? _routeId : null,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.scDefaultRoute),
                  items: [
                    DropdownMenuItem<int?>(value: null, child: Text(l10n.scRouteCheapest)),
                    for (final r in routes) DropdownMenuItem<int?>(value: r.id, child: Text(r.name)),
                  ],
                  onChanged: (v) => setState(() => _routeId = v),
                ),
              ),
              SizedBox(
                width: 520,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _primary,
                  title: Text(l10n.scPrimary),
                  onChanged: (v) => setState(() => _primary = v),
                ),
              ),
              if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.term?.id != null)
          TextButton(
            onPressed: _busy
                ? null
                : () => scSaveAndClose(context, ref, () => ref.read(supplyChainRepositoryProvider).archive('supplier_product', widget.term!.id!),
                    (m) => setState(() => _error = m)),
            child: Text(l10n.actionDelete),
          ),
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('sc-term-save'),
          onPressed: _busy || _partnerId == null ? null : _save,
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}

/// A product's sales price, volume, weight, carton, storage and HS code.
class ScProfileDialog extends ConsumerStatefulWidget {
  const ScProfileDialog({super.key, required this.productId, this.profile});

  final int productId;
  final ScProfile? profile;

  @override
  ConsumerState<ScProfileDialog> createState() => _ScProfileDialogState();
}

class _ScProfileDialogState extends ConsumerState<ScProfileDialog> {
  late final _price = TextEditingController(text: scFieldText(widget.profile?.salesPrice));
  late final _volume = TextEditingController(text: scFieldText(widget.profile?.annualVolume));
  late final _weight = TextEditingController(text: scFieldText(widget.profile?.unitWeightKg));
  late final _carton = TextEditingController(text: widget.profile?.unitsPerCarton?.toString() ?? '');
  late final _storage = TextEditingController(text: scFieldText(widget.profile?.storageDays));
  late final _hs = TextEditingController(text: widget.profile?.hsCode ?? '');
  late final _origin = TextEditingController(text: widget.profile?.originCountry ?? '');
  late final _dest = TextEditingController(text: widget.profile?.destinationCountry ?? '');
  String? _error;

  @override
  void dispose() {
    for (final c in [_price, _volume, _weight, _carton, _storage, _hs, _origin, _dest]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String? t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    return AlertDialog(
      title: Text(l10n.scProfile),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              ScNumberField(controller: _price, label: l10n.scSalesPrice, hint: l10n.scSalesPriceHint, width: 250, fieldKey: const ValueKey('sc-profile-price')),
              ScNumberField(controller: _volume, label: l10n.scAnnualVolume, hint: l10n.scAnnualVolumeHint, width: 250, fieldKey: const ValueKey('sc-profile-volume')),
              ScNumberField(controller: _weight, label: l10n.scWeight, fieldKey: const ValueKey('sc-profile-weight')),
              ScNumberField(controller: _carton, label: l10n.scUnitsPerCarton),
              ScNumberField(controller: _storage, label: l10n.scStorageDays),
              SizedBox(width: 160, child: TextField(controller: _hs, decoration: InputDecoration(labelText: l10n.scHsCode, isDense: true))),
              SizedBox(width: 160, child: TextField(controller: _origin, decoration: InputDecoration(labelText: l10n.scOriginCountry, hintText: 'CN', isDense: true))),
              SizedBox(width: 160, child: TextField(controller: _dest, decoration: InputDecoration(labelText: l10n.scDestinationCountry, hintText: 'JP', isDense: true))),
              if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('sc-profile-save'),
          onPressed: () => scSaveAndClose(
            context,
            ref,
            () => ref.read(supplyChainRepositoryProvider).saveProfile(
                  widget.productId,
                  ScProfile(
                    salesPrice: scParse(_price),
                    annualVolume: scParse(_volume),
                    unitWeightKg: scParse(_weight),
                    unitsPerCarton: int.tryParse(_carton.text.trim()),
                    storageDays: scParse(_storage),
                    hsCode: t(_hs),
                    originCountry: t(_origin)?.toUpperCase(),
                    destinationCountry: t(_dest)?.toUpperCase(),
                  ),
                ),
            (m) => setState(() => _error = m),
          ),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}

/// A leg-by-leg route from a supplier to a warehouse.
class ScRouteDialog extends ConsumerStatefulWidget {
  const ScRouteDialog({super.key, required this.model, this.route});

  final ScModel model;
  final ScRoute? route;

  @override
  ConsumerState<ScRouteDialog> createState() => _ScRouteDialogState();
}

class _ScRouteDialogState extends ConsumerState<ScRouteDialog> {
  late final _name = TextEditingController(text: widget.route?.name ?? '');
  late List<ScEdge> _legs = [...?widget.route?.edges];
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _editLeg(int? index) async {
    final prev = index == null ? (_legs.isEmpty ? null : _legs.last) : _legs[index];
    final leg = await showDialog<ScEdge>(
      context: context,
      builder: (_) => _LegDialog(
        model: widget.model,
        leg: index == null ? null : _legs[index],
        fromNodeId: index == null ? prev?.toNodeId : null,
      ),
    );
    if (leg == null) return;
    setState(() {
      if (index == null) {
        _legs = [..._legs, leg];
      } else {
        _legs[index] = leg;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    String name(int id) => widget.model.node(id)?.name ?? '#$id';
    return AlertDialog(
      title: Text(widget.route == null ? l10n.scAddRoute : widget.route!.name),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(key: const ValueKey('sc-route-name'), controller: _name, decoration: InputDecoration(labelText: l10n.scRouteName)),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.scLegs, style: theme.textTheme.labelLarge),
              for (var i = 0; i < _legs.length; i++)
                ListTile(
                  key: ValueKey('sc-route-leg-$i'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(scModeIcon(_legs[i].mode)),
                  title: Text('${name(_legs[i].fromNodeId)} → ${name(_legs[i].toNodeId)}'),
                  subtitle: Text([
                    scModeLabel(l10n, _legs[i].mode),
                    l10n.scDays(scNumber(_legs[i].leadTimeDays)),
                    if (_legs[i].customsClearance) l10n.scKindCustoms,
                  ].join(' · ')),
                  onTap: () => _editLeg(i),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => _legs = [..._legs]..removeAt(i)),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('sc-route-add-leg'),
                  onPressed: () => _editLeg(null),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.scAddLeg),
                ),
              ),
              if (_error != null) Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.route != null)
          TextButton(
            onPressed: () => scSaveAndClose(context, ref, () => ref.read(supplyChainRepositoryProvider).archive('route', widget.route!.id),
                (m) => setState(() => _error = m)),
            child: Text(l10n.actionDelete),
          ),
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('sc-route-save'),
          onPressed: () {
            if (_name.text.trim().isEmpty) return setState(() => _error = l10n.scErrorNameRequired);
            for (var i = 1; i < _legs.length; i++) {
              if (_legs[i].fromNodeId != _legs[i - 1].toNodeId) return setState(() => _error = l10n.scErrorRouteLegs);
            }
            if (_legs.isEmpty) return setState(() => _error = l10n.scErrorRouteLegs);
            scSaveAndClose(
              context,
              ref,
              () => ref.read(supplyChainRepositoryProvider).saveRoute(id: widget.route?.id, name: _name.text.trim(), edges: _legs),
              (m) => setState(() => _error = m),
            );
          },
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}

class _LegDialog extends StatefulWidget {
  const _LegDialog({required this.model, this.leg, this.fromNodeId});

  final ScModel model;
  final ScEdge? leg;
  final int? fromNodeId;

  @override
  State<_LegDialog> createState() => _LegDialogState();
}

class _LegDialogState extends State<_LegDialog> {
  late int? _from = widget.leg?.fromNodeId ?? widget.fromNodeId;
  late int? _to = widget.leg?.toNodeId;
  late String _mode = widget.leg?.mode ?? 'sea';
  late bool _customs = widget.leg?.customsClearance ?? false;
  late RiskLevel _risk = widget.leg?.riskLevel ?? RiskLevel.low;
  late final _lead = TextEditingController(text: scFieldText(widget.leg?.leadTimeDays));
  late final _base = TextEditingController(text: scFieldText(widget.leg?.baseCost));
  late final _kg = TextEditingController(text: scFieldText(widget.leg?.costPerKg));
  late final _unit = TextEditingController(text: scFieldText(widget.leg?.costPerUnit));
  late final _ins = TextEditingController(text: widget.leg == null || widget.leg!.insuranceRate == 0 ? '' : scFieldText(widget.leg!.insuranceRate * 100));
  late final _capKg = TextEditingController(text: scFieldText(widget.leg?.capacityKgMonth));
  late final _customsCost = TextEditingController(text: scFieldText(widget.leg?.customsCost));

  @override
  void dispose() {
    for (final c in [_lead, _base, _kg, _unit, _ins, _capKg, _customsCost]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nodes = widget.model.nodes;
    DropdownButtonFormField<int> nodeField(String label, int? value, ValueChanged<int?> onChanged, Key key) => DropdownButtonFormField<int>(
          key: key,
          initialValue: nodes.any((n) => n.id == value) ? value : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            for (final n in nodes) DropdownMenuItem(value: n.id, child: Text('${n.name} (${scNodeKindLabel(l10n, n.kind)})')),
          ],
          onChanged: onChanged,
        );
    return AlertDialog(
      title: Text(l10n.scLegs),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              SizedBox(width: 250, child: nodeField(l10n.scFrom, _from, (v) => setState(() => _from = v), const ValueKey('sc-leg-from'))),
              SizedBox(width: 250, child: nodeField(l10n.scTo, _to, (v) => setState(() => _to = v), const ValueKey('sc-leg-to'))),
              SizedBox(
                width: 250,
                child: DropdownButtonFormField<String>(
                  key: const ValueKey('sc-leg-mode'),
                  initialValue: _mode,
                  decoration: InputDecoration(labelText: l10n.scMode),
                  items: [for (final m in scModes) DropdownMenuItem(value: m, child: Text(scModeLabel(l10n, m)))],
                  onChanged: (v) => setState(() => _mode = v ?? _mode),
                ),
              ),
              SizedBox(
                width: 250,
                child: DropdownButtonFormField<RiskLevel>(
                  initialValue: _risk,
                  decoration: InputDecoration(labelText: l10n.scRisk),
                  items: [for (final r in RiskLevel.values) DropdownMenuItem(value: r, child: Text(scRiskLevelLabel(l10n, r)))],
                  onChanged: (v) => setState(() => _risk = v ?? _risk),
                ),
              ),
              ScNumberField(controller: _lead, label: l10n.scLeadTimeDays, fieldKey: const ValueKey('sc-leg-lead')),
              ScNumberField(controller: _base, label: l10n.scBaseCost),
              ScNumberField(controller: _kg, label: l10n.scCostPerKg, fieldKey: const ValueKey('sc-leg-kg')),
              ScNumberField(controller: _unit, label: l10n.scCostPerUnit),
              ScNumberField(controller: _ins, label: l10n.scInsuranceRate, suffix: '%'),
              ScNumberField(controller: _capKg, label: l10n.scCapacityKg),
              SizedBox(
                width: 520,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _customs,
                  title: Text(l10n.scCustomsClearance),
                  onChanged: (v) => setState(() => _customs = v),
                ),
              ),
              if (_customs) ScNumberField(controller: _customsCost, label: l10n.scCustomsCost),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('sc-leg-save'),
          onPressed: _from == null || _to == null
              ? null
              : () => Navigator.pop(
                    context,
                    ScEdge(
                      fromNodeId: _from!,
                      toNodeId: _to!,
                      mode: _mode,
                      leadTimeDays: scParse(_lead) ?? 0,
                      baseCost: scParse(_base) ?? 0,
                      costPerKg: scParse(_kg) ?? 0,
                      costPerUnit: scParse(_unit) ?? 0,
                      insuranceRate: (scParse(_ins) ?? 0) / 100,
                      capacityKgMonth: scParse(_capKg),
                      customsClearance: _customs,
                      customsCost: _customs ? scParse(_customsCost) ?? 0 : 0,
                      riskLevel: _risk,
                    ),
                  ),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}

/// A site: supplier, port, airport, customs, warehouse, hub…
class ScNodeDialog extends ConsumerStatefulWidget {
  const ScNodeDialog({super.key, this.node});

  final ScNode? node;

  @override
  ConsumerState<ScNodeDialog> createState() => _ScNodeDialogState();
}

class _ScNodeDialogState extends ConsumerState<ScNodeDialog> {
  late final _name = TextEditingController(text: widget.node?.name ?? '');
  late final _country = TextEditingController(text: widget.node?.countryCode ?? '');
  late final _cap = TextEditingController(text: scFieldText(widget.node?.capacityUnitsMonth));
  late final _capKg = TextEditingController(text: scFieldText(widget.node?.capacityKgMonth));
  late final _dwell = TextEditingController(text: scFieldText(widget.node?.dwellDays == 0 ? null : widget.node?.dwellDays));
  late final _handling = TextEditingController(text: scFieldText(widget.node?.handlingCostPerUnit == 0 ? null : widget.node?.handlingCostPerUnit));
  late String _kind = widget.node?.kind ?? 'port';
  late RiskLevel _risk = widget.node?.riskLevel ?? RiskLevel.low;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _country, _cap, _capKg, _dwell, _handling]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final n = widget.node;
    return AlertDialog(
      title: Text(n == null ? l10n.scAddNode : n.name),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              SizedBox(width: 520, child: TextField(key: const ValueKey('sc-node-name'), controller: _name, decoration: InputDecoration(labelText: l10n.scNodeName))),
              SizedBox(
                width: 250,
                child: DropdownButtonFormField<String>(
                  key: const ValueKey('sc-node-kind'),
                  initialValue: _kind,
                  decoration: InputDecoration(labelText: l10n.scNodeKind),
                  items: [for (final k in scNodeKinds) DropdownMenuItem(value: k, child: Text(scNodeKindLabel(l10n, k)))],
                  onChanged: (n?.kind == 'warehouse' || n?.kind == 'supplier') ? null : (v) => setState(() => _kind = v ?? _kind),
                ),
              ),
              SizedBox(
                width: 250,
                child: DropdownButtonFormField<RiskLevel>(
                  initialValue: _risk,
                  decoration: InputDecoration(labelText: l10n.scRisk),
                  items: [for (final r in RiskLevel.values) DropdownMenuItem(value: r, child: Text(scRiskLevelLabel(l10n, r)))],
                  onChanged: (v) => setState(() => _risk = v ?? _risk),
                ),
              ),
              SizedBox(width: 160, child: TextField(controller: _country, decoration: InputDecoration(labelText: l10n.scCountry, hintText: 'JP', isDense: true))),
              ScNumberField(controller: _cap, label: l10n.scCapacityUnits, fieldKey: const ValueKey('sc-node-capacity')),
              ScNumberField(controller: _capKg, label: l10n.scCapacityKg),
              ScNumberField(controller: _dwell, label: l10n.scDwellDays),
              ScNumberField(controller: _handling, label: l10n.scHandlingPerUnit),
              if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ),
        ),
      ),
      actions: [
        if (n != null && n.kind != 'warehouse' && n.kind != 'supplier')
          TextButton(
            onPressed: () => scSaveAndClose(context, ref, () => ref.read(supplyChainRepositoryProvider).archive('node', n.id), (m) => setState(() => _error = m)),
            child: Text(l10n.actionDelete),
          ),
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('sc-node-save'),
          onPressed: () {
            if (_name.text.trim().isEmpty) return setState(() => _error = l10n.scErrorNameRequired);
            scSaveAndClose(
              context,
              ref,
              () => ref.read(supplyChainRepositoryProvider).saveNode({
                'id': n?.id,
                'code': n?.code,
                'name': _name.text.trim(),
                'kind': _kind,
                'partner_id': n?.partnerId,
                'warehouse_id': n?.warehouseId,
                'country_code': _country.text.trim().isEmpty ? null : _country.text.trim().toUpperCase(),
                'capacity_units_month': scParse(_cap),
                'capacity_kg_month': scParse(_capKg),
                'dwell_days': scParse(_dwell) ?? 0,
                'handling_cost_per_unit': scParse(_handling) ?? 0,
                'handling_cost_per_shipment': n?.handlingCostPerShipment ?? 0,
                'risk_level': _risk.name,
                'risk_note': n?.riskNote,
              }),
              (m) => setState(() => _error = m),
            );
          },
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
