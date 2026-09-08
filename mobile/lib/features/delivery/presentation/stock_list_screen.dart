import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/scan/scan_field.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../application/delivery_providers.dart';
import '../domain/jan.dart';
import '../domain/stock_item.dart';

/// The "総在庫" column: per-JAN total on-hand, accumulated from every completed
/// reconciliation. A scan/search box filters by JAN or product name.
class StockListScreen extends ConsumerStatefulWidget {
  const StockListScreen({super.key});

  @override
  ConsumerState<StockListScreen> createState() => _StockListScreenState();
}

enum _StockSort { onHand, name, jan }

class _StockListScreenState extends ConsumerState<StockListScreen> {
  String _query = '';
  _StockSort _sort = _StockSort.onHand;

  bool _matches(StockItem s) {
    final q = _query.trim();
    if (q.isEmpty) return true;
    final nq = normalizeJan(q);
    if (nq.isNotEmpty && s.janCode.contains(nq)) return true;
    return s.productName.toLowerCase().contains(q.toLowerCase());
  }

  List<StockItem> _sorted(List<StockItem> items) {
    final list = [...items];
    switch (_sort) {
      case _StockSort.onHand:
        list.sort((a, b) => b.onHand.compareTo(a.onHand));
      case _StockSort.name:
        list.sort((a, b) => (a.productName.isEmpty ? a.janCode : a.productName)
            .compareTo(b.productName.isEmpty ? b.janCode : b.productName));
      case _StockSort.jan:
        list.sort((a, b) => a.janCode.compareTo(b.janCode));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stock = ref.watch(stockListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.totalStockTitle),
        actions: [
          PopupMenuButton<_StockSort>(
            tooltip: l10n.sortMenu,
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (context) => [
              PopupMenuItem(
                  value: _StockSort.onHand, child: Text(l10n.sortByStock)),
              PopupMenuItem(
                  value: _StockSort.name, child: Text(l10n.sortByName)),
              PopupMenuItem(value: _StockSort.jan, child: Text(l10n.sortByJan)),
            ],
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            child: ScanField(
              autofocusOnWide: true,
              clearOnSubmit: false,
              hintText: l10n.scanOrTypeBarcode,
              onSubmitted: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(stockListProvider),
              child: stock.when(
                data: (items) {
                  final filtered = _sorted(items.where(_matches).toList());
                  if (items.isEmpty) {
                    return _ScrollableEmpty(
                      title: l10n.stockEmpty,
                      message: l10n.stockEmptyBody,
                    );
                  }
                  if (filtered.isEmpty) {
                    return _ScrollableEmpty(
                      title: l10n.deliveryNoMatches,
                      message: l10n.deliverySearchTip,
                    );
                  }
                  final totalUnits =
                      filtered.fold<int>(0, (s, it) => s + it.onHand);
                  return Column(
                    children: [
                      _SummaryStrip(
                          skuCount: filtered.length, totalUnits: totalUnits),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, i) =>
                              _StockCard(item: filtered[i]),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => LoadingView(message: l10n.loading),
                error: (e, _) => ErrorStateView(
                  message: '$e',
                  onRetry: () => ref.invalidate(stockListProvider),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact totals strip: number of SKUs and total units in view.
class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.skuCount, required this.totalUnits});

  final int skuCount;
  final int totalUnits;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Text(
            l10n.planPreviewCount(skuCount, totalUnits),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ScrollableEmpty extends StatelessWidget {
  const _ScrollableEmpty({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: EmptyStateView(
            icon: Icons.inventory_outlined, title: title, message: message),
      ),
    ]);
  }
}

class _StockCard extends StatelessWidget {
  const _StockCard({required this.item});

  final StockItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final zero = item.onHand <= 0;
    final hasName = item.productName.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasName ? item.productName : item.janCode,
                    style: theme.textTheme.titleSmall?.copyWith(
                        color: zero ? scheme.onSurfaceVariant : null),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasName) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.janCode,
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'FiraCode',
                          color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Prominent, right-aligned quantity so a shelf count reads fast.
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.onHand}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontFamily: 'FiraCode',
                    fontWeight: FontWeight.w700,
                    color: zero ? scheme.onSurfaceVariant : scheme.onSurface,
                  ),
                ),
                Text(
                  l10n.stockOnHandUnit,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
