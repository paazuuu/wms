import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/supply_chain_providers.dart';
import '../domain/supply_chain.dart';
import 'sc_editors.dart';
import 'sc_labels.dart';
import 'sc_product_sheet.dart';
import 'sc_widgets.dart';

/// 原価構造 (§4, §10–13, §32): one product's cost from sales price down to
/// profit, and the rules every cost comes from — warehouse, labour and
/// overhead, duty and import tax, FX. No rate is written in code (rule 7):
/// all of it is here.
class ScCostStructureScreen extends ConsumerStatefulWidget {
  const ScCostStructureScreen({super.key});

  @override
  ConsumerState<ScCostStructureScreen> createState() => _ScCostStructureScreenState();
}

class _ScCostStructureScreenState extends ConsumerState<ScCostStructureScreen> {
  int? _productId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canManage = ref.watch(scCanManageProvider);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.featScCosts),
          bottom: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
            Tab(key: const ValueKey('sc-tab-product'), text: l10n.scByProduct),
            Tab(key: const ValueKey('sc-tab-rules'), text: l10n.scCostRules),
            Tab(key: const ValueKey('sc-tab-tariffs'), text: l10n.scTariffRules),
            Tab(key: const ValueKey('sc-tab-fx'), text: l10n.scFxRates),
          ]),
        ),
        body: ref.watch(scModelProvider).when(
              loading: () => LoadingView(message: l10n.loading),
              error: (e, _) => ErrorStateView(message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => ref.invalidate(scModelProvider)),
              data: (m) => TabBarView(children: [
                _productTab(context, l10n, m, canManage),
                _RulesTab(model: m, canManage: canManage),
                _TariffsTab(model: m, canManage: canManage),
                _FxTab(model: m, canManage: canManage),
              ]),
            ),
      ),
    );
  }

  Widget _productTab(BuildContext context, AppLocalizations l10n, ScModel m, bool canManage) {
    final products = [...m.products]..sort((a, b) => a.name.compareTo(b.name));
    final ids = products.map((p) => p.id).toSet();
    final id = ids.contains(_productId) ? _productId : (products.isEmpty ? null : products.first.id);
    final profile = products.where((p) => p.id == id).firstOrNull?.profile;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              key: const ValueKey('sc-cost-product'),
              initialValue: id,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.scProduct),
              items: [for (final p in products) DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setState(() => _productId = v),
            ),
          ),
          if (canManage && id != null)
            TextButton.icon(
              onPressed: () => showDialog(context: context, builder: (_) => ScProfileDialog(productId: id, profile: profile)),
              icon: const Icon(Icons.tune, size: 18),
              label: Text(l10n.scEditProfile),
            ),
        ]),
        const SizedBox(height: AppSpacing.md),
        if (id == null)
          Text(l10n.scNoData)
        else
          ScSection(title: l10n.scWaterfall, child: ScProductProfitView(productId: id, compact: true)),
      ],
    );
  }
}

class _RulesTab extends ConsumerWidget {
  const _RulesTab({required this.model, required this.canManage});

  final ScModel model;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (canManage)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              key: const ValueKey('sc-add-rule'),
              onPressed: () => showDialog(context: context, builder: (_) => const _RuleDialog()),
              icon: const Icon(Icons.add),
              label: Text(l10n.scAddRule),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        for (final r in model.costRules)
          Card(
            key: ValueKey('sc-rule-${r.id}'),
            child: ListTile(
              title: Text(r.name),
              subtitle: Text([
                scCategoryLabel(l10n, r.category),
                scBasisLabel(l10n, r.basis),
                if (r.unitsPerBasis != null) '${l10n.scUnitsPerBasis} ${scNumber(r.unitsPerBasis!)}',
                if (!r.expensed) l10n.scRecoverable,
              ].join(' · ')),
              trailing: Text(r.isPercent ? scPercent(r.amount, digits: 2) : scUnitMoney(r.amount),
                  style: Theme.of(context).textTheme.titleSmall),
              onTap: canManage ? () => showDialog(context: context, builder: (_) => _RuleDialog(rule: r)) : null,
            ),
          ),
      ],
    );
  }
}

class _RuleDialog extends ConsumerStatefulWidget {
  const _RuleDialog({this.rule});

  final ScCostRule? rule;

