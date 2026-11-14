import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/bar_chart.dart';
import '../../../l10n/app_localizations.dart';
import '../../admin/data/menu_visibility_repository.dart' show showPricesProvider;
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/profit_repository.dart';
import '../domain/monthly_profit.dart';

enum ProfitMeasure { profit, revenue, cost }

final _yen = NumberFormat('#,##0');
String yen(double v) => v < 0 ? '-¥${_yen.format(-v.round())}' : '¥${_yen.format(v.round())}';

/// 月ごとの収益 (0211), from every shipment that left: bars by month for the
/// profit (or the sales or the cost), narrowed by maker and by product, with
/// the period's totals, a table of the months and the products behind them.
class MonthlyProfitSection extends ConsumerStatefulWidget {
  const MonthlyProfitSection({super.key});

  @override
  ConsumerState<MonthlyProfitSection> createState() => _MonthlyProfitSectionState();
}

class _MonthlyProfitSectionState extends ConsumerState<MonthlyProfitSection> {
  int _months = 12;
  ProfitMeasure _measure = ProfitMeasure.profit;
  String? _maker;
  String? _product; // ProfitRow.key
  final _search = TextEditingController();
  int _productsShown = 10;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// null: both; 'stock' or 'proxy' (在庫外出荷, 0213).
  String? _kind;

