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
import 'product_alerts_tab.dart';
import 'product_delete.dart';
import 'product_detail_screen.dart';
import 'product_facts.dart';
import 'product_form_sheet.dart';
import 'product_labels.dart';
import 'product_lifecycle_ui.dart';
import '../../product_library/application/product_library_providers.dart';
import '../../master_import/presentation/master_import_screen.dart';
import '../../price_book/application/price_book_providers.dart';
import '../../price_book/presentation/price_book_import_screen.dart';
import '../../price_book/presentation/price_book_pick_screen.dart';
import '../../../core/ui/product_name.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../../warehouse_context/domain/warehouse.dart';
import '../../product_library/presentation/product_thumb.dart';

/// 商品マスタ: what each product is — its names, codes, attributes, size and
/// weight (0125), base unit, pack units and tracking (0057-0060). Suppliers,
/// their terms and stock are shown by 価格台帳 (0124/0125).
///
/// Anyone who can see products sees them, and can narrow them by state,
/// maker and category. Adding one — by hand or a whole
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

  /// 新規登録 (0130): how the products come in — a file of our own, items
  /// chosen from 価格台帳, or one by hand.
  Future<void> _newProducts() async {
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
            child: Text(l10n.pmNewTitle, style: Theme.of(c).textTheme.titleMedium),
          ),
          // ファイルから商品と在庫を登録 (0138): 商品マスタ first, then the
          // stock, all from the one file.
          ListTile(
            key: const ValueKey('new-master-stock'),
            leading: const Icon(Icons.playlist_add_check_outlined),
            title: Text(l10n.pmMasterStock),
            subtitle: Text(l10n.pmMasterStockDesc),
            onTap: () => Navigator.pop(c, 'master_stock'),
          ),
          ListTile(
            key: const ValueKey('new-file'),
            leading: const Icon(Icons.auto_awesome_outlined),
            title: Text(l10n.pmImportFile),
            subtitle: Text(l10n.pmNewFileDesc),
            onTap: () => Navigator.pop(c, 'file'),
          ),
          ListTile(
            key: const ValueKey('new-price-book'),
            leading: const Icon(Icons.request_quote_outlined),
            title: Text(l10n.pmFromPriceBook),
            subtitle: Text(l10n.pmNewPriceBookDesc),
            onTap: () => Navigator.pop(c, 'price_book'),
          ),
          ListTile(
            key: const ValueKey('new-manual'),
            leading: const Icon(Icons.edit_note_outlined),
            title: Text(l10n.pmNewManual),
            subtitle: Text(l10n.pmNewManualDesc),
            onTap: () => Navigator.pop(c, 'manual'),
          ),
          const SizedBox(height: AppSpacing.sm),
        ]),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'master_stock':
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MasterImportScreen()));
      case 'manual':
        await _openForm();
      case 'file':
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const PriceBookImportScreen(target: ImportTarget.library),
        ));
      case 'price_book':
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PriceBookPickScreen()));
    }
    ref.invalidate(productListProvider);
    ref.invalidate(productAlertsProvider);
  }

  /// The chosen products out of the master for good (0126), after the
  /// person types 削除. Those anything booked still names are kept.
  Future<void> _removeForGood() async {
    final l10n = AppLocalizations.of(context);
    final ids = (_selected ?? const <int>{}).toList()..sort();
    if (ids.isEmpty) return;
    final ok = await showDialog<bool>(context: context, builder: (_) => _RemoveDialog(count: ids.length));
    if (ok != true || !mounted) return;
    final r = await ref.read(productRepositoryProvider).deleteMany(ids);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        setState(() => _selected = null);
        ref.invalidate(productListProvider);
        ref.invalidate(priceBookListProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(data.inUse.isEmpty
              ? l10n.rmDone(data.removed.length)
              : l10n.rmDoneInUse(data.removed.length, data.inUse.length)),
        ));
      case ApiFailure(:final message):
        _snackError(humanizeApiErrorMessage(l10n, message));
    }
  }

  /// Into two panes, or back to one. A first split shows the first two
  /// warehouses when the one pane was showing every warehouse; else the
  /// second pane takes the first warehouse the first is not showing.
  void _toggleSplit(List<Warehouse> warehouses) {
    final on = !ref.read(librarySplitProvider);
    if (on && warehouses.length > 1) {
      final first = ref.read(libraryPaneWarehouseProvider(0));
      if (first == null) {
        ref.read(libraryPaneWarehouseProvider(0).notifier).state = warehouses[0].id;
        ref.read(libraryPaneWarehouseProvider(1).notifier).state = warehouses[1].id;
      } else {
        final second = ref.read(libraryPaneWarehouseProvider(1));
        if (second == null || second == first) {
          ref.read(libraryPaneWarehouseProvider(1).notifier).state =
              warehouses.firstWhere((w) => w.id != first).id;
        }
      }
    }
    ref.read(librarySplitProvider.notifier).state = on;
  }

  /// One pane: whose warehouse it shows, how many, and the products with
  /// their stock there.
  Widget _pane(int pane, {required List<Warehouse> warehouses, required int? total, required bool split}) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(libraryPaneProductsProvider(pane));
    final filter = ref.watch(productFilterProvider);
    final photos = ref.watch(productPhotoViewProvider);
    final canManage = ref.watch(productLibraryCanManageProvider);
    final canDelete = ref.watch(productCanDeleteProvider);
    final canLifecycle = ref.watch(productCanLifecycleProvider);
    // Choosing many: to move them between states, or to remove them.
    final canSelect = canLifecycle || canDelete;
    final selected = _selected;
    final shown = async.valueOrNull ?? const <Product>[];
    final chosen = ref.watch(libraryPaneWarehouseProvider(pane));
    // A warehouse no longer listed is read as every warehouse.
    final warehouseId = warehouses.any((w) => w.id == chosen) ? chosen : null;
    final stockFilter = ref.watch(libraryPaneStockProvider(pane));
    final suffix = pane == 0 ? '' : '-$pane';
    return Column(
      children: [
        _WarehouseBar(
          pane: pane,
          split: split,
          warehouses: warehouses,
          warehouseId: warehouseId,
          products: shown,
        ),
        if (total != null && async.hasValue)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.xs),
            child: Wrap(
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Choosing many at once (0120), for the administrator.
                if (pane == 0 && canSelect && selected == null) ...[
                  OutlinedButton.icon(
                    key: const ValueKey('lc-start'),
                    onPressed: () => setState(() => _selected = {}),
                    icon: const Icon(Icons.checklist_outlined, size: 18),
                    label: Text(l10n.lcSelect),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Text(
                    selected != null ? l10n.lcHint : l10n.pfShowing(shown.length, total),
                    key: ValueKey('pf-showing$suffix'),
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
                if ((total ?? 0) == 0) {
                  return EmptyStateView(
                    icon: Icons.inventory_2_outlined,
                    title: l10n.productsEmpty,
                    message: l10n.productsEmptyBody,
                  );
                }
                // There are products, only none the filters let
                // through: say where they are and offer to show them.
                if (stockFilter != StockFilter.all) {
                  return EmptyStateView(
                    key: ValueKey('pl-no-stock$suffix'),
                    icon: Icons.inventory_2_outlined,
                    title: stockFilter == StockFilter.inStock ? l10n.plNoneInStock : l10n.plNoneOutOfStock,
                  );
                }
                return _HiddenProducts(filter: filter);
              }
              void toggle(Product p) =>
                  setState(() => selected!.contains(p.id) ? selected.remove(p.id) : selected.add(p.id));
              if (photos) {
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(productListProvider),
                  child: GridView.builder(
                    key: ValueKey('products-grid$suffix'),
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 96),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      mainAxisExtent: 290,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                    ),
                    itemCount: products.length,
                    itemBuilder: (_, i) {
                      final p = products[i];
                      return _PhotoCard(
                        product: p,
                        warehouseId: warehouseId,
                        pane: pane,
                        selected: selected?.contains(p.id),
                        onTap: selected != null ? () => toggle(p) : () => _openDetailById(p.id),
                        onLongPress: canSelect && selected == null
                            ? () => setState(() => _selected = {p.id})
                            : null,
                      );
                    },
                  ),
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
                      warehouseId: warehouseId,
                      pane: pane,
                      selected: selected?.contains(p.id),
                      // A long press starts choosing, on the product pressed.
                      onLongPress: canSelect && selected == null
                          ? () => setState(() => _selected = {p.id})
                          : null,
                      onTap: selected != null ? () => toggle(p) : () => _openDetailById(p.id),
                      // Bringing back an archived or discontinued product is
                      // the administrator's (0123); the switch is for active ↔ dormant.
                      onToggleStatus: canManage &&
                              selected == null &&
                              (canLifecycle ||
                                  p.lifecycle == ProductLifecycle.active ||
                                  p.lifecycle == ProductLifecycle.dormant) &&
                              p.lifecycle != ProductLifecycle.archived
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final total = ref.watch(productListProvider).valueOrNull?.length;
    final filter = ref.watch(productFilterProvider);
    final photos = ref.watch(productPhotoViewProvider);
    final canManage = ref.watch(productLibraryCanManageProvider);
    final canDelete = ref.watch(productCanDeleteProvider);
    final canLifecycle = ref.watch(productCanLifecycleProvider);
    final selected = _selected;
    final shown = ref.watch(libraryPaneProductsProvider(0)).valueOrNull ?? const <Product>[];
    final warehouses = ref.watch(warehouseOverviewProvider).valueOrNull?.warehouses ?? const <Warehouse>[];
    final split = ref.watch(librarySplitProvider);
    final alertCount = ref.watch(productAlertsProvider).valueOrNull?.length ?? 0;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
                // Two warehouses side by side (or one above the other).
                if (warehouses.length > 1) ...[
                  IconButton(
                    key: const ValueKey('pl-split'),
                    tooltip: split ? l10n.plSplitOff : l10n.plSplitOn,
                    isSelected: split,
                    icon: const Icon(Icons.vertical_split_outlined),
                    selectedIcon: const Icon(Icons.vertical_split),
                    onPressed: () => _toggleSplit(warehouses),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
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
                IconButton(
                    tooltip: l10n.productsShowInactive,
                    icon: Icon(filter.lifecycles.length > 1
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => ref.read(productFilterProvider.notifier).update((f) => f.copyWith(
                        lifecycles: f.lifecycles.length > 1 ? {ProductLifecycle.active} : ProductFilter.notArchived)),
                  ),
              ],
              // The products, and the lines imports kept back (0130).
              bottom: TabBar(
                tabs: [
                  Tab(key: const ValueKey('pm-tab-list'), text: l10n.plTabList),
                  Tab(key: const ValueKey('pm-tab-alerts'), text: l10n.plTabAlerts(alertCount)),
                ],
              ),
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
              onApply: !canLifecycle || selected.isEmpty ? null : _applyLifecycle,
              showLifecycle: canLifecycle,
              onRemove: canDelete && selected.isNotEmpty ? _removeForGood : null,
              showRemove: canDelete,
            ),
      // 新規登録: from a file of our own, from 価格台帳, or one by hand.
      floatingActionButton: canManage && selected == null
          ? FloatingActionButton.extended(
              key: const ValueKey('products-add'),
              tooltip: l10n.pmNew,
              onPressed: _newProducts,
              icon: const Icon(Icons.add),
              label: Text(l10n.pmNew),
            )
          : null,
      // One list for both views: the same products, search, filters and
      // selection, drawn as cards or as pictures (0122).
      body: TabBarView(children: [
        Column(
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
            Expanded(
              child: !split
                  ? _pane(0, warehouses: warehouses, total: total, split: false)
                  // Two warehouses at once: side by side when there is room,
                  // else one above the other.
                  : LayoutBuilder(
                      builder: (context, c) => c.maxWidth >= 720
                          ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              Expanded(child: _pane(0, warehouses: warehouses, total: total, split: true)),
                              const VerticalDivider(width: 1),
                              Expanded(child: _pane(1, warehouses: warehouses, total: total, split: true)),
                            ])
                          : Column(children: [
                              Expanded(child: _pane(0, warehouses: warehouses, total: total, split: true)),
                              const Divider(height: 1),
                              Expanded(child: _pane(1, warehouses: warehouses, total: total, split: true)),
                            ]),
                    ),
            ),
          ],
        ),
        const ProductAlertsTab(),
      ]),
      ),
    );
  }
}

