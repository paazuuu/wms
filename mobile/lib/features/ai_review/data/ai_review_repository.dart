import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/ai_analysis_entry.dart';

/// Human review of recorded AI results (spec §31, 0030) — the missing half
/// of 0026's `ai_analysis` store: `confirm_ai_analysis`/`reject_ai_analysis`
/// existed as RPCs with no screen calling them until this.
abstract class AiReviewRepository {
  /// Entries in [status] (default `PENDING_REVIEW`), newest first.
  Future<ApiResult<List<AiAnalysisEntry>>> list({String status = 'PENDING_REVIEW'});

  Future<ApiResult<bool>> confirm(int id);

  Future<ApiResult<bool>> reject(int id, {String? reason});
}

class AiReviewRepositoryImpl implements AiReviewRepository {
  AiReviewRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<List<AiAnalysisEntry>>> list({String status = 'PENDING_REVIEW'}) async {
    try {
      final response = await _dio.post('/rpc/list_ai_analysis', data: {
        'p_status': status,
      });
      final data = response.data;
      // A jsonb-array-returning RPC comes back as the array itself; some
      // PostgREST setups wrap it in a single-element list — accept both,
      // same ambiguity `list_app_users`/`list_connectors` already handle.
      final rows = data is List
          ? (data.length == 1 && data.first is List ? data.first as List : data)
          : const [];
      return ApiSuccess(rows
          .whereType<Map>()
          .map((e) => AiAnalysisEntry.fromJson(e.cast<String, dynamic>()))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<AiAnalysisEntry>>(e);
    }
  }

  @override
  Future<ApiResult<bool>> confirm(int id) async {
    try {
      final response =
          await _dio.post('/rpc/confirm_ai_analysis', data: {'p_id': id});
      return ApiSuccess(response.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<bool>> reject(int id, {String? reason}) async {
    try {
      final response = await _dio.post('/rpc/reject_ai_analysis', data: {
        'p_id': id,
        'p_reason': reason,
      });
      return ApiSuccess(response.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }
}
