import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../data/warehouse_repository.dart';
import '../domain/warehouse.dart';

final warehouseRepositoryProvider = Provider<WarehouseRepository>((ref) {
  // Reuses the delivery feature's Dio, which already points at the Supabase
  // Edge Functions base URL with the anon key attached.
  return WarehouseRepositoryImpl(ref.watch(deliveryDioProvider));
});

/// Every warehouse plus company totals. Kept alive (not autoDispose) so the
/// warehouse picker in the top bar does not refetch on every navigation.
final warehouseOverviewProvider =
    FutureProvider<WarehouseOverview>((ref) async {
  final result = await ref.watch(warehouseRepositoryProvider).overview();
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// The active warehouse context.
///
/// `null` means "all warehouses" — the admin-wide view (spec §50). It is also
/// the initial value: with a single warehouse the scoped and unscoped figures
/// are identical, so nothing needs preselecting until a second warehouse exists,
/// at which point the picker sets this explicitly.
final activeWarehouseIdProvider = StateProvider<int?>((_) => null);

/// The warehouse a *write* should target.
///
/// Reads happily span every warehouse, but a stock movement has to land in
/// exactly one, so "all warehouses" (null) only resolves when there is a single
/// warehouse to fall back on. With two or more the caller must ask the user —
/// guessing would post stock into the wrong building.
final writeWarehouseIdProvider = Provider<int?>((ref) {
  final active = ref.watch(activeWarehouseIdProvider);
  if (active != null) return active;
  final list = ref.watch(warehouseOverviewProvider).valueOrNull?.warehouses;
  return list != null && list.length == 1 ? list.single.id : null;
});

/// The active warehouse resolved against the overview, or null for "all".
final activeWarehouseProvider = Provider<Warehouse?>((ref) {
  final id = ref.watch(activeWarehouseIdProvider);
  if (id == null) return null;
  return ref.watch(warehouseOverviewProvider).valueOrNull?.byId(id);
});

/// Bins of one warehouse (used by the warehouse detail / later put-away flows).
final warehouseBinsProvider =
    FutureProvider.autoDispose.family<List<Bin>, int>((ref, warehouseId) async {
  final result = await ref.watch(warehouseRepositoryProvider).bins(warehouseId);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});
