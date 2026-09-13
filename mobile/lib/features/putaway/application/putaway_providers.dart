import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/putaway_repository.dart';
import '../domain/putaway_task.dart';

final putawayRepositoryProvider = Provider<PutawayRepository>((ref) {
  return PutawayRepositoryImpl(ref.watch(restDioProvider));
});

/// The put-away queue for the warehouse a write would land in.
///
/// Uses [writeWarehouseIdProvider], not the read-scope provider: put-away
/// moves stock inside exactly one warehouse, so "all warehouses" only resolves
/// when there is a single warehouse to fall back on. Null means the operator
/// has to pick one first, and the screen says so rather than guessing.
final putawayQueueProvider =
    FutureProvider.autoDispose<List<PutawayTask>>((ref) async {
  final warehouseId = ref.watch(writeWarehouseIdProvider);
  if (warehouseId == null) return const [];
  final result = await ref.watch(putawayRepositoryProvider).queue(warehouseId);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});