/// Shown when products exist but none pass the filters: how many are in
/// each state the filter leaves out, a button to show them, and one to clear
/// the filters.
class _HiddenProducts extends ConsumerWidget {
  const _HiddenProducts({required this.filter});

  final ProductFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final counts = ref.watch(productFacetsProvider).lifecycles;
    final hidden = [
      for (final l in ProductLifecycle.values)
        if (!filter.lifecycles.contains(l) && (counts[l] ?? 0) > 0) (l, counts[l]!),
    ];
    void set(ProductFilter f) => ref.read(productFilterProvider.notifier).state = f;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.pfNoneMatchTitle, key: const ValueKey('pf-none-title'), style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            if (hidden.isNotEmpty)
              Text(
                l10n.pfHiddenByState(hidden.map((h) => '${lifecycleLabel(l10n, h.$1)} ${h.$2}件').join('・')),
                key: const ValueKey('pf-hidden'),
                textAlign: TextAlign.center,
              )
            else
              Text(l10n.pfNoneMatch, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                for (final (l, n) in hidden)
                  FilledButton.tonalIcon(
                    key: ValueKey('pf-show-${l.wire}'),
                    onPressed: () => set(filter.copyWith(lifecycles: {...filter.lifecycles, l})),
                    icon: Icon(lifecycleIcon(l), size: 18),
                    label: Text(l10n.pfShowState(lifecycleLabel(l10n, l), n)),
                  ),
                OutlinedButton.icon(
                  key: const ValueKey('pf-clear-empty'),
                  onPressed: () => set(filter.copyWith(
                    lifecycles: ProductLifecycle.values.toSet(),
                    makers: const {},
                    supplierIds: const {},
                    categories: const {},
                    stock: StockFilter.all,
                    withoutImages: false,
                  )),
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                  label: Text(l10n.pfShowEverything),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One product as a picture: its face, name, maker, JAN, stock, state and
/// how many pictures it has — the same product as its card in the list.
class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.product,
    required this.onTap,
    this.onLongPress,
    this.selected,
    this.warehouseId,
    this.pane = 0,
  });

