import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/scan/scan_field.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
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

class _StockListScreenState extends ConsumerState<StockListScreen> {
  String _query = '';

  bool _matches(StockItem s) {
    final q = _query.trim();
    if (q.isEmpty) return true;
    final nq = normalizeJan(q);
    if (nq.isNotEmpty && s.janCode.contains(nq)) return true;
    return s.productName.toLowerCase().contains(q.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stock = ref.watch(stockListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.totalStockTitle)),
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
                  final filtered = items.where(_matches).toList();
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
                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) => _StockCard(item: filtered[i]),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName.isNotEmpty ? item.productName : item.janCode,
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.janCode,
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'FiraCode', color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            StatusPill(
              tone: item.onHand > 0 ? StatusTone.success : StatusTone.neutral,
              label: '${item.onHand}',
              icon: Icons.inventory_2_outlined,
            ),
          ],
        ),
      ),
    );
  }
}
