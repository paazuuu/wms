import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/warehouse.dart';

/// Data access for warehouses, backed by the `/warehouses` API.
abstract class WarehouseRepository {
  Future<ApiResult<List<Warehouse>>> list({String? search});
  Future<ApiResult<Warehouse>> show(int id);
}

class WarehouseRepositoryImpl implements WarehouseRepository {
  WarehouseRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<List<Warehouse>>> list({String? search}) async {
    try {
      final response = await _dio.get('/warehouses', queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'per_page': 50,
      });
      final data = (response.data['data'] as List<dynamic>)
          .map((e) => Warehouse.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiSuccess(data);
    } on DioException catch (e) {
      return mapDioError<List<Warehouse>>(e);
    }
  }

  @override
  Future<ApiResult<Warehouse>> show(int id) async {
    try {
      final response = await _dio.get('/warehouses/$id');
      return ApiSuccess(
          Warehouse.fromJson(response.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return mapDioError<Warehouse>(e);
    }
  }
}
