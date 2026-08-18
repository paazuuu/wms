import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/supplier.dart';

/// Data access for suppliers, backed by the `/suppliers` API.
abstract class SupplierRepository {
  Future<ApiResult<List<Supplier>>> list({String? search});
  Future<ApiResult<Supplier>> show(int id);
}

class SupplierRepositoryImpl implements SupplierRepository {
  SupplierRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<List<Supplier>>> list({String? search}) async {
    try {
      final response = await _dio.get('/suppliers', queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'per_page': 50,
      });
      final data = (response.data['data'] as List<dynamic>)
          .map((e) => Supplier.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiSuccess(data);
    } on DioException catch (e) {
      return mapDioError<List<Supplier>>(e);
    }
  }

  @override
  Future<ApiResult<Supplier>> show(int id) async {
    try {
      final response = await _dio.get('/suppliers/$id');
      return ApiSuccess(
          Supplier.fromJson(response.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return mapDioError<Supplier>(e);
    }
  }
}
