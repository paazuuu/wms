import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../data/virtual_stock_repository.dart';
import '../domain/virtual_stock.dart';

final virtualStockRepositoryProvider = Provider<VirtualStockRepository>((ref) {
  return VirtualStockRepositoryImpl(ref.watch(restDioProvider));
});

final virtualWarehousesProvider =
    FutureProvider.autoDispose<List<VirtualWarehouse>>((ref) async {
  final result = await ref.watch(virtualStockRepositoryProvider).warehouses();
  return result.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

typedef VirtualSummaryKey = ({int warehouseId, DateTime from, DateTime to});

final virtualStockSummaryProvider = FutureProvider.autoDispose
    .family<VirtualStockSummary, VirtualSummaryKey>((ref, key) async {
  final result = await ref
      .watch(virtualStockRepositoryProvider)
      .summary(key.warehouseId, from: key.from, to: key.to);
  return result.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

final virtualStockHistoryProvider = FutureProvider.autoDispose
    .family<List<VirtualStockEntry>, ({int warehouseId, int productId})>((ref, key) async {
  final result = await ref
      .watch(virtualStockRepositoryProvider)
      .history(key.warehouseId, key.productId);
  return result.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});
