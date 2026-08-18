import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/attachment.dart';
import '../domain/inspection.dart';
import '../domain/inspection_item.dart';

/// Data access for the inspection domain. Every method returns an [ApiResult]
/// so the UI handles success/failure uniformly.
abstract class InspectionRepository {
  Future<ApiResult<List<Inspection>>> list({String? status, String? type});
  Future<ApiResult<Inspection>> show(int id);
  Future<ApiResult<Inspection>> create({
    required String type,
    String? note,
    List<Map<String, dynamic>> items,
  });
  Future<ApiResult<InspectionItem>> recordItem(int inspectionId, Map<String, dynamic> payload);
  Future<ApiResult<Inspection>> complete(int inspectionId);
  Future<ApiResult<List<Attachment>>> uploadAttachments(
    int inspectionId, {
    required List<MultipartFile> files,
    String? kind,
    int? inspectionItemId,
  });
}

class InspectionRepositoryImpl implements InspectionRepository {
  InspectionRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<List<Inspection>>> list({String? status, String? type}) async {
    try {
      final response = await _dio.get('/inspections', queryParameters: {
        if (status != null) 'status': status,
        if (type != null) 'type': type,
      });
      final data = (response.data['data'] as List<dynamic>)
          .map((e) => Inspection.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiSuccess(data);
    } on DioException catch (e) {
      return mapDioError<List<Inspection>>(e);
    }
  }

  @override
  Future<ApiResult<Inspection>> show(int id) async {
    try {
      final response = await _dio.get('/inspections/$id');
      return ApiSuccess(Inspection.fromJson(response.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return mapDioError<Inspection>(e);
    }
  }

  @override
  Future<ApiResult<Inspection>> create({
    required String type,
    String? note,
    List<Map<String, dynamic>> items = const [],
  }) async {
    try {
      final response = await _dio.post('/inspections', data: {
        'type': type,
        if (note != null) 'note': note,
        if (items.isNotEmpty) 'items': items,
      });
      return ApiSuccess(Inspection.fromJson(response.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return mapDioError<Inspection>(e);
    }
  }

  @override
  Future<ApiResult<InspectionItem>> recordItem(int inspectionId, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post('/inspections/$inspectionId/items', data: payload);
      return ApiSuccess(InspectionItem.fromJson(response.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return mapDioError<InspectionItem>(e);
    }
  }

  @override
  Future<ApiResult<Inspection>> complete(int inspectionId) async {
    try {
      final response = await _dio.post('/inspections/$inspectionId/complete');
      return ApiSuccess(Inspection.fromJson(response.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return mapDioError<Inspection>(e);
    }
  }

  @override
  Future<ApiResult<List<Attachment>>> uploadAttachments(
    int inspectionId, {
    required List<MultipartFile> files,
    String? kind,
    int? inspectionItemId,
  }) async {
    try {
      final formData = FormData();
      for (final file in files) {
        formData.files.add(MapEntry('files[]', file));
      }
      if (kind != null) formData.fields.add(MapEntry('kind', kind));
      if (inspectionItemId != null) {
        formData.fields.add(MapEntry('inspection_item_id', '$inspectionItemId'));
      }

      final response = await _dio.post(
        '/inspections/$inspectionId/attachments',
        data: formData,
      );
      final data = (response.data['data'] as List<dynamic>)
          .map((e) => Attachment.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiSuccess(data);
    } on DioException catch (e) {
      return mapDioError<List<Attachment>>(e);
    }
  }
}
