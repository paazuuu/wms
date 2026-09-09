import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/warehouse.dart';

/// Reads and mutates the company's warehouses through the `warehouses` edge
/// function. The tables are read-only to the client, so every write goes here
/// (the function holds the service role) — matching the delivery/shipment
/// pattern and keeping the door closed for direct client writes.
abstract class WarehouseRepository {
  Future<ApiResult<WarehouseOverview>> overview();
  Future<ApiResult<Warehouse>> create(NewWarehouse warehouse);
  Future<ApiResult<Warehouse>> update(
    int id, {
    String? name,
    String? address,
    String? phone,
    String? timezone,
    bool? isActive,
    bool? usesLocations,
  });
  Future<ApiResult<List<Bin>>> bins(int warehouseId);
}

class WarehouseRepositoryImpl implements WarehouseRepository {
  WarehouseRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<WarehouseOverview>> overview() async {
    try {
      final response = await _dio.get('/warehouses');
      final data = (response.data as Map)['data'];
      return ApiSuccess(
          WarehouseOverview.fromJson((data as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<WarehouseOverview>(e);
    }
  }

  @override
  Future<ApiResult<Warehouse>> create(NewWarehouse warehouse) async {
    try {
      final response =
          await _dio.post('/warehouses', data: warehouse.toJson());
      final data = (response.data as Map)['data'];
      return ApiSuccess(Warehouse.fromJson((data as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<Warehouse>(e);
    }
  }

  @override
  Future<ApiResult<Warehouse>> update(
    int id, {
    String? name,
    String? address,
    String? phone,
    String? timezone,
    bool? isActive,
    bool? usesLocations,
  }) async {
    try {
      final response = await _dio.patch('/warehouses/$id', data: {
        if (name != null) 'name': name,
        if (address != null) 'address': address,
        if (phone != null) 'phone': phone,
        if (timezone != null) 'timezone': timezone,
        if (isActive != null) 'is_active': isActive,
        if (usesLocations != null) 'uses_locations': usesLocations,
      });
      final data = (response.data as Map)['data'];
      return ApiSuccess(Warehouse.fromJson((data as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<Warehouse>(e);
    }
  }

  @override
  Future<ApiResult<List<Bin>>> bins(int warehouseId) async {
    try {
      final response = await _dio.get('/warehouses/$warehouseId/bins');
      final list = (response.data as Map)['data'] as List? ?? const [];
      return ApiSuccess(list
          .whereType<Map>()
          .map((e) => Bin.fromJson(e.cast<String, dynamic>()))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<Bin>>(e);
    }
  }
}
