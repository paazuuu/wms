import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/location.dart';

/// Data access for warehouse locations, backed by the `/locations` API.
abstract class LocationRepository {
  Future<ApiResult<List<Location>>> list({String? search});
  Future<ApiResult<Location>> show(int id);
}

class LocationRepositoryImpl implements LocationRepository {
  LocationRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<List<Location>>> list({String? search}) async {
    try {
      final response = await _dio.get('/locations', queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'per_page': 50,
      });
      final data = (response.data['data'] as List<dynamic>)
          .map((e) => Location.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiSuccess(data);
    } on DioException catch (e) {
      return mapDioError<List<Location>>(e);
    }
  }

  @override
  Future<ApiResult<Location>> show(int id) async {
    try {
      final response = await _dio.get('/locations/$id');
      return ApiSuccess(
          Location.fromJson(response.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return mapDioError<Location>(e);
    }
  }
}
