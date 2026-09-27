import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../product/presentation/unlinked_jan_screen.dart';
import '../../purchasing/domain/purchase_order.dart';
import '../../purchasing/presentation/purchase_order_detail_screen.dart';
import '../../purchasing/presentation/purchase_order_status_ui.dart';
import '../../../core/ui/status_pill.dart';
import '../../warehouse_context/presentation/warehouse_overview_screen.dart'
    show countryLabel;
import '../application/dashboard_providers.dart';
import '../domain/dashboard_charts.dart';

/// The categorical palette, in its fixed order (validated for adjacent
/// segments, light and dark). A series keeps its slot whatever else is on
/// screen: slots follow the entity, never its rank.
const _lightSlots = [
  Color(0xFF2A78D6), Color(0xFFEB6834), Color(0xFF1BAF7A), Color(0xFFEDA100),
  Color(0xFFE87BA4), Color(0xFF008300), Color(0xFF4A3AA7), Color(0xFFE34948),
];
const _darkSlots = [
  Color(0xFF3987E5), Color(0xFFD95926), Color(0xFF199E70), Color(0xFFC98500),
  Color(0xFFD55181), Color(0xFF008300), Color(0xFF9085E9), Color(0xFFE66767),
];

/// Neutral for folded-in series ("その他"), never a ninth hue.
const _otherLight = Color(0xFF9A9994);
const _otherDark = Color(0xFF6E6D68);

/// Palette slot [i] for a chart drawn elsewhere, so every chart shares one
/// palette.
Color chartSlotColor(int i, Brightness b) =>
    (b == Brightness.dark ? _darkSlots : _lightSlots)[i % _lightSlots.length];

/// The neutral that pairs with a slot for a comparison series.
Color chartNeutralColor(Brightness b) => b == Brightness.dark ? _otherDark : _otherLight;

enum StockBreakdown { warehouse, state }

/// One stacked series: a warehouse (or its virtual figure), or a stock state.
class _Series {
  const _Series({
    required this.key,
    required this.label,
    required this.color,
    required this.value,
    this.hatched = false,
  });

  final String key;
  final String label;
  final Color color;

  /// Hatched = virtual: counted, not held (0088).
  final bool hatched;
  final int Function(ChartProduct) value;
}

List<_Series> _seriesFor(
  StockBreakdown breakdown,
  StockChartData data,
  AppLocalizations l10n,
  bool dark,
) {
  final slots = dark ? _darkSlots : _lightSlots;
  final other = dark ? _otherDark : _otherLight;
  if (breakdown == StockBreakdown.state) {
    return [
      _Series(key: 'free', label: l10n.chartFree, color: slots[0], value: (p) => p.free),
      _Series(key: 'reserved', label: l10n.chartReserved, color: slots[1], value: (p) => p.reserved),
      _Series(key: 'unusable', label: l10n.chartUnusable, color: slots[2], value: (p) => p.unusable),
      _Series(
          key: 'virtual',
          label: l10n.chartVirtualAbroad,
          color: slots[3],
          hatched: true,
          value: (p) => p.virtualAbroad),
    ].where((s) => data.products.any((p) => s.value(p) > 0)).toList();
  }

  // Slots by the warehouse's place in the server's id-ordered list, so a
  // warehouse is the same colour on every visit. Past eight, the rest fold
  // into one neutral "other" series.
  final present = [
    for (final w in data.warehouses)
      if (data.products.any((p) => (p.byWarehouse[w.key] ?? 0) > 0)) w,
  ];
  final series = <_Series>[];
  for (var i = 0; i < data.warehouses.length && i < slots.length - 1; i++) {
    final w = data.warehouses[i];
    if (!present.contains(w)) continue;
    series.add(_Series(
      key: w.key,
      label: w.isVirtual ? l10n.chartWarehouseVirtual(w.name) : w.name,
      color: slots[i],
      hatched: w.isVirtual,
      value: (p) => p.byWarehouse[w.key] ?? 0,
    ));
  }
  final rest = data.warehouses.skip(slots.length - 1).map((w) => w.key).toSet();
  if (rest.isNotEmpty && data.products.any((p) => rest.any((k) => (p.byWarehouse[k] ?? 0) > 0))) {
    series.add(_Series(
      key: 'other',
      label: l10n.chartOther,
      color: other,
      value: (p) => rest.fold(0, (s, k) => s + (p.byWarehouse[k] ?? 0)),
    ));
  }
  return series;
}

