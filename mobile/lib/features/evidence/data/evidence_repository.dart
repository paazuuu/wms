import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/import_document.dart';

/// The bucket every uploaded file is kept in (0132).
const evidenceBucket = 'import-documents';

/// Uploaded files kept as evidence (0132). The edge functions store them;
/// this reads the list and the bytes back. Both are gated by what the file
/// was for (receiving, shipping, products, or audit.view), on the server.
abstract class EvidenceRepository {
  Future<ApiResult<List<ImportDocument>>> list({EvidencePurpose? purpose, String? search});

  /// The files a plan was read from.
  Future<ApiResult<List<ImportDocument>>> forPlan({int? deliveryPlanId, int? shipmentPlanId});

  Future<ApiResult<Uint8List>> download(ImportDocument doc);
}

class EvidenceRepositoryImpl implements EvidenceRepository {
  EvidenceRepositoryImpl({required Dio rest, required Dio storage})
      : _rest = rest,
        _storage = storage;

  final Dio _rest;
  final Dio _storage;

  List<ImportDocument> _rows(dynamic data) => [
        for (final e in (data is List ? data : const []).whereType<Map>())
          ImportDocument.fromJson(e.cast<String, dynamic>()),
      ];

  @override
  Future<ApiResult<List<ImportDocument>>> list({EvidencePurpose? purpose, String? search}) async {
    try {
      final r = await _rest.post('/rpc/import_documents_list', data: {
        'p_purpose': purpose?.wire,
        'p_search': (search?.trim().isEmpty ?? true) ? null : search!.trim(),
      });
      return ApiSuccess(_rows(r.data));
    } on DioException catch (e) {
      return mapDioError<List<ImportDocument>>(e);
    }
  }

  @override
  Future<ApiResult<List<ImportDocument>>> forPlan({int? deliveryPlanId, int? shipmentPlanId}) async {
    try {
      final r = await _rest.get('/import_documents', queryParameters: {
        'select': '*',
        if (deliveryPlanId != null) 'delivery_plan_id': 'eq.$deliveryPlanId',
        if (shipmentPlanId != null) 'shipment_plan_id': 'eq.$shipmentPlanId',
        'order': 'uploaded_at.desc',
      });
      return ApiSuccess(_rows(r.data));
    } on DioException catch (e) {
      return mapDioError<List<ImportDocument>>(e);
    }
  }

  @override
  Future<ApiResult<Uint8List>> download(ImportDocument doc) async {
    try {
      final r = await _storage.get<List<int>>(
        '/object/authenticated/$evidenceBucket/${doc.storagePath}',
        options: Options(responseType: ResponseType.bytes),
      );
      return ApiSuccess(Uint8List.fromList(r.data ?? const []));
    } on DioException catch (e) {
      return mapDioError<Uint8List>(e);
    }
  }
}
