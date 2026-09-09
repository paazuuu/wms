import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/audit_entry.dart';

/// Read-only access to the audit trail over the `audit-log` edge function
/// (spec §33). `audit_log` itself has no anon read policy — every row comes
/// through the SECURITY DEFINER RPC the function calls.
abstract class AuditRepository {
  Future<ApiResult<List<AuditEntry>>> list({
    int? warehouseId,
    String? entityType,
    String? eventType,
    DateTime? since,
    int limit = 100,
  });

  Future<ApiResult<List<String>>> eventTypes();
}

class AuditRepositoryImpl implements AuditRepository {
  AuditRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<List<AuditEntry>>> list({
    int? warehouseId,
    String? entityType,
    String? eventType,
    DateTime? since,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get('/audit-log', queryParameters: {
        if (warehouseId != null) 'warehouse_id': warehouseId,
        if (entityType != null) 'entity_type': entityType,
        if (eventType != null) 'event_type': eventType,
        if (since != null) 'since': since.toUtc().toIso8601String(),
        'limit': limit,
      });
      final rows = (response.data as Map)['data'] as List? ?? const [];
      return ApiSuccess(rows
          .whereType<Map>()
          .map((e) => AuditEntry.fromJson(e.cast<String, dynamic>()))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<AuditEntry>>(e);
    }
  }

  @override
  Future<ApiResult<List<String>>> eventTypes() async {
    try {
      final response = await _dio.get('/audit-log/event-types');
      final rows = (response.data as Map)['data'] as List? ?? const [];
      return ApiSuccess(rows.map((e) => e.toString()).toList());
    } on DioException catch (e) {
      return mapDioError<List<String>>(e);
    }
  }
}
