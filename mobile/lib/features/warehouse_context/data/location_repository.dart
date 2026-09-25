import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/bin_stock.dart';
import '../domain/location.dart';

/// The location tree (§7, §8 — migration 0062).
///
/// Structure only: `locations` is canonical for the shape of the warehouse,
/// while `bins` stays canonical for bin-level quantity. Zones and bins are
/// synced into the tree by the database, so creating a *bin* is still the
/// warehouse repository's job — this one adds the nodes that are not bins: an
/// aisle, a rack, a virtual RECEIVING area.
abstract class LocationRepository {
  /// `location_tree` — nested, to its full depth, for one warehouse.
  Future<ApiResult<List<Location>>> tree(
    int warehouseId, {
    bool includeInactive = false,
  });

  /// `list_location_types` — the vocabulary, with each type's default flags.
  Future<ApiResult<List<LocationType>>> types();

  /// `bin_stock_overview` — every bin in a warehouse that uses locations, and
  /// what is actually sitting in each one. The location tree's own `onHand`
  /// is a per-location total; this is the breakdown behind it.
  Future<ApiResult<List<BinStock>>> binStockOverview(int warehouseId);

  /// `create_location`. [parentCode] is a code, not an id, because the operator
  /// is reading it off the rack. The flags are nullable: left null they come
  /// from the type, which is what makes "a RECEIVING area" one argument instead
  /// of five.
  Future<ApiResult<int>> create({
    required int warehouseId,
    required String code,
    String? name,
    String locationType = 'STORAGE',
    String? parentCode,
    String? barcode,
    bool? pickable,
    bool? receivable,
    bool? shipping,
    bool? quarantine,
    bool? isVirtual,
  });

  /// `update_location`. Only the fields named are changed; the rest keep their
  /// values, so one flag can be flipped without restating the row.
  Future<ApiResult<bool>> update({
    required int locationId,
    String? name,
    String? locationType,
    String? parentCode,
    String? barcode,
    bool? isActive,
    bool? pickable,
    bool? receivable,
    bool? shipping,
    bool? quarantine,
  });
}

class LocationRepositoryImpl implements LocationRepository {
  LocationRepositoryImpl(this._dio);

  final Dio _dio;

  static List<Map<String, dynamic>> _rows(dynamic data) {
    final list = data is List
        ? (data.length == 1 && data.first is List ? data.first as List : data)
        : const [];
    return list
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList(growable: false);
  }

  @override
  Future<ApiResult<List<Location>>> tree(
    int warehouseId, {
    bool includeInactive = false,
  }) async {
    try {
      final response = await _dio.post('/rpc/location_tree', data: {
        'p_warehouse_id': warehouseId,
        'p_include_inactive': includeInactive,
      });
      return ApiSuccess(
          _rows(response.data).map((e) => Location.fromJson(e)).toList());
    } on DioException catch (e) {
      return mapDioError<List<Location>>(e);
    }
  }

  @override
  Future<ApiResult<List<LocationType>>> types() async {
    try {
      final response =
          await _dio.post('/rpc/list_location_types', data: const {});
      return ApiSuccess(
          _rows(response.data).map((e) => LocationType.fromJson(e)).toList());
    } on DioException catch (e) {
      return mapDioError<List<LocationType>>(e);
    }
  }

  @override
  Future<ApiResult<List<BinStock>>> binStockOverview(int warehouseId) async {
    try {
      final response = await _dio.post('/rpc/bin_stock_overview', data: {
        'p_warehouse_id': warehouseId,
      });
      return ApiSuccess(
          _rows(response.data).map((e) => BinStock.fromJson(e)).toList());
    } on DioException catch (e) {
      return mapDioError<List<BinStock>>(e);
    }
  }

  @override
  Future<ApiResult<int>> create({
    required int warehouseId,
    required String code,
    String? name,
    String locationType = 'STORAGE',
    String? parentCode,
    String? barcode,
    bool? pickable,
    bool? receivable,
    bool? shipping,
    bool? quarantine,
    bool? isVirtual,
  }) async {
    try {
      final response = await _dio.post('/rpc/create_location', data: {
        'p_warehouse_id': warehouseId,
        'p_code': code,
        'p_name': name,
        'p_location_type': locationType,
        'p_parent_code': parentCode,
        'p_barcode': barcode,
        'p_pickable': pickable,
        'p_receivable': receivable,
        'p_shipping': shipping,
        'p_quarantine': quarantine,
        'p_is_virtual': isVirtual,
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
    required int locationId,
    String? name,
    String? locationType,
    String? parentCode,
    String? barcode,
    bool? isActive,
    bool? pickable,
    bool? receivable,
    bool? shipping,
    bool? quarantine,
  }) async {
    try {
      final response = await _dio.post('/rpc/update_location', data: {
        'p_location_id': locationId,
        'p_name': name,
        'p_location_type': locationType,
        'p_parent_code': parentCode,
        'p_barcode': barcode,
        'p_is_active': isActive,
        'p_pickable': pickable,
        'p_receivable': receivable,
        'p_shipping': shipping,
        'p_quarantine': quarantine,
      });
      return ApiSuccess(response.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }
}