/// A round axis maximum: 1, 2 or 5 times a power of ten.
int _niceMax(int v) {
  if (v <= 0) return 1;
  final exp = math.pow(10, (math.log(v) / math.ln10).floor()).toInt();
  for (final m in [1, 2, 5, 10]) {
    if (m * exp >= v) return m * exp;
  }
  return 10 * exp;
}

/// Stock per product as a horizontal stacked bar (§ dashboard, 0089), split by
/// warehouse or by state. Every figure is also in the table view, and each
/// bar's segments are in its tooltip, so no number hangs on colour alone.
class StockBreakdownPanel extends ConsumerStatefulWidget {
  const StockBreakdownPanel({super.key});

  @override
  ConsumerState<StockBreakdownPanel> createState() => _StockBreakdownPanelState();
}

class _StockBreakdownPanelState extends ConsumerState<StockBreakdownPanel> {
  StockBreakdown _breakdown = StockBreakdown.warehouse;
  bool _table = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final async = ref.watch(dashboardStockChartProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<StockBreakdown>(
                  segments: [
                    ButtonSegment(value: StockBreakdown.warehouse, label: Text(l10n.chartByWarehouse)),
                    ButtonSegment(value: StockBreakdown.state, label: Text(l10n.chartByState)),
                  ],
                  selected: {_breakdown},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => setState(() => _breakdown = v.first),
                ),
                IconButton(
                  tooltip: _table ? l10n.chartShowChart : l10n.chartShowTable,
                  icon: Icon(_table ? Icons.bar_chart : Icons.table_rows_outlined),
                  onPressed: () => setState(() => _table = !_table),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            async.when(
              loading: () => const SizedBox(
                  height: 160, child: Center(child: CircularProgressIndicator(strokeWidth: 3))),
              error: (e, _) => Row(
                children: [
                  const Icon(Icons.cloud_off_outlined),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text(l10n.somethingWentWrong)),
                  TextButton(
                    onPressed: () => ref.invalidate(dashboardStockChartProvider),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
              data: (data) {
                if (data.products.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (data.countries.length > 1) _CountryChips(data: data),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        child: Text(l10n.chartEmpty, style: theme.textTheme.bodyMedium),
                      ),
                      if (data.unregisteredJans > 0) _UnregisteredNote(data: data),
                    ],
                  );
                }
                final series =
                    _seriesFor(_breakdown, data, l10n, theme.brightness == Brightness.dark);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // One country at a time: stock is never added up across a
                    // border (0090).
                    if (data.countries.length > 1) ...[
                      _CountryChips(data: data),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    _Legend(series: series),
                    const SizedBox(height: AppSpacing.md),
                    if (_table)
                      _ChartTable(products: data.products, series: series)
                    else
                      _StackedBars(products: data.products, series: series),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.chartTopOfCountry(countryLabel(l10n, data.countryCode),
                          data.products.length, data.productCount),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    if (data.unregisteredJans > 0) _UnregisteredNote(data: data),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Stock the bars leave out because its JAN has no product record (0094),
/// with the way to fix it.
class _UnregisteredNote extends StatelessWidget {
  const _UnregisteredNote({required this.data});

  final StockChartData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final nf = NumberFormat.decimalPattern();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n.chartUnregisteredNote(
                  data.unregisteredJans, nf.format(data.unregisteredUnits)),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            key: const ValueKey('chart-unregistered-open'),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const UnlinkedJanScreen())),
            child: Text(l10n.chartUnregisteredAction),
          ),
        ],
      ),
    );
  }
}

class _CountryChips extends ConsumerWidget {
  const _CountryChips({required this.data});

  final StockChartData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final c in data.countries)
          ChoiceChip(
            label: Text(countryLabel(l10n, c)),
            selected: c == data.countryCode,
            onSelected: (_) => ref.read(dashboardChartCountryProvider.notifier).state = c,
          ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.series});

  final List<_Series> series;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.xs,
      children: [
        for (final s in series)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CustomPaint(painter: _SwatchPainter(s.color, s.hatched)),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(s.label, style: theme.textTheme.bodySmall),
            ],
          ),
      ],
    );
  }
}

