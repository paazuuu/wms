import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/held_stock.dart';
import '../domain/inspection.dart';

/// Inbound inspection (検品) over the `inspections` edge function. The tables
/// are read-only to the client, so every mutation goes through the function.
abstract class InspectionRepository {
  Future<ApiResult<List<Inspection>>> list({String? status, int? warehouseId});
  Future<ApiResult<Inspection>> show(int id);

  /// Opens (or returns) the inspection for a receipt — idempotent server-side.
  Future<ApiResult<Inspection>> start(int reconciliationId);

  Future<ApiResult<Inspection>> saveItem(
      int inspectionId, int itemId, InspectionFinding finding);

  Future<ApiResult<Inspection>> complete(int inspectionId,
      {String? note, String? failStatus});

  /// `qc_pending_stock` (0068): parcels on hand that cannot ship until an
  /// inspection releases them. Read straight off the RPC rather than through the
  /// edge function, because it is a read and 0068 scoped it itself.
  Future<ApiResult<List<HeldStock>>> heldStock({int? warehouseId});
}

class InspectionRepositoryImpl implements InspectionRepository {
  /// Two clients, because this repository spans two doors. The inspection
  /// writes go through the edge function (`_dio`), which is the only gate in
  /// front of RPCs granted to `service_role` alone; the held-stock read is an
  /// ordinary guarded RPC and goes straight to PostgREST (`_restDio`).
  InspectionRepositoryImpl(this._dio, {Dio? restDio})
      : _restDio = restDio ?? _dio;

  final Dio _dio;
  final Dio _restDio;

  Inspection _one(dynamic responseData) => Inspection.fromJson(
      ((responseData as Map)['data'] as Map).cast<String, dynamic>());

  @override
  Future<ApiResult<List<Inspection>>> list(
      {String? status, int? warehouseId}) async {
    try {
      final response = await _dio.get('/inspections', queryParameters: {
        if (status != null) 'status': status,
        if (warehouseId != null) 'warehouse_id': warehouseId,
      });
      final rows = (response.data as Map)['data'] as List? ?? const [];
      return ApiSuccess(rows
          .whereType<Map>()
          .map((e) => Inspection.fromJson(e.cast<String, dynamic>()))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<Inspection>>(e);
    }
  }

  @override
  Future<ApiResult<Inspection>> show(int id) async {
    try {
      final response = await _dio.get('/inspections/$id');
      return ApiSuccess(_one(response.data));
    } on DioException catch (e) {
      return mapDioError<Inspection>(e);
    }
  }

  @override
  Future<ApiResult<Inspection>> start(int reconciliationId) async {
    try {
      final response = await _dio.post('/inspections',
          data: {'reconciliation_id': reconciliationId});
      return ApiSuccess(_one(response.data));
    } on DioException catch (e) {
      return mapDioError<Inspection>(e);
    }
  }

  @override
  Future<ApiResult<Inspection>> saveItem(
      int inspectionId, int itemId, InspectionFinding finding) async {
    try {
      final response = await _dio.patch(
        '/inspections/$inspectionId/items/$itemId',
        data: finding.toJson(),
      );
      return ApiSuccess(_one(response.data));
    } on DioException catch (e) {
      return mapDioError<Inspection>(e);
    }
  }

  @override
  Future<ApiResult<Inspection>> complete(int inspectionId,
      {String? note, String? failStatus}) async {
    try {
      final response = await _dio.post(
        '/inspections/$inspectionId/complete',
        data: {
          if (note != null && note.isNotEmpty) 'note': note,
          if (failStatus != null && failStatus.isNotEmpty)
            'fail_status': failStatus,
        },
      );
      return ApiSuccess(_one(response.data));
    } on DioException catch (e) {
      return mapDioError<Inspection>(e);
    }
  }

  @override
  Future<ApiResult<List<HeldStock>>> heldStock({int? warehouseId}) async {
    try {
      final response = await _restDio.post('/rpc/qc_pending_stock', data: {
        'p_warehouse_id': warehouseId,
      });
      final data = response.data;
      final list = data is List
          ? (data.length == 1 && data.first is List ? data.first as List : data)
          : const [];
      return ApiSuccess(list
          .whereType<Map>()
          .map((e) => HeldStock.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false));
    } on DioException catch (e) {
      return mapDioError<List<HeldStock>>(e);
    }
  }
}
