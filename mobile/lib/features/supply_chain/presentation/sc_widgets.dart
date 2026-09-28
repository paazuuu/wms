import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/supply_chain.dart';
import 'sc_labels.dart';

// Shared pieces of the supply chain screens (spec §31): KPI cards, the cost
// bar and waterfall, risk and load badges, the route graph, and the current
// vs. simulated table. Built from the app's own tokens so they sit with the
// rest of the WMS rather than a separate style.

/// One figure with its label (§4).
class ScKpiCard extends StatelessWidget {
  const ScKpiCard({super.key, required this.label, required this.value, this.sub, this.tone, this.emphasis = false, this.width = 168});

  final String label;
  final String value;
  final String? sub;
  final StatusTone? tone;
  final bool emphasis;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = switch (tone) {
      StatusTone.success => AppColors.success,
      StatusTone.danger => AppColors.danger,
      StatusTone.warning => AppColors.warning,
      StatusTone.info => AppColors.info,
      _ => scheme.onSurface,
    };
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        color: emphasis ? scheme.primaryContainer.withValues(alpha: 0.35) : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.xs),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700, color: color, fontFamily: AppFonts.mono)),
              ),
              if (sub != null)
                Text(sub!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The §4 KPIs of a run.
class ScKpiGrid extends StatelessWidget {
  const ScKpiGrid({super.key, required this.summary});

  final ScSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = summary;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        ScKpiCard(key: const ValueKey('sc-kpi-revenue'), label: l10n.scRevenue, value: scMoney(s.revenue)),
        ScKpiCard(label: l10n.scPurchase, value: scMoney(s.purchase)),
        if (s.fxImpact.abs() >= 0.5) ScKpiCard(label: l10n.scFxImpact, value: scSigned(s.fxImpact)),
        ScKpiCard(label: l10n.scLogistics, value: scMoney(s.logistics)),
        ScKpiCard(label: l10n.scCustoms, value: scMoney(s.customs)),
        ScKpiCard(label: l10n.scWarehouse, value: scMoney(s.warehouse)),
        ScKpiCard(label: l10n.scLabor, value: scMoney(s.labor)),
        ScKpiCard(label: l10n.scOther, value: scMoney(s.other + s.salesRelated)),
        ScKpiCard(key: const ValueKey('sc-kpi-total-cost'), label: l10n.scTotalCost, value: scMoney(s.totalCost), emphasis: true),
        ScKpiCard(
          key: const ValueKey('sc-kpi-profit'),
          label: l10n.scProfit,
          value: scMoney(s.profit),
          tone: s.profit < 0 ? StatusTone.danger : StatusTone.success,
          emphasis: true,
        ),
        ScKpiCard(
          key: const ValueKey('sc-kpi-margin'),
          label: l10n.scMargin,
          value: scPercent(s.margin),
          tone: (s.margin ?? 0) < 0 ? StatusTone.danger : null,
          emphasis: true,
        ),
        if (s.leadTimeDays != null) ScKpiCard(label: l10n.scLeadTime, value: l10n.scDays(s.leadTimeDays!.toStringAsFixed(1))),
      ],
    );
  }
}

/// Colours for the cost lines, stable across screens.
Color scLineColor(CostLine l) => switch (l) {
      CostLine.purchase => const Color(0xFF334155),
      CostLine.fxImpact => const Color(0xFF7C3AED),
      CostLine.internationalFreight => const Color(0xFF0369A1),
      CostLine.insurance => const Color(0xFF0EA5E9),
      CostLine.customsDuty => const Color(0xFFB45309),
      CostLine.importTax => const Color(0xFFD97706),
      CostLine.customsFee => const Color(0xFFF59E0B),
      CostLine.portFee => const Color(0xFF14B8A6),
      CostLine.domesticFreight => const Color(0xFF0891B2),
      CostLine.warehouse => const Color(0xFF16A34A),
      CostLine.receiving => const Color(0xFF65A30D),
      CostLine.inspection => const Color(0xFF84CC16),
      CostLine.packing => const Color(0xFFA3E635),
      CostLine.labor => const Color(0xFFDB2777),
      CostLine.overhead => const Color(0xFF9CA3AF),
      CostLine.other => const Color(0xFFCBD5E1),
    };

