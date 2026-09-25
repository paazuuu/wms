import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../../product/domain/product_lot.dart';
import '../../product/domain/warehouse_product.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/inventory_repository.dart';
import '../domain/reservation.dart';
import '../domain/stock_discrepancy.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepositoryImpl(ref.watch(restDioProvider));
});

/// How far ahead the expiry list looks. A choice rather than a constant, because
/// "what expires this week" and "what expires this quarter" are different jobs
/// done by different people.
final expiryHorizonProvider = StateProvider<int>((_) => 30);

/// Lots at or past their date within [expiryHorizonProvider], soonest first.
/// Expired lots are included: they are the most urgent row on the list, not an
/// archive to be filtered away.
final expiringLotsProvider =
    FutureProvider.autoDispose<List<ExpiringLot>>((ref) async {
  final days = ref.watch(expiryHorizonProvider);
  final result =
      await ref.watch(inventoryRepositoryProvider).expiringLots(days: days);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// Which reservation status the list shows; null means every one.
final reservationStatusProvider = StateProvider<String?>((_) => 'ACTIVE');

/// Reservations in the active warehouse. Warehouse-scoped like every other stock
/// read since 0052 — a promise belongs to the building that has to keep it.
final reservationsProvider =
    FutureProvider.autoDispose<List<Reservation>>((ref) async {
  final warehouseId = ref.watch(activeWarehouseIdProvider);
  final status = ref.watch(reservationStatusProvider);
  final result = await ref.watch(inventoryRepositoryProvider).reservations(
        warehouseId: warehouseId,
        status: status,
      );
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// Parcels promised to more than they hold. Empty is healthy, so the screen
/// shows this section only when it is not.
final overAllocatedProvider =
    FutureProvider.autoDispose<List<OverAllocatedStock>>((ref) async {
  final warehouseId = ref.watch(activeWarehouseIdProvider);
  final result = await ref
      .watch(inventoryRepositoryProvider)
      .overAllocated(warehouseId: warehouseId);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// Products under their reorder point in the active warehouse, worst first.
final replenishmentProvider =
    FutureProvider.autoDispose<List<ReplenishmentSuggestion>>((ref) async {
  final warehouseId = ref.watch(activeWarehouseIdProvider);
  final result = await ref
      .watch(inventoryRepositoryProvider)
      .replenishment(warehouseId: warehouseId);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// Where the ledger and the stock units under it disagree, in the active
/// warehouse. Empty is healthy — this is a diagnostic an operator checks, not
/// a list that is normally worth looking at.
final stockReconciliationProvider =
    FutureProvider.autoDispose<List<StockDiscrepancy>>((ref) async {
  final warehouseId = ref.watch(activeWarehouseIdProvider);
  final result = await ref
      .watch(inventoryRepositoryProvider)
      .stockReconciliation(warehouseId: warehouseId);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});