class _SwatchPainter extends CustomPainter {
  const _SwatchPainter(this.color, this.hatched);

  final Color color;
  final bool hatched;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(3));
    canvas.drawRRect(rect, Paint()..color = color);
    if (hatched) _hatch(canvas, rect, color);
  }

  @override
  bool shouldRepaint(_SwatchPainter old) => old.color != color || old.hatched != hatched;
}

/// 45° lines a darker step of the fill's own colour: the texture channel that
/// marks a virtual figure without leaning on hue.
void _hatch(Canvas canvas, RRect rect, Color color) {
  final ink = Color.lerp(color, Colors.black, 0.35)!;
  final paint = Paint()
    ..color = ink
    ..strokeWidth = 1.5;
  canvas.save();
  canvas.clipRRect(rect);
  final r = rect.outerRect;
  for (var x = r.left - r.height; x < r.right; x += 5) {
    canvas.drawLine(Offset(x, r.bottom), Offset(x + r.height, r.top), paint);
  }
  canvas.restore();
}

class _StackedBars extends StatelessWidget {
  const _StackedBars({required this.products, required this.series});

  final List<ChartProduct> products;
  final List<_Series> series;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nf = NumberFormat.decimalPattern();
    final totals = [for (final p in products) series.fold(0, (s, x) => s + x.value(p))];
    final max = _niceMax(totals.fold(0, math.max));
    final grid = theme.colorScheme.outlineVariant.withValues(alpha: 0.6);

