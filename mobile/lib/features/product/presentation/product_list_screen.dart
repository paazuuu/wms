import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../application/product_providers.dart';
import '../domain/product.dart';
import 'product_detail_screen.dart';
import 'product_facts.dart';
import 'product_form_sheet.dart';

/// The product master (spec §19, 0032), now showing what 0057-0060 added to it:
/// the internal SKU, the base unit its quantities are counted in, the pack units
/// defined against it, how many barcodes reach it, and whether a lot or a serial
/// has to be recorded when it arrives.
///
/// Anyone can open this screen; the server is the real gate
/// (`product.view`/`product.manage`), same pattern as every other screen.
class ProductListScreen extends ConsumerWidget {
  const ProductListScreen({super.key});

  void _snackError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref,
      {Product? product}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProductFormSheet(product: product),
    );
    if (saved == true) {
      ref.invalidate(productListProvider);
    }
  }

  Future<void> _openDetail(
      BuildContext context, WidgetRef ref, Product product) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProductDetailScreen(productId: product.id),
    ));
    // The detail screen can change the identity, the codes or the units, so the
    // list is refetched rather than left showing what it had.
    ref.invalidate(productListProvider);
  }

  Future<void> _toggleStatus(
      BuildContext context, WidgetRef ref, Product product) async {
    final l10n = AppLocalizations.of(context);
    // Reactivating is harmless and needs no dialog; deactivating hides the
    // product from receiving/shipping, so confirm before that one (§36).
    if (product.isActive) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.productDeactivateQ),
          content: Text(l10n.productDeactivateBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.productDeactivateAction),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
    }

    final nextStatus = product.isActive ? 'inactive' : 'active';
    final result = await ref
        .read(productRepositoryProvider)
        .setStatus(product.id, nextStatus);
    if (!context.mounted) return;
    result.when(
      success: (_) => ref.invalidate(productListProvider),
      failure: (f) => _snackError(context, humanizeApiErrorMessage(l10n, f.message)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(productListProvider);
    final showInactive = ref.watch(showInactiveProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.productsTitle),
        actions: [
          IconButton(
            tooltip: l10n.productsShowInactive,
            icon: Icon(showInactive
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined),
            onPressed: () => ref
                .read(showInactiveProductsProvider.notifier)
                .update((v) => !v),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context, ref),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.productsSearchHint,
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
              ),
              onChanged: (value) =>
                  ref.read(productSearchProvider.notifier).state = value,
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => LoadingView(message: l10n.loading),
              error: (e, _) => ErrorStateView(
                message: '$e',
                onRetry: () => ref.invalidate(productListProvider),
              ),
              data: (products) {
                if (products.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.inventory_2_outlined,
                    title: l10n.productsEmpty,
                    message: l10n.productsEmptyBody,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(productListProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                    itemCount: products.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) => _ProductCard(
                      product: products[i],
                      onTap: () => _openDetail(context, ref, products[i]),
                      onToggleStatus: () =>
                          _toggleStatus(context, ref, products[i]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onToggleStatus,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(product.janCode,
                            style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: AppFonts.mono,
                                color: scheme.onSurfaceVariant)),
                        // The SKU sits beside the JAN rather than replacing it:
                        // one is what the supplier printed, the other is what
                        // this warehouse calls it, and both get scanned (0057).
                        if (product.sku != null) ...[
                          Text(' · ',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant)),
                          Flexible(
                            child: Text(product.sku!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                    fontFamily: AppFonts.mono,
                                    color: scheme.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ],
                    ),
                    if (product.category != null &&
                        product.category!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(product.category!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    ProductFacts(product: product),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (product.price != null)
                    Text('¥${product.price!.toStringAsFixed(0)}',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontFamily: AppFonts.mono)),
                  const SizedBox(height: AppSpacing.sm),
                  GestureDetector(
                    onTap: onToggleStatus,
                    child: StatusPill(
                      tone: product.isActive
                          ? StatusTone.success
                          : StatusTone.neutral,
                      label: product.isActive
                          ? l10n.productActive
                          : l10n.productInactive,
                      dense: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
