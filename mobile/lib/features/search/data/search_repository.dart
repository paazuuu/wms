import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/search_result.dart';

/// Cross-entity search (spec §23) over the `global_search` PostgREST RPC —
/// read-only and already granted to anon, so it's called directly like
/// `dashboard_metrics`/`stock_ledger`, no edge function needed.
abstract class SearchRepository {
  Future<ApiResult<List<SearchResult>>> search(
    String query, {
    int? warehouseId,
    int limit = 8,
  });
}

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<List<SearchResult>>> search(
    String query, {
    int? warehouseId,
    int limit = 8,
  }) async {
    try {
      final response = await _dio.post('/rpc/global_search', data: {
        'p_query': query,
        'p_warehouse_id': warehouseId,
        'p_limit': limit,
      });
      final data = response.data;
      // A setof-free jsonb-returning RPC comes back as the array itself;
      // defensively also accept a PostgREST setup that wraps it one level
      // deeper (`[[...]]`), the same ambiguity `dashboard_metrics` has to
      // handle for its object-returning counterpart.
      final rows = data is List
          ? (data.length == 1 && data.first is List
              ? data.first as List
              : data)
          : const [];
      return ApiSuccess(rows
          .whereType<Map>()
          .map((e) => SearchResult.fromJson(e.cast<String, dynamic>()))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<SearchResult>>(e);
    }
  }
}
