import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../application/warehouse_providers.dart';
import '../domain/bin_stock.dart';

/// Every bin in one warehouse, and what is actually sitting in it right now
/// (`bin_stock_overview`, 0016). The location tree's own `onHand` per node is
/// a rollup; this is the breakdown a picker or a counter actually needs when
/// standing in front of a shelf asking "what's in this bin".
class BinStockOverviewScreen extends ConsumerWidget {
  const BinStockOverviewScreen({super.key, required this.warehouseId});

  final int warehouseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(binStockOverviewProvider(warehouseId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.binStockTitle)),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(binStockOverviewProvider(warehouseId)),
        ),
        data: (bins) => bins.isEmpty
            ? EmptyStateView(
                icon: Icons.inventory_2_outlined,
                title: l10n.binStockEmpty,
              )
            : RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(binStockOverviewProvider(warehouseId)),
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: bins.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => _BinCard(bin: bins[i]),
                ),
              ),
      ),
    );
  }
}

class _BinCard extends StatelessWidget {
  const _BinCard({required this.bin});

  final BinStock bin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 20, color: scheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(bin.binCode,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontFamily: AppFonts.mono)),
                ),
                Text(
                  bin.isEmpty
                      ? l10n.binStockBinEmpty
                      : l10n.binStockTotalUnits(bin.totalUnits),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontStyle: bin.isEmpty ? FontStyle.italic : null,
                  ),
                ),
              ],
            ),
            if (bin.lines.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              for (final line in bin.lines)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          line.productName.isEmpty
                              ? line.janCode
                              : line.productName,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text('× ${line.onHand}',
                          style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: AppFonts.mono,
                              color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
