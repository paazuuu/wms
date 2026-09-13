import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/carton.dart';
import '../domain/shipment.dart';

/// Data access for the outbound / shipping flow. Shipments are imported through
/// the shared import-plan function (target=shipment); this repository reads
/// them, manages cartons, and confirms/cancels the shipment.
abstract class ShipmentRepository {
  /// Shipments, newest first. [warehouseId] scopes them to one warehouse
  /// (UI spec §4); null means every warehouse the caller can see.
  Future<ApiResult<List<Shipment>>> list(
      {String? status, String? search, int? warehouseId});
  Future<ApiResult<Shipment>> show(int id);

  /// Confirm the shipment: deduct stock and mark it shipped.
  Future<ApiResult<Shipment>> ship(int id);

  /// Undo a shipment: restore stock and return it to open.
  Future<ApiResult<Shipment>> cancel(int id);

  Future<ApiResult<Shipment>> createCarton(int id, {String? label});
  Future<ApiResult<Shipment>> deleteCarton(int id, int cartonId);

  /// Replace a carton's label and items in one call.
  Future<ApiResult<Shipment>> updateCarton(
    int id,
    int cartonId, {
    String? label,
    required List<CartonItem> items,
  });

  /// §18 — split the shipment into cartons of at most [unitsPerCarton] pieces,
  /// server-side, so nobody divides by hand. Refused when cartons already
  /// exist; returns how many boxes were made.
  Future<ApiResult<AutopackResult>> autopack(int id,
      {required int unitsPerCarton});

  /// §21 — the shipping desk's weight / carrier / tracking. A null clears the
  /// field rather than leaving the old value behind.
  Future<ApiResult<bool>> setLogistics(
    int id, {
    double? weightKg,
    String? carrier,
    String? trackingNumber,
  });
}

/// What `autopack_shipment` reports back.
class AutopackResult {
  const AutopackResult({
    required this.cartonCount,
    required this.unitsPerCarton,
    required this.totalUnits,
  });

  final int cartonCount;
  final int unitsPerCarton;
  final int totalUnits;

  factory AutopackResult.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) =>
        v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
    return AutopackResult(
      cartonCount: asInt(json['carton_count']),
      unitsPerCarton: asInt(json['units_per_carton']),
      totalUnits: asInt(json['total_units']),
    );
  }
}

class ShipmentRepositoryImpl implements ShipmentRepository {
  /// [_dio] reaches the `shipments` edge function; [_rest] reaches PostgREST for
  /// the two 0039 RPCs, which are plain database functions rather than routes on
  /// that function. Callers that never pack can pass only the first.
  ShipmentRepositoryImpl(this._dio, [Dio? rest]) : _rest = rest;

  final Dio _dio;
  final Dio? _rest;

  Dio get _rpc {
    final rest = _rest;
    if (rest == null) {
      throw StateError('ShipmentRepositoryImpl needs a REST Dio for RPC calls');
    }
    return rest;
  }

  @override
  Future<ApiResult<List<Shipment>>> list(
      {String? status, String? search, int? warehouseId}) async {
    try {
      final response = await _dio.get('/shipments', queryParameters: {
        if (status != null) 'status': status,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (warehouseId != null) 'warehouse_id': warehouseId,
      });
      final data = (response.data['data'] as List<dynamic>)
          .map((e) => Shipment.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiSuccess(data);
    } on DioException catch (e) {
      return mapDioError<List<Shipment>>(e);
    }
  }

  @override
  Future<ApiResult<Shipment>> show(int id) => _get('/shipments/$id');

  @override
  Future<ApiResult<Shipment>> ship(int id) => _post('/shipments/$id/ship');

  @override
  Future<ApiResult<Shipment>> cancel(int id) => _post('/shipments/$id/cancel');

  @override
  Future<ApiResult<Shipment>> createCarton(int id, {String? label}) =>
      _post('/shipments/$id/cartons', data: {if (label != null) 'label': label});

  @override
  Future<ApiResult<Shipment>> deleteCarton(int id, int cartonId) async {
    try {
      final response = await _dio.delete('/shipments/$id/cartons/$cartonId');
      return ApiSuccess(
          Shipment.fromJson(response.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return mapDioError<Shipment>(e);
    }
  }

  @override
  Future<ApiResult<Shipment>> updateCarton(
    int id,
    int cartonId, {
    String? label,
    required List<CartonItem> items,
  }) async {
    try {
      final response = await _dio.put('/shipments/$id/cartons/$cartonId', data: {
        if (label != null) 'label': label,
        'items': items.map((e) => e.toJson()).toList(),
      });
      return ApiSuccess(
          Shipment.fromJson(response.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return mapDioError<Shipment>(e);
    }
  }

  Future<ApiResult<Shipment>> _get(String path) async {
    try {
      final response = await _dio.get(path);
      return ApiSuccess(
          Shipment.fromJson(response.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return mapDioError<Shipment>(e);
    }
  }

  Future<ApiResult<Shipment>> _post(String path, {Object? data}) async {
    try {
      final response = await _dio.post(path, data: data);
      return ApiSuccess(
          Shipment.fromJson(response.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return mapDioError<Shipment>(e);
    }
  }

  @override
  Future<ApiResult<AutopackResult>> autopack(int id,
      {required int unitsPerCarton}) async {
    try {
      final response = await _rpc.post('/rpc/autopack_shipment', data: {
        'p_plan_id': id,
        'p_units_per_carton': unitsPerCarton,
      });
      final data = response.data;
      final json = data is List && data.isNotEmpty ? data.first : data;
      return ApiSuccess(
          AutopackResult.fromJson((json as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<AutopackResult>(e);
    }
  }

  @override
  Future<ApiResult<bool>> setLogistics(
    int id, {
    double? weightKg,
    String? carrier,
    String? trackingNumber,
  }) async {
    try {
      await _rpc.post('/rpc/set_shipment_logistics', data: {
        'p_plan_id': id,
        'p_weight_kg': weightKg,
        'p_carrier': carrier,
        'p_tracking_number': trackingNumber,
      });
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }
}
