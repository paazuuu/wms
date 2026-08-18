import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/warehouse_repository.dart';
import '../domain/warehouse.dart';

final warehouseRepositoryProvider = Provider<WarehouseRepository>((ref) {
  return WarehouseRepositoryImpl(ref.watch(dioProvider));
});

/// Warehouses matching a search query. Empty query lists all warehouses.
final warehouseSearchProvider = FutureProvider.autoDispose
    .family<List<Warehouse>, String>((ref, query) async {
  final repository = ref.watch(warehouseRepositoryProvider);
  final result = await repository.list(search: query);
  return result.when(
    success: (data) => data,
    failure: (failure) => throw Exception(failure.message),
  );
});

/// A single warehouse with its full detail.
final warehouseDetailProvider =
    FutureProvider.autoDispose.family<Warehouse, int>((ref, id) async {
  final repository = ref.watch(warehouseRepositoryProvider);
  final result = await repository.show(id);
  return result.when(
    success: (data) => data,
    failure: (failure) => throw Exception(failure.message),
  );
});
