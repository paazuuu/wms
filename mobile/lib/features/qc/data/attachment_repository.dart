import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/attachment.dart';

/// Photo evidence for an inspection (spec §32, 0031). Uploads go straight to
/// Supabase Storage — RLS-gated on `inspection.confirm`, same as the metadata
/// row — then get recorded via `record_attachment`, never a direct table
/// insert (0031 leaves no insert policy on `attachments`).
abstract class AttachmentRepository {
  /// Attachments for one entity, newest first.
  Future<ApiResult<List<Attachment>>> list(String entityType, String entityId);

  Future<ApiResult<Attachment>> upload({
    required String entityType,
    required String entityId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  });

  /// A time-limited URL to view a file in the private bucket.
  Future<ApiResult<String>> signedUrl(String storagePath);
}

class AttachmentRepositoryImpl implements AttachmentRepository {
  AttachmentRepositoryImpl({
    required Dio restDio,
    required Dio storageDio,
    required String bucket,
  })  : _restDio = restDio,
        _storageDio = storageDio,
        _bucket = bucket;

  final Dio _restDio;
  final Dio _storageDio;
  final String _bucket;

  @override
  Future<ApiResult<List<Attachment>>> list(
      String entityType, String entityId) async {
    try {
      final response = await _restDio.get('/attachments', queryParameters: {
        'entity_type': 'eq.$entityType',
        'entity_id': 'eq.$entityId',
        'order': 'created_at.desc',
      });
      final rows = response.data as List? ?? const [];
      return ApiSuccess(rows
          .whereType<Map>()
          .map((e) => Attachment.fromJson(e.cast<String, dynamic>()))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<Attachment>>(e);
    }
  }

  @override
  Future<ApiResult<Attachment>> upload({
    required String entityType,
    required String entityId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final path = '$entityType/$entityId/'
        '${DateTime.now().microsecondsSinceEpoch}_$fileName';

    try {
      await _storageDio.post(
        '/object/$_bucket/$path',
        data: bytes,
        options: Options(headers: {'Content-Type': contentType}),
      );
    } on DioException catch (e) {
      return mapDioError<Attachment>(e);
    }

    try {
      final response = await _restDio.post('/rpc/record_attachment', data: {
        'p_entity_type': entityType,
        'p_entity_id': entityId,
        'p_storage_path': path,
        'p_content_type': contentType,
      });
      final id = response.data is int
          ? response.data as int
          : int.tryParse('${response.data}') ?? 0;
      return ApiSuccess(Attachment(
        id: id,
        entityType: entityType,
        entityId: entityId,
        storagePath: path,
        contentType: contentType,
        createdAt: DateTime.now(),
      ));
    } on DioException catch (e) {
      return mapDioError<Attachment>(e);
    }
  }

  @override
  Future<ApiResult<String>> signedUrl(String storagePath) async {
    try {
      final response = await _storageDio.post(
        '/object/sign/$_bucket/$storagePath',
        data: {'expiresIn': 3600},
      );
      final signed = (response.data as Map)['signedURL'] as String? ?? '';
      return ApiSuccess('${_storageDio.options.baseUrl}$signed');
    } on DioException catch (e) {
      return mapDioError<String>(e);
    }
  }
}
