import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/product.dart';
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
  });

  final Set<ProductLifecycle> lifecycles;
  final Set<String> makers;
  final Set<int> supplierIds;
  final Set<String> categories;
  final StockFilter stock;

  /// Every lifecycle but the archived one: what "show inactive" shows.
  static const notArchived = {ProductLifecycle.active, ProductLifecycle.dormant, ProductLifecycle.discontinued};

  bool matches(Product p) {
    if (lifecycles.isNotEmpty && !lifecycles.contains(p.lifecycle)) return false;
    if (makers.isNotEmpty && !makers.contains(p.maker ?? '')) return false;
    if (categories.isNotEmpty && !categories.contains(p.category ?? '')) return false;
    if (supplierIds.isNotEmpty && !p.suppliers.any((s) => supplierIds.contains(s.id))) return false;
    final onHand = p.stock?.onHand ?? 0;
    return switch (stock) {
      StockFilter.all => true,
      StockFilter.inStock => onHand > 0,
      StockFilter.outOfStock => onHand <= 0,
    };
  }

  /// How many choices narrow the list beyond the default.
  int get narrowing =>
      makers.length + supplierIds.length + categories.length + (stock == StockFilter.all ? 0 : 1);

  ProductFilter copyWith({
    Set<ProductLifecycle>? lifecycles,
    Set<String>? makers,
    Set<int>? supplierIds,
    Set<String>? categories,
    StockFilter? stock,
  }) =>
      ProductFilter(
        lifecycles: lifecycles ?? this.lifecycles,
        makers: makers ?? this.makers,
        supplierIds: supplierIds ?? this.supplierIds,
        categories: categories ?? this.categories,
        stock: stock ?? this.stock,
      );

  @override
  List<Object?> get props => [lifecycles, makers, supplierIds, categories, stock];
}

final productFilterProvider = StateProvider<ProductFilter>((_) => const ProductFilter());

/// The products the filter lets through.
final filteredProductsProvider = Provider.autoDispose<AsyncValue<List<Product>>>((ref) {
  final filter = ref.watch(productFilterProvider);
  return ref.watch(productListProvider).whenData((all) => [for (final p in all) if (filter.matches(p)) p]);
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
