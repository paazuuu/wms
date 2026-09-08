import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/dashboard_metrics.dart';

/// Reads the aggregated home-dashboard figures from the Supabase
/// `dashboard_metrics` RPC (exposed over PostgREST at `/rpc/...`).
abstract class DashboardRepository {
  Future<ApiResult<DashboardMetrics>> metrics(
      {int days = 14, int lowThreshold = 10});
}

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<DashboardMetrics>> metrics(
      {int days = 14, int lowThreshold = 10}) async {
    try {
      final response = await _dio.post(
        '/rpc/dashboard_metrics',
        data: {'p_days': days, 'p_low_threshold': lowThreshold},
      );
      final data = response.data;
      // A scalar jsonb-returning RPC comes back as the object itself; some
      // PostgREST setups wrap it in a single-row list — accept both.
      final map = data is List
          ? (data.isNotEmpty ? data.first as Map : const {})
          : (data as Map);
      return ApiSuccess(DashboardMetrics.fromJson(map.cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<DashboardMetrics>(e);
    }
  }
}
