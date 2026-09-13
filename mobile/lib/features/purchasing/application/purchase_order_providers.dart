import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/purchase_order_repository.dart';
import '../domain/purchase_order.dart';

final purchaseOrderRepositoryProvider = Provider<PurchaseOrderRepository>((ref) {
  return PurchaseOrderRepositoryImpl(ref.watch(restDioProvider));
});

/// Status filter for the index; null shows every status.
final purchaseOrderStatusFilterProvider = StateProvider<String?>((_) => null);

/// Purchase orders for the active warehouse, newest first.
final purchaseOrderListProvider =
    FutureProvider.autoDispose<List<PurchaseOrder>>((ref) async {
  final status = ref.watch(purchaseOrderStatusFilterProvider);
  final warehouseId = ref.watch(activeWarehouseIdProvider);
  final result = await ref
      .watch(purchaseOrderRepositoryProvider)
      .list(warehouseId: warehouseId, status: status);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// One purchase order with its lines.
final purchaseOrderDetailProvider =
    FutureProvider.autoDispose.family<PurchaseOrder, int>((ref, id) async {
  final result = await ref.watch(purchaseOrderRepositoryProvider).show(id);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});