/// One stacked bar of what a cost is made of, with a legend (§31
/// CostBreakdownChart).
class ScCostBreakdownBar extends StatelessWidget {
  const ScCostBreakdownBar({super.key, required this.lines, this.unit = false});

  final Map<CostLine, double> lines;
  final bool unit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final parts = [
      for (final l in CostLine.values)
        if ((lines[l] ?? 0) > 0) (l, lines[l]!),
    ];
    final total = parts.fold<double>(0, (s, p) => s + p.$2);
    if (total <= 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: SizedBox(
            height: 18,
            child: Row(
              children: [
                for (final (l, v) in parts)
                  Expanded(
                    flex: (v / total * 1000).round().clamp(1, 1000),
                    child: Container(color: scLineColor(l)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          children: [
            for (final (l, v) in parts)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, color: scLineColor(l)),
                  const SizedBox(width: 4),
                  Text('${scCostLineLabel(l10n, l)} ${unit ? scUnitMoney(v) : scMoney(v)} (${(v / total * 100).toStringAsFixed(1)}%)',
                      style: theme.textTheme.bodySmall),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// From the sales price down to the profit, one cost at a time (§32).
class ScProfitWaterfall extends StatelessWidget {
  const ScProfitWaterfall({super.key, required this.salesPrice, required this.unit, required this.profit});

  final double salesPrice;
  final CostBreakdown unit;
  final double profit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rows = <(String, double, Color)>[
      for (final l in CostLine.values)
        if (unit[l].abs() >= 0.005) (scCostLineLabel(l10n, l), -unit[l], scLineColor(l)),
      if (unit.salesRelated.abs() >= 0.005) (l10n.scSalesRelated, -unit.salesRelated, const Color(0xFF64748B)),
    ];
    final scale = [salesPrice.abs(), unit.landed + unit.salesRelated, profit.abs(), 1.0].reduce((a, b) => a > b ? a : b);

    Widget bar(String label, double value, Color color, {bool strong = false, Key? key}) => Padding(
          key: key,
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(label,
                    style: strong ? theme.textTheme.labelLarge : theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) => Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: (value.abs() / scale * c.maxWidth).clamp(2.0, c.maxWidth),
                      height: strong ? 16 : 12,
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 96,
                child: Text(value < 0 ? '-${scUnitMoney(-value)}' : scUnitMoney(value),
                    textAlign: TextAlign.right,
                    style: (strong ? theme.textTheme.labelLarge : theme.textTheme.bodySmall)
                        ?.copyWith(fontFamily: AppFonts.mono)),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        bar(l10n.scSalesPrice, salesPrice, scheme.primary, strong: true),
        for (final (label, v, color) in rows) bar(label, v, color),
        const Divider(height: AppSpacing.md),
        bar(l10n.scProfitPerUnit, profit, profit < 0 ? AppColors.danger : AppColors.success,
            strong: true, key: const ValueKey('sc-waterfall-profit')),
      ],
    );
  }
}

StatusTone scRiskTone(RiskLevel l) => switch (l) {
      RiskLevel.low => StatusTone.success,
      RiskLevel.medium => StatusTone.info,
      RiskLevel.high => StatusTone.warning,
      RiskLevel.critical => StatusTone.danger,
    };

class ScRiskBadge extends StatelessWidget {
  const ScRiskBadge({super.key, required this.level});

  final RiskLevel level;

  @override
  Widget build(BuildContext context) => StatusPill(
        tone: scRiskTone(level),
        label: scRiskLevelLabel(AppLocalizations.of(context), level),
        icon: level == RiskLevel.low ? Icons.check_circle_outline : Icons.warning_amber_outlined,
        dense: true,
      );
}

StatusTone scLoadTone(LoadStatus s) => switch (s) {
      LoadStatus.ok => StatusTone.success,
      LoadStatus.busy => StatusTone.warning,
      LoadStatus.exceeded || LoadStatus.stopped => StatusTone.danger,
      LoadStatus.noCapacity => StatusTone.neutral,
    };

/// How full a node or leg is (§18: "負荷 125% / CAPACITY EXCEEDED").
class ScLoadBar extends StatelessWidget {
  const ScLoadBar({super.key, required this.load});

  final ScLoad load;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = switch (load.status) {
      LoadStatus.ok => AppColors.success,
      LoadStatus.busy => AppColors.warning,
      LoadStatus.exceeded || LoadStatus.stopped => AppColors.danger,
      LoadStatus.noCapacity => theme.colorScheme.outline,
    };
    final pct = load.load;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(load.name, style: theme.textTheme.titleSmall)),
            StatusPill(tone: scLoadTone(load.status), label: scLoadStatusLabel(l10n, load.status), dense: true),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (pct != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: pct.clamp(0, 1), minHeight: 8, color: color, backgroundColor: color.withValues(alpha: 0.15)),
          ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          [
            if (pct != null) l10n.scLoadPercent(scPercent(pct, digits: 0)),
            l10n.scPerMonth(scNumber(load.unitsMonth)),
            if (load.capacityUnitsMonth != null) '/ ${scNumber(load.capacityUnitsMonth!)}',
            if (load.kgMonth > 0) '${scNumber(load.kgMonth)}kg',
            load.hasAlternative ? l10n.scAlternative : l10n.scNoAlternative,
          ].join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

IconData scModeIcon(String? mode) => switch (mode) {
      'sea' => Icons.directions_boat_outlined,
      'air' => Icons.flight_outlined,
      'truck' => Icons.local_shipping_outlined,
      'rail' => Icons.train_outlined,
      'courier' => Icons.delivery_dining_outlined,
      'internal' => Icons.swap_horiz,
      _ => Icons.arrow_forward,
    };

IconData scNodeIcon(String kind) => switch (kind) {
      'supplier' => Icons.factory_outlined,
      'port' => Icons.anchor_outlined,
      'airport' => Icons.local_airport_outlined,
      'customs' => Icons.gavel_outlined,
      'warehouse' => Icons.warehouse_outlined,
      'dc' => Icons.hub_outlined,
      'customer' => Icons.storefront_outlined,
      _ => Icons.place_outlined,
    };

/// A route as a chain: node → leg → node … (§33). Tapping a leg opens it.
class ScRouteGraph extends StatelessWidget {
  const ScRouteGraph({super.key, required this.route, required this.model, this.onLegTap});

  final ScRoute route;
  final ScModel model;
  final void Function(ScEdge edge)? onLegTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    Widget node(int id) {
      final n = model.node(id);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          color: scheme.surfaceContainerLow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(scNodeIcon(n?.kind ?? ''), size: 16, color: scheme.primary),
            const SizedBox(width: 4),
            Text(n?.name ?? '#$id', style: theme.textTheme.bodySmall),
          ],
        ),
      );
    }

    Widget leg(ScEdge e) {
      final cost = [
        if (e.costPerKg > 0) '${scUnitMoney(e.costPerKg)}/kg',
        if (e.costPerUnit > 0) '${scUnitMoney(e.costPerUnit)}/${l10n.scBasisPerUnit}',
        if (e.baseCost > 0) scMoney(e.baseCost),
      ].join(' ');
      final color = scRiskTone(e.riskLevel) == StatusTone.success ? scheme.outline : AppColors.warning;
      return InkWell(
        key: ValueKey('sc-leg-${route.id}-${e.seq}'),
        onTap: onLegTap == null ? null : () => onLegTap!(e),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(scModeIcon(e.mode), size: 16, color: color),
                const SizedBox(width: 2),
                Text(scModeLabel(l10n, e.mode), style: theme.textTheme.labelSmall),
                if (e.customsClearance) ...[
                  const SizedBox(width: 2),
                  Icon(Icons.gavel_outlined, size: 12, color: scheme.tertiary),
                ],
              ]),
              Container(width: 72, height: 2, color: color),
              Text([l10n.scDays(scNumber(e.leadTimeDays)), if (cost.isNotEmpty) cost].join(' '),
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          node(route.originNodeId),
          for (final e in route.edges) ...[leg(e), node(e.toNodeId)],
        ],
      ),
    );
  }
}

