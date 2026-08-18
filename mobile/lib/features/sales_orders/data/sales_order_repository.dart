import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/sales_order.dart';

/// Data access for sales (customer) orders, backed by the `/orders` API.
abstract class SalesOrderRepository {
  Future<ApiResult<List<SalesOrder>>> list({String? search, String? status});
  Future<ApiResult<SalesOrder>> show(int id);
}

class SalesOrderRepositoryImpl implements SalesOrderRepository {
  SalesOrderRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<List<SalesOrder>>> list({
    String? search,
    String? status,
  }) async {
    try {
      final response = await _dio.get('/orders', queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
        'per_page': 50,
      });
      final data = (response.data['data'] as List<dynamic>)
          .map((e) => SalesOrder.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiSuccess(data);
    } on DioException catch (e) {
      return mapDioError<List<SalesOrder>>(e);
    }
  }

  @override
  Future<ApiResult<SalesOrder>> show(int id) async {
    try {
      final response = await _dio.get('/orders/$id');
      return ApiSuccess(
          SalesOrder.fromJson(response.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return mapDioError<SalesOrder>(e);
    }
  }
}