  @override
  ConsumerState<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends ConsumerState<_RuleDialog> {
  late final _name = TextEditingController(text: widget.rule?.name ?? '');
  late final _amount = TextEditingController(text: scFieldText(widget.rule?.amount));
  late final _per = TextEditingController(text: scFieldText(widget.rule?.unitsPerBasis));
  late String _category = widget.rule?.category ?? 'storage';
  late String _basis = widget.rule?.basis ?? 'per_unit';
  late bool _expensed = widget.rule?.expensed ?? true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _per.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final r = widget.rule;
    return AlertDialog(
      title: Text(r?.name ?? l10n.scAddRule),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md, children: [
            SizedBox(width: 480, child: TextField(key: const ValueKey('sc-rule-name'), controller: _name, decoration: InputDecoration(labelText: l10n.scRuleName))),
            SizedBox(
              width: 230,
              child: DropdownButtonFormField<String>(
                key: const ValueKey('sc-rule-category'),
                initialValue: _category,
                decoration: InputDecoration(labelText: l10n.scCategory),
                items: [for (final c in costCategories) DropdownMenuItem(value: c, child: Text(scCategoryLabel(l10n, c)))],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
            ),
            SizedBox(
              width: 230,
              child: DropdownButtonFormField<String>(
                key: const ValueKey('sc-rule-basis'),
                initialValue: _basis,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.scBasis),
                items: [for (final b in costBases) DropdownMenuItem(value: b, child: Text(scBasisLabel(l10n, b)))],
                onChanged: (v) => setState(() => _basis = v ?? _basis),
              ),
            ),
            ScNumberField(
              controller: _amount,
              label: l10n.scAmount,
              hint: _basis.startsWith('percent') ? l10n.scAmountPercentHint : null,
              width: 230,
              fieldKey: const ValueKey('sc-rule-amount'),
            ),
            ScNumberField(controller: _per, label: l10n.scUnitsPerBasis, hint: l10n.scUnitsPerBasisHint, width: 230),
            SizedBox(
              width: 480,
              child: SwitchListTile(contentPadding: EdgeInsets.zero, value: _expensed, title: Text(l10n.scExpensed), onChanged: (v) => setState(() => _expensed = v)),
            ),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ]),
        ),
      ),
      actions: [
        if (r?.id != null)
          TextButton(
            onPressed: () => scSaveAndClose(context, ref, () => ref.read(supplyChainRepositoryProvider).archive('cost_rule', r!.id!), (m) => setState(() => _error = m)),
            child: Text(l10n.actionDelete),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('sc-rule-save'),
          onPressed: () {
            if (_name.text.trim().isEmpty) return setState(() => _error = l10n.scErrorNameRequired);
            scSaveAndClose(
              context,
              ref,
              () => ref.read(supplyChainRepositoryProvider).saveCostRule(ScCostRule(
                    id: r?.id,
                    name: _name.text.trim(),
                    category: _category,
                    basis: _basis,
                    amount: scParse(_amount) ?? 0,
                    unitsPerBasis: scParse(_per),
                    warehouseId: r?.warehouseId,
                    productId: r?.productId,
                    partnerId: r?.partnerId,
                    expensed: _expensed,
                  )),
              (m) => setState(() => _error = m),
            );
          },
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}

class _TariffsTab extends ConsumerWidget {
  const _TariffsTab({required this.model, required this.canManage});

  final ScModel model;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (canManage)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              key: const ValueKey('sc-add-tariff'),
              onPressed: () => showDialog(context: context, builder: (_) => const _TariffDialog()),
              icon: const Icon(Icons.add),
              label: Text(l10n.scAddTariff),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        for (final t in model.tariffRules)
          Card(
            key: ValueKey('sc-tariff-${t.id}'),
            child: ListTile(
              title: Text(t.name ?? (t.hsCodePrefix != null ? 'HS ${t.hsCodePrefix}' : l10n.scAll)),
              subtitle: Text([
                if (t.hsCodePrefix != null) 'HS ${t.hsCodePrefix}',
                '${t.originCountry ?? '*'} → ${t.destinationCountry ?? '*'}',
                '${l10n.scImportTaxRate} ${scPercent(t.importTaxRate)}${t.importTaxRecoverable ? ' (${l10n.scRecoverable})' : ''}',
                t.valuation,
              ].join(' · ')),
              trailing: Text(scPercent(t.tariffRate, digits: 2), style: Theme.of(context).textTheme.titleSmall),
              onTap: canManage ? () => showDialog(context: context, builder: (_) => _TariffDialog(rule: t)) : null,
            ),
          ),
      ],
    );
  }
}

class _TariffDialog extends ConsumerStatefulWidget {
  const _TariffDialog({this.rule});

  final ScTariffRule? rule;

  @override
  ConsumerState<_TariffDialog> createState() => _TariffDialogState();
}

