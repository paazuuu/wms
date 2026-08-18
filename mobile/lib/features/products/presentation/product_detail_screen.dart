import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../application/product_providers.dart';
import '../domain/product.dart';
import 'product_stock_ui.dart';

/// Read-only product detail: identity, stock status, and key attributes.
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productDetailProvider(productId));

    return Scaffold(
      appBar: AppBar(title: const Text('Product')),
      body: product.when(
        data: (p) => _ProductBody(product: p),
        loading: () => const LoadingView(message: 'Loading product…'),
        error: (error, _) => ErrorStateView(
          message: '$error',
          onRetry: () => ref.invalidate(productDetailProvider(productId)),
        ),
      ),
    );
  }
}

class _ProductBody extends StatelessWidget {
  const _ProductBody({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stock = ProductStockUi.of(product);
    final currency = product.currency ?? '';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusAvatar(tone: stock.tone, icon: stock.icon),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Text(
                        product.name,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    StatusPill(
                      tone: stock.tone,
                      label: '${stock.label} · ${product.displayStock}',
                      icon: stock.icon,
                    ),
                    if (!product.isActive)
                      const StatusPill(
                        tone: StatusTone.neutral,
                        label: 'Inactive',
                        icon: Icons.pause_circle_outline,
                      ),
                    if (product.hasVariants)
                      const StatusPill(
                        tone: StatusTone.info,
                        label: 'Has variants',
                        icon: Icons.account_tree_outlined,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                _InfoRow(
                  label: 'SKU',
                  value: product.sku,
                  mono: true,
                ),
                _InfoRow(
                  label: 'Barcode',
                  value: product.barcode ?? '—',
                  mono: true,
                ),
                _InfoRow(
                  label: 'On hand',
                  value: '${product.displayStock}',
                ),
                if (product.minStock != null)
                  _InfoRow(
                    label: 'Min stock',
                    value: '${product.minStock}',
                  ),
                if (product.price != null)
                  _InfoRow(
                    label: 'Price',
                    value: '$currency ${product.price}'.trim(),
                  ),
                if (product.sellingPrice != null)
                  _InfoRow(
                    label: 'Selling price',
                    value: '$currency ${product.sellingPrice}'.trim(),
                  ),
                if (product.categoryName != null)
                  _InfoRow(label: 'Category', value: product.categoryName!),
                if (product.locationName != null)
                  _InfoRow(label: 'Location', value: product.locationName!),
              ],
            ),
          ),
        ),
        if (product.description != null &&
            product.description!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(product.description!, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.mono = false});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: mono ? 'FiraCode' : null,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
