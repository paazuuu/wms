import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/attachment.dart';

/// Evidence attached to a warehouse record (§29, 0031 and 0070). Uploads go
/// straight to Supabase Storage — RLS-gated the same way as the metadata row —
/// then get recorded via `record_attachment`, never a direct table insert
/// (0031 leaves no insert policy on `attachments`).
abstract class AttachmentRepository {
  /// Attachments for one entity, newest first, withdrawn ones excluded unless
  /// asked for. Goes through `attachments_for` rather than reading the table, so
  /// the warehouse scoping and the withdrawn filter live in one place — on the
  /// server, where 0070 put them.
  Future<ApiResult<List<Attachment>>> list(
    String entityType,
    String entityId, {
    bool includeWithdrawn = false,
  });

  Future<ApiResult<Attachment>> upload({
    required String entityType,
    required String entityId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    AttachmentKind kind = AttachmentKind.photo,
    String? caption,
    int? warehouseId,
  });

  /// Withdraw one. Not a delete: the row survives so a photo that settled a
  /// claim stays findable (0070).
  Future<ApiResult<bool>> withdraw(int attachmentId, {String? reason});

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
    String entityType,
    String entityId, {
    bool includeWithdrawn = false,
  }) async {
    try {
      final response = await _restDio.post('/rpc/attachments_for', data: {
        'p_entity_type': entityType,
        'p_entity_id': entityId,
        'p_include_withdrawn': includeWithdrawn,
      });
      final data = response.data;
      final rows = data is List
          ? (data.length == 1 && data.first is List ? data.first as List : data)
          : const [];
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
    AttachmentKind kind = AttachmentKind.photo,
    String? caption,
    int? warehouseId,
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
        'p_kind': kind.code,
        'p_caption': caption,
        // The size the client already knows, so the server does not have to ask
        // Storage for it later.
        'p_byte_size': bytes.length,
        'p_warehouse_id': warehouseId,
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
        kind: kind,
        caption: caption,
        byteSize: bytes.length,
        warehouseId: warehouseId,
      ));
    } on DioException catch (e) {
      return mapDioError<Attachment>(e);
    }
  }

  @override
  Future<ApiResult<bool>> withdraw(int attachmentId, {String? reason}) async {
    try {
      await _restDio.post('/rpc/withdraw_attachment', data: {
        'p_attachment_id': attachmentId,
        'p_reason': reason,
      });
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
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
