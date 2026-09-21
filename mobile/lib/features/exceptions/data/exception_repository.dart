import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/warehouse_exception.dart';

/// The exception queue (0071): what went wrong, and what was decided about it.
///
/// Every write here records a *decision*, never a stock movement. Scrapping the
/// goods is an adjustment, sending them back is a return, putting them beyond use
/// is a status move — each of those is its own RPC with its own audit trail, and
/// folding them in here would give one call two reasons to fail.
abstract class ExceptionRepository {
  /// `open_exceptions`, blockers first. [includeClosed] brings back the resolved
  /// and cancelled ones, which is a history view rather than a work queue.
  Future<ApiResult<List<WarehouseException>>> open({
    int? warehouseId,
    String? category,
    bool includeClosed = false,
    int limit = 100,
  });

  /// `exception_summary` — the two numbers a dashboard tile needs.
  Future<ApiResult<ExceptionSummary>> summary({int? warehouseId});

  /// `acknowledge_exception` — "I have seen this", which is not the same as
  /// "this is dealt with". Only valid once, and only while untouched.
  Future<ApiResult<bool>> acknowledge(int exceptionId);

  /// `resolve_exception`. The server refuses RETURNED / SCRAPPED / CORRECTED
  /// without a note, so [ExceptionResolution.needsNote] asks for one first.
  Future<ApiResult<bool>> resolve(
    int exceptionId,
    ExceptionResolution resolution, {
    String? note,
  });

  /// `cancel_exception` — raised in error. Refused once resolved.
  Future<ApiResult<bool>> cancel(int exceptionId, {String? reason});

  /// `raise_exception` — the operator saw something the system did not catch.
  Future<ApiResult<int>> raise({
    required String exceptionType,
    required int warehouseId,
    String? note,
    int? reconciliationId,
    int? productId,
    String? janCode,
    int? quantity,
    int? receiptItemId,
    int? inspectionId,
  });
}

class ExceptionRepositoryImpl implements ExceptionRepository {
  ExceptionRepositoryImpl(this._dio);

  final Dio _dio;

  static List<Map<String, dynamic>> _rows(dynamic data) {
    final list = data is List
        ? (data.length == 1 && data.first is List ? data.first as List : data)
        : const [];
    return list
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList(growable: false);
  }

  static Map<String, dynamic> _object(dynamic data) {
    final row = data is List ? (data.isEmpty ? null : data.first) : data;
    return row is Map ? row.cast<String, dynamic>() : const {};
  }

  @override
  Future<ApiResult<List<WarehouseException>>> open({
    int? warehouseId,
    String? category,
    bool includeClosed = false,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.post('/rpc/open_exceptions', data: {
        'p_warehouse_id': warehouseId,
        'p_category': category,
        'p_include_closed': includeClosed,
        'p_limit': limit,
      });
      return ApiSuccess(_rows(response.data)
          .map((e) => WarehouseException.fromJson(e))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<WarehouseException>>(e);
    }
  }

  @override
  Future<ApiResult<ExceptionSummary>> summary({int? warehouseId}) async {
    try {
      final response = await _dio.post('/rpc/exception_summary', data: {
        'p_warehouse_id': warehouseId,
      });
      return ApiSuccess(ExceptionSummary.fromJson(_object(response.data)));
    } on DioException catch (e) {
      return mapDioError<ExceptionSummary>(e);
    }
  }

  @override
  Future<ApiResult<bool>> acknowledge(int exceptionId) async {
    try {
      await _dio.post('/rpc/acknowledge_exception', data: {
        'p_exception_id': exceptionId,
      });
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<bool>> resolve(
    int exceptionId,
    ExceptionResolution resolution, {
    String? note,
  }) async {
    try {
      await _dio.post('/rpc/resolve_exception', data: {
        'p_exception_id': exceptionId,
        'p_resolution': resolution.code,
        'p_note': note,
      });
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<bool>> cancel(int exceptionId, {String? reason}) async {
    try {
      await _dio.post('/rpc/cancel_exception', data: {
        'p_exception_id': exceptionId,
        'p_reason': reason,
      });
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<int>> raise({
    required String exceptionType,
    required int warehouseId,
    String? note,
    int? reconciliationId,
    int? productId,
    String? janCode,
    int? quantity,
    int? receiptItemId,
    int? inspectionId,
  }) async {
    try {
      final response = await _dio.post('/rpc/raise_exception', data: {
        'p_exception_type': exceptionType,
        'p_warehouse_id': warehouseId,
        'p_note': note,
        'p_reconciliation_id': reconciliationId,
        'p_product_id': productId,
        'p_jan_code': janCode,
        'p_quantity': quantity,
        'p_receipt_item_id': receiptItemId,
        'p_inspection_id': inspectionId,
      });
      final data = response.data;
      return ApiSuccess(data is int ? data : int.tryParse('$data') ?? 0);
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
  }
}
