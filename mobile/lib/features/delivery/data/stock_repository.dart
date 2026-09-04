import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/stock_item.dart';

/// Reads the per-JAN total on-hand stock directly from the Supabase table
/// (PostgREST), highest quantity first.
abstract class StockRepository {
  Future<ApiResult<List<StockItem>>> list();
}

class StockRepositoryImpl implements StockRepository {
  StockRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<List<StockItem>>> list() async {
    try {
      final response = await _dio.get(
        '/stock_levels',
        queryParameters: {
          'select': 'jan_code,product_name,on_hand',
          'order': 'on_hand.desc',
          'limit': 500,
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
}
