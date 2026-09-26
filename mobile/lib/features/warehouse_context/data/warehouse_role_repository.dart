import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/warehouse_role.dart';

/// A warehouse's country and cross-border role (0087). Kept apart from
/// [WarehouseRepository] because it goes through its own RPCs rather than the
/// `warehouses` edge function, which whitelists the fields it writes.
abstract class WarehouseRoleRepository {
  Future<ApiResult<List<WarehouseRole>>> list();

  Future<ApiResult<bool>> set(int warehouseId,
      {required String countryCode, required bool receivesCrossBorder});
}

class WarehouseRoleRepositoryImpl implements WarehouseRoleRepository {
  WarehouseRoleRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<List<WarehouseRole>>> list() async {
    try {
      final response = await _dio.post('/rpc/warehouse_roles', data: const {});
      final data = response.data;
      final rows = data is List
          ? (data.length == 1 && data.first is List ? data.first as List : data)
          : const [];
      return ApiSuccess(rows
          .whereType<Map>()
          .map((e) => WarehouseRole.fromJson(e.cast<String, dynamic>()))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<WarehouseRole>>(e);
    }
  }

  @override
  Future<ApiResult<bool>> set(int warehouseId,
      {required String countryCode, required bool receivesCrossBorder}) async {
    try {
      final response = await _dio.post('/rpc/set_warehouse_role', data: {
        'p_warehouse_id': warehouseId,
        'p_country_code': countryCode,
        'p_receives_cross_border': receivesCrossBorder,
      });
      return ApiSuccess(response.data != null);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }
}
