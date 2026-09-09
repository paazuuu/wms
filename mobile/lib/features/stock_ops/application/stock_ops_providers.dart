import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/stock_ops_repository.dart';
import '../domain/stock_ops.dart';

final stockOpsRepositoryProvider = Provider<StockOpsRepository>((ref) {
  return StockOpsRepositoryImpl(ref.watch(deliveryDioProvider));
});

/// Recent reason-coded adjustments for the active warehouse.
final adjustmentListProvider =
    FutureProvider.autoDispose<List<StockAdjustment>>((ref) async {
  final warehouseId = ref.watch(activeWarehouseIdProvider);
  final result = await ref
      .watch(stockOpsRepositoryProvider)
      .adjustments(warehouseId: warehouseId);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// Count sessions for the active warehouse, newest first.
final stockCountListProvider =
    FutureProvider.autoDispose<List<StockCount>>((ref) async {
  final warehouseId = ref.watch(activeWarehouseIdProvider);
  final result = await ref
      .watch(stockOpsRepositoryProvider)
      .counts(warehouseId: warehouseId);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// One count session with its lines.
final stockCountDetailProvider =
    FutureProvider.autoDispose.family<StockCount, int>((ref, id) async {
  final result = await ref.watch(stockOpsRepositoryProvider).count(id);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});
