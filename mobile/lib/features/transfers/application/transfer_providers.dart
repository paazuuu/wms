import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/transfer_repository.dart';
import '../domain/transfer_order.dart';

final transferRepositoryProvider = Provider<TransferRepository>((ref) {
  return TransferRepositoryImpl(ref.watch(deliveryDioProvider));
});

/// Transfers touching the active warehouse, either as source or destination.
final transferListProvider =
    FutureProvider.autoDispose<List<TransferOrder>>((ref) async {
  final warehouseId = ref.watch(activeWarehouseIdProvider);
  final result =
      await ref.watch(transferRepositoryProvider).list(warehouseId: warehouseId);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// One transfer with its lines.
final transferDetailProvider =
    FutureProvider.autoDispose.family<TransferOrder, int>((ref, id) async {
  final result = await ref.watch(transferRepositoryProvider).show(id);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});
