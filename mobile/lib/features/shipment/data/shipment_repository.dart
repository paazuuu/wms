import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/carton.dart';
import '../domain/shipment.dart';

/// Data access for the outbound / shipping flow. Shipments are imported through
/// the shared import-plan function (target=shipment); this repository reads
/// them, manages cartons, and confirms/cancels the shipment.
abstract class ShipmentRepository {
  Future<ApiResult<List<Shipment>>> list({String? status, String? search});
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
}

class ShipmentRepositoryImpl implements ShipmentRepository {
  ShipmentRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<List<Shipment>>> list({String? status, String? search}) async {
    try {
      final response = await _dio.get('/shipments', queryParameters: {
        if (status != null) 'status': status,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
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
}
