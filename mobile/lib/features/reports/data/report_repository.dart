import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/report.dart';

/// Custom/saved report builder (spec §46 checklist item 10, 0037) — a fixed
/// set of safe, server-defined data sources with structured filters, never
/// arbitrary user SQL. Reads and writes both go through RPCs.
abstract class ReportRepository {
  Future<ApiResult<ReportResult>> run(
    ReportSource source, {
    Map<String, dynamic> filters = const {},
    int limit = 500,
  });

  Future<ApiResult<List<ReportDefinition>>> listSaved();

  Future<ApiResult<int>> save({
    required String name,
    required ReportSource source,
    Map<String, dynamic> filters = const {},
  });

  Future<ApiResult<bool>> delete(int id);
}

class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<ReportResult>> run(
    ReportSource source, {
    Map<String, dynamic> filters = const {},
    int limit = 500,
  }) async {
    try {
      final response = await _dio.post('/rpc/run_report', data: {
        'p_source': source.wire,
        'p_filters': filters,
        'p_limit': limit,
      });
      final data = response.data;
      final json = data is List && data.isNotEmpty ? data.first : data;
      return ApiSuccess(ReportResult.fromJson((json as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<ReportResult>(e);
    }
  }

  @override
  Future<ApiResult<List<ReportDefinition>>> listSaved() async {
    try {
      final response = await _dio.post('/rpc/list_report_definitions');
      final data = response.data;
      // A jsonb-array-returning RPC comes back as the array itself; some
      // PostgREST setups wrap it in a single-element list — accept both,
      // same ambiguity every other jsonb-returning RPC here already handles.
      final rows = data is List
          ? (data.length == 1 && data.first is List ? data.first as List : data)
          : const [];
      return ApiSuccess(rows
          .whereType<Map>()
          .map((e) => ReportDefinition.fromJson(e.cast<String, dynamic>()))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<ReportDefinition>>(e);
    }
  }

  @override
  Future<ApiResult<int>> save({
    required String name,
    required ReportSource source,
    Map<String, dynamic> filters = const {},
  }) async {
    try {
      final response = await _dio.post('/rpc/save_report_definition', data: {
        'p_name': name,
        'p_source': source.wire,
        'p_filters': filters,
      });
      final id = response.data is int
          ? response.data as int
          : int.tryParse('${response.data}') ?? 0;
      return ApiSuccess(id);
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
  }

  @override
  Future<ApiResult<bool>> delete(int id) async {
    try {
      final response =
          await _dio.post('/rpc/delete_report_definition', data: {'p_id': id});
      return ApiSuccess(response.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }
}
