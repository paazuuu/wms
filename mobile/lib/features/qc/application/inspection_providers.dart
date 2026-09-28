import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/pending_sync.dart';
import '../../delivery/application/delivery_providers.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/inspection_repository.dart';
import '../data/offline_inspection_repository.dart';
import '../domain/bulk_inspection.dart';
import '../domain/held_stock.dart';
import '../domain/inspection.dart';

final inspectionRepositoryProvider = Provider<InspectionRepository>((ref) {
  // Reuses the Supabase Edge Functions Dio (anon key attached). Wrapped so
  // counts and findings survive a dropped connection (spec §58).
  final sync = ref.watch(pendingSyncProvider.notifier);
  return OfflineInspectionRepository(
    InspectionRepositoryImpl(
      ref.watch(deliveryDioProvider),
      restDio: ref.watch(restDioProvider),
      onRaw: OfflineInspectionRepository.cacheWriter(sync),
    ),
    sync,
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

/// Which held status the held-stock screen shows; null = every status.
final heldStatusFilterProvider = StateProvider.autoDispose<String?>((ref) => null);

/// Parcels on hand in the active warehouse that cannot ship until an inspection
/// releases them (§13). Nearest expiry first, which is the server's order: the
/// held parcel closest to running out of time is the one to inspect next.
final heldStockProvider =
    FutureProvider.autoDispose<List<HeldStock>>((ref) async {
  final warehouseId = ref.watch(activeWarehouseIdProvider);
  final status = ref.watch(heldStatusFilterProvider);
  final result = await ref
      .watch(inspectionRepositoryProvider)
      .heldStock(warehouseId: warehouseId, status: status);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// Every inspection line still to settle in the active warehouse (0099).
final openInspectionLinesProvider =
    FutureProvider.autoDispose<List<OpenInspectionLine>>((ref) async {
  final warehouseId = ref.watch(activeWarehouseIdProvider);
  final result = await ref
      .watch(inspectionRepositoryProvider)
      .openLines(warehouseId: warehouseId);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});
