import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/role_dashboards.dart';

/// The per-job dashboard reads, and the hand-written inbound list (0102).
abstract class RoleDashboardRepository {
  Future<ApiResult<InboundSchedule>> inboundSchedule({int? warehouseId});
  Future<ApiResult<StockOverview>> stockOverview({String? countryCode, String? search});
  Future<ApiResult<SalesCycle>> salesCycle({String? countryCode = 'CN', int months = 12});

  /// `create_manual_delivery_plan`: returns the new delivery number.
  Future<ApiResult<String>> createManualInboundList({
    required int warehouseId,
    required List<({String janCode, int quantity})> lines,
    String? supplierName,
    DateTime? expectedOn,
  });
}

Map<String, dynamic> _one(dynamic data) {
  final map = data is List ? (data.isNotEmpty ? data.first : const {}) : data;
  return (map as Map).cast<String, dynamic>();
}

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class RoleDashboardRepositoryImpl implements RoleDashboardRepository {
  RoleDashboardRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<InboundSchedule>> inboundSchedule({int? warehouseId}) async {
    try {
      final r = await _dio.post('/rpc/dashboard_inbound_schedule',
          data: {'p_warehouse_id': warehouseId});
      return ApiSuccess(InboundSchedule.fromJson(_one(r.data)));
    } on DioException catch (e) {
      return mapDioError<InboundSchedule>(e);
    }
  }

  @override
  Future<ApiResult<StockOverview>> stockOverview({String? countryCode, String? search}) async {
    try {
      final r = await _dio.post('/rpc/dashboard_stock_position', data: {
        'p_country_code': countryCode,
        'p_search': (search == null || search.trim().isEmpty) ? null : search.trim(),
      });
      return ApiSuccess(StockOverview.fromJson(_one(r.data)));
    } on DioException catch (e) {
      return mapDioError<StockOverview>(e);
    }
  }

  @override
  Future<ApiResult<SalesCycle>> salesCycle({String? countryCode = 'CN', int months = 12}) async {
    try {
      final r = await _dio.post('/rpc/dashboard_sales_cycle',
          data: {'p_country_code': countryCode, 'p_months': months});
      return ApiSuccess(SalesCycle.fromJson(_one(r.data)));
    } on DioException catch (e) {
      return mapDioError<SalesCycle>(e);
    }
  }

  @override
  Future<ApiResult<String>> createManualInboundList({
    required int warehouseId,
    required List<({String janCode, int quantity})> lines,
    String? supplierName,
    DateTime? expectedOn,
  }) async {
    try {
      final r = await _dio.post('/rpc/create_manual_delivery_plan', data: {
        'p_warehouse_id': warehouseId,
        'p_lines': [
          for (final l in lines) {'jan_code': l.janCode, 'quantity': l.quantity},
        ],
        'p_supplier_name':
            (supplierName == null || supplierName.trim().isEmpty) ? null : supplierName.trim(),
        'p_expected_on': expectedOn == null ? null : _day(expectedOn),
      });
      return ApiSuccess((_one(r.data)['delivery_number'] ?? '').toString());
    } on DioException catch (e) {
      return mapDioError<String>(e);
    }
  }
}
