import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../application/product_providers.dart';
import '../domain/product.dart';
import 'product_detail_screen.dart';
import 'product_stock_ui.dart';

/// Scan a barcode or type a name/SKU to find a product and view its stock.
///
/// Uses a text query (works on web and mobile) against `GET /products?search=`.
/// The search is submitted explicitly to avoid a request per keystroke.
class ProductLookupScreen extends ConsumerStatefulWidget {
  const ProductLookupScreen({super.key, this.initialQuery});

  /// Pre-fills the search box and runs a search immediately — used when a scan
  /// from elsewhere in the app routes here.
  final String? initialQuery;

  @override
  ConsumerState<ProductLookupScreen> createState() =>
      _ProductLookupScreenState();
}

class _ProductLookupScreenState extends ConsumerState<ProductLookupScreen> {
  final _controller = TextEditingController();

  /// The query currently driving the results provider. Starts empty (recent
  /// products) and only changes when the user submits.
  String _query = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery?.trim() ?? '';
    if (initial.isNotEmpty) {
      _controller.text = initial;
      _query = initial;
    }
  }

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
      appBar: AppBar(title: const Text('Product Lookup')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Scan or type barcode, SKU, or name',
                prefixIcon: const Icon(Icons.qr_code_scanner_outlined),
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  icon: const Icon(Icons.search),
                  onPressed: _submit,
                ),
              ),
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
                            ? 'No products yet.'
                            : 'No matches for "$_query".',
                        message: 'Try a different barcode, SKU, or name.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) =>
                            _ProductCard(product: items[index]),
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

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

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
            builder: (_) => ProductDetailScreen(productId: product.id),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusPill(
                    tone: stock.tone,
                    label: '${product.displayStock}',
                    icon: stock.icon,
                    dense: true,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'in stock',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
