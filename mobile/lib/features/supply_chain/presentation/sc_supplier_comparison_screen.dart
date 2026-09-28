import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../product/domain/product.dart';
import '../../product/presentation/product_picker_sheet.dart';
import '../application/supply_chain_providers.dart';
import '../domain/supply_chain.dart';
import 'sc_editors.dart';
import 'sc_labels.dart';
import 'sc_widgets.dart';

/// 仕入先比較 (§5, §7, §28): for one product and one order quantity, every
/// supplier × route side by side — not the cheapest price but what is left —
/// the same at other 掛率, the product's supply terms, and each supplier's
/// record.
class ScSupplierComparisonScreen extends ConsumerStatefulWidget {
  const ScSupplierComparisonScreen({super.key, this.initialProductId});

  final int? initialProductId;

  @override
  ConsumerState<ScSupplierComparisonScreen> createState() => _ScSupplierComparisonScreenState();
}

class _ScSupplierComparisonScreenState extends ConsumerState<ScSupplierComparisonScreen> {
  late int? _productId = widget.initialProductId;
  String? _pickedName;
  final _qty = TextEditingController();
  final _rates = TextEditingController();
  int? _lot;
  String _rateKey = '';

  @override
  void dispose() {
    _qty.dispose();
    _rates.dispose();
    super.dispose();
  }

  void _apply() {
    setState(() {
      _lot = int.tryParse(_qty.text.trim());
      _rateKey = [
        for (final r in _rates.text.split(RegExp(r'[,、\s]+')))
          if (double.tryParse(r) != null) (double.parse(r) > 2 ? double.parse(r) / 100 : double.parse(r)).toString(),
      ].join(',');
    });
  }

  Future<void> _pickOther() async {
    final p = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ProductPickerSheet(),
    );
    if (p != null) {
      setState(() {
        _productId = p.id;
        _pickedName = p.name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.featScSuppliers),
          bottom: TabBar(tabs: [
            Tab(key: const ValueKey('sc-tab-compare'), text: l10n.featScSuppliers),
            Tab(key: const ValueKey('sc-tab-stats'), text: l10n.scSupplierStats),
          ]),
        ),
        body: TabBarView(children: [
          _compareTab(context, l10n),
          const _StatsTab(),
        ]),
      ),
    );
  }

  Widget _compareTab(BuildContext context, AppLocalizations l10n) {
    final model = ref.watch(scModelProvider);
    return model.when(
      loading: () => LoadingView(message: l10n.loading),
      error: (e, _) => ErrorStateView(message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => ref.invalidate(scModelProvider)),
      data: (m) {
        final products = [...m.products]..sort((a, b) => a.name.compareTo(b.name));
        final ids = products.map((p) => p.id).toSet();
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(
                  width: 320,
                  child: DropdownButtonFormField<int>(
                    key: const ValueKey('sc-compare-product'),
                    initialValue: ids.contains(_productId) ? _productId : null,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l10n.scProduct),
                    hint: Text(_pickedName ?? l10n.scChooseProduct),
                    items: [for (final p in products) DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis))],
                    onChanged: (v) => setState(() => _productId = v),
                  ),
                ),
                IconButton(tooltip: l10n.productPickerTitle, onPressed: _pickOther, icon: const Icon(Icons.search)),
                ScNumberField(controller: _qty, label: l10n.scQuantity, fieldKey: const ValueKey('sc-compare-qty')),
                SizedBox(
                  width: 200,
                  child: TextField(
                    key: const ValueKey('sc-compare-rates'),
                    controller: _rates,
                    decoration: InputDecoration(labelText: l10n.scRates, hintText: l10n.scRatesHint, isDense: true),
                    onSubmitted: (_) => _apply(),
                  ),
                ),
                FilledButton.tonal(key: const ValueKey('sc-compare-apply'), onPressed: _apply, child: Text(l10n.scRecalculate)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (_productId == null)
              Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text(l10n.scChooseProduct))
            else ...[
              _Comparison(productId: _productId!, rates: _rateKey, lot: _lot),
              _Terms(productId: _productId!, model: m),
            ],
          ],
        );
      },
    );
  }
}

class _Comparison extends ConsumerWidget {
  const _Comparison({required this.productId, required this.rates, required this.lot});

  final int productId;
  final String rates;
  final int? lot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(scProductViewProvider((productId: productId, rates: rates, lot: lot)));
    return async.when(
      loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.lg), child: LinearProgressIndicator()),
      error: (e, _) => Text(humanizeApiErrorMessage(l10n, '$e')),
      data: (view) {
        final p = view.product;
        if (p == null || p.options.isEmpty) {
          return Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text(l10n.scNoTerms));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScSection(
              title: p.name,
              subtitle: [
                '${l10n.scSalesPrice} ${scUnitMoney(p.salesPrice)}',
                '${l10n.scVolume} ${scNumber(p.volume)}',
                if (lot != null) '${l10n.scQuantity} ${scNumber(lot!.toDouble())}',
              ].join(' · '),
              child: _OptionsTable(options: p.options, chosenKeys: {for (final c in p.chosen) c.key}),
            ),
            if (view.sweeps.isNotEmpty) ScSection(title: l10n.scRates, child: _SweepTable(sweeps: view.sweeps)),
          ],
        );
      },
    );
  }
}

