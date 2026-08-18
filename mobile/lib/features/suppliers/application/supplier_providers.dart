import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/supplier_repository.dart';
import '../domain/supplier.dart';

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  return SupplierRepositoryImpl(ref.watch(dioProvider));
});

/// Suppliers matching a search query. Empty query lists all (recent) suppliers.
final supplierSearchProvider =
    FutureProvider.autoDispose.family<List<Supplier>, String>((ref, query) async {
  final repository = ref.watch(supplierRepositoryProvider);
  final result = await repository.list(search: query);
  return result.when(
    success: (data) => data,
    failure: (failure) => throw Exception(failure.message),
  );
});

/// A single supplier with its full detail.
final supplierDetailProvider =
    FutureProvider.autoDispose.family<Supplier, int>((ref, id) async {
  final repository = ref.watch(supplierRepositoryProvider);
  final result = await repository.show(id);
  return result.when(
    success: (data) => data,
    failure: (failure) => throw Exception(failure.message),
  );
});
