import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/product.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import 'product_providers.dart';

/// Stock, as the library filters by it.
enum StockFilter { all, inStock, outOfStock }

/// What the product library shows (0120): by lifecycle, maker, supplier,
/// category and whether there is stock. Empty sets mean "any".
class ProductFilter extends Equatable {
  const ProductFilter({
    this.lifecycles = const {ProductLifecycle.active},
    this.makers = const {},
    this.supplierIds = const {},
    this.categories = const {},
    this.stock = StockFilter.all,
    this.withoutImages = false,
  });

  final Set<ProductLifecycle> lifecycles;
  final Set<String> makers;
  final Set<int> supplierIds;
  final Set<String> categories;
  final StockFilter stock;

  /// Only the products still without a picture (the photo view's old
  /// 写真なしのみ, now a filter of the one list).
  final bool withoutImages;

  /// Every lifecycle but the archived one: what "show inactive" shows.
  static const notArchived = {ProductLifecycle.active, ProductLifecycle.dormant, ProductLifecycle.discontinued};

  /// [warehouseId] narrows the stock test to one warehouse (null: every
  /// one the person can see); [stockIn] replaces [stock] for it.
  bool matches(Product p, {int? warehouseId, StockFilter? stockIn}) {
    if (lifecycles.isNotEmpty && !lifecycles.contains(p.lifecycle)) return false;
    if (makers.isNotEmpty && !makers.contains(p.maker ?? '')) return false;
    if (categories.isNotEmpty && !categories.contains(p.category ?? '')) return false;
    if (supplierIds.isNotEmpty && !p.suppliers.any((s) => supplierIds.contains(s.id))) return false;
    if (withoutImages && p.imageCount > 0) return false;
    final onHand = productStockIn(p, warehouseId).onHand;
    return switch (stockIn ?? stock) {
      StockFilter.all => true,
      StockFilter.inStock => onHand > 0,
      StockFilter.outOfStock => onHand <= 0,
    };
  }

  /// How many choices narrow the list beyond the default.
  int get narrowing =>
      makers.length + supplierIds.length + categories.length + (stock == StockFilter.all ? 0 : 1) +
      (withoutImages ? 1 : 0);

  ProductFilter copyWith({
    Set<ProductLifecycle>? lifecycles,
    Set<String>? makers,
    Set<int>? supplierIds,
    Set<String>? categories,
    StockFilter? stock,
    bool? withoutImages,
  }) =>
      ProductFilter(
        lifecycles: lifecycles ?? this.lifecycles,
        makers: makers ?? this.makers,
        supplierIds: supplierIds ?? this.supplierIds,
        categories: categories ?? this.categories,
        stock: stock ?? this.stock,
        withoutImages: withoutImages ?? this.withoutImages,
      );

  @override
  List<Object?> get props => [lifecycles, makers, supplierIds, categories, stock, withoutImages];
}

final productFilterProvider = StateProvider<ProductFilter>((_) => const ProductFilter());

/// The products the filter lets through.
final filteredProductsProvider = Provider.autoDispose<AsyncValue<List<Product>>>((ref) {
  final filter = ref.watch(productFilterProvider);
  return ref.watch(productListProvider).whenData((all) => [for (final p in all) if (filter.matches(p)) p]);
});

/// A product's stock in one warehouse, or in every warehouse the person can
/// see for null. A warehouse that is not in the product's breakdown holds
/// none of it.
({int onHand, int reserved, int available}) productStockIn(Product p, int? warehouseId) {
  final s = p.stock;
  if (s == null) return (onHand: 0, reserved: 0, available: 0);
  if (warehouseId == null) return (onHand: s.onHand, reserved: s.reserved, available: s.available);
  final w = s.warehouses.where((w) => w.warehouseId == warehouseId).firstOrNull;
  return w == null
      ? (onHand: 0, reserved: 0, available: 0)
      : (onHand: w.onHand, reserved: w.reserved, available: w.available);
}

/// The library shown as two panes side by side (or one above the other on a
/// narrow screen), each with its own warehouse.
final librarySplitProvider = StateProvider<bool>((_) => false);

/// The second pane's warehouse; null is every warehouse.
final _secondPaneWarehouseProvider = StateProvider<int?>((_) => null);

/// Which warehouse pane 0 or 1 shows; null is every warehouse. The first
/// pane is the app's own warehouse — the picker at the top right — so the
/// two always agree, and choosing in either changes both. The second pane
/// keeps its own for the session.
StateProvider<int?> libraryPaneWarehouseProvider(int pane) =>
    pane == 0 ? activeWarehouseIdProvider : _secondPaneWarehouseProvider;

/// Each pane's stock filter, against its own warehouse.
final libraryPaneStockProvider = StateProvider.family<StockFilter, int>((_, __) => StockFilter.all);

/// The products pane [pane] shows: the shared filters, and its own
/// warehouse's stock filter.
final libraryPaneProductsProvider = Provider.autoDispose.family<AsyncValue<List<Product>>, int>((ref, pane) {
  final filter = ref.watch(productFilterProvider);
  final warehouseId = ref.watch(libraryPaneWarehouseProvider(pane));
  final stock = ref.watch(libraryPaneStockProvider(pane));
  return ref.watch(productListProvider).whenData((all) => [
        for (final p in all)
          if (filter.matches(p, warehouseId: warehouseId, stockIn: stock)) p,
      ]);
});

/// What the filters can choose from, with how many products each has —
/// counted over every product that is not archived.
class ProductFacets extends Equatable {
  const ProductFacets({this.makers = const {}, this.suppliers = const {}, this.categories = const {}, this.lifecycles = const {}});

  final Map<String, int> makers;

  /// id → (name, count).
  final Map<int, (String, int)> suppliers;
  final Map<String, int> categories;
  final Map<ProductLifecycle, int> lifecycles;

  factory ProductFacets.of(List<Product> products) {
    final makers = <String, int>{};
    final suppliers = <int, (String, int)>{};
    final categories = <String, int>{};
    final lifecycles = <ProductLifecycle, int>{};
    for (final p in products) {
      lifecycles[p.lifecycle] = (lifecycles[p.lifecycle] ?? 0) + 1;
      if (p.lifecycle == ProductLifecycle.archived) continue;
      final m = p.maker?.trim() ?? '';
      if (m.isNotEmpty) makers[m] = (makers[m] ?? 0) + 1;
      final c = p.category?.trim() ?? '';
      if (c.isNotEmpty) categories[c] = (categories[c] ?? 0) + 1;
      for (final s in p.suppliers) {
        suppliers[s.id] = (s.name, (suppliers[s.id]?.$2 ?? 0) + 1);
      }
    }
    return ProductFacets(makers: makers, suppliers: suppliers, categories: categories, lifecycles: lifecycles);
  }

  @override
  List<Object?> get props => [makers, suppliers, categories, lifecycles];
}

final productFacetsProvider = Provider.autoDispose<ProductFacets>((ref) =>
    ProductFacets.of(ref.watch(productListProvider).valueOrNull ?? const []));