/// Suppliers × routes in columns, cost lines in rows (§5).
class _OptionsTable extends StatelessWidget {
  const _OptionsTable({required this.options, required this.chosenKeys});

  final List<ScOption> options;
  final Set<String> chosenKeys;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodySmall?.copyWith(fontFamily: AppFonts.mono);
    final best = options.where((o) => o.available).fold<ScOption?>(null, (a, o) => a == null || o.profitPerUnit > a.profitPerUnit ? o : a);

    TableRow row(String label, String Function(ScOption) value, {bool strong = false, Color? Function(ScOption)? color}) => TableRow(children: [
          Padding(padding: const EdgeInsets.all(6), child: Text(label, style: strong ? theme.textTheme.labelLarge : theme.textTheme.bodySmall)),
          for (final o in options)
            Padding(
              padding: const EdgeInsets.all(6),
              child: Text(value(o),
                  textAlign: TextAlign.right,
                  style: (strong ? mono?.copyWith(fontWeight: FontWeight.w700) : mono)?.copyWith(color: color?.call(o))),
            ),
        ]);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        key: const ValueKey('sc-options-table'),
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder(horizontalInside: BorderSide(color: theme.colorScheme.outlineVariant)),
        children: [
          TableRow(children: [
            const SizedBox(),
            for (final o in options)
              Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(o.partnerName, style: theme.textTheme.labelLarge),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(scModeIcon(o.mode), size: 14),
                      const SizedBox(width: 2),
                      Text(o.routeName ?? l10n.scNoRoute, style: theme.textTheme.bodySmall),
                    ]),
                    Wrap(spacing: 4, children: [
                      if (chosenKeys.contains(o.key)) StatusPill(tone: StatusTone.info, label: l10n.scCurrent, dense: true),
                      if (o.hypothetical) StatusPill(tone: StatusTone.neutral, label: l10n.scHypothetical, dense: true),
                      if (!o.available) StatusPill(tone: StatusTone.neutral, label: l10n.scBlocked, dense: true),
                    ]),
                  ],
                ),
              ),
          ]),
          row(l10n.scUnitPrice, (o) => o.currency == 'JPY' ? scUnitMoney(o.unitPriceForeign) : '${scNumber(o.unitPriceForeign)} ${o.currency}'),
          row(l10n.scDiscountRate, (o) => scRate(o.discountRate)),
          row(l10n.scLinePurchase, (o) => scUnitMoney(o.unit[CostLine.purchase] + o.unit[CostLine.fxImpact])),
          row(l10n.scLogistics, (o) => scUnitMoney(o.unit.logistics)),
          row(l10n.scCustoms, (o) => scUnitMoney(o.unit.customs)),
          row(l10n.scWarehouse, (o) => scUnitMoney(o.unit[CostLine.warehouse])),
          row(l10n.scLabor, (o) => scUnitMoney(o.unit.labor)),
          row(l10n.scOther, (o) => scUnitMoney(o.unit[CostLine.overhead] + o.unit[CostLine.other] + o.unit.salesRelated)),
          row(l10n.scLandedCost, (o) => scUnitMoney(o.unit.landed), strong: true),
          row(l10n.scSalesPrice, (o) => scUnitMoney(o.salesPrice)),
          row(l10n.scProfitPerUnit, (o) => scUnitMoney(o.profitPerUnit),
              strong: true,
              color: (o) => o.profitPerUnit < 0 ? AppColors.danger : (o.key == best?.key ? AppColors.success : null)),
          row(l10n.scMargin, (o) => scPercent(o.margin)),
          row(l10n.scLeadTimeDays, (o) => scNumber(o.leadTimeDays)),
          row(l10n.scMoq, (o) => o.moq == null ? '—' : '${o.moq}'),
        ],
      ),
    );
  }
}

/// 掛率 65% / 70% / 75% … for every option (§7).
class _SweepTable extends StatelessWidget {
  const _SweepTable({required this.sweeps});

