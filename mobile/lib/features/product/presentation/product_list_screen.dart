import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/product_filter.dart';
import '../application/product_providers.dart';
import '../domain/product.dart';
import 'product_delete.dart';
import 'product_detail_screen.dart';
import 'product_facts.dart';
import 'product_form_sheet.dart';
import 'product_lifecycle_ui.dart';
import '../../product_library/application/product_library_providers.dart';
import '../../product_library/presentation/product_library_screen.dart';
import '../../product_library/presentation/quote_import_screen.dart';
import '../../../core/ui/product_name.dart';
import '../../product_library/presentation/product_thumb.dart';

/// 商品ライブラリー: our products with their stock beside them (0120), the
/// SKU, base unit, pack units, codes and tracking (0057-0060).
///
/// Anyone who can see products sees them, and can narrow them by state,
/// maker, supplier, category and stock. Adding one — by hand or a whole
/// quotation — and editing need `product.manage`; deleting one never used
/// needs `product.delete` (0119); choosing many at once to make them
/// dormant, discontinued or archived needs `product.lifecycle` (0120). The
/// server checks each again.
class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  /// Null outside selection mode; the chosen product ids within it.
  Set<int>? _selected;

  void _snackError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
  }

  Future<void> _openForm({Product? product}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProductFormSheet(product: product),
    );
    if (saved == true) ref.invalidate(productListProvider);
  }

  Future<void> _openDetailById(int productId) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProductDetailScreen(productId: productId),
    ));
    // The detail screen can change the identity, the codes or the units, so the
    // list is refetched rather than left showing what it had.
    ref.invalidate(productListProvider);
  }

  /// The card's own switch: active ↔ dormant. Waking is harmless; putting
  /// to sleep hides the product from receiving and shipping, so it asks (§36).
  Future<void> _toggleStatus(Product product) async {
    final l10n = AppLocalizations.of(context);
    if (product.isActive) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.productDeactivateQ),
          content: Text(l10n.productDeactivateBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.productDeactivateAction),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    final result = await ref
        .read(productRepositoryProvider)
        .setStatus(product.id, product.isActive ? 'inactive' : 'active');
    if (!mounted) return;
    result.when(
      success: (_) => ref.invalidate(productListProvider),
      failure: (f) => _snackError(humanizeApiErrorMessage(l10n, f.message)),
    );
  }

  /// The chosen products into [target], after asking, with an optional reason.
  Future<void> _applyLifecycle(ProductLifecycle target) async {
    final l10n = AppLocalizations.of(context);
    final ids = (_selected ?? const <int>{}).toList()..sort();
    if (ids.isEmpty) return;
    final label = lifecycleLabel(l10n, target);
    final why = await showDialog<String>(
      context: context,
      builder: (_) => _LifecycleDialog(count: ids.length, target: target),
    );
    if (why == null || !mounted) return;
    final r = await ref
        .read(productRepositoryProvider)
        .setLifecycle(ids, target, reason: why.isEmpty ? null : why);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        setState(() => _selected = null);
        ref.invalidate(productListProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.lcDone(data, label))));
      case ApiFailure(:final message):
        _snackError(humanizeApiErrorMessage(l10n, message));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(filteredProductsProvider);
    final total = ref.watch(productListProvider).valueOrNull?.length;
    final filter = ref.watch(productFilterProvider);
    final photos = ref.watch(productPhotoViewProvider);
    final canManage = ref.watch(productLibraryCanManageProvider);
    final canDelete = ref.watch(productCanDeleteProvider);
    final canLifecycle = ref.watch(productCanLifecycleProvider);
    final selected = _selected;
    final shown = async.valueOrNull ?? const <Product>[];

    return Scaffold(
      appBar: selected != null
          ? AppBar(
              leading: IconButton(
                key: const ValueKey('lc-exit'),
                tooltip: l10n.actionCancel,
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selected = null),
              ),
              title: Text(l10n.lcSelected(selected.length)),
            )
          : AppBar(
              title: Text(l10n.productsTitle),
              actions: [
                // One place for our products: the list to edit them, or their
                // pictures to check and add photos. Either opens the same product.
                SegmentedButton<bool>(
                  key: const ValueKey('products-view'),
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: false, icon: const Icon(Icons.view_list_outlined), tooltip: l10n.productsListView),
                    ButtonSegment(value: true, icon: const Icon(Icons.photo_library_outlined), tooltip: l10n.productsPhotoView),
                  ],
                  selected: {photos},
                  onSelectionChanged: (v) => ref.read(productPhotoViewProvider.notifier).state = v.first,
                ),
                const SizedBox(width: AppSpacing.sm),
                if (!photos)
                  IconButton(
                    tooltip: l10n.productsShowInactive,
                    icon: Icon(filter.lifecycles.length > 1
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => ref.read(productFilterProvider.notifier).update((f) => f.copyWith(
                        lifecycles: f.lifecycles.length > 1 ? {ProductLifecycle.active} : ProductFilter.notArchived)),
                  ),
              ],
            ),
      // The chosen products' actions sit at the bottom, labelled, where they
      // cannot end up off the side of a narrow or zoomed window.
      bottomNavigationBar: selected == null
          ? null
          : _SelectionBar(
              count: selected.length,
              shown: shown.length,
              onSelectAll: () => setState(() => _selected = {for (final p in shown) p.id}),
              onClear: selected.isEmpty ? null : () => setState(() => _selected = {}),
              onApply: selected.isEmpty ? null : _applyLifecycle,
            ),
      floatingActionButton: canManage && selected == null
          ? FloatingActionButton(
              key: const ValueKey('products-add'),
              tooltip: l10n.productAddOne,
              onPressed: () => _openForm(),
              child: const Icon(Icons.add),
            )
          : null,
      body: photos
          ? ProductLibraryView(onOpen: (p) => _openDetailById(p.id))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: l10n.productsSearchHint,
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                    ),
                    onChanged: (value) => ref.read(productSearchProvider.notifier).state = value,
                  ),
                ),
                const _FilterBar(),
                if (total != null && async.hasValue)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xs),
                    child: Row(
                      children: [
                        // Any document listing products — quotation, invoice,
                        // catalogue — read by the AI and registered at once.
                        if (canManage && selected == null) ...[
                          FilledButton.tonalIcon(
                            key: const ValueKey('products-from-quote'),
                            onPressed: () async {
                              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QuoteImportScreen()));
                              ref.invalidate(productListProvider);
                            },
                            icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                            label: Text(l10n.quoteImportTitle),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        // Choosing many at once (0120), for the administrator.
                        if (canLifecycle && selected == null) ...[
                          OutlinedButton.icon(
                            key: const ValueKey('lc-start'),
                            onPressed: () => setState(() => _selected = {}),
                            icon: const Icon(Icons.checklist_outlined, size: 18),
                            label: Text(l10n.lcSelect),
                          ),
                          const SizedBox(width: AppSpacing.md),
                        ],
                        Expanded(
                          child: Text(
                            selected != null ? l10n.lcHint : l10n.pfShowing(shown.length, total),
                            key: const ValueKey('pf-showing'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
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
                          message: (total ?? 0) > 0 ? l10n.pfNoneMatch : l10n.productsEmptyBody,
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: () async => ref.invalidate(productListProvider),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 96),
                          itemCount: products.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, i) {
                            final p = products[i];
                            return _ProductCard(
                              product: p,
                              selected: selected?.contains(p.id),
                              // A long press starts choosing, on the product pressed.
                              onLongPress: canLifecycle && selected == null
                                  ? () => setState(() => _selected = {p.id})
                                  : null,
                              onTap: selected != null
                                  ? () => setState(() => selected.contains(p.id) ? selected.remove(p.id) : selected.add(p.id))
                                  : () => _openDetailById(p.id),
                              onToggleStatus: canManage && selected == null && p.lifecycle != ProductLifecycle.archived
                                  ? () => _toggleStatus(p)
                                  : null,
                              onEdit: canManage && selected == null ? () => _openForm(product: p) : null,
                              onDelete: canDelete && selected == null ? () => confirmDeleteProduct(context, ref, p) : null,
                            );
                          },
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

/// What can be done with the chosen products: choose all shown, clear,
/// and move them into a lifecycle — each a labelled button.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.shown,
    required this.onSelectAll,
    required this.onClear,
    required this.onApply,
  });

  final int count;
  final int shown;
  final VoidCallback onSelectAll;
  final VoidCallback? onClear;
  final void Function(ProductLifecycle)? onApply;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      key: const ValueKey('lc-bar'),
      elevation: 8,
      color: scheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(l10n.lcSelected(count), style: theme.textTheme.titleSmall),
              TextButton.icon(
                key: const ValueKey('lc-select-all'),
                onPressed: onSelectAll,
                icon: const Icon(Icons.select_all, size: 18),
                label: Text(l10n.lcSelectAll(shown)),
              ),
              TextButton.icon(
                key: const ValueKey('lc-clear'),
                onPressed: onClear,
                icon: const Icon(Icons.deselect, size: 18),
                label: Text(l10n.lcClear),
              ),
              const SizedBox(width: AppSpacing.md),
              for (final l in ProductLifecycle.values)
                FilledButton.tonalIcon(
                  key: ValueKey('lc-to-${l.wire}'),
                  style: l == ProductLifecycle.archived
                      ? FilledButton.styleFrom(backgroundColor: scheme.errorContainer, foregroundColor: scheme.onErrorContainer)
                      : null,
                  onPressed: onApply == null ? null : () => onApply!(l),
                  icon: Icon(lifecycleIcon(l), size: 18),
                  label: Text(lifecycleAction(l10n, l)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks before moving products into [target]; resolves to the reason typed
/// ('' for none), or null when cancelled.
class _LifecycleDialog extends StatefulWidget {
  const _LifecycleDialog({required this.count, required this.target});

  final int count;
  final ProductLifecycle target;

  @override
  State<_LifecycleDialog> createState() => _LifecycleDialogState();
}

class _LifecycleDialogState extends State<_LifecycleDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final target = widget.target;
    return AlertDialog(
      title: Text(l10n.lcConfirm(widget.count, lifecycleLabel(l10n, target))),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(switch (target) {
              ProductLifecycle.active => l10n.lcActiveBody,
              ProductLifecycle.dormant => l10n.lcDormantBody,
              ProductLifecycle.discontinued => l10n.lcDiscontinuedBody,
              ProductLifecycle.archived => l10n.lcArchivedBody,
            }),
            if (target != ProductLifecycle.active) ...[
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const ValueKey('lc-reason'),
                controller: _reason,
                decoration: InputDecoration(labelText: l10n.lcReason),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('lc-confirm'),
          onPressed: () => Navigator.pop(context, _reason.text.trim()),
          child: Text(lifecycleAction(l10n, target)),
        ),
      ],
    );
  }
}

