import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/pick_wave.dart';

/// What completing or cancelling a wave changed.
class WaveOutcome {
  const WaveOutcome({required this.waveId, required this.status, required this.count});
  final int waveId;
  final String status;

  /// `lists_closed` on complete, `lists_released` on cancel.
  final int count;

  factory WaveOutcome.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) =>
        v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
    return WaveOutcome(
      waveId: asInt(json['wave_id']),
      status: (json['status'] ?? '').toString(),
      count: asInt(json['lists_closed'] ?? json['lists_released'] ?? 0),
    );
  }
}

/// §15's wave picking (0077) — grouping several shipments' pick lists so the
/// same parcel wanted by more than one order becomes one stop on the sheet,
/// not one walk per order. A wave moves no stock and changes nothing about
/// what a pick list means: `record_pick_item`/`complete_pick_list` (picking
/// feature) work on its lists unchanged.
abstract class PickWaveRepository {
  Future<ApiResult<List<PickWave>>> index({int? warehouseId, String? status});
  Future<ApiResult<PickWave>> detail(int id);

  /// Groups [shipmentPlanIds]' pick lists into one wave, opening a list for
  /// any shipment that does not have one yet (idempotent, 0018). Shipments
  /// that cannot join are reported in the result, not fatal.
  Future<ApiResult<CreatePickWaveResult>> create({
    required int warehouseId,
    required List<int> shipmentPlanIds,
    String? code,
    String? assignedTo,
    int priority = 100,
    String? note,
  });

  /// Assigns the wave to [userId], or hands it back to the pool when null.
  Future<ApiResult<PickWave>> assign(int id, {String? userId});

  Future<ApiResult<WaveOutcome>> complete(int id);
  Future<ApiResult<WaveOutcome>> cancel(int id);

  /// The aggregated sheet: one row per place-and-parcel, in picking-rule
  /// order, with what could not be covered reported separately.
  Future<ApiResult<WavePickPlan>> plan(int id);
}

class PickWaveRepositoryImpl implements PickWaveRepository {
  PickWaveRepositoryImpl(this._dio);

  final Dio _dio;

  Map<String, dynamic> _asJson(dynamic data) {
    final json = data is List && data.isNotEmpty ? data.first : data;
    return (json as Map).cast<String, dynamic>();
  }

  @override
  Future<ApiResult<List<PickWave>>> index({int? warehouseId, String? status}) async {
    try {
      final response = await _dio.post('/rpc/pick_wave_index', data: {
        'p_warehouse_id': warehouseId,
        'p_status': status,
      });
      final data = response.data;
      final rows = data is List
          ? (data.length == 1 && data.first is List ? data.first as List : data)
          : const [];
      return ApiSuccess(rows
          .whereType<Map>()
          .map((e) => PickWave.fromJson(e.cast<String, dynamic>()))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<PickWave>>(e);
    }
  }

  @override
  Future<ApiResult<PickWave>> detail(int id) async {
    try {
      final response =
          await _dio.post('/rpc/pick_wave_detail', data: {'p_wave_id': id});
      return ApiSuccess(PickWave.fromJson(_asJson(response.data)));
    } on DioException catch (e) {
      return mapDioError<PickWave>(e);
    }
  }

  @override
  Future<ApiResult<CreatePickWaveResult>> create({
    required int warehouseId,
    required List<int> shipmentPlanIds,
    String? code,
    String? assignedTo,
    int priority = 100,
    String? note,
  }) async {
    try {
      final response = await _dio.post('/rpc/create_pick_wave', data: {
        'p_warehouse_id': warehouseId,
        'p_shipment_plan_ids': shipmentPlanIds,
        'p_code': code,
        'p_assigned_to': assignedTo,
        'p_priority': priority,
        'p_note': note,
      });
      return ApiSuccess(CreatePickWaveResult.fromJson(_asJson(response.data)));
    } on DioException catch (e) {
      return mapDioError<CreatePickWaveResult>(e);
    }
  }

  @override
  Future<ApiResult<PickWave>> assign(int id, {String? userId}) async {
    try {
      final response = await _dio.post('/rpc/assign_pick_wave',
          data: {'p_wave_id': id, 'p_user_id': userId});
      return ApiSuccess(PickWave.fromJson(_asJson(response.data)));
    } on DioException catch (e) {
      return mapDioError<PickWave>(e);
    }
  }

  @override
  Future<ApiResult<WaveOutcome>> complete(int id) async {
    try {
      final response =
          await _dio.post('/rpc/complete_pick_wave', data: {'p_wave_id': id});
      return ApiSuccess(WaveOutcome.fromJson(_asJson(response.data)));
    } on DioException catch (e) {
      return mapDioError<WaveOutcome>(e);
    }
  }

  @override
  Future<ApiResult<WaveOutcome>> cancel(int id) async {
    try {
      final response =
          await _dio.post('/rpc/cancel_pick_wave', data: {'p_wave_id': id});
      return ApiSuccess(WaveOutcome.fromJson(_asJson(response.data)));
    } on DioException catch (e) {
      return mapDioError<WaveOutcome>(e);
    }
  }

  @override
  Future<ApiResult<WavePickPlan>> plan(int id) async {
    try {
      final response =
          await _dio.post('/rpc/wave_pick_plan', data: {'p_wave_id': id});
      return ApiSuccess(WavePickPlan.fromJson(_asJson(response.data)));
    } on DioException catch (e) {
      return mapDioError<WavePickPlan>(e);
    }
  }
}
