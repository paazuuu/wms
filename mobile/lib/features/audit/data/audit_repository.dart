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

  /// Everything logged against one specific record — the §40 "where is this
  /// job / what happened to it" timeline for a document's own detail screen.
  Future<ApiResult<List<AuditEntry>>> forEntity(
    String entityType,
    String entityId, {
    int limit = 50,
  });
}

class AuditRepositoryImpl implements AuditRepository {
  AuditRepositoryImpl(this._dio, this._restDio);

  /// The `audit-log` edge function's Dio (service-role reads, list/filter).
  final Dio _dio;

  /// PostgREST directly — `audit_log_for_entity` is already granted to anon,
  /// same pattern as `dashboard_metrics`/`stock_ledger`/`global_search`; no
  /// edge function needed for a plain read.
  final Dio _restDio;

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

  @override
  Future<ApiResult<List<AuditEntry>>> forEntity(
    String entityType,
    String entityId, {
    int limit = 50,
  }) async {
    try {
      final response = await _restDio.post('/rpc/audit_log_for_entity', data: {
        'p_entity_type': entityType,
        'p_entity_id': entityId,
        'p_limit': limit,
      });
      final data = response.data;
      final rows = data is List
          ? (data.length == 1 && data.first is List ? data.first as List : data)
          : const [];
      return ApiSuccess(rows
          .whereType<Map>()
          .map((e) => AuditEntry.fromJson(e.cast<String, dynamic>()))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<AuditEntry>>(e);
    }
  }
}
