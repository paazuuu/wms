import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepositoryImpl(ref.watch(restDioProvider));
});

/// Free-text filter over name/JAN; empty shows every product in scope.
final productSearchProvider = StateProvider<String>((_) => '');

/// Whether the list also shows deactivated products.
final showInactiveProductsProvider = StateProvider<bool>((_) => false);

/// The product master filtered by [productSearchProvider] and
/// [showInactiveProductsProvider], name-sorted.
final productListProvider =
    FutureProvider.autoDispose<List<Product>>((ref) async {
  final search = ref.watch(productSearchProvider);
  final showInactive = ref.watch(showInactiveProductsProvider);
  final result = await ref.watch(productRepositoryProvider).list(
        search: search.isEmpty ? null : search,
        status: showInactive ? null : 'active',
      );
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});
