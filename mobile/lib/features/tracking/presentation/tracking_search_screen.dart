import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/scan/scan_field.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../products/application/product_providers.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/product_stock_ui.dart';
import 'tracking_detail_screen.dart';

/// Step one of lot/serial tracking: find the product whose batches and serials
/// you want to inspect. Reuses the products search provider so the lookup
/// behaviour stays identical to Product Lookup and Stock Adjustment.
class TrackingSearchScreen extends ConsumerStatefulWidget {
  const TrackingSearchScreen({super.key});

  @override
  ConsumerState<TrackingSearchScreen> createState() =>
      _TrackingSearchScreenState();
}

class _TrackingSearchScreenState extends ConsumerState<TrackingSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final next = _controller.text.trim();
    if (next == _query) {
      ref.invalidate(productSearchProvider(_query));
    } else {
      setState(() => _query = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(productSearchProvider(_query));

    return Scaffold(
      appBar: AppBar(title: const Text('Lots & Serials')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ScanField(
              controller: _controller,
              autofocus: true,
              clearOnSubmit: false,
              hintText: 'Scan or type barcode, SKU, or name',
              onSubmitted: (_) => _submit(),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(productSearchProvider(_query)),
              child: results.when(
                data: (items) => items.isEmpty
                    ? EmptyStateView(
                        icon: Icons.search_off,
                        title: _query.isEmpty
                            ? 'Find a product to trace.'
                            : 'No matches for "$_query".',
                        message: 'Scan or type a barcode, SKU, or name.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) =>
                            _TrackingCandidateCard(product: items[index]),
                      ),
                loading: () => const LoadingView(message: 'Searching…'),
                error: (error, _) => ErrorStateView(
                  message: '$error',
                  onRetry: () => ref.invalidate(productSearchProvider(_query)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingCandidateCard extends StatelessWidget {
  const _TrackingCandidateCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stock = ProductStockUi.of(product);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TrackingDetailScreen(product: product),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              StatusAvatar(tone: stock.tone, icon: stock.icon),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.sku,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFamily: 'FiraCode',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