  final Product product;

  /// The pane's warehouse, whose stock is shown; null for every warehouse.
  final int? warehouseId;
  final int pane;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = product;
    return Card(
      key: ValueKey('pl-product-${p.id}'),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      color: selected == true ? scheme.secondaryContainer : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Stack(children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (_, c) => Center(
                    child: ProductThumb(
                      productId: p.id,
                      janCode: p.janCode,
                      productName: p.name,
                      size: c.maxHeight < c.maxWidth ? c.maxHeight : c.maxWidth,
                      openOnTap: false,
                    ),
                  ),
                ),
              ),
              if (selected != null)
                Positioned(
                  left: 4,
                  top: 4,
                  child: Checkbox(key: ValueKey('lc-check-${p.id}'), value: selected, onChanged: (_) => onTap()),
                ),
              if (p.lifecycle != ProductLifecycle.active)
                Positioned(right: 6, top: 6, child: LifecyclePill(lifecycle: p.lifecycle)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ProductNameText(name: p.name, nameEn: p.nameEn, names: p.names, maxLines: 1, style: theme.textTheme.titleSmall),
              Text([if (p.maker != null) widenKana(p.maker!), p.janCode].join(' · '),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
              if (specShort(weightG: p.unitWeightG, width: p.widthMm, depth: p.depthMm, height: p.heightMm, note: p.sizeNote)
                  case final spec?)
                Text(spec, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall),
              _StockLine(product: p, warehouseId: warehouseId, pane: pane, compact: true),
              Text(p.imageCount == 0 ? l10n.plNoImages : l10n.plImageCount(p.imageCount),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: p.imageCount == 0 ? scheme.error : scheme.onSurfaceVariant)),
            ]),
          ),
        ]),
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
    this.showLifecycle = true,
    this.onRemove,
    this.showRemove = false,
  });

  final int count;
  final int shown;
  final VoidCallback onSelectAll;
  final VoidCallback? onClear;
  final void Function(ProductLifecycle)? onApply;
  final bool showLifecycle;

  /// Removing for good (0126), for whoever holds product.delete.
  final VoidCallback? onRemove;
  final bool showRemove;

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
              if (showLifecycle)
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
              if (showRemove) ...[
                const SizedBox(width: AppSpacing.md),
                FilledButton.icon(
                  key: const ValueKey('lc-remove'),
                  style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_forever_outlined, size: 18),
                  label: Text(l10n.rmAction),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks before removing products for good: says what goes and what stays,
/// and is confirmed only once 削除 is typed.
class _RemoveDialog extends StatefulWidget {
  const _RemoveDialog({required this.count});

  final int count;

  @override
  State<_RemoveDialog> createState() => _RemoveDialogState();
}

class _RemoveDialogState extends State<_RemoveDialog> {
  final _word = TextEditingController();

  @override
  void dispose() {
    _word.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final ready = _word.text.trim() == l10n.rmConfirmWord;
    return AlertDialog(
      title: Text(l10n.rmQ(widget.count)),
      content: SizedBox(
        width: 480,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.rmBody),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('rm-word'),
            controller: _word,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.rmConfirmLabel),
            onChanged: (_) => setState(() {}),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('rm-confirm'),
          style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
          onPressed: ready ? () => Navigator.pop(context, true) : null,
          child: Text(l10n.rmAction),
        ),
      ],
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

/// The master's filters: state, maker and category, each a chip that opens
/// its choices with how many products each has. Suppliers and stock are the
/// library's (0125).
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
          FilterChip(
            key: const ValueKey('pf-without-images'),
            label: Text(l10n.plWithoutImages),
            selected: filter.withoutImages,
            onSelected: (v) => set(filter.copyWith(withoutImages: v)),
          ),
          const SizedBox(width: AppSpacing.sm),
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
    this.warehouseId,
    this.pane = 0,
    this.onLongPress,
    this.selected,
    this.onToggleStatus,
    this.onEdit,
    this.onDelete,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// The pane's warehouse, whose stock is shown; null for every warehouse.
  final int? warehouseId;
  final int pane;

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
                    // Its size and weight, as on the spec (0125).
                    if (specShort(
                            weightG: product.unitWeightG,
                            width: product.widthMm,
                            depth: product.depthMm,
                            height: product.heightMm,
                            note: product.sizeNote)
                        case final spec?) ...[
                      const SizedBox(height: 2),
                      Text(spec,
                          key: ValueKey('product-spec-${product.id}'),
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                    if (product.category != null &&
                        product.category!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(product.category!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                    if (product.lifecycleReason case final why? when !product.isActive)
                      Text(why, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    _StockLine(product: product, warehouseId: warehouseId, pane: pane),
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

/// Which warehouse a pane shows, unmissable: a tinted band naming it, a
/// chip for 全倉庫 and for each warehouse, the pane's stock filter, and how
/// much of what is shown is in stock there.
class _WarehouseBar extends ConsumerWidget {
  const _WarehouseBar({
    required this.pane,
    required this.split,
    required this.warehouses,
    required this.warehouseId,
    required this.products,
  });

  final int pane;
  final bool split;
  final List<Warehouse> warehouses;
  final int? warehouseId;
  final List<Product> products;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Each pane its own colour, so which side is which stays clear.
    final (bg, fg) = pane == 0
        ? (scheme.primaryContainer, scheme.onPrimaryContainer)
        : (scheme.tertiaryContainer, scheme.onTertiaryContainer);
    final name = warehouseId == null
        ? l10n.plAllWarehouses
        : warehouses.firstWhere((w) => w.id == warehouseId).name;
    final stock = ref.watch(libraryPaneStockProvider(pane));
    final suffix = pane == 0 ? '' : '-$pane';
    var items = 0;
    var units = 0;
    for (final p in products) {
      final s = productStockIn(p, warehouseId);
      if (s.onHand > 0) {
        items++;
        units += s.onHand;
      }
    }
    void choose(int? id) => ref.read(libraryPaneWarehouseProvider(pane).notifier).state = id;

    return Material(
      key: ValueKey('pl-warehouse-bar$suffix'),
      color: bg.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (split)
                CircleAvatar(
                  radius: 11,
                  backgroundColor: fg,
                  child: Text('${pane + 1}', style: theme.textTheme.labelSmall?.copyWith(color: bg)),
                ),
              Icon(warehouseId == null ? Icons.domain_outlined : Icons.warehouse_outlined, size: 20, color: fg),
              Text(
                l10n.plShowingWarehouse(name),
                key: ValueKey('pl-warehouse-name$suffix'),
                style: theme.textTheme.titleSmall?.copyWith(color: fg, fontWeight: FontWeight.w700),
              ),
              Text(
                l10n.plStockSummary(items, units),
                key: ValueKey('pl-stock-summary$suffix'),
                style: theme.textTheme.bodySmall?.copyWith(color: fg),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              ChoiceChip(
                key: ValueKey('pl-wh$suffix-all'),
                avatar: const Icon(Icons.domain_outlined, size: 16),
                label: Text(l10n.plAllWarehouses),
                selected: warehouseId == null,
                onSelected: (_) => choose(null),
              ),
              for (final w in warehouses) ...[
                const SizedBox(width: AppSpacing.xs),
                ChoiceChip(
                  key: ValueKey('pl-wh$suffix-${w.id}'),
                  label: Text(w.isActive ? w.name : '${w.name} (${l10n.plWarehouseInactive})'),
                  selected: warehouseId == w.id,
                  onSelected: (_) => choose(w.id),
                ),
              ],
              const SizedBox(width: AppSpacing.md),
              SegmentedButton<StockFilter>(
                key: ValueKey('pl-stock-filter$suffix'),
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: [
                  ButtonSegment(value: StockFilter.all, label: Text(l10n.plStockAll)),
                  ButtonSegment(value: StockFilter.inStock, label: Text(l10n.plStockIn)),
                  ButtonSegment(value: StockFilter.outOfStock, label: Text(l10n.plStockOut)),
                ],
                selected: {stock},
                onSelectionChanged: (v) => ref.read(libraryPaneStockProvider(pane).notifier).state = v.first,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// A product's stock in the pane's warehouse; for every warehouse, the total
/// and where it is.
class _StockLine extends StatelessWidget {
  const _StockLine({required this.product, required this.warehouseId, required this.pane, this.compact = false});

  final Product product;
  final int? warehouseId;
  final int pane;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = productStockIn(product, warehouseId);
    final key = ValueKey('pl-stock-$pane-${product.id}');
    if (s.onHand == 0 && s.reserved == 0) {
      return Text(
        warehouseId == null ? l10n.plNoStock : l10n.plNoStockHere,
        key: key,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
      );
    }
    final line = compact
        ? l10n.plStockShort(s.onHand, s.available)
        : l10n.plStockLine(s.onHand, s.reserved, s.available);
    final where = warehouseId == null && !compact && (product.stock?.warehouses.length ?? 0) > 0
        ? ' (${[for (final w in product.stock!.warehouses) '${w.name} ${w.onHand}'].join(' / ')})'
        : '';
    return Text(
      '$line$where',
      key: key,
      maxLines: compact ? 1 : 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelMedium?.copyWith(
        color: s.available > 0 ? scheme.primary : scheme.error,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
