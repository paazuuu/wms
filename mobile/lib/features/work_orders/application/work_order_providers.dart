import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/work_order_repository.dart';
import '../domain/work_order.dart';

final workOrderRepositoryProvider = Provider<WorkOrderRepository>((ref) {
  return WorkOrderRepositoryImpl(ref.watch(restDioProvider));
});

/// Status filter for the index; null shows every status.
final workOrderStatusFilterProvider = StateProvider<String?>((_) => null);

/// Work orders for the active warehouse, newest first.
final workOrderListProvider =
    FutureProvider.autoDispose<List<WorkOrder>>((ref) async {
  final status = ref.watch(workOrderStatusFilterProvider);
  final warehouseId = ref.watch(activeWarehouseIdProvider);
  final result = await ref
      .watch(workOrderRepositoryProvider)
      .list(warehouseId: warehouseId, status: status);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// One work order with its components.
final workOrderDetailProvider =
    FutureProvider.autoDispose.family<WorkOrder, int>((ref, id) async {
  final result = await ref.watch(workOrderRepositoryProvider).show(id);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});
