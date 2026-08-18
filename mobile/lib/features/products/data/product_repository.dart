import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/product.dart';

/// Data access for the product catalogue. Backed by two backend endpoints:
/// - `GET /products?search=` — paginated `{ data, meta }` collection.
/// - `GET /barcode/{code}`   — custom `{ found, product }` single lookup.
abstract class ProductRepository {
  /// Free-text search across name / SKU / barcode.
  Future<ApiResult<List<Product>>> search({String? query, int perPage});

  /// Exact barcode/SKU lookup. Returns `null` data when nothing matches so the
  /// UI can distinguish "not found" from a transport error.
  Future<ApiResult<Product?>> lookupBarcode(String code);

  Future<ApiResult<Product>> show(int id);
}

class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<List<Product>>> search({String? query, int perPage = 25}) async {
    try {
      final response = await _dio.get('/products', queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'search': query.trim(),
        'per_page': perPage,
      });
      final data = (response.data['data'] as List<dynamic>)
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiSuccess(data);
    } on DioException catch (e) {
      return mapDioError<List<Product>>(e);
    }
  }

  @override
  Future<ApiResult<Product?>> lookupBarcode(String code) async {
    try {
      final response = await _dio.get('/barcode/${Uri.encodeComponent(code)}');
      final body = response.data as Map<String, dynamic>;
      final product = body['product'];
      if (body['found'] == true && product is Map<String, dynamic>) {
        return ApiSuccess<Product?>(Product.fromJson(product));
      }
      return const ApiSuccess<Product?>(null);
    } on DioException catch (e) {
      // A 404 from this endpoint means "no product", not a failure.
      if (e.response?.statusCode == 404) {
        return const ApiSuccess<Product?>(null);
      }
      return mapDioError<Product?>(e);
    }
  }

  @override
  Future<ApiResult<Product>> show(int id) async {
    try {
      final response = await _dio.get('/products/$id');
      return ApiSuccess(
          Product.fromJson(response.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return mapDioError<Product>(e);
    }
  }
}
