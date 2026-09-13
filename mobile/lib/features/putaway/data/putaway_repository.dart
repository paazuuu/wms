import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/putaway_task.dart';

/// Put-away (UI spec §13, 0038) — the step between receiving and stock being
/// findable on a shelf. Reads the derived queue, resolves a scanned location,
/// and confirms a quantity into a bin via `confirm_putaway`
/// (`putaway.confirm`-gated); the warehouse total never changes, only where
/// the stock sits.
abstract class PutawayRepository {
  /// What still awaits put-away in [warehouseId]. Empty for a warehouse that
  /// has not opted into locations — there is no put-away step without bins.
  Future<ApiResult<List<PutawayTask>>> queue(int warehouseId);

  /// Resolve a scanned/typed location code. Success with `null` means the code
  /// matched no bin in this warehouse.
  Future<ApiResult<BinLocation?>> binByCode(int warehouseId, String code);

  /// Put [quantity] of [janCode] into [binId].
  ///
  /// [idempotencyKey] must be generated once per logical confirm (not per tap)
  /// so a double submit replays the first result instead of posting twice.
  Future<ApiResult<PutawayResult>> confirm({
    required int warehouseId,
    required String janCode,
    required int binId,
    required int quantity,
    required String idempotencyKey,
    String? note,
  });
}

class PutawayRepositoryImpl implements PutawayRepository {
  PutawayRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<List<PutawayTask>>> queue(int warehouseId) async {
    try {
      final response = await _dio.post('/rpc/putaway_queue', data: {
        'p_warehouse_id': warehouseId,
      });
      final data = response.data;
      // A jsonb-array-returning RPC comes back as the array itself; some
      // PostgREST setups wrap it in a single-element list — accept both,
      // same ambiguity every other jsonb-returning RPC here already handles.
      final rows = data is List
          ? (data.length == 1 && data.first is List ? data.first as List : data)
          : const [];
      return ApiSuccess(rows
          .whereType<Map>()
          .map((e) => PutawayTask.fromJson(e.cast<String, dynamic>()))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<PutawayTask>>(e);
    }
  }

  @override
  Future<ApiResult<BinLocation?>> binByCode(int warehouseId, String code) async {
    try {
      final response = await _dio.post('/rpc/bin_by_code', data: {
        'p_warehouse_id': warehouseId,
        'p_code': code,
      });
      final data = response.data;
      final json = data is List && data.isNotEmpty ? data.first : data;
      if (json == null) return const ApiSuccess(null);
      return ApiSuccess(BinLocation.fromJson((json as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<BinLocation?>(e);
    }
  }

  @override
  Future<ApiResult<PutawayResult>> confirm({
    required int warehouseId,
    required String janCode,
    required int binId,
    required int quantity,
    required String idempotencyKey,
    String? note,
  }) async {
    try {
      final response = await _dio.post('/rpc/confirm_putaway', data: {
        'p_warehouse_id': warehouseId,
        'p_jan_code': janCode,
        'p_bin_id': binId,
        'p_quantity': quantity,
        'p_idempotency_key': idempotencyKey,
        'p_note': note,
      });
      final data = response.data;
      final json = data is List && data.isNotEmpty ? data.first : data;
      return ApiSuccess(
          PutawayResult.fromJson((json as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<PutawayResult>(e);
    }
  }
}
