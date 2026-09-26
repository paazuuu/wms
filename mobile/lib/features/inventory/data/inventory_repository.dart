import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../product/domain/product_lot.dart';
import '../../product/domain/warehouse_product.dart';
import '../domain/reservation.dart';
import '../domain/stock_discrepancy.dart';

/// The inventory-control reads Phase A made possible: what is running out of
/// time (§4), what has been promised (§6), where a promise has been
/// over-committed (§6), and what needs reordering (§31).
///
/// One repository because they are one job — the attention list an inventory
/// controller works through — and because each is a single RPC with no writes
/// beyond releasing a reservation.
abstract class InventoryRepository {
  /// `expiring_lots` (0060). [days] is the horizon; [includeExpired] keeps lots
  /// already past their date, which is the default because an expired lot is the
  /// most urgent thing on the list, not the least.
  ///
  /// Not warehouse-scoped: a lot belongs to a product, not to a building. It
  /// becomes a per-warehouse number when stock rows carry `lot_id` (step 8's
  /// remaining half).
  Future<ApiResult<List<ExpiringLot>>> expiringLots({
    int days = 30,
    bool includeExpired = true,
  });

  /// `list_reservations` (0064). Null [status] means every status, which is what
  /// the history view needs; the default is ACTIVE, the ones holding stock.
  Future<ApiResult<List<Reservation>>> reservations({
    int? warehouseId,
    int? productId,
    String? status = 'ACTIVE',
  });

  /// `over_allocated_stock` (0064). Empty is the healthy state.
  Future<ApiResult<List<OverAllocatedStock>>> overAllocated({int? warehouseId});

  /// `release_reservation` (0064) — the promise is dropped and its allocations
  /// go with it, but the row survives as RELEASED so the audit trail has
  /// something to point at.
  Future<ApiResult<bool>> releaseReservation(int reservationId, {String? note});

  /// `fulfil_reservation` (0064) — the promise has been kept: stock actually
  /// left against it (the shipment's own movement, recorded elsewhere; this
  /// only stops the reservation holding the quantity). Null [quantity] means
  /// all of what is still outstanding, the common case at shipping time.
  Future<ApiResult<bool>> fulfilReservation(int reservationId, {int? quantity});

  /// `allocate_stock` (0064) — pins a reservation to particular parcels,
  /// soonest expiry first. Reports what it could not find rather than failing.
  Future<ApiResult<AllocationOutcome>> allocateStock(int reservationId,
      {int? quantity});

  /// `release_allocation` (0064) — un-pins one parcel; the promise stays.
  Future<ApiResult<bool>> releaseAllocation(int allocationId);

  /// `reserve_stock` (0064) — a promise made by hand, for anything that is not
  /// a sales order (internal use, a sample, a hold for a phone order).
  Future<ApiResult<int>> reserveStock({
    required int productId,
    required int warehouseId,
    required int quantity,
    DateTime? expiresAt,
    String? note,
  });

  /// `replenishment_suggestions` (0063, §31), worst shortfall first.
  Future<ApiResult<List<ReplenishmentSuggestion>>> replenishment({
    int? warehouseId,
  });

  /// `stock_reconciliation` (0061) — every place the ledger and the stock
  /// units it is supposed to summarize disagree. Empty is the healthy state;
  /// this is a diagnostic, not a routine list.
  Future<ApiResult<List<StockDiscrepancy>>> stockReconciliation({
    int? warehouseId,
  });
}

class InventoryRepositoryImpl implements InventoryRepository {
  InventoryRepositoryImpl(this._dio);

  final Dio _dio;

  /// A jsonb-array RPC comes back as the array, or wrapped in a one-element list
  /// depending on the PostgREST setup. Accepted in one place, as elsewhere.
  static List<Map<String, dynamic>> _rows(dynamic data) {
    final list = data is List
        ? (data.length == 1 && data.first is List ? data.first as List : data)
        : const [];
    return list
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList(growable: false);
  }

  @override
  Future<ApiResult<List<ExpiringLot>>> expiringLots({
    int days = 30,
    bool includeExpired = true,
  }) async {
    try {
      final response = await _dio.post('/rpc/expiring_lots', data: {
        'p_days': days,
        'p_include_expired': includeExpired,
      });
      return ApiSuccess(
          _rows(response.data).map((e) => ExpiringLot.fromJson(e)).toList());
    } on DioException catch (e) {
      return mapDioError<List<ExpiringLot>>(e);
    }
  }

