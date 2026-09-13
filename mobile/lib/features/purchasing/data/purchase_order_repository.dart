import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/purchase_order.dart';

/// Purchase orders (spec §46 checklist item 6, 0033) — a self-contained
/// order lifecycle (draft → submit → approve/reject → cancel/complete) that
/// never moves stock; receiving still goes through the existing delivery
/// plan/reconciliation flow. Reads and writes both go through RPCs, never a
/// direct table read/write.
abstract class PurchaseOrderRepository {
  Future<ApiResult<List<PurchaseOrder>>> list({int? warehouseId, String? status});

  Future<ApiResult<PurchaseOrder>> show(int id);

  Future<ApiResult<int>> create({
    required String supplierName,
    required int warehouseId,
    required List<PurchaseOrderLineDraft> lines,
    int? supplierId,
    DateTime? expectedDate,
    String? note,
  });

  Future<ApiResult<bool>> submit(int id);
  Future<ApiResult<bool>> approve(int id);
  Future<ApiResult<bool>> reject(int id, {String? reason});
  Future<ApiResult<bool>> cancel(int id);
  Future<ApiResult<bool>> complete(int id);
}

class PurchaseOrderRepositoryImpl implements PurchaseOrderRepository {
  PurchaseOrderRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<List<PurchaseOrder>>> list(
      {int? warehouseId, String? status}) async {
    try {
      final response = await _dio.post('/rpc/purchase_order_index', data: {
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
          .map((e) => PurchaseOrder.fromJson(e.cast<String, dynamic>()))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<PurchaseOrder>>(e);
    }
  }

  @override
  Future<ApiResult<PurchaseOrder>> show(int id) async {
    try {
      final response =
          await _dio.post('/rpc/purchase_order_detail', data: {'p_id': id});
      final data = response.data;
      final json = data is List && data.isNotEmpty ? data.first : data;
      return ApiSuccess(
          PurchaseOrder.fromJson((json as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<PurchaseOrder>(e);
    }
  }

  @override
  Future<ApiResult<int>> create({
    required String supplierName,
    required int warehouseId,
    required List<PurchaseOrderLineDraft> lines,
    int? supplierId,
    DateTime? expectedDate,
    String? note,
  }) async {
    try {
      final response = await _dio.post('/rpc/create_purchase_order', data: {
        'p_supplier_name': supplierName,
        'p_warehouse_id': warehouseId,
        'p_lines': lines.map((l) => l.toJson()).toList(),
        'p_supplier_id': supplierId,
        'p_expected_date': expectedDate?.toIso8601String().substring(0, 10),
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
  Future<ApiResult<bool>> submit(int id) => _action('/rpc/submit_purchase_order', {'p_id': id});

  @override
  Future<ApiResult<bool>> approve(int id) =>
      _action('/rpc/approve_purchase_order', {'p_id': id});

  @override
  Future<ApiResult<bool>> reject(int id, {String? reason}) =>
      _action('/rpc/reject_purchase_order', {'p_id': id, 'p_reason': reason});

  @override
  Future<ApiResult<bool>> cancel(int id) =>
      _action('/rpc/cancel_purchase_order', {'p_id': id});

  @override
  Future<ApiResult<bool>> complete(int id) =>
      _action('/rpc/complete_purchase_order', {'p_id': id});

  Future<ApiResult<bool>> _action(String path, Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(path, data: data);
      return ApiSuccess(response.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }
}
