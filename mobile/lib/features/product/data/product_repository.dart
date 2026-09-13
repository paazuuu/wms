import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/product.dart';

/// The product master (spec §19, 0032) — read via `list_products`, written
/// only through `create_product`/`update_product`/`set_product_status`
/// (`product.manage`-gated), never a direct table write.
abstract class ProductRepository {
  Future<ApiResult<List<Product>>> list({String? search, String? status = 'active'});

  Future<ApiResult<int>> create({
    required String janCode,
    required String name,
    String? category,
    double? price,
  });

  Future<ApiResult<bool>> update({
    required int id,
    required String name,
    String? category,
    double? price,
  });

  Future<ApiResult<bool>> setStatus(int id, String status);
}

class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<List<Product>>> list(
      {String? search, String? status = 'active'}) async {
    try {
      final response = await _dio.post('/rpc/list_products', data: {
        'p_search': search,
        'p_status': status,
      });
      final data = response.data;
      // A jsonb-array-returning RPC comes back as the array itself; some
      // PostgREST setups wrap it in a single-element list — accept both,
      // same ambiguity `list_connectors`/`list_ai_analysis` already handle.
      final rows = data is List
          ? (data.length == 1 && data.first is List ? data.first as List : data)
          : const [];
      return ApiSuccess(rows
          .whereType<Map>()
          .map((e) => Product.fromJson(e.cast<String, dynamic>()))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<Product>>(e);
    }
  }

  @override
  Future<ApiResult<int>> create({
    required String janCode,
    required String name,
    String? category,
    double? price,
  }) async {
    try {
      final response = await _dio.post('/rpc/create_product', data: {
        'p_jan_code': janCode,
        'p_name': name,
        'p_category': category,
        'p_price': price,
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
  Future<ApiResult<bool>> update({
    required int id,
    required String name,
    String? category,
    double? price,
  }) async {
    try {
      final response = await _dio.post('/rpc/update_product', data: {
        'p_id': id,
        'p_name': name,
        'p_category': category,
        'p_price': price,
      });
      return ApiSuccess(response.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<bool>> setStatus(int id, String status) async {
    try {
      final response = await _dio.post('/rpc/set_product_status', data: {
        'p_id': id,
        'p_status': status,
      });
      return ApiSuccess(response.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }
}
