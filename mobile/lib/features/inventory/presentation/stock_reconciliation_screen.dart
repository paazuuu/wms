import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../product/presentation/product_detail_screen.dart';
import '../application/inventory_providers.dart';
import '../domain/stock_discrepancy.dart';

/// Where `stock_levels.on_hand` and what `stock_units` actually sums to have
/// come apart (`stock_reconciliation`, 0061) — the safety property 0061's own
/// migration comment describes made checkable. An empty list is the
/// invariant holding, so this screen is a diagnostic to check now and then,
/// not an attention list that is normally worth looking at.
class StockReconciliationScreen extends ConsumerWidget {
  const StockReconciliationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(stockReconciliationProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.stockReconciliationTitle)),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(stockReconciliationProvider),
        ),
        data: (rows) => rows.isEmpty
            ? EmptyStateView(
                icon: Icons.fact_check_outlined,
                title: l10n.stockReconciliationEmpty,
                message: l10n.stockReconciliationEmptyBody,
              )
            : RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(stockReconciliationProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => _DiscrepancyCard(row: rows[i]),
                ),
              ),
      ),
    );
  }
}

class _DiscrepancyCard extends StatelessWidget {
  const _DiscrepancyCard({required this.row});

  final StockDiscrepancy row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final nf = NumberFormat.decimalPattern();
    final productId = row.productId;

    return Card(
      color: scheme.errorContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: productId == null
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(productId: productId),
                )),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_outlined,
                      size: 18, color: scheme.onErrorContainer),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(row.janCode,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(color: scheme.onErrorContainer),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                row.isUnlinked
                    ? l10n.stockReconciliationReasonUnlinked
                    : l10n.stockReconciliationReasonDrift,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onErrorContainer),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                children: [
                  Text(
                      l10n.stockReconciliationLevels(row.stockLevelsOnHand),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: scheme.onErrorContainer)),
                  Text(l10n.stockReconciliationUnits(row.stockUnitsOnHand),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: scheme.onErrorContainer)),
                  Text(
                      l10n.stockReconciliationDrift(
                          row.drift > 0
                              ? '+${nf.format(row.drift)}'
                              : nf.format(row.drift)),
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onErrorContainer,
                          fontFamily: AppFonts.mono)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