/// Current and simulated side by side, never mixed (rule 5).
class ScCompareTable extends StatelessWidget {
  const ScCompareTable({super.key, required this.current, required this.simulated});

  final ScSummary current;
  final ScSummary simulated;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final simColor = scheme.tertiaryContainer.withValues(alpha: 0.35);
    final mono = theme.textTheme.bodyMedium?.copyWith(fontFamily: AppFonts.mono);

    TableRow row(String label, double a, double b, {bool money = true, bool strong = false, bool costUp = true}) {
      final d = b - a;
      final good = costUp ? d < 0 : d > 0;
      final style = strong ? mono?.copyWith(fontWeight: FontWeight.w700) : mono;
      return TableRow(children: [
        Padding(padding: const EdgeInsets.all(6), child: Text(label, style: strong ? theme.textTheme.labelLarge : null)),
        Padding(padding: const EdgeInsets.all(6), child: Text(money ? scMoney(a) : scPercent(a), textAlign: TextAlign.right, style: style)),
        Container(
          color: simColor,
          padding: const EdgeInsets.all(6),
          child: Text(money ? scMoney(b) : scPercent(b), textAlign: TextAlign.right, style: style),
        ),
        Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            money ? scSigned(d) : scSignedPoints(d),
            textAlign: TextAlign.right,
            style: style?.copyWith(color: d.abs() < 0.005 ? null : (good ? AppColors.success : AppColors.danger)),
          ),
        ),
      ]);
    }

    return Table(
      key: const ValueKey('sc-compare-table'),
      columnWidths: const {0: FlexColumnWidth(1.4), 1: FlexColumnWidth(), 2: FlexColumnWidth(), 3: FlexColumnWidth()},
      border: TableBorder(horizontalInside: BorderSide(color: scheme.outlineVariant)),
      children: [
        TableRow(children: [
          const SizedBox(),
          Padding(padding: const EdgeInsets.all(6), child: Text(l10n.scCurrent, textAlign: TextAlign.right, style: theme.textTheme.labelMedium)),
          Container(
            color: simColor,
            padding: const EdgeInsets.all(6),
            child: Text(l10n.scSimulated, textAlign: TextAlign.right, style: theme.textTheme.labelMedium?.copyWith(color: scheme.tertiary)),
          ),
          Padding(padding: const EdgeInsets.all(6), child: Text(l10n.scDifference, textAlign: TextAlign.right, style: theme.textTheme.labelMedium)),
        ]),
        row(l10n.scRevenue, current.revenue, simulated.revenue, costUp: false),
        row(l10n.scPurchase, current.purchase + current.fxImpact, simulated.purchase + simulated.fxImpact),
        row(l10n.scLogistics, current.logistics, simulated.logistics),
        row(l10n.scCustoms, current.customs, simulated.customs),
        row(l10n.scWarehouse, current.warehouse, simulated.warehouse),
        row(l10n.scLabor, current.labor, simulated.labor),
        row(l10n.scOther, current.other + current.salesRelated, simulated.other + simulated.salesRelated),
        row(l10n.scTotalCost, current.totalCost, simulated.totalCost, strong: true),
        row(l10n.scProfit, current.profit, simulated.profit, strong: true, costUp: false),
        row(l10n.scMargin, current.margin ?? 0, simulated.margin ?? 0, money: false, costUp: false),
      ],
    );
  }
}

