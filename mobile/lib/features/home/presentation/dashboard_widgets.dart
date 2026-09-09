import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../application/dashboard_providers.dart';
import '../domain/dashboard_metrics.dart';

/// The live figures block at the top of the home dashboard: KPI tiles, a
/// 14-day inbound/outbound trend chart, and the outstanding / low-stock watch
/// lists. Fails soft — a load error shows a small retry card and leaves the
/// rest of the dashboard (the feature menu) usable.
class DashboardMetricsSection extends ConsumerWidget {
  const DashboardMetricsSection({super.key, this.onOpenOutstanding});

  /// Opens the delivery reconciliation list (the 未納 worklist's "source").
  final VoidCallback? onOpenOutstanding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(dashboardMetricsProvider);

    return async.when(
      loading: () => const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
      ),
      error: (e, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_outlined),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(l10n.somethingWentWrong)),
              TextButton(
                onPressed: () => ref.invalidate(dashboardMetricsProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
      data: (m) => _MetricsBody(metrics: m, onOpenOutstanding: onOpenOutstanding),
    );
  }
}

class _MetricsBody extends StatelessWidget {
  const _MetricsBody({required this.metrics, this.onOpenOutstanding});

  final DashboardMetrics metrics;
  final VoidCallback? onOpenOutstanding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nf = NumberFormat.decimalPattern();

    final tiles = <Widget>[
      _KpiTile(
        tone: StatusTone.success,
        icon: Icons.move_to_inbox_outlined,
        label: l10n.dashInboundToday,
        value: nf.format(metrics.inboundTodayUnits),
        caption: l10n.dashCount(metrics.inboundTodayEvents),
      ),
      _KpiTile(
        tone: StatusTone.info,
        icon: Icons.outbox_outlined,
        label: l10n.dashOutboundToday,
        value: nf.format(metrics.outboundTodayUnits),
        caption: l10n.dashCount(metrics.outboundTodayEvents),
      ),
      _KpiTile(
        tone: metrics.outstandingUnits > 0
            ? StatusTone.warning
            : StatusTone.neutral,
        icon: Icons.pending_actions_outlined,
        label: l10n.dashOutstanding,
        value: nf.format(metrics.outstandingUnits),
        caption: l10n.dashCount(metrics.outstandingPlanCount),
        onTap: onOpenOutstanding,
      ),
      _KpiTile(
        tone: StatusTone.neutral,
        icon: Icons.inventory_2_outlined,
        label: l10n.dashTotalStock,
        value: nf.format(metrics.totalOnHand),
        caption: l10n.dashSkuCount(metrics.totalSkus),
      ),
      _KpiTile(
        tone:
            metrics.lowStockCount > 0 ? StatusTone.danger : StatusTone.neutral,
        icon: Icons.warning_amber_outlined,
        label: l10n.dashLowStock,
        value: nf.format(metrics.lowStockCount),
        caption: l10n.dashThreshold(metrics.lowThreshold),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisExtent: 132,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
          ),
          itemCount: tiles.length,
          itemBuilder: (_, i) => tiles[i],
        ),
        const SizedBox(height: AppSpacing.lg),
        _TrendCard(trend: metrics.trend),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 640;
            final outstanding = _OutstandingCard(
                items: metrics.outstandingList, onOpen: onOpenOutstanding);
            final lowStock = _LowStockCard(items: metrics.lowStockList);
            if (!wide) {
              return Column(children: [
                outstanding,
                const SizedBox(height: AppSpacing.lg),
                lowStock,
              ]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: outstanding),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: lowStock),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.tone,
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    this.onTap,
  });

  final StatusTone tone;
  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusAvatar(tone: tone, icon: icon),
                  const Spacer(),
                  if (onTap != null)
                    Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                ],
              ),
              const Spacer(),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                    fontFamily: AppFonts.mono, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '$label · $caption',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A dependency-free grouped bar chart of inbound (green) vs outbound (blue)
