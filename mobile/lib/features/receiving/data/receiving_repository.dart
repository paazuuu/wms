import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/purchase_order.dart';

/// A single receive instruction: how many units of a PO line to book in.
class ReceiveLine {
  const ReceiveLine({required this.itemId, required this.quantityToReceive});

  final int itemId;
  final int quantityToReceive;

  Map<String, dynamic> toJson() => {
        'id': itemId,
        'quantity_to_receive': quantityToReceive,
      };
}

/// Data access for the receiving flow, backed by the purchase-orders API.
/// Receiving a PO auto-creates an inspection on the backend.
abstract class ReceivingRepository {
  Future<ApiResult<List<PurchaseOrder>>> list({String? status, String? search});
  Future<ApiResult<PurchaseOrder>> show(int id);
  Future<ApiResult<PurchaseOrder>> receive(int id, List<ReceiveLine> lines);
}

class ReceivingRepositoryImpl implements ReceivingRepository {
  ReceivingRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<List<PurchaseOrder>>> list({String? status, String? search}) async {
    try {
      final response = await _dio.get('/purchase-orders', queryParameters: {
        if (status != null) 'status': status,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'per_page': 50,
      });
      final data = (response.data['data'] as List<dynamic>)
          .map((e) => PurchaseOrder.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiSuccess(data);
    } on DioException catch (e) {
      return mapDioError<List<PurchaseOrder>>(e);
    }
  }

  @override
  Future<ApiResult<PurchaseOrder>> show(int id) async {
    try {
      final response = await _dio.get('/purchase-orders/$id');
      return ApiSuccess(
          PurchaseOrder.fromJson(response.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return mapDioError<PurchaseOrder>(e);
    }
  }

  @override
  Future<ApiResult<PurchaseOrder>> receive(int id, List<ReceiveLine> lines) async {
    try {
      final response = await _dio.post('/purchase-orders/$id/receive', data: {
        'items': lines.map((l) => l.toJson()).toList(),
      });
      return ApiSuccess(
          PurchaseOrder.fromJson(response.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return mapDioError<PurchaseOrder>(e);
    }
  }
}
