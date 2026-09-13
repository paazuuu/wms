import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/sales_order.dart';

/// Sales orders (spec §46 checklist item 7, 0034) — the outbound counterpart
/// to purchase orders: a self-contained order lifecycle (draft → submit →
/// approve/reject → cancel/complete) that never moves stock; fulfillment
/// still goes through the existing shipment-plan/picking/packing flow.
/// Reads and writes both go through RPCs, never a direct table read/write.
abstract class SalesOrderRepository {
  Future<ApiResult<List<SalesOrder>>> list({int? warehouseId, String? status});

  Future<ApiResult<SalesOrder>> show(int id);

  Future<ApiResult<int>> create({
    required String customerName,
    required int warehouseId,
    required List<SalesOrderLineDraft> lines,
    int? customerId,
    DateTime? requestedShipDate,
    String? note,
  });

  Future<ApiResult<bool>> submit(int id);
  Future<ApiResult<bool>> approve(int id);
  Future<ApiResult<bool>> reject(int id, {String? reason});
  Future<ApiResult<bool>> cancel(int id);
  Future<ApiResult<bool>> complete(int id);
}

class SalesOrderRepositoryImpl implements SalesOrderRepository {
  SalesOrderRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<List<SalesOrder>>> list(
      {int? warehouseId, String? status}) async {
    try {
      final response = await _dio.post('/rpc/sales_order_index', data: {
        'p_warehouse_id': warehouseId,
        'p_status': status,
      });
      final data = response.data;
      // A jsonb-array-returning RPC comes back as the array itself; some
      // PostgREST setups wrap it in a single-element list — accept both,
      // same ambiguity every other jsonb-returning RPC here already handles.
      final rows = data is List
          ? (data.length == 1 && data.first is List ? data.first as List : data)
          : const [];
      return ApiSuccess(rows
          .whereType<Map>()
          .map((e) => SalesOrder.fromJson(e.cast<String, dynamic>()))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<SalesOrder>>(e);
    }
  }

  @override
  Future<ApiResult<SalesOrder>> show(int id) async {
    try {
      final response =
          await _dio.post('/rpc/sales_order_detail', data: {'p_id': id});
      final data = response.data;
      final json = data is List && data.isNotEmpty ? data.first : data;
      return ApiSuccess(
          SalesOrder.fromJson((json as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<SalesOrder>(e);
    }
  }

  @override
  Future<ApiResult<int>> create({
    required String customerName,
    required int warehouseId,
    required List<SalesOrderLineDraft> lines,
    int? customerId,
    DateTime? requestedShipDate,
    String? note,
  }) async {
    try {
      final response = await _dio.post('/rpc/create_sales_order', data: {
        'p_customer_name': customerName,
        'p_warehouse_id': warehouseId,
        'p_lines': lines.map((l) => l.toJson()).toList(),
        'p_customer_id': customerId,
        'p_requested_ship_date':
            requestedShipDate?.toIso8601String().substring(0, 10),
        'p_note': note,
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
  Future<ApiResult<bool>> submit(int id) => _action('/rpc/submit_sales_order', {'p_id': id});

  @override
  Future<ApiResult<bool>> approve(int id) =>
      _action('/rpc/approve_sales_order', {'p_id': id});

  @override
  Future<ApiResult<bool>> reject(int id, {String? reason}) =>
      _action('/rpc/reject_sales_order', {'p_id': id, 'p_reason': reason});

  @override
  Future<ApiResult<bool>> cancel(int id) =>
      _action('/rpc/cancel_sales_order', {'p_id': id});

  @override
  Future<ApiResult<bool>> complete(int id) =>
      _action('/rpc/complete_sales_order', {'p_id': id});

  Future<ApiResult<bool>> _action(String path, Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(path, data: data);
      return ApiSuccess(response.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }
}
