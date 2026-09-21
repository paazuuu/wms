import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../product/presentation/product_detail_screen.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../application/inspection_providers.dart';
import '../domain/held_stock.dart';

/// Stock that is on hand and cannot ship: everything sitting in QC_PENDING
/// (§13, 0068).
///
/// This screen exists because held stock is invisible in the numbers people
/// normally read. It counts toward on-hand and not toward available, so a product
/// can say "100 in stock" and ship nothing — and before 0068 that state was not
/// even possible, so nobody had a habit of looking for it. This is the list that
/// explains the gap, ordered by the expiry closest to running out.
class HeldStockScreen extends ConsumerWidget {
  const HeldStockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final warehouseId = ref.watch(activeWarehouseIdProvider);

    if (warehouseId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.heldStockTitle)),
        body: EmptyStateView(
          icon: Icons.warehouse_outlined,
          title: l10n.heldStockNoWarehouse,
          message: l10n.heldStockEmptyBody,
        ),
      );
    }

    final async = ref.watch(heldStockProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.heldStockTitle)),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(heldStockProvider),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return EmptyStateView(
              icon: Icons.verified_outlined,
              title: l10n.heldStockEmpty,
              message: l10n.heldStockEmptyBody,
            );
          }
          final total = rows.fold(0, (sum, r) => sum + r.quantity);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(heldStockProvider),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _TotalBar(parcels: rows.length, units: total),
                const SizedBox(height: AppSpacing.md),
                for (final row in rows) ...[
                  _HeldCard(row: row),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The one number worth leading with: how much of the building's stock is
/// sitting there unable to move.
class _TotalBar extends StatelessWidget {
  const _TotalBar({required this.parcels, required this.units});

  final int parcels;
  final int units;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(Icons.pan_tool_outlined, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(l10n.heldStockTotal(units, parcels))),
          ],
        ),
      ),
    );
  }
}

class _HeldCard extends StatelessWidget {
  const _HeldCard({required this.row});

  final HeldStock row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final df = DateFormat('yyyy-MM-dd');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProductDetailScreen(productId: row.productId),
        )),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(row.productName ?? row.janCode ?? '—',
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text(l10n.heldStockQuantity(row.quantity),
                      style: theme.textTheme.titleSmall),
                ],
              ),
              if (row.janCode != null && row.productName != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(row.janCode!,
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  if (row.lotCode != null)
                    StatusPill(
                        tone: StatusTone.neutral,
                        label: l10n.heldStockLot(row.lotCode!),
                        dense: true),
                  if (row.serialNumber != null)
                    StatusPill(
                        tone: StatusTone.neutral,
                        label: row.serialNumber!,
                        dense: true),
                  // An expiry that has already passed on stock that cannot ship
                  // is the worst square on this screen, so it is marked as such.
                  if (row.expiry != null)
                    StatusPill(
                        tone: row.isExpired
                            ? StatusTone.danger
                            : StatusTone.warning,
                        label: l10n.heldStockExpiry(df.format(row.expiry!)),
                        dense: true),
                  // How long it has been waiting turns a queue into a priority.
                  if (row.daysHeld != null)
                    StatusPill(
                        tone: row.daysHeld! >= 3
                            ? StatusTone.warning
                            : StatusTone.neutral,
                        label: l10n.heldStockDays(row.daysHeld!),
                        dense: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
