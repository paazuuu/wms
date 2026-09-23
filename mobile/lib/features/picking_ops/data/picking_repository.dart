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

  /// §16's advice for one task: which parcels to take, in the product's
  /// picking-rule order, and what it cannot cover.
  Future<ApiResult<PickCandidates>> candidatesFor(int taskId);

  /// Records one parcel of what was actually taken (0074) — optional detail
  /// on top of the task's total. Unlike [recordPick], this *adds* a parcel
  /// rather than overwriting the task's picked quantity, so calling it twice
  /// records two parcels, not a corrected total.
  Future<ApiResult<PickList>> recordPickItem(
    int taskId, {
    required int quantity,
    String? lotCode,
    String? serialNumber,
    int? binId,
    int? stockUnitId,
    String? note,
  });

  /// Takes one recorded parcel back. The task's picked quantity is
  /// recomputed as the sum of what remains.
  Future<ApiResult<PickList>> removePickItem(int itemId, {required int pickListId});
}

class PickingRepositoryImpl implements PickingRepository {
  /// [_dio] reaches the `picking` edge function, for the older, list-level
  /// writes (start/complete/cancel/record_pick) that are service_role-only.
  /// [_rest] reaches PostgREST for 0074's newer, directly-`authenticated`
  /// RPCs — the same two-Dio shape `ShipmentRepositoryImpl` uses.
  PickingRepositoryImpl(this._dio, [Dio? rest]) : _rest = rest;

  final Dio _dio;
  final Dio? _rest;

  Dio get _rpc {
    final rest = _rest;
    if (rest == null) {
      throw StateError('PickingRepositoryImpl needs a REST Dio for RPC calls');
    }
    return rest;
  }

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

  @override
  Future<ApiResult<PickCandidates>> candidatesFor(int taskId) async {
    try {
      final response = await _rpc
          .post('/rpc/pick_task_candidates', data: {'p_task_id': taskId});
      final data = response.data;
      final json = data is List && data.isNotEmpty ? data.first : data;
      return ApiSuccess(
          PickCandidates.fromJson((json as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<PickCandidates>(e);
    }
  }

  @override
  Future<ApiResult<PickList>> recordPickItem(
    int taskId, {
    required int quantity,
    String? lotCode,
    String? serialNumber,
    int? binId,
    int? stockUnitId,
    String? note,
  }) async {
    try {
      final response = await _rpc.post('/rpc/record_pick_item', data: {
        'p_task_id': taskId,
        'p_quantity': quantity,
        'p_lot_code': lotCode,
        'p_serial_number': serialNumber,
        'p_bin_id': binId,
        'p_stock_unit_id': stockUnitId,
        'p_note': note,
      });
      final data = response.data;
      final json = (data is List && data.isNotEmpty ? data.first : data) as Map;
      final pickListId = json['pick_list_id'] is int
          ? json['pick_list_id'] as int
          : int.tryParse('${json['pick_list_id']}');
      if (pickListId == null) {
        return const ApiFailure(message: 'record_pick_item did not return a pick_list_id');
      }
      return await show(pickListId);
    } on DioException catch (e) {
      return mapDioError<PickList>(e);
    }
  }

  @override
  Future<ApiResult<PickList>> removePickItem(int itemId, {required int pickListId}) async {
    try {
      await _rpc.post('/rpc/remove_pick_item', data: {'p_item_id': itemId});
      return await show(pickListId);
    } on DioException catch (e) {
      return mapDioError<PickList>(e);
    }
  }
}
