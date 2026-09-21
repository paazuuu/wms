import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/inspection_repository.dart';
import '../domain/held_stock.dart';
import '../domain/inspection.dart';

final inspectionRepositoryProvider = Provider<InspectionRepository>((ref) {
  // Reuses the Supabase Edge Functions Dio (anon key attached).
  return InspectionRepositoryImpl(
    ref.watch(deliveryDioProvider),
    restDio: ref.watch(restDioProvider),
  );
});

/// Status filter for the inspection list; null shows every inspection.
final inspectionStatusFilterProvider = StateProvider<String?>((_) => null);

/// Inspections for the active warehouse, newest first.
final inspectionListProvider =
    FutureProvider.autoDispose<List<Inspection>>((ref) async {
  final status = ref.watch(inspectionStatusFilterProvider);
  final warehouseId = ref.watch(activeWarehouseIdProvider);
  final result = await ref
      .watch(inspectionRepositoryProvider)
      .list(status: status, warehouseId: warehouseId);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// One inspection with its items.
final inspectionDetailProvider =
    FutureProvider.autoDispose.family<Inspection, int>((ref, id) async {
  final result = await ref.watch(inspectionRepositoryProvider).show(id);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// Parcels on hand in the active warehouse that cannot ship until an inspection
/// releases them (§13). Nearest expiry first, which is the server's order: the
/// held parcel closest to running out of time is the one to inspect next.
final heldStockProvider =
    FutureProvider.autoDispose<List<HeldStock>>((ref) async {
  final warehouseId = ref.watch(activeWarehouseIdProvider);
  final result = await ref
      .watch(inspectionRepositoryProvider)
      .heldStock(warehouseId: warehouseId);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});
