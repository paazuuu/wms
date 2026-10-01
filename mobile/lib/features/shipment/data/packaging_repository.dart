import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/packaging.dart';

/// Boxes, packing material and what a shipment should weigh (0115).
abstract class PackagingRepository {
  Future<ApiResult<List<CartonType>>> cartonTypes({bool includeInactive = false});

  /// Creates (no id) or changes a carton type; returns its id.
  Future<ApiResult<int>> saveCartonType(CartonType type);

  Future<ApiResult<ShipmentWeightEstimate>> estimate(int planId);

  /// Replaces the boxes a shipment is expected to need.
  Future<ApiResult<ShipmentWeightEstimate>> setPlannedCartons(int planId, List<PlannedCarton> items);

  /// A real carton's type, empty weight and packing material.
  Future<ApiResult<bool>> setCartonPackaging(int cartonId,
      {required int cartonTypeId, double? emptyWeightG, double? packingMaterialG});
}

class PackagingRepositoryImpl implements PackagingRepository {
  PackagingRepositoryImpl(this._dio);

  final Dio _dio;

  Map<String, dynamic> _one(dynamic data) {
    final json = data is List && data.isNotEmpty ? data.first : data;
    return (json as Map).cast<String, dynamic>();
  }

  @override
  Future<ApiResult<List<CartonType>>> cartonTypes({bool includeInactive = false}) async {
    try {
      final r = await _dio.post('/rpc/list_carton_types', data: {'p_include_inactive': includeInactive});
      final rows = r.data is List ? r.data as List : const [];
      return ApiSuccess(rows.whereType<Map>().map((e) => CartonType.fromJson(e.cast<String, dynamic>())).toList());
    } on DioException catch (e) {
      return mapDioError<List<CartonType>>(e);
    }
  }

  @override
  Future<ApiResult<int>> saveCartonType(CartonType type) async {
    try {
      final r = await _dio.post('/rpc/save_carton_type', data: {'p': type.toJson()});
      return ApiSuccess(r.data is num ? (r.data as num).toInt() : int.tryParse('${r.data}') ?? 0);
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
  }

  @override
  Future<ApiResult<ShipmentWeightEstimate>> estimate(int planId) async {
    try {
      final r = await _dio.post('/rpc/shipment_weight_estimate', data: {'p_plan_id': planId});
      return ApiSuccess(ShipmentWeightEstimate.fromJson(_one(r.data)));
    } on DioException catch (e) {
      return mapDioError<ShipmentWeightEstimate>(e);
    }
  }

  @override
  Future<ApiResult<ShipmentWeightEstimate>> setPlannedCartons(int planId, List<PlannedCarton> items) async {
    try {
      final r = await _dio.post('/rpc/set_shipment_planned_cartons',
          data: {'p_plan_id': planId, 'p_items': items.map((e) => e.toJson()).toList()});
      return ApiSuccess(ShipmentWeightEstimate.fromJson(_one(r.data)));
    } on DioException catch (e) {
      return mapDioError<ShipmentWeightEstimate>(e);
    }
  }

  @override
  Future<ApiResult<bool>> setCartonPackaging(int cartonId,
      {required int cartonTypeId, double? emptyWeightG, double? packingMaterialG}) async {
    try {
      await _dio.post('/rpc/set_carton_packaging', data: {
        'p_carton_id': cartonId,
        'p_carton_type_id': cartonTypeId,
        'p_empty_weight_g': emptyWeightG,
        'p_packing_material_g': packingMaterialG,
      });
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }
}
