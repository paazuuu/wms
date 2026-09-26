import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/demand_repository.dart';
import '../domain/open_demand.dart';

final demandRepositoryProvider = Provider<DemandRepository>((ref) {
  return DemandRepositoryImpl(ref.watch(restDioProvider));
});

/// What approved orders in the active warehouse are still waiting for.
final openDemandProvider =
    FutureProvider.autoDispose<List<OpenDemandItem>>((ref) async {
  final warehouseId = ref.watch(activeWarehouseIdProvider);
  final result = await ref
      .watch(demandRepositoryProvider)
      .openDemand(warehouseId: warehouseId);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});
