import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
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

  Future<ApiResult<Inspection>> complete(int inspectionId, {String? note});
}

class InspectionRepositoryImpl implements InspectionRepository {
  InspectionRepositoryImpl(this._dio);

  final Dio _dio;

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
      {String? note}) async {
    try {
      final response = await _dio.post(
        '/inspections/$inspectionId/complete',
        data: {if (note != null && note.isNotEmpty) 'note': note},
      );
      return ApiSuccess(_one(response.data));
    } on DioException catch (e) {
      return mapDioError<Inspection>(e);
    }
  }
}