/// What moved the profit (§20, §30).
class ScDriversList extends StatelessWidget {
  const ScDriversList({super.key, required this.drivers, this.unit = false, this.limit = 6});

  final List<ScDriver> drivers;
  final bool unit;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (drivers.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final d in drivers.take(limit))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(child: Text(scLineLabel(l10n, d.line), style: theme.textTheme.bodySmall)),
                Text(
                  scSigned(d.delta, unit: unit),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: AppFonts.mono,
                    // A cost going up is bad; revenue going up is good.
                    color: (d.line == 'revenue' ? d.delta > 0 : d.delta < 0) ? AppColors.success : AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A titled card, the common frame of these screens.
class ScSection extends StatelessWidget {
  const ScSection({super.key, required this.title, required this.child, this.trailing, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                if (trailing != null) trailing!,
              ],
            ),
            if (subtitle != null)
              Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

/// A number field for the editors: text in, double out.
class ScNumberField extends StatelessWidget {
  const ScNumberField({super.key, required this.controller, required this.label, this.hint, this.suffix, this.width = 160, this.fieldKey});

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? suffix;
  final double width;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: TextField(
          key: fieldKey,
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: InputDecoration(labelText: label, hintText: hint, suffixText: suffix, isDense: true),
        ),
      );
}

double? scParse(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', ''));
String scFieldText(double? v) => v == null ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v');
