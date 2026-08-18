import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/product_batch.dart';
import '../domain/product_serial.dart';

/// Data access for a product's lot/batch and serial tracking, backed by the
/// product-scoped `/products/{id}/batches` and `/products/{id}/serials` APIs.
abstract class TrackingRepository {
  Future<ApiResult<List<ProductBatch>>> batches(int productId);
  Future<ApiResult<List<ProductSerial>>> serials(int productId);
}

class TrackingRepositoryImpl implements TrackingRepository {
  TrackingRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<List<ProductBatch>>> batches(int productId) async {
    try {
      final response = await _dio.get(
        '/products/$productId/batches',
        queryParameters: {'per_page': 50},
      );
      final data = (response.data['data'] as List<dynamic>)
          .map((e) => ProductBatch.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiSuccess(data);
    } on DioException catch (e) {
      return mapDioError<List<ProductBatch>>(e);
    }
  }

  @override
  Future<ApiResult<List<ProductSerial>>> serials(int productId) async {
    try {
      final response = await _dio.get(
        '/products/$productId/serials',
        queryParameters: {'per_page': 50},
      );
      final data = (response.data['data'] as List<dynamic>)
          .map((e) => ProductSerial.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiSuccess(data);
    } on DioException catch (e) {
      return mapDioError<List<ProductSerial>>(e);
    }
  }
}