  final List<ScRateSweep> sweeps;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final keys = <String, String>{
      for (final s in sweeps)
        for (final o in s.options) o.key: '${o.partnerName} / ${o.routeName ?? l10n.scNoRoute}',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        key: const ValueKey('sc-sweep-table'),
        columns: [
          DataColumn(label: Text(l10n.scDiscountRate)),
          for (final name in keys.values) DataColumn(label: Text(name), numeric: true),
        ],
        rows: [
          for (final s in sweeps)
            DataRow(cells: [
              DataCell(Text(scRate(s.rate))),
              for (final k in keys.keys)
                DataCell(Builder(builder: (context) {
                  final o = s.options.where((x) => x.key == k).firstOrNull;
                  if (o == null) return const Text('—');
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${l10n.scLandedCost} ${scUnitMoney(o.unit.landed)}', style: theme.textTheme.bodySmall),
                      Text('${scUnitMoney(o.profitPerUnit)} · ${scPercent(o.margin)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: AppFonts.mono, color: o.profitPerUnit < 0 ? AppColors.danger : AppColors.success)),
                    ],
                  );
                })),
            ]),
        ],
      ),
    );
  }
}

class _Terms extends ConsumerWidget {
  const _Terms({required this.productId, required this.model});

  final int productId;
  final ScModel model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final canManage = ref.watch(scCanManageProvider);
    final terms = model.terms.where((t) => t.productId == productId).toList();
    final profile = model.products.where((p) => p.id == productId).firstOrNull?.profile;
    return ScSection(
      title: l10n.scSupplyTerms,
      trailing: canManage
          ? Wrap(children: [
              TextButton.icon(
                key: const ValueKey('sc-edit-profile'),
                onPressed: () => showDialog(context: context, builder: (_) => ScProfileDialog(productId: productId, profile: profile)),
                icon: const Icon(Icons.tune, size: 18),
                label: Text(l10n.scEditProfile),
              ),
              TextButton.icon(
                key: const ValueKey('sc-add-term'),
                onPressed: () => showDialog(context: context, builder: (_) => ScTermDialog(productId: productId, model: model)),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.scAddTerm),
              ),
            ])
          : null,
      child: Column(
        children: [
          if (terms.isEmpty) Text(l10n.scNoTerms),
          for (final t in terms)
            ListTile(
              key: ValueKey('sc-term-${t.id}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(t.isPrimary ? Icons.star : Icons.store_outlined),
              title: Text(model.partnerName(t.partnerId)),
              subtitle: Text([
                if (t.listPrice != null) '${l10n.scListPrice} ${scNumber(t.listPrice!)}',
                if (t.discountRate != null) '${l10n.scDiscountRate} ${scRate(t.discountRate)}',
                if (t.unitPrice != null) '${l10n.scUnitPrice} ${scNumber(t.unitPrice!)}',
                t.currency ?? 'JPY',
                if (t.moq != null) 'MOQ ${t.moq}',
                if (t.leadTimeDays != null) l10n.scDays(scNumber(t.leadTimeDays!)),
              ].join(' · ')),
              onTap: canManage
                  ? () => showDialog(context: context, builder: (_) => ScTermDialog(productId: productId, term: t, model: model))
                  : null,
            ),
        ],
      ),
    );
  }
}

class _StatsTab extends ConsumerWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ref.watch(scSupplierStatsProvider).when(
          loading: () => LoadingView(message: l10n.loading),
          error: (e, _) => ErrorStateView(message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => ref.invalidate(scSupplierStatsProvider)),
          data: (rows) => rows.isEmpty
              ? EmptyStateView(icon: Icons.store_outlined, title: l10n.scNoTerms)
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    for (final s in rows)
                      Card(
                        key: ValueKey('sc-stat-${s.partnerId}'),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${s.name}${s.countryCode != null ? ' (${s.countryCode})' : ''}', style: theme.textTheme.titleSmall),
                              Text(l10n.scStatLine(s.products, s.soleSourceProducts, s.purchaseOrders), style: theme.textTheme.bodySmall),
                              const SizedBox(height: AppSpacing.xs),
                              Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
                                StatusPill(tone: StatusTone.neutral, label: '${l10n.scPurchased} ${scMoney(s.purchasedAmount)}', dense: true),
                                if (s.avgLeadTimeDays != null)
                                  StatusPill(tone: StatusTone.neutral, label: '${l10n.scLeadTime} ${l10n.scDays(scNumber(s.avgLeadTimeDays!))}', dense: true),
                                if (s.lateRate != null)
                                  StatusPill(
                                      tone: s.lateRate! > 0.1 ? StatusTone.warning : StatusTone.success,
                                      label: '${l10n.scLateRate} ${scPercent(s.lateRate)}',
                                      dense: true),
                                if (s.defectRate != null)
                                  StatusPill(
                                      tone: s.defectRate! > 0.02 ? StatusTone.warning : StatusTone.success,
                                      label: '${l10n.scDefectRate} ${scPercent(s.defectRate, digits: 2)}',
                                      dense: true),
                                if (s.soleSourceProducts > 0)
                                  StatusPill(tone: StatusTone.warning, label: l10n.scReasonSole('${s.soleSourceProducts}'), dense: true),
                              ]),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        );
  }
}