class _TariffDialogState extends ConsumerState<_TariffDialog> {
  late final _name = TextEditingController(text: widget.rule?.name ?? '');
  late final _hs = TextEditingController(text: widget.rule?.hsCodePrefix ?? '');
  late final _origin = TextEditingController(text: widget.rule?.originCountry ?? '');
  late final _dest = TextEditingController(text: widget.rule?.destinationCountry ?? '');
  late final _rate = TextEditingController(text: widget.rule == null ? '' : scFieldText(widget.rule!.tariffRate * 100));
  late final _tax = TextEditingController(text: widget.rule == null ? '' : scFieldText(widget.rule!.importTaxRate * 100));
  late final _other = TextEditingController(text: widget.rule == null || widget.rule!.otherRate == 0 ? '' : scFieldText(widget.rule!.otherRate * 100));
  late bool _recoverable = widget.rule?.importTaxRecoverable ?? true;
  late String _valuation = widget.rule?.valuation ?? 'CIF';
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _hs, _origin, _dest, _rate, _tax, _other]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final r = widget.rule;
    String? t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    return AlertDialog(
      title: Text(r?.name ?? l10n.scAddTariff),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md, children: [
            SizedBox(width: 480, child: TextField(controller: _name, decoration: InputDecoration(labelText: l10n.scRuleName))),
            SizedBox(width: 150, child: TextField(key: const ValueKey('sc-tariff-hs'), controller: _hs, decoration: InputDecoration(labelText: l10n.scHsPrefix, isDense: true))),
            SizedBox(width: 150, child: TextField(controller: _origin, decoration: InputDecoration(labelText: l10n.scOriginCountry, hintText: 'CN', isDense: true))),
            SizedBox(width: 150, child: TextField(controller: _dest, decoration: InputDecoration(labelText: l10n.scDestinationCountry, hintText: 'JP', isDense: true))),
            ScNumberField(controller: _rate, label: l10n.scTariffRate, suffix: '%', width: 150, fieldKey: const ValueKey('sc-tariff-rate')),
            ScNumberField(controller: _tax, label: l10n.scImportTaxRate, suffix: '%', width: 150),
            ScNumberField(controller: _other, label: l10n.scOtherRate, suffix: '%', width: 150),
            SizedBox(
              width: 480,
              child: SwitchListTile(contentPadding: EdgeInsets.zero, value: _recoverable, title: Text(l10n.scImportTaxRecoverable), onChanged: (v) => setState(() => _recoverable = v)),
            ),
            SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'CIF', label: Text('CIF')), ButtonSegment(value: 'FOB', label: Text('FOB'))],
              selected: {_valuation},
              onSelectionChanged: (s) => setState(() => _valuation = s.first),
            ),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ]),
        ),
      ),
      actions: [
        if (r?.id != null)
          TextButton(
            onPressed: () => scSaveAndClose(context, ref, () => ref.read(supplyChainRepositoryProvider).archive('tariff_rule', r!.id!), (m) => setState(() => _error = m)),
            child: Text(l10n.actionDelete),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('sc-tariff-save'),
          onPressed: () => scSaveAndClose(
            context,
            ref,
            () => ref.read(supplyChainRepositoryProvider).saveTariffRule(ScTariffRule(
                  id: r?.id,
                  name: t(_name),
                  productId: r?.productId,
                  hsCodePrefix: t(_hs),
                  originCountry: t(_origin)?.toUpperCase(),
                  destinationCountry: t(_dest)?.toUpperCase(),
                  tariffRate: (scParse(_rate) ?? 0) / 100,
                  importTaxRate: (scParse(_tax) ?? 0) / 100,
                  importTaxRecoverable: _recoverable,
                  otherRate: (scParse(_other) ?? 0) / 100,
                  valuation: _valuation,
                )),
            (m) => setState(() => _error = m),
          ),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}

class _FxTab extends ConsumerWidget {
  const _FxTab({required this.model, required this.canManage});

  final ScModel model;
  final bool canManage;

  Future<void> _edit(BuildContext context, WidgetRef ref, String? currency, double? rate) async {
    final l10n = AppLocalizations.of(context);
    final cur = TextEditingController(text: currency ?? '');
    final val = TextEditingController(text: scFieldText(rate));
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(currency ?? l10n.scAddFx),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(key: const ValueKey('sc-fx-currency'), controller: cur, enabled: currency == null, decoration: InputDecoration(labelText: l10n.scCurrency, hintText: 'USD')),
          TextField(
            key: const ValueKey('sc-fx-rate'),
            controller: val,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.scRateToBase, suffixText: model.settings.baseCurrency),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.actionCancel)),
          FilledButton(key: const ValueKey('sc-fx-save'), onPressed: () => Navigator.pop(dialogContext, true), child: Text(l10n.actionSave)),
        ],
      ),
    );
    final c = cur.text.trim().toUpperCase();
    final v = double.tryParse(val.text.trim());
    if (ok != true || c.isEmpty || v == null || v <= 0 || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final r = await ref.read(supplyChainRepositoryProvider).saveFx(c, v);
    r.when(
      success: (_) => refreshSupplyChain(ref),
      failure: (f) => messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, f.message)))),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final base = model.settings.baseCurrency;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (canManage)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              key: const ValueKey('sc-add-fx'),
              onPressed: () => _edit(context, ref, null, null),
              icon: const Icon(Icons.add),
              label: Text(l10n.scAddFx),
            ),
          ),
        for (final e in model.fx.entries.where((e) => e.key != base))
          ListTile(
            key: ValueKey('sc-fx-${e.key}'),
            leading: const Icon(Icons.currency_exchange),
            title: Text('1 ${e.key}'),
            trailing: Text('${scNumber(e.value)} $base', style: Theme.of(context).textTheme.titleSmall),
            onTap: canManage ? () => _edit(context, ref, e.key, e.value) : null,
          ),
      ],
    );
  }
}
