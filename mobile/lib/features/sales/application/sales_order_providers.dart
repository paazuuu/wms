import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/sales_order_repository.dart';
import '../domain/sales_order.dart';

final salesOrderRepositoryProvider = Provider<SalesOrderRepository>((ref) {
  return SalesOrderRepositoryImpl(ref.watch(restDioProvider));
});

/// Status filter for the index; null shows every status.
final salesOrderStatusFilterProvider = StateProvider<String?>((_) => null);

/// Sales orders for the active warehouse, newest first.
final salesOrderListProvider =
    FutureProvider.autoDispose<List<SalesOrder>>((ref) async {
  final status = ref.watch(salesOrderStatusFilterProvider);
  final warehouseId = ref.watch(activeWarehouseIdProvider);
  final result = await ref
      .watch(salesOrderRepositoryProvider)
      .list(warehouseId: warehouseId, status: status);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// One sales order with its lines.
final salesOrderDetailProvider =
    FutureProvider.autoDispose.family<SalesOrder, int>((ref, id) async {
  final result = await ref.watch(salesOrderRepositoryProvider).show(id);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});
