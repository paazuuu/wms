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

  /// §17's per-box facts (0076): what a carrier prices a box on. A null
  /// clears a field, the same convention [setLogistics] uses at the plan
  /// level.
  Future<ApiResult<bool>> setCartonMeasurements(
    int cartonId, {
    double? weightKg,
    double? lengthCm,
    double? widthCm,
    double? heightCm,
    String? cartonType,
    String? trackingNumber,
  });

  /// Closes a box once it is packed. Refused while it is empty.
  Future<ApiResult<bool>> closeCarton(int cartonId);

  /// Reopens a closed box so its contents can change again. Refused once the
  /// shipment itself has shipped.
  Future<ApiResult<bool>> reopenCarton(int cartonId);

  /// Renames a carton without touching what is inside it (0079) — the safe
  /// alternative to the old whole-carton replace, which has no lot/serial
  /// columns in its payload and would silently drop them.
  Future<ApiResult<bool>> setCartonLabel(int cartonId, String? label);

  /// Each product's packing ceiling (from picks, or the order when picking
  /// never ran) next to every carton's own, properly-joined detail (0076) —
  /// what the packing screen reads instead of the lighter cartons embedded in
  /// [show].
  Future<ApiResult<ShipmentPacking>> packing(int planId);

  /// Records one parcel packed into a box — additive, the same shape
  /// `record_pick_item` has on the picking side: calling it twice records two
  /// parcels, not a corrected total. Bounded by [PackableLine.unpacked],
  /// which the server enforces regardless of which carton it goes in.
  Future<ApiResult<bool>> packCartonItem(
    int cartonId, {
    required int quantity,
    required String janCode,
    String? lotCode,
    String? serialNumber,
    int? stockUnitId,
    String? note,
  });

  /// Takes one packed parcel back out of its carton.
  Future<ApiResult<bool>> removeCartonItem(int itemId);
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

  @override
  Future<ApiResult<bool>> setCartonMeasurements(
    int cartonId, {
    double? weightKg,
    double? lengthCm,
    double? widthCm,
    double? heightCm,
    String? cartonType,
    String? trackingNumber,
  }) async {
    try {
      await _rpc.post('/rpc/set_carton_measurements', data: {
        'p_carton_id': cartonId,
        'p_weight_kg': weightKg,
        'p_length_cm': lengthCm,
        'p_width_cm': widthCm,
        'p_height_cm': heightCm,
        'p_carton_type': cartonType,
        'p_tracking_number': trackingNumber,
      });
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<bool>> closeCarton(int cartonId) async {
    try {
      await _rpc.post('/rpc/close_carton', data: {'p_carton_id': cartonId});
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<bool>> reopenCarton(int cartonId) async {
    try {
      await _rpc.post('/rpc/reopen_carton', data: {'p_carton_id': cartonId});
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<bool>> setCartonLabel(int cartonId, String? label) async {
    try {
      await _rpc.post('/rpc/set_carton_label', data: {
        'p_carton_id': cartonId,
        'p_label': label,
      });
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<ShipmentPacking>> packing(int planId) async {
    try {
      final response = await _rpc
          .post('/rpc/shipment_packing', data: {'p_plan_id': planId});
      final data = response.data;
      final json = data is List && data.isNotEmpty ? data.first : data;
      return ApiSuccess(
          ShipmentPacking.fromJson((json as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<ShipmentPacking>(e);
    }
  }

  @override
  Future<ApiResult<bool>> packCartonItem(
    int cartonId, {
    required int quantity,
    required String janCode,
    String? lotCode,
    String? serialNumber,
    int? stockUnitId,
    String? note,
  }) async {
    try {
      await _rpc.post('/rpc/pack_carton_item', data: {
        'p_carton_id': cartonId,
        'p_quantity': quantity,
        'p_jan_code': janCode,
        'p_lot_code': lotCode,
        'p_serial_number': serialNumber,
        'p_stock_unit_id': stockUnitId,
        'p_note': note,
      });
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<bool>> removeCartonItem(int itemId) async {
    try {
      await _rpc.post('/rpc/remove_carton_item', data: {'p_item_id': itemId});
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }
}
