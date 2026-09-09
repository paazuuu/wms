import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/pick_list.dart';

/// The completed-list result: the refreshed list plus what it changed.
class CompletedPickList {
  const CompletedPickList(this.list, this.summary);
  final PickList list;
  final PickSummary summary;
}

/// Picking over the `picking` edge function. Nothing here moves stock — a
/// pick list only records what left the shelf; shipping is a separate act
/// (spec §14/§15).
abstract class PickingRepository {
  Future<ApiResult<List<PickList>>> lists({int? warehouseId, String? status});
  Future<ApiResult<PickList>> show(int id);

  /// Opens (or returns) the pick list for one shipment plan.
  Future<ApiResult<PickList>> start(int shipmentPlanId, {String? note});

  Future<ApiResult<PickList>> recordPick(
    int taskId, {
    required int quantity,
    int? binId,
    String? note,
  });

  Future<ApiResult<CompletedPickList>> complete(int pickListId);
  Future<ApiResult<PickList>> cancel(int pickListId);
}

class PickingRepositoryImpl implements PickingRepository {
  PickingRepositoryImpl(this._dio);

  final Dio _dio;

  PickList _list(dynamic body) =>
      PickList.fromJson(((body as Map)['data'] as Map).cast<String, dynamic>());

  @override
  Future<ApiResult<List<PickList>>> lists({int? warehouseId, String? status}) async {
    try {
      final response = await _dio.get('/picking/lists', queryParameters: {
        if (warehouseId != null) 'warehouse_id': warehouseId,
        if (status != null) 'status': status,
      });
      final rows = (response.data as Map)['data'] as List? ?? const [];
      return ApiSuccess(rows
          .whereType<Map>()
          .map((e) => PickList.fromJson(e.cast<String, dynamic>()))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<PickList>>(e);
    }
  }

  @override
  Future<ApiResult<PickList>> show(int id) async {
    try {
      final response = await _dio.get('/picking/lists/$id');
      return ApiSuccess(_list(response.data));
    } on DioException catch (e) {
      return mapDioError<PickList>(e);
    }
  }

  @override
  Future<ApiResult<PickList>> start(int shipmentPlanId, {String? note}) async {
    try {
      final response = await _dio.post('/picking/lists', data: {
        'shipment_plan_id': shipmentPlanId,
        if (note != null && note.isNotEmpty) 'note': note,
      });
      return ApiSuccess(_list(response.data));
    } on DioException catch (e) {
      return mapDioError<PickList>(e);
    }
  }

  @override
  Future<ApiResult<PickList>> recordPick(
    int taskId, {
    required int quantity,
    int? binId,
    String? note,
  }) async {
    try {
      final response = await _dio.patch('/picking/tasks/$taskId', data: {
        'quantity': quantity,
        if (binId != null) 'bin_id': binId,
        if (note != null && note.isNotEmpty) 'note': note,
      });
      return ApiSuccess(_list(response.data));
    } on DioException catch (e) {
      return mapDioError<PickList>(e);
    }
  }

  @override
  Future<ApiResult<CompletedPickList>> complete(int pickListId) async {
    try {
      final response = await _dio.post('/picking/lists/$pickListId/complete');
      final body = response.data as Map;
      return ApiSuccess(CompletedPickList(
        PickList.fromJson((body['data'] as Map).cast<String, dynamic>()),
        PickSummary.fromJson(
            (body['summary'] as Map? ?? const {}).cast<String, dynamic>()),
      ));
    } on DioException catch (e) {
      return mapDioError<CompletedPickList>(e);
    }
  }

  @override
  Future<ApiResult<PickList>> cancel(int pickListId) async {
    try {
      final response = await _dio.post('/picking/lists/$pickListId/cancel');
      return ApiSuccess(_list(response.data));
    } on DioException catch (e) {
      return mapDioError<PickList>(e);
    }
  }
}
