import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../application/product_providers.dart';
import '../domain/product.dart';

/// The product master (spec §19, 0032): name, category, price against a JAN
/// — the same barcode already used throughout stock/receiving/picking, not a
/// new identifier. Anyone can open this screen; the server is the real gate
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
      builder: (_) => _ProductFormSheet(product: product),
    );
    if (saved == true) {
      ref.invalidate(productListProvider);
    }
  }

  Future<void> _toggleStatus(
      BuildContext context, WidgetRef ref, Product product) async {
    final nextStatus = product.isActive ? 'inactive' : 'active';
    final result = await ref
        .read(productRepositoryProvider)
        .setStatus(product.id, nextStatus);
    if (!context.mounted) return;
    result.when(
      success: (_) => ref.invalidate(productListProvider),
      failure: (f) => _snackError(context, f.message),
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
                      onTap: () =>
                          _openForm(context, ref, product: products[i]),
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
                    Text(product.janCode,
                        style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: AppFonts.mono,
                            color: scheme.onSurfaceVariant)),
                    if (product.category != null &&
                        product.category!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(product.category!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
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

/// Bottom sheet for creating or editing one product. The JAN code is fixed
/// once created — `update_product` never touches it — so it's read-only
/// (shown, not editable) when [product] is non-null.
class _ProductFormSheet extends ConsumerStatefulWidget {
  const _ProductFormSheet({this.product});

  final Product? product;

  @override
  ConsumerState<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends ConsumerState<_ProductFormSheet> {
  late final TextEditingController _jan =
      TextEditingController(text: widget.product?.janCode ?? '');
  late final TextEditingController _name =
      TextEditingController(text: widget.product?.name ?? '');
  late final TextEditingController _category =
      TextEditingController(text: widget.product?.category ?? '');
  late final TextEditingController _price = TextEditingController(
      text: widget.product?.price == null
          ? ''
          : widget.product!.price!.toStringAsFixed(0));
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.product != null;

  @override
  void dispose() {
    _jan.dispose();
    _name.dispose();
    _category.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_jan.text.trim().isEmpty || _name.text.trim().isEmpty) {
      setState(() => _error = l10n.productValidationRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    final category = _category.text.trim().isEmpty ? null : _category.text.trim();
    final price = double.tryParse(_price.text.trim());
    final repo = ref.read(productRepositoryProvider);

    String? errorMessage;
    if (_isEdit) {
      final result = await repo.update(
        id: widget.product!.id,
        name: _name.text.trim(),
        category: category,
        price: price,
      );
      result.when(success: (_) {}, failure: (f) => errorMessage = f.message);
    } else {
      final result = await repo.create(
        janCode: _jan.text.trim(),
        name: _name.text.trim(),
        category: category,
        price: price,
      );
      result.when(success: (_) {}, failure: (f) => errorMessage = f.message);
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = errorMessage;
    });
    if (errorMessage == null) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEdit ? l10n.productEditTitle : l10n.productNewTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _jan,
              readOnly: _isEdit,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.productJanCode),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: l10n.productName),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _category,
              decoration: InputDecoration(labelText: l10n.productCategory),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(labelText: l10n.productPrice),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!,
                  style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              height: AppSpacing.minTouch,
              child: FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.productSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