    return LayoutBuilder(builder: (context, constraints) {
      final labelWidth = math.min(160.0, constraints.maxWidth * 0.32);
      const totalWidth = 56.0;
      final barWidth = math.max(40.0, constraints.maxWidth - labelWidth - totalWidth - AppSpacing.md);

      return Column(
        children: [
          // Axis ticks on top: 0, half, max — the numbers the tip labels
          // and the tooltip don't carry.
          Row(
            children: [
              SizedBox(width: labelWidth + AppSpacing.md),
              SizedBox(
                width: barWidth,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const SizedBox(height: 16),
                    for (final (i, v) in [0, max ~/ 2, max].indexed)
                      Positioned(
                        left: i == 0 ? 0 : null,
                        right: i == 2 ? 0 : null,
                        child: i == 1
                            ? SizedBox(
                                width: barWidth,
                                child: Text(nf.format(v),
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.labelSmall
                                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                              )
                            : Text(nf.format(v),
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          for (var i = 0; i < products.length; i++)
            Tooltip(
              triggerMode: TooltipTriggerMode.tap,
              waitDuration: const Duration(milliseconds: 150),
              richMessage: TextSpan(children: [
                TextSpan(
                    text: '${products[i].displayName}\n',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                for (final s in series)
                  if (s.value(products[i]) > 0)
                    TextSpan(text: '${s.label}: ${nf.format(s.value(products[i]))}\n'),
                TextSpan(text: '${AppLocalizations.of(context).chartTotal} ${nf.format(totals[i])}'),
              ]),
              child: Semantics(
                label: '${products[i].displayName} ${nf.format(totals[i])}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: labelWidth,
                        child: Text(products[i].displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      // The total rides the bar's tip; the room for it is
                      // reserved past the axis end so the longest bar keeps it.
                      SizedBox(
                        width: barWidth + totalWidth,
                        height: 18,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            SizedBox(
                              width: barWidth,
                              height: 18,
                              child: CustomPaint(
                                painter: _BarPainter(
                                  values: [for (final s in series) s.value(products[i])],
                                  colors: [for (final s in series) s.color],
                                  hatched: [for (final s in series) s.hatched],
                                  max: max,
                                  grid: grid,
                                ),
                              ),
                            ),
                            Positioned(
                              left: barWidth * totals[i] / max + AppSpacing.xs,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: Text(nf.format(totals[i]),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.values,
    required this.colors,
    required this.hatched,
    required this.max,
    required this.grid,
  });

  final List<int> values;
  final List<Color> colors;
  final List<bool> hatched;
  final int max;
  final Color grid;

  static const _thickness = 14.0;
  static const _gap = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    // Hairline gridlines at the tick positions, recessive, drawn first.
    for (final f in [0.0, 0.5, 1.0]) {
      final x = (size.width * f).clamp(0.5, size.width - 0.5);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final top = (size.height - _thickness) / 2;
    final lastIndex = values.lastIndexWhere((v) => v > 0);
    var x = 0.0;
    for (var i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final w = size.width * values[i] / max;
      final gapAfter = i == lastIndex ? 0.0 : _gap;
      final width = math.max(1.0, w - gapAfter);
      final rect = Rect.fromLTWH(x, top, width, _thickness);
      // Square at the baseline, 4px round only at the bar's data end.
      final rrect = i == lastIndex
          ? RRect.fromRectAndCorners(rect,
              topRight: const Radius.circular(4), bottomRight: const Radius.circular(4))
          : RRect.fromRectAndRadius(rect, Radius.zero);
      canvas.drawRRect(rrect, Paint()..color = colors[i]);
      if (hatched[i]) _hatch(canvas, rrect, colors[i]);
      x += w;
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.max != max || old.values.join(',') != values.join(',') || old.colors != colors;
}

class _ChartTable extends StatelessWidget {
  const _ChartTable({required this.products, required this.series});

  final List<ChartProduct> products;
  final List<_Series> series;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nf = NumberFormat.decimalPattern();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: AppSpacing.lg,
        headingRowHeight: 36,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 44,
        columns: [
          DataColumn(label: Text(l10n.chartProduct)),
          for (final s in series) DataColumn(label: Text(s.label), numeric: true),
          DataColumn(label: Text(l10n.chartTotal), numeric: true),
        ],
        rows: [
          for (final p in products)
            DataRow(cells: [
              DataCell(ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(p.displayName, overflow: TextOverflow.ellipsis),
              )),
              for (final s in series) DataCell(Text(nf.format(s.value(p)))),
              DataCell(Text(nf.format(series.fold(0, (sum, s) => sum + s.value(p))))),
            ]),
        ],
      ),
    );
  }
}

/// The latest purchase orders, each with the warehouse it is bound for and how
/// much of it has arrived.
class RecentPurchaseOrdersPanel extends ConsumerWidget {
  const RecentPurchaseOrdersPanel({super.key, this.onOpenAll});

  final VoidCallback? onOpenAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final async = ref.watch(dashboardRecentPurchaseOrdersProvider);
    final df = DateFormat('M/d');
    final nf = NumberFormat.decimalPattern();

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: async.when(
          loading: () => const SizedBox(
              height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 3))),
          error: (e, _) => ListTile(
            leading: const Icon(Icons.cloud_off_outlined),
            title: Text(l10n.somethingWentWrong),
            trailing: TextButton(
              onPressed: () => ref.invalidate(dashboardRecentPurchaseOrdersProvider),
              child: Text(l10n.retry),
            ),
          ),
          data: (orders) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (orders.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(l10n.recentPoEmpty),
                ),
              for (final po in orders)
                InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PurchaseOrderDetailScreen(purchaseOrderId: po.id),
                  )),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                [po.poNumber ?? '#${po.id}', po.supplierName]
                                    .where((s) => s.isNotEmpty)
                                    .join(' · '),
                                style: theme.textTheme.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Builder(builder: (context) {
                              final ui = PurchaseOrderStatusUi.of(
                                  l10n, PurchaseOrderStatus.parse(po.status));
                              return StatusPill(
                                  tone: ui.tone, label: ui.label, icon: ui.icon, dense: true);
                            }),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            l10n.recentPoDestination(
                                po.warehouseName,
                                po.countryCode.isEmpty ? '' : '（${po.countryCode}）'),
                            if (po.expectedDate != null)
                              l10n.recentPoExpected(df.format(po.expectedDate!)),
                          ].join(' · '),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: po.receivedRatio,
                                  minHeight: 6,
                                  color: theme.brightness == Brightness.dark
                                      ? _darkSlots[0]
                                      : _lightSlots[0],
                                  // The track is a lighter step of the same blue.
                                  backgroundColor: theme.brightness == Brightness.dark
                                      ? const Color(0xFF184F95)
                                      : const Color(0xFFCDE2FB),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              l10n.recentPoReceived(
                                  nf.format(po.receivedUnits), nf.format(po.orderedUnits)),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (onOpenAll != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: onOpenAll, child: Text(l10n.recentPoOpenAll)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
