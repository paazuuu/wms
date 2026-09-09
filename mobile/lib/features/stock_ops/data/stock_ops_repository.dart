import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/stock_ops.dart';

/// The completed-count result: the refreshed session plus what it changed.
class CompletedCount {
  const CompletedCount(this.count, this.summary);
  final StockCount count;
  final CountSummary summary;
}

/// Stock corrections over the `stock-ops` edge function. Every write posts
/// through the ledger server-side, so nothing here can move stock silently.
abstract class StockOpsRepository {
  Future<ApiResult<List<StockAdjustment>>> adjustments({int? warehouseId});

  Future<ApiResult<StockAdjustment>> adjust({
    required int warehouseId,
    required String janCode,
    required int delta,
    required AdjustReason reason,
    String? note,
    String? productName,
  });

  Future<ApiResult<List<StockCount>>> counts({int? warehouseId, String? status});
  Future<ApiResult<StockCount>> count(int id);

  Future<ApiResult<StockCount>> startCount({
    required int warehouseId,
    bool blind = true,
    String? note,
  });

  Future<ApiResult<StockCount>> recordLine(int countId, int lineId, int counted);
  Future<ApiResult<CompletedCount>> completeCount(int countId, {String? note});
  Future<ApiResult<StockCount>> cancelCount(int countId);
}

class StockOpsRepositoryImpl implements StockOpsRepository {
  StockOpsRepositoryImpl(this._dio);

  final Dio _dio;

  StockCount _count(dynamic body) =>
      StockCount.fromJson(((body as Map)['data'] as Map).cast<String, dynamic>());

  @override
  Future<ApiResult<List<StockAdjustment>>> adjustments({int? warehouseId}) async {
    try {
      final response = await _dio.get('/stock-ops/adjustments',
          queryParameters: {
            if (warehouseId != null) 'warehouse_id': warehouseId,
          });
      final rows = (response.data as Map)['data'] as List? ?? const [];
      return ApiSuccess(rows
          .whereType<Map>()
          .map((e) => StockAdjustment.fromJson(e.cast<String, dynamic>()))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<StockAdjustment>>(e);
    }
  }

  @override
  Future<ApiResult<StockAdjustment>> adjust({
    required int warehouseId,
    required String janCode,
    required int delta,
    required AdjustReason reason,
    String? note,
    String? productName,
  }) async {
    try {
      final response = await _dio.post('/stock-ops/adjustments', data: {
        'warehouse_id': warehouseId,
        'jan_code': janCode,
        'delta': delta,
        'reason': reason.wire,
        if (note != null && note.isNotEmpty) 'note': note,
        if (productName != null && productName.isNotEmpty)
          'product_name': productName,
      });
      // The RPC returns a summary rather than the row; rebuild enough of it for
      // the UI to confirm what happened.
      final data = ((response.data as Map)['data'] as Map).cast<String, dynamic>();
      return ApiSuccess(StockAdjustment(
        id: data['adjustment_id'] is int
            ? data['adjustment_id'] as int
            : int.tryParse('${data['adjustment_id']}') ?? 0,
        janCode: '${data['jan_code']}',
        quantityDelta: data['delta'] is int
            ? data['delta'] as int
            : int.tryParse('${data['delta']}') ?? 0,
        reason: reason,
        productName: productName ?? '',
        note: note,
      ));
    } on DioException catch (e) {
      return mapDioError<StockAdjustment>(e);
    }
  }

  @override
  Future<ApiResult<List<StockCount>>> counts(
      {int? warehouseId, String? status}) async {
    try {
      final response = await _dio.get('/stock-ops/counts', queryParameters: {
        if (warehouseId != null) 'warehouse_id': warehouseId,
        if (status != null) 'status': status,
      });
      final rows = (response.data as Map)['data'] as List? ?? const [];
      return ApiSuccess(rows
          .whereType<Map>()
          .map((e) => StockCount.fromJson(e.cast<String, dynamic>()))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<StockCount>>(e);
    }
  }

  @override
  Future<ApiResult<StockCount>> count(int id) async {
    try {
      final response = await _dio.get('/stock-ops/counts/$id');
      return ApiSuccess(_count(response.data));
    } on DioException catch (e) {
      return mapDioError<StockCount>(e);
    }
  }

  @override
  Future<ApiResult<StockCount>> startCount({
    required int warehouseId,
    bool blind = true,
    String? note,
  }) async {
    try {
      final response = await _dio.post('/stock-ops/counts', data: {
        'warehouse_id': warehouseId,
        'blind': blind,
        if (note != null && note.isNotEmpty) 'note': note,
      });
      return ApiSuccess(_count(response.data));
    } on DioException catch (e) {
      return mapDioError<StockCount>(e);
    }
  }

  @override
  Future<ApiResult<StockCount>> recordLine(
      int countId, int lineId, int counted) async {
    try {
      final response = await _dio.patch(
        '/stock-ops/counts/$countId/lines/$lineId',
        data: {'counted': counted},
      );
      return ApiSuccess(_count(response.data));
    } on DioException catch (e) {
      return mapDioError<StockCount>(e);
    }
  }

  @override
  Future<ApiResult<CompletedCount>> completeCount(int countId,
      {String? note}) async {
    try {
      final response = await _dio.post(
        '/stock-ops/counts/$countId/complete',
        data: {if (note != null && note.isNotEmpty) 'note': note},
      );
      final body = response.data as Map;
      return ApiSuccess(CompletedCount(
        StockCount.fromJson((body['data'] as Map).cast<String, dynamic>()),
        CountSummary.fromJson(
            (body['summary'] as Map? ?? const {}).cast<String, dynamic>()),
      ));
    } on DioException catch (e) {
      return mapDioError<CompletedCount>(e);
    }
  }

  @override
  Future<ApiResult<StockCount>> cancelCount(int countId) async {
    try {
      final response = await _dio.post('/stock-ops/counts/$countId/cancel');
      return ApiSuccess(_count(response.data));
    } on DioException catch (e) {
      return mapDioError<StockCount>(e);
    }
  }
}