/// The library's filters: state, maker, supplier, category and stock, each
/// a chip that opens its choices with how many products each has.
class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(productFilterProvider);
    final facets = ref.watch(productFacetsProvider);
    void set(ProductFilter f) => ref.read(productFilterProvider.notifier).state = f;

    String summary(String name, Iterable<String> picked) {
      final list = picked.toList();
      if (list.isEmpty) return name;
      return list.length == 1 ? '$name: ${list.single}' : '$name: ${list.first} +${list.length - 1}';
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          _FacetChip(
            key: const ValueKey('pf-lifecycle'),
            label: summary(l10n.pfLifecycle, [for (final l in filter.lifecycles) lifecycleLabel(l10n, l)]),
            active: filter.lifecycles.length != 1 || !filter.lifecycles.contains(ProductLifecycle.active),
            options: [
              for (final l in ProductLifecycle.values)
                (l.wire, lifecycleLabel(l10n, l), facets.lifecycles[l] ?? 0, filter.lifecycles.contains(l)),
            ],
            onChanged: (v, on) {
              final l = ProductLifecycle.parse(v)!;
              final next = {...filter.lifecycles};
              on ? next.add(l) : next.remove(l);
              set(filter.copyWith(lifecycles: next));
            },
          ),
          _FacetChip(
            key: const ValueKey('pf-maker'),
            label: summary(l10n.pfMaker, filter.makers),
            active: filter.makers.isNotEmpty,
            options: [
              for (final e in facets.makers.entries) (e.key, e.key, e.value, filter.makers.contains(e.key)),
            ],
            onChanged: (v, on) => set(filter.copyWith(makers: on ? {...filter.makers, v} : ({...filter.makers}..remove(v)))),
          ),
          _FacetChip(
            key: const ValueKey('pf-supplier'),
            label: summary(l10n.pfSupplier, [
              for (final id in filter.supplierIds) facets.suppliers[id]?.$1 ?? '#$id',
            ]),
            active: filter.supplierIds.isNotEmpty,
            options: [
              for (final e in facets.suppliers.entries)
                ('${e.key}', e.value.$1, e.value.$2, filter.supplierIds.contains(e.key)),
            ],
            onChanged: (v, on) {
              final id = int.parse(v);
              set(filter.copyWith(supplierIds: on ? {...filter.supplierIds, id} : ({...filter.supplierIds}..remove(id))));
            },
          ),
          if (facets.categories.isNotEmpty)
            _FacetChip(
              key: const ValueKey('pf-category'),
              label: summary(l10n.pfCategory, filter.categories),
              active: filter.categories.isNotEmpty,
              options: [
                for (final e in facets.categories.entries) (e.key, e.key, e.value, filter.categories.contains(e.key)),
              ],
              onChanged: (v, on) =>
                  set(filter.copyWith(categories: on ? {...filter.categories, v} : ({...filter.categories}..remove(v)))),
            ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: PopupMenuButton<StockFilter>(
              key: const ValueKey('pf-stock'),
              initialValue: filter.stock,
              onSelected: (v) => set(filter.copyWith(stock: v)),
              itemBuilder: (_) => [
                for (final s in StockFilter.values)
                  PopupMenuItem(key: ValueKey('pf-stock-${s.name}'), value: s, child: Text(_stockLabel(l10n, s))),
              ],
              child: Chip(
                avatar: const Icon(Icons.inventory_outlined, size: 18),
                label: Text(filter.stock == StockFilter.all ? l10n.pfStock : '${l10n.pfStock}: ${_stockLabel(l10n, filter.stock)}'),
                backgroundColor: filter.stock == StockFilter.all ? null : Theme.of(context).colorScheme.secondaryContainer,
              ),
            ),
          ),
          if (filter != const ProductFilter())
            ActionChip(
              key: const ValueKey('pf-clear'),
              avatar: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: Text(l10n.pfClear),
              onPressed: () => set(const ProductFilter()),
            ),
        ],
      ),
    );
  }

  static String _stockLabel(AppLocalizations l10n, StockFilter s) => switch (s) {
        StockFilter.all => l10n.pfStockAll,
        StockFilter.inStock => l10n.pfStockIn,
        StockFilter.outOfStock => l10n.pfStockOut,
      };
}

