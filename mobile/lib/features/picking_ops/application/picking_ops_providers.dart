import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../../shipment/application/shipment_providers.dart';
import '../../shipment/domain/shipment.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/picking_repository.dart';
import '../domain/pick_list.dart';

final pickingRepositoryProvider = Provider<PickingRepository>((ref) {
  return PickingRepositoryImpl(ref.watch(deliveryDioProvider));
});

/// Pick lists for the active warehouse, newest first.
final pickListsProvider =
    FutureProvider.autoDispose<List<PickList>>((ref) async {
  final warehouseId = ref.watch(activeWarehouseIdProvider);
  final result = await ref
      .watch(pickingRepositoryProvider)
      .lists(warehouseId: warehouseId);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// One pick list with its tasks.
final pickListDetailProvider =
    FutureProvider.autoDispose.family<PickList, int>((ref, id) async {
  final result = await ref.watch(pickingRepositoryProvider).show(id);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// Shipments still open — i.e. not yet packed, shipped or cancelled — that a
/// new pick list could be started against.
final pickableShipmentsProvider =
    FutureProvider.autoDispose<List<Shipment>>((ref) async {
  final result =
      await ref.watch(shipmentRepositoryProvider).list(status: 'open');
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});
