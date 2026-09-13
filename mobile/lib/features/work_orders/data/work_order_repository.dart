import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/work_order.dart';

/// Work orders / kitting / assembly (spec §46 checklist item 9, 0036) — the
/// internal counterpart to purchase/sales orders: unlike those, completing
/// a work order DOES move stock (every component's required quantity
/// leaves, the output quantity arrives). Reads and writes both go through
/// RPCs, never a direct table read/write.
abstract class WorkOrderRepository {
  Future<ApiResult<List<WorkOrder>>> list({int? warehouseId, String? status});

  Future<ApiResult<WorkOrder>> show(int id);

  Future<ApiResult<int>> create({
    required int warehouseId,
    required String outputJanCode,
    required int outputQuantity,
    required List<WorkOrderComponentDraft> components,
    String? outputProductName,
    String? note,
  });

  Future<ApiResult<bool>> start(int id);
  Future<ApiResult<bool>> cancel(int id);
  Future<ApiResult<bool>> complete(int id);
}

class WorkOrderRepositoryImpl implements WorkOrderRepository {
  WorkOrderRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<List<WorkOrder>>> list(
      {int? warehouseId, String? status}) async {
    try {
      final response = await _dio.post('/rpc/work_order_index', data: {
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
          .map((e) => WorkOrder.fromJson(e.cast<String, dynamic>()))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<WorkOrder>>(e);
    }
  }

  @override
  Future<ApiResult<WorkOrder>> show(int id) async {
    try {
      final response =
          await _dio.post('/rpc/work_order_detail', data: {'p_id': id});
      final data = response.data;
      final json = data is List && data.isNotEmpty ? data.first : data;
      return ApiSuccess(
          WorkOrder.fromJson((json as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<WorkOrder>(e);
    }
  }

  @override
  Future<ApiResult<int>> create({
    required int warehouseId,
    required String outputJanCode,
    required int outputQuantity,
    required List<WorkOrderComponentDraft> components,
    String? outputProductName,
    String? note,
  }) async {
    try {
      final response = await _dio.post('/rpc/create_work_order', data: {
        'p_warehouse_id': warehouseId,
        'p_output_jan_code': outputJanCode,
        'p_output_quantity': outputQuantity,
        'p_components': components.map((c) => c.toJson()).toList(),
        'p_output_product_name': outputProductName,
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
  Future<ApiResult<bool>> start(int id) => _action('/rpc/start_work_order', {'p_id': id});

  @override
  Future<ApiResult<bool>> cancel(int id) =>
      _action('/rpc/cancel_work_order', {'p_id': id});

  @override
  Future<ApiResult<bool>> complete(int id) async {
    try {
      final response =
          await _dio.post('/rpc/complete_work_order', data: {'p_id': id});
      return ApiSuccess(response.data != null);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  Future<ApiResult<bool>> _action(String path, Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(path, data: data);
      return ApiSuccess(response.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }
}
