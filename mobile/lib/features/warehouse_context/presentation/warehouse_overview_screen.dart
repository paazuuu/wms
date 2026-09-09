import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../application/warehouse_providers.dart';
import '../domain/warehouse.dart';
import 'add_warehouse_screen.dart';
import 'bin_type_ui.dart';

/// The "all warehouses" view (spec §50): every warehouse with its headline
/// figures plus a company total, and the entry point for adding one. Tapping a
/// warehouse makes it the active context.
class WarehouseOverviewScreen extends ConsumerWidget {
  const WarehouseOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(warehouseOverviewProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.whOverviewTitle),
        actions: [
          IconButton(
            tooltip: l10n.whAdd,
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddWarehouseScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(warehouseOverviewProvider),
        ),
        data: (overview) {
          if (overview.warehouses.isEmpty) {
            return EmptyStateView(
              icon: Icons.warehouse_outlined,
              title: l10n.whNoWarehouses,
              message: l10n.whAdd,
            );
          }
          final activeId = ref.watch(activeWarehouseIdProvider);
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _TotalsCard(totals: overview.totals),
              const SizedBox(height: AppSpacing.lg),
              for (final w in overview.warehouses) ...[
                _WarehouseCard(
                  warehouse: w,
                  selected: activeId == w.id,
                  onTap: () {
                    ref.read(activeWarehouseIdProvider.notifier).state = w.id;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.totals});

  final WarehouseTotals totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final nf = NumberFormat.decimalPattern();

    return Card(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize_outlined,
                    size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Text(l10n.whTotals, style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(
                  nf.format(totals.warehouseCount),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontFamily: AppFonts.mono),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                _Stat(label: l10n.whStatSku, value: nf.format(totals.skuCount)),
                _Stat(label: l10n.whStatOnHand, value: nf.format(totals.onHand)),
                _Stat(
                    label: l10n.whStatInbound,
                    value: nf.format(totals.inboundOpen)),
                _Stat(
                    label: l10n.whStatOutbound,
                    value: nf.format(totals.outboundOpen)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WarehouseCard extends ConsumerWidget {
  const _WarehouseCard({
    required this.warehouse,
    required this.selected,
    required this.onTap,
  });

  final Warehouse warehouse;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final nf = NumberFormat.decimalPattern();
    final bins = ref.watch(warehouseBinsProvider(warehouse.id));

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: selected
          ? RoundedRectangleBorder(
              side: BorderSide(color: scheme.primary, width: 2),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusAvatar(
                    tone: warehouse.isActive
                        ? StatusTone.info
                        : StatusTone.neutral,
                    icon: Icons.warehouse_outlined,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(warehouse.name,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                          warehouse.code,
                          style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: AppFonts.mono,
                              color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (warehouse.usesLocations) ...[
                    StatusPill(
                        tone: StatusTone.info,
                        label: l10n.whLocationsOn,
                        icon: Icons.shelves,
                        dense: true),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  if (!warehouse.isActive)
                    StatusPill(
                        tone: StatusTone.neutral,
                        label: l10n.whInactive,
                        dense: true)
                  else if (selected)
                    Icon(Icons.check_circle, color: scheme.primary),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                children: [
                  _Stat(
                      label: l10n.whStatSku,
                      value: nf.format(warehouse.skuCount)),
                  _Stat(
                      label: l10n.whStatOnHand,
                      value: nf.format(warehouse.onHand)),
                  _Stat(
                      label: l10n.whStatInbound,
                      value: nf.format(warehouse.inboundOpen)),
                  _Stat(
                      label: l10n.whStatOutbound,
                      value: nf.format(warehouse.outboundOpen)),
                ],
              ),
              // Bins are a per-warehouse detail; show them once loaded so the
              // operator can see the warehouse is actually set up.
              ...bins.maybeWhen(
                data: (list) => list.isEmpty
                    ? const []
                    : [
                        const SizedBox(height: AppSpacing.md),
                        Text(l10n.whBinsTitle,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant)),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            for (final b in list)
                              StatusPill(
                                tone: BinTypeUi.of(l10n, b.binType).tone,
                                label: b.code,
                                dense: true,
                              ),
                          ],
                        ),
                      ],
                orElse: () => const [],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontFamily: AppFonts.mono, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