  bool _keep(ProfitRow r) {
    if (_kind != null && r.kind != _kind) return false;
    if (_maker != null && (r.maker ?? '') != _maker) return false;
    if (_product != null && r.key != _product) return false;
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty && !'${r.name} ${r.jan ?? ''}'.toLowerCase().contains(q)) return false;
    return true;
  }

  double _value(ProfitMonth m) => switch (_measure) {
        ProfitMeasure.profit => m.profit,
        ProfitMeasure.revenue => m.revenue,
        ProfitMeasure.cost => m.costAll,
      };

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(showPricesProvider)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final warehouseId = ref.watch(activeWarehouseIdProvider);
    final async = ref.watch(monthlyProfitProvider((months: _months, warehouseId: warehouseId)));
    final now = DateTime.now();
    final months = monthsBetween(DateTime(now.year, now.month - _months + 1), now);

    return Card(
      key: const ValueKey('pf-section'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(l10n.pfTitle, style: theme.textTheme.titleMedium)),
            Tooltip(
              message: l10n.pfHelp,
              child: Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
            ),
          ]),
          const SizedBox(height: AppSpacing.sm),
          ...async.when(
            loading: () => [const Padding(padding: EdgeInsets.all(AppSpacing.lg), child: LinearProgressIndicator())],
            error: (e, _) => [
              Text(
                '$e'.contains('not permitted') ? l10n.pfNoPermission : humanizeApiErrorMessage(l10n, '$e'),
                key: const ValueKey('pf-error'),
                style: muted,
              ),
            ],
            data: (rows) => _body(context, l10n, rows, months),
          ),
        ]),
      ),
    );
  }

  List<Widget> _body(BuildContext context, AppLocalizations l10n, List<ProfitRow> rows, List<String> months) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final makers = {for (final r in rows) if (r.maker != null) r.maker!}.toList()..sort();
    final byMonth = profitByMonth(months, rows, _keep);
    final total = ProfitMonth('');
    for (final r in rows.where(_keep)) {
      total.add(r);
    }
    final products = profitByProduct(rows, (r) => _maker == null || (r.maker ?? '') == _maker);
    final q = _search.text.trim().toLowerCase();
    final listed = [
      for (final p in products)
        if (q.isEmpty || '${p.first.name} ${p.first.jan ?? ''}'.toLowerCase().contains(q)) p
    ];
    String pct(double? m) => m == null ? '—' : '${(m * 100).toStringAsFixed(1)}%';
    final compact = NumberFormat.compact(locale: Localizations.localeOf(context).toString());

    return [
      // The filters, in one row above the chart.
      Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SegmentedButton<int>(
          key: const ValueKey('pf-period'),
          segments: [for (final n in const [6, 12, 24]) ButtonSegment(value: n, label: Text(l10n.pfPeriod(n)))],
          selected: {_months},
          onSelectionChanged: (v) => setState(() => _months = v.first),
        ),
        // From our warehouse, or 在庫外出荷 (another company's, for a fee).
        SegmentedButton<String>(
          key: const ValueKey('pf-kind'),
          segments: [
            ButtonSegment(value: '', label: Text(l10n.pfKindAll)),
            ButtonSegment(value: 'stock', label: Text(l10n.pfKindStock)),
            ButtonSegment(value: 'proxy', label: Text(l10n.pfKindProxy)),
          ],
          selected: {_kind ?? ''},
          onSelectionChanged: (v) => setState(() => _kind = v.first.isEmpty ? null : v.first),
        ),
        SegmentedButton<ProfitMeasure>(
          key: const ValueKey('pf-measure'),
          segments: [
            ButtonSegment(value: ProfitMeasure.profit, label: Text(l10n.pfMeasureProfit)),
            ButtonSegment(value: ProfitMeasure.revenue, label: Text(l10n.pfMeasureRevenue)),
            ButtonSegment(value: ProfitMeasure.cost, label: Text(l10n.pfMeasureCost)),
          ],
          selected: {_measure},
          onSelectionChanged: (v) => setState(() => _measure = v.first),
        ),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String?>(
            key: const ValueKey('pf-maker'),
            initialValue: makers.contains(_maker) ? _maker : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.pfMaker, isDense: true),
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.pfAllMakers)),
              for (final m in makers) DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() {
              _maker = v;
              _product = null;
            }),
          ),
        ),
        SizedBox(
          width: 280,
          child: TextField(
            key: const ValueKey('pf-search'),
            controller: _search,
            onChanged: (_) => setState(() => _product = null),
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.pfSearch, isDense: true),
          ),
        ),
        if (_maker != null || _product != null || _search.text.isNotEmpty)
          TextButton.icon(
            key: const ValueKey('pf-clear'),
            onPressed: () => setState(() {
              _maker = null;
              _product = null;
              _search.clear();
            }),
            icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
            label: Text(l10n.pfClear),
          ),
      ]),
      if (_product != null)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: InputChip(
            key: const ValueKey('pf-product-chip'),
            label: Text(products.firstWhere((p) => p.first.key == _product, orElse: () => products.first).first.name),
            onDeleted: () => setState(() => _product = null),
          ),
        ),
      const SizedBox(height: AppSpacing.md),
      if (rows.isEmpty)
        Text(l10n.pfEmpty, key: const ValueKey('pf-empty'), style: muted)
      else ...[
        Text(
          l10n.pfTotals(yen(total.revenue), yen(total.costAll), yen(total.profit), pct(total.margin)) +
              (total.fee > 0 ? l10n.pfTotalsFee(yen(total.fee)) : '') +
              (total.freight > 0 ? l10n.pfTotalsFreight(yen(total.freight)) : ''),
          key: const ValueKey('pf-totals'),
          style: theme.textTheme.titleSmall,
        ),
        // Both kinds shown: how much each made.
        if (_kind == null && rows.any((r) => r.proxy))
          Text(l10n.pfSplit(yen(total.profitStock), yen(total.profitProxy)), key: const ValueKey('pf-split'), style: muted),
        const SizedBox(height: AppSpacing.md),
        BarChart(
          key: const ValueKey('pf-chart'),
          format: (v) => v == 0 ? '0' : compact.format(v),
          bars: [
            for (final m in byMonth)
              BarDatum(
                key: ValueKey('pf-bar-${m.month}'),
                label: m.month.endsWith('-01') || m == byMonth.first ? m.month.replaceFirst('-', '/') : m.month.substring(5),
                value: _value(m),
                tooltip: l10n.pfTooltip3(m.month.replaceFirst('-', '/'), yen(m.revenue), yen(m.cost), yen(m.fee),
                    yen(m.freight), yen(m.profit)),
              ),
          ],
        ),
        if (total.qtyNoCost > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.pfNoCost(total.qtyNoCost, yen(total.revenueNoCost)),
              key: const ValueKey('pf-no-cost'), style: TextStyle(color: scheme.warning)),
        ],
        if (total.qtyNoPrice > 0)
          Text(l10n.pfNoPrice(total.qtyNoPrice), key: const ValueKey('pf-no-price'), style: TextStyle(color: scheme.warning)),
        const SizedBox(height: AppSpacing.md),
        // The same numbers as a table: newest month first.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            key: const ValueKey('pf-table'),
            headingRowHeight: 36,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 40,
            columns: [
              DataColumn(label: Text(l10n.pfColMonth)),
              DataColumn(label: Text(l10n.pfColQty), numeric: true),
              DataColumn(label: Text(l10n.pfMeasureRevenue), numeric: true),
              DataColumn(label: Text(l10n.pfColBuy), numeric: true),
              DataColumn(label: Text(l10n.pfColFee), numeric: true),
              DataColumn(label: Text(l10n.pfColFreight), numeric: true),
              DataColumn(label: Text(l10n.pfMeasureProfit), numeric: true),
              DataColumn(label: Text(l10n.pfColMargin), numeric: true),
              DataColumn(label: Text(l10n.pfColNoCost), numeric: true),
            ],
            rows: [
              for (final m in byMonth.reversed)
                if (m.quantity > 0)
                  DataRow(cells: [
                    DataCell(Text(m.month.replaceFirst('-', '/'), key: ValueKey('pf-row-${m.month}'))),
                    DataCell(Text(_yen.format(m.quantity))),
                    DataCell(Text(yen(m.revenue))),
                    DataCell(Text(yen(m.cost))),
                    DataCell(Text(m.fee == 0 ? '—' : yen(m.fee))),
                    DataCell(Text(m.freight == 0 ? '—' : yen(m.freight))),
                    DataCell(Text(yen(m.profit),
                        style: TextStyle(fontWeight: FontWeight.w700, color: m.profit < 0 ? scheme.error : null))),
                    DataCell(Text(pct(m.margin))),
                    DataCell(Text(m.qtyNoCost == 0 ? '—' : _yen.format(m.qtyNoCost))),
                  ]),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.pfProducts, style: theme.textTheme.titleSmall),
        for (final p in listed.take(_productsShown))
          ListTile(
            key: ValueKey('pf-product-${p.first.key}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            selected: _product == p.first.key,
            onTap: () => setState(() => _product = _product == p.first.key ? null : p.first.key),
            title: Text(p.first.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text([if (p.first.maker != null) p.first.maker!, if (p.first.jan != null) 'JAN ${p.first.jan}'].join(' · '),
                style: muted),
            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(yen(p.total.profit),
                  style: theme.textTheme.titleSmall?.copyWith(color: p.total.profit < 0 ? scheme.error : null)),
              Text('${l10n.pfMeasureRevenue} ${yen(p.total.revenue)} · ${pct(p.total.margin)}', style: muted),
            ]),
          ),
        if (listed.length > _productsShown)
          TextButton(
            key: const ValueKey('pf-more'),
            onPressed: () => setState(() => _productsShown += 20),
            child: Text(l10n.pfShowMore(listed.length - _productsShown)),
          ),
      ],
    ];
  }
}