/// units per day. Bars scale to the largest value in the window.
class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.trend});

  final List<TrendPoint> trend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final maxVal = trend.fold<int>(
        1, (m, p) => math.max(m, math.max(p.inbound, p.outbound)));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l10n.dashTrendTitle,
                      style: theme.textTheme.titleSmall),
                ),
                _LegendDot(color: AppColors.success, label: l10n.dashInbound),
                const SizedBox(width: AppSpacing.md),
                _LegendDot(color: AppColors.info, label: l10n.dashOutbound),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 120,
              child: trend.isEmpty
                  ? const SizedBox.shrink()
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final p in trend)
                          Expanded(
                            child: _DayBars(point: p, maxVal: maxVal),
                          ),
                      ],
                    ),
            ),
            if (trend.length >= 2) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_shortDay(trend.first.day),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                  Text(_shortDay(trend.last.day),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _shortDay(String iso) {
    // "2026-09-09" -> "9/9"
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (m == null || d == null) return iso;
    return '$m/$d';
  }
}

class _DayBars extends StatelessWidget {
  const _DayBars({required this.point, required this.maxVal});

  final TrendPoint point;
  final int maxVal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget bar(int value, Color color) => Expanded(
          child: Tooltip(
            message: '$value',
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: (value / maxVal).clamp(0.0, 1.0),
                alignment: Alignment.bottomCenter,
                child: Container(
                  decoration: BoxDecoration(
                    color: value == 0 ? scheme.surfaceContainerHighest : color,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(2)),
                  ),
                ),
              ),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          bar(point.inbound, AppColors.success),
          const SizedBox(width: 2),
          bar(point.outbound, AppColors.info),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _OutstandingCard extends StatelessWidget {
  const _OutstandingCard({required this.items, this.onOpen});

  final List<OutstandingPlanBrief> items;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nf = NumberFormat.decimalPattern();
    return _WatchCard(
      title: l10n.dashOutstandingListTitle,
      icon: Icons.pending_actions_outlined,
      tone: StatusTone.warning,
      onOpen: onOpen,
      emptyLabel: l10n.dashNoOutstanding,
      children: [
        for (final it in items)
          _WatchRow(
            title: it.deliveryNumber,
            subtitle: it.supplierName ?? '',
            trailing: nf.format(it.outstanding),
            trailingTone: StatusTone.warning,
          ),
      ],
    );
  }
}

class _LowStockCard extends StatelessWidget {
  const _LowStockCard({required this.items});

  final List<LowStockBrief> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nf = NumberFormat.decimalPattern();
    return _WatchCard(
      title: l10n.dashLowStockListTitle,
      icon: Icons.warning_amber_outlined,
      tone: StatusTone.danger,
      emptyLabel: l10n.dashNoAlerts,
      children: [
        for (final it in items)
          _WatchRow(
            title: it.productName?.isNotEmpty == true
                ? it.productName!
                : it.janCode,
            subtitle: it.productName?.isNotEmpty == true ? it.janCode : '',
            trailing: nf.format(it.onHand),
            trailingTone: it.onHand <= 0 ? StatusTone.danger : StatusTone.warning,
          ),
      ],
    );
  }
}

class _WatchCard extends StatelessWidget {
  const _WatchCard({
    required this.title,
    required this.icon,
    required this.tone,
    required this.emptyLabel,
    required this.children,
    this.onOpen,
  });

  final String title;
  final IconData icon;
  final StatusTone tone;
  final String emptyLabel;
  final List<Widget> children;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                    child:
                        Text(title, style: theme.textTheme.titleSmall)),
                if (onOpen != null && children.isNotEmpty)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onOpen,
                    icon: const Icon(Icons.chevron_right),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            if (children.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 18, color: AppColors.success),
                    const SizedBox(width: AppSpacing.sm),
                    Text(emptyLabel,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              )
            else
              ...children,
          ],
        ),
      ),
    );
  }
}

class _WatchRow extends StatelessWidget {
  const _WatchRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.trailingTone,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final StatusTone trailingTone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: AppFonts.mono,
                          color: scheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusPill(tone: trailingTone, label: trailing, dense: true),
        ],
      ),
    );
  }
}
