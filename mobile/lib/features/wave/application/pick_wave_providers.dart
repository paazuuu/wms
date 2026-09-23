import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/pick_wave_repository.dart';
import '../domain/pick_wave.dart';

final pickWaveRepositoryProvider = Provider<PickWaveRepository>((ref) {
  return PickWaveRepositoryImpl(ref.watch(restDioProvider));
});

/// Status filter for the wave index; null shows every status.
final pickWaveStatusFilterProvider = StateProvider<String?>((_) => null);

/// Waves for the active warehouse, newest first within priority.
final pickWaveListProvider =
    FutureProvider.autoDispose<List<PickWave>>((ref) async {
  final warehouseId = ref.watch(activeWarehouseIdProvider);
  final status = ref.watch(pickWaveStatusFilterProvider);
  final result = await ref
      .watch(pickWaveRepositoryProvider)
      .index(warehouseId: warehouseId, status: status);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// One wave with its lists.
final pickWaveDetailProvider =
    FutureProvider.autoDispose.family<PickWave, int>((ref, id) async {
  final result = await ref.watch(pickWaveRepositoryProvider).detail(id);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// The aggregated sheet for one wave.
final wavePickPlanProvider =
    FutureProvider.autoDispose.family<WavePickPlan, int>((ref, id) async {
  final result = await ref.watch(pickWaveRepositoryProvider).plan(id);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});
