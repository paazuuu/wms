import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../product/domain/warehouse_product.dart';
import '../../product/presentation/product_detail_screen.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../application/inventory_providers.dart';

/// Products under their reorder point in this warehouse (§31,
/// `replenishment_suggestions`).
///
/// The list is computed on every read rather than stored, so it cannot go stale
/// and nothing has to decide when to invalidate it — and it is measured against
/// `available`, not `on_hand`. That distinction is the whole reason this screen
/// tells the truth: a warehouse holding a hundred of something, ninety of them
/// quarantined, does need to reorder, and comparing against on-hand would have
/// said otherwise.
class ReplenishmentScreen extends ConsumerWidget {
  const ReplenishmentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final warehouseId = ref.watch(activeWarehouseIdProvider);

    if (warehouseId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.replenishmentTitle)),
        body: EmptyStateView(
          icon: Icons.warehouse_outlined,
          title: l10n.replenishmentNoWarehouse,
          message: l10n.replenishmentEmptyBody,
        ),
      );
    }

    final async = ref.watch(replenishmentProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.replenishmentTitle)),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(replenishmentProvider),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return EmptyStateView(
              icon: Icons.inventory_outlined,
              title: l10n.replenishmentEmpty,
              message: l10n.replenishmentEmptyBody,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(replenishmentProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) => _SuggestionCard(row: rows[i]),
            ),
          );
        },
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.row});

  final ReplenishmentSuggestion row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final nf = NumberFormat.decimalPattern();
    final unit = row.baseUom == null ? '' : ' ${row.baseUom}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // The product detail is where the reorder point was set and where it can
        // be changed, so that is where a disagreement with this list is settled.
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
                    child: Text(row.productName,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  // The number someone acts on, so it gets the pill.
                  StatusPill(
                    tone: StatusTone.warning,
                    label: l10n.replenishmentSuggest(
                        '${nf.format(row.suggestedQuantity)}$unit'),
                    dense: true,
                  ),
                ],
              ),
              if (row.janCode != null) ...[
                const SizedBox(height: 2),
                Text(
                  row.sku == null ? row.janCode! : '${row.janCode} · ${row.sku}',
                  style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: AppFonts.mono, color: scheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                children: [
                  Text(
                    '${l10n.stockAvailable} ${nf.format(row.available)}'
                    ' / ${l10n.whpReorderPoint} ${nf.format(row.reorderPoint ?? 0)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(l10n.replenishmentShortfall(nf.format(row.shortfall)),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                  // Why a product with stock on the shelf is nevertheless here.
                  if (row.blocked > 0)
                    Text(l10n.replenishmentBlocked(nf.format(row.blocked)),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.tertiary)),
                ],
              ),
              if (row.preferredSupplierName != null ||
                  row.leadTimeDays != null) ...[
                const SizedBox(height: 2),
                Text(
                  [
                    if (row.preferredSupplierName != null)
                      row.preferredSupplierName!,
                    if (row.leadTimeDays != null)
                      l10n.replenishmentLeadTime(row.leadTimeDays!),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
