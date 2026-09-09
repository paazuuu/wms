import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/stock_item.dart';
import '../domain/stock_movement.dart';

/// Reads on-hand stock and its ledger from Supabase (PostgREST).
///
/// Stock is per warehouse since migration 0013, so [list] takes the active
/// warehouse; null means every warehouse (the company-wide view).
abstract class StockRepository {
  Future<ApiResult<List<StockItem>>> list({int? warehouseId});

  /// Why the quantity of [janCode] changed, newest first (spec §18).
  Future<ApiResult<List<StockMovement>>> ledger(
    String janCode, {
    int? warehouseId,
    int limit = 100,
  });
}

class StockRepositoryImpl implements StockRepository {
  StockRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<List<StockItem>>> list({int? warehouseId}) async {
    try {
      final response = await _dio.get(
        '/stock_levels',
        queryParameters: {
          'select': 'jan_code,product_name,on_hand',
          'order': 'on_hand.desc',
          'limit': 500,
          if (warehouseId != null) 'warehouse_id': 'eq.$warehouseId',
        },
      );
      final data = (response.data as List<dynamic>)
          .map((e) => StockItem.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiSuccess(data);
    } on DioException catch (e) {
      return mapDioError<List<StockItem>>(e);
    }
  }

  @override
  Future<ApiResult<List<StockMovement>>> ledger(
    String janCode, {
    int? warehouseId,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.post('/rpc/stock_ledger', data: {
        'p_jan_code': janCode,
        'p_warehouse_id': warehouseId,
        'p_limit': limit,
      });
      final rows = response.data is List
          ? response.data as List
          : const <dynamic>[];
      return ApiSuccess(rows
          .whereType<Map>()
          .map((e) => StockMovement.fromJson(e.cast<String, dynamic>()))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<StockMovement>>(e);
    }
  }
}
