import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/inspection_repository.dart';
import '../domain/inspection.dart';

final inspectionRepositoryProvider = Provider<InspectionRepository>((ref) {
  // Reuses the Supabase Edge Functions Dio (anon key attached).
  return InspectionRepositoryImpl(ref.watch(deliveryDioProvider));
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