/// One filter: a chip that opens a list of choices to tick.
class _FacetChip extends StatelessWidget {
  const _FacetChip({
    super.key,
    required this.label,
    required this.active,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final bool active;

  /// (value, label, count, chosen).
  final List<(String, String, int, bool)> options;
  final void Function(String value, bool on) onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ActionChip(
        label: Text(label),
        avatar: Icon(Icons.arrow_drop_down, size: 18, color: active ? scheme.onSecondaryContainer : null),
        backgroundColor: active ? scheme.secondaryContainer : null,
        onPressed: options.isEmpty
            ? null
            : () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  builder: (sheetContext) => _FacetSheet(title: label, options: options, onChanged: onChanged),
                ),
      ),
    );
  }
}

class _FacetSheet extends StatefulWidget {
  const _FacetSheet({required this.title, required this.options, required this.onChanged});

  final String title;
  final List<(String, String, int, bool)> options;
  final void Function(String value, bool on) onChanged;

  @override
  State<_FacetSheet> createState() => _FacetSheetState();
}

class _FacetSheetState extends State<_FacetSheet> {
  late final Map<String, bool> _on = {for (final o in widget.options) o.$1: o.$4};

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final o in widget.options)
              CheckboxListTile(
                key: ValueKey('pf-opt-${o.$1}'),
                value: _on[o.$1],
                title: Text(widenKana(o.$2)),
                secondary: Text('${o.$3}'),
                onChanged: (v) {
                  setState(() => _on[o.$1] = v ?? false);
                  widget.onChanged(o.$1, v ?? false);
                },
              ),
          ],
        ),
      );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    this.onLongPress,
    this.selected,
    this.onToggleStatus,
    this.onEdit,
    this.onDelete,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Null outside selection mode; whether this one is chosen within it.
  final bool? selected;

  /// Null where the person may not change products.
  final VoidCallback? onToggleStatus;
  final VoidCallback? onEdit;

  /// Null without `product.delete`.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      color: selected == true ? Theme.of(context).colorScheme.secondaryContainer : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              if (selected != null)
                Checkbox(
                  key: ValueKey('lc-check-${product.id}'),
                  value: selected,
                  onChanged: (_) => onTap(),
                ),
              ProductThumb(productId: product.id, janCode: product.janCode, productName: product.name, size: 56),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProductNameText(
                        name: product.name,
                        nameEn: product.nameEn,
                        names: product.names,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1),
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
                    // What suppliers call it, so a search by a supplier's
                    // own name shows why this product matched (0087).
                    if (product.supplierNames.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        product.supplierNames
                            .map((n) => '${n.supplierDisplayName}: ${widenKana(n.supplierName)}'
                                '${n.supplierCode == null ? '' : ' (${widenKana(n.supplierCode!)})'}')
                            .join(' / '),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (product.category != null &&
                        product.category!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(product.category!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                    // Its stock where this person can see (0120).
                    if (product.stock case final st?) ...[
                      const SizedBox(height: 2),
                      StockLine(key: ValueKey('product-stock-${product.id}'), stock: st),
                    ],
                    if (product.lifecycleReason case final why? when !product.isActive)
                      Text(why, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
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
                  if (onEdit != null || onToggleStatus != null || onDelete != null)
                    PopupMenuButton<String>(
                      key: ValueKey('product-menu-${product.id}'),
                      tooltip: l10n.productMenu,
                      onSelected: (v) => switch (v) {
                        'edit' => onEdit?.call(),
                        'status' => onToggleStatus?.call(),
                        'delete' => onDelete?.call(),
                        _ => null,
                      },
                      itemBuilder: (_) => [
                        if (onEdit != null)
                          PopupMenuItem(value: 'edit', child: Text(l10n.productEdit)),
                        if (onToggleStatus != null)
                          PopupMenuItem(
                            value: 'status',
                            child: Text(product.isActive ? l10n.productDeactivateAction : l10n.lifecycleToActive),
                          ),
                        if (onDelete != null)
                          PopupMenuItem(
                            key: ValueKey('product-delete-${product.id}'),
                            value: 'delete',
                            child: Text(l10n.productDeleteAction, style: TextStyle(color: scheme.error)),
                          ),
                      ],
                    )
                  else
                    const SizedBox(height: AppSpacing.sm),
                  GestureDetector(
                    onTap: onToggleStatus,
                    child: LifecyclePill(lifecycle: product.lifecycle),
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
