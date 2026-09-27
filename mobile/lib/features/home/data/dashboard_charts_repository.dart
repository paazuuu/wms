import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/dashboard_charts.dart';

/// The dashboard's chart reads (0089), kept apart from [DashboardRepository]
/// so each panel loads and fails on its own.
abstract class DashboardChartsRepository {
  /// One country at a time; null is the home country.
  Future<ApiResult<StockChartData>> stockChart({int limit = 10, String? countryCode});

  Future<ApiResult<List<RecentPurchaseOrder>>> recentPurchaseOrders({int limit = 8});
}

class DashboardChartsRepositoryImpl implements DashboardChartsRepository {
  DashboardChartsRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<StockChartData>> stockChart({int limit = 10, String? countryCode}) async {
    try {
      final response = await _dio.post('/rpc/dashboard_stock_chart',
          data: {'p_limit': limit, 'p_country_code': countryCode});
      final data = response.data;
      final map = data is List ? (data.isNotEmpty ? data.first as Map : const {}) : data as Map;
      return ApiSuccess(StockChartData.fromJson(map.cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<StockChartData>(e);
    }
  }

  @override
  Future<ApiResult<List<RecentPurchaseOrder>>> recentPurchaseOrders({int limit = 8}) async {
    try {
      final response = await _dio
          .post('/rpc/dashboard_recent_purchase_orders', data: {'p_limit': limit});
      final data = response.data;
      final rows = data is List
          ? (data.length == 1 && data.first is List ? data.first as List : data)
          : const [];
      return ApiSuccess([
        for (final e in rows.whereType<Map>())
          RecentPurchaseOrder.fromJson(e.cast<String, dynamic>()),
      ]);
    } on DioException catch (e) {
      return mapDioError<List<RecentPurchaseOrder>>(e);
    }
  }
}