  @override
  Future<ApiResult<List<Reservation>>> reservations({
    int? warehouseId,
    int? productId,
    String? status = 'ACTIVE',
  }) async {
    try {
      final response = await _dio.post('/rpc/list_reservations', data: {
        'p_warehouse_id': warehouseId,
        'p_product_id': productId,
        // '' is how the RPC is told "every status"; null would take its default.
        'p_status': status ?? '',
      });
      return ApiSuccess(
          _rows(response.data).map((e) => Reservation.fromJson(e)).toList());
    } on DioException catch (e) {
      return mapDioError<List<Reservation>>(e);
    }
  }

  @override
  Future<ApiResult<List<OverAllocatedStock>>> overAllocated(
      {int? warehouseId}) async {
    try {
      final response = await _dio.post('/rpc/over_allocated_stock', data: {
        'p_warehouse_id': warehouseId,
      });
      return ApiSuccess(_rows(response.data)
          .map((e) => OverAllocatedStock.fromJson(e))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<OverAllocatedStock>>(e);
    }
  }

  @override
  Future<ApiResult<bool>> releaseReservation(int reservationId,
      {String? note}) async {
    try {
      final response = await _dio.post('/rpc/release_reservation', data: {
        'p_reservation_id': reservationId,
        'p_note': note,
      });
      // Returns the new position as jsonb; anything non-null is a success, and
      // the caller refetches rather than trusting a parsed echo.
      return ApiSuccess(response.data != null);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<bool>> fulfilReservation(int reservationId,
      {int? quantity}) async {
    try {
      final response = await _dio.post('/rpc/fulfil_reservation', data: {
        'p_reservation_id': reservationId,
        'p_quantity': quantity,
      });
      return ApiSuccess(response.data != null);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<AllocationOutcome>> allocateStock(int reservationId,
      {int? quantity}) async {
    try {
      final response = await _dio.post('/rpc/allocate_stock', data: {
        'p_reservation_id': reservationId,
        'p_quantity': quantity,
      });
      final data = response.data;
      final json = data is List && data.isNotEmpty ? data.first : data;
      return ApiSuccess(
          AllocationOutcome.fromJson((json as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<AllocationOutcome>(e);
    }
  }

  @override
  Future<ApiResult<bool>> releaseAllocation(int allocationId) async {
    try {
      final response = await _dio.post('/rpc/release_allocation',
          data: {'p_allocation_id': allocationId});
      return ApiSuccess(response.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<int>> reserveStock({
    required int productId,
    required int warehouseId,
    required int quantity,
    DateTime? expiresAt,
    String? note,
  }) async {
    try {
      final response = await _dio.post('/rpc/reserve_stock', data: {
        'p_product_id': productId,
        'p_warehouse_id': warehouseId,
        'p_quantity': quantity,
        'p_reference_type': 'manual',
        'p_expires_at': expiresAt?.toUtc().toIso8601String(),
        'p_note': note,
      });
      final data = response.data;
      final json = data is List && data.isNotEmpty ? data.first : data;
      final id = json is Map ? json['reservation_id'] : null;
      return ApiSuccess(id is int ? id : int.tryParse('$id') ?? 0);
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
  }

  @override
  Future<ApiResult<List<ReplenishmentSuggestion>>> replenishment({
    int? warehouseId,
  }) async {
    try {
      final response = await _dio.post('/rpc/replenishment_suggestions', data: {
        'p_warehouse_id': warehouseId,
      });
      return ApiSuccess(_rows(response.data)
          .map((e) => ReplenishmentSuggestion.fromJson(e))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<ReplenishmentSuggestion>>(e);
    }
  }

  @override
  Future<ApiResult<List<StockDiscrepancy>>> stockReconciliation({
    int? warehouseId,
  }) async {
    try {
      final response = await _dio.post('/rpc/stock_reconciliation', data: {
        'p_warehouse_id': warehouseId,
      });
      return ApiSuccess(_rows(response.data)
          .map((e) => StockDiscrepancy.fromJson(e))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<StockDiscrepancy>>(e);
    }
  }
}
