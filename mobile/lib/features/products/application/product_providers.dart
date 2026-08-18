import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepositoryImpl(ref.watch(dioProvider));
});

/// Runs a product search for the given query. An empty query lists recent
/// products. Keyed by query so distinct searches are cached independently.
final productSearchProvider =
    FutureProvider.autoDispose.family<List<Product>, String>((ref, query) async {
  final repository = ref.watch(productRepositoryProvider);
  final result = await repository.search(query: query);
  return result.when(
    success: (data) => data,
    failure: (failure) => throw Exception(failure.message),
  );
});

/// Loads a single product detail by id.
final productDetailProvider =
    FutureProvider.autoDispose.family<Product, int>((ref, id) async {
  final repository = ref.watch(productRepositoryProvider);
  final result = await repository.show(id);
  return result.when(
    success: (data) => data,
    failure: (failure) => throw Exception(failure.message),
  );
});
