import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error_mapper.dart';
import '../../core/api/api_result.dart';
import '../delivery/application/delivery_providers.dart';

/// A note kept for one warehouse (0184), on the day it was written.
class WarehouseMemo extends Equatable {
  const WarehouseMemo({
    required this.id,
    required this.warehouseId,
    required this.body,
    required this.day,
    this.warehouseName,
    this.createdAt,
    this.createdByName,
    this.updatedAt,
    this.updatedByName,
  });

  final int id;
  final int warehouseId;
  final String? warehouseName;
  final String body;

  /// The day it was written, Japan time.
  final DateTime day;
  final DateTime? createdAt;
  final String? createdByName;
  final DateTime? updatedAt;
  final String? updatedByName;

  factory WarehouseMemo.fromJson(Map<String, dynamic> j) {
    int n(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
    String? s(Object? v) => v == null || '$v'.trim().isEmpty ? null : '$v'.trim();
    final d = DateTime.tryParse('${j['day'] ?? ''}') ?? DateTime(2000);
    return WarehouseMemo(
      id: n(j['id']),
      warehouseId: n(j['warehouse_id']),
      warehouseName: s(j['warehouse_name']),
      body: '${j['body'] ?? ''}',
      day: DateTime(d.year, d.month, d.day),
      createdAt: DateTime.tryParse('${j['created_at'] ?? ''}')?.toLocal(),
      createdByName: s(j['created_by_name']),
      updatedAt: DateTime.tryParse('${j['updated_at'] ?? ''}')?.toLocal(),
      updatedByName: s(j['updated_by_name']),
    );
  }

  @override
  List<Object?> get props => [id, warehouseId, body, day, createdAt, updatedAt];
}

/// メモ (0184): notes per warehouse — written, changed, taken away; read by
/// day and searched by their words.
abstract class WarehouseMemosRepository {
  /// [warehouseId] null: every warehouse one may see.
  Future<ApiResult<List<WarehouseMemo>>> list({int? warehouseId, DateTime? from, DateTime? to, String? query});

  /// A new note ([id] null) or that note changed: its id.
  Future<ApiResult<int>> save({int? id, required int warehouseId, required String body});

  Future<ApiResult<bool>> remove(int id);
}

class WarehouseMemosRepositoryImpl implements WarehouseMemosRepository {
  WarehouseMemosRepositoryImpl(this._rest);

  final Dio _rest;

  String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<ApiResult<List<WarehouseMemo>>> list({int? warehouseId, DateTime? from, DateTime? to, String? query}) async {
    try {
      final r = await _rest.post('/rpc/warehouse_memos_list', data: {
        'p_warehouse_id': warehouseId,
        'p_from': from == null ? null : _day(from),
        'p_to': to == null ? null : _day(to),
        'p_query': (query?.trim().isEmpty ?? true) ? null : query!.trim(),
      });
      final d = r.data is List && (r.data as List).isNotEmpty && (r.data as List).first is List ? (r.data as List).first : r.data;
      return ApiSuccess([
        for (final e in (d as List? ?? const []).whereType<Map>()) WarehouseMemo.fromJson(e.cast<String, dynamic>()),
      ]);
    } on DioException catch (e) {
      return mapDioError<List<WarehouseMemo>>(e);
    }
  }

  @override
  Future<ApiResult<int>> save({int? id, required int warehouseId, required String body}) async {
    try {
      final r = await _rest.post('/rpc/warehouse_memo_save', data: {'p_id': id, 'p_warehouse_id': warehouseId, 'p_body': body});
      return ApiSuccess((r.data as num?)?.toInt() ?? 0);
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
  }

  @override
  Future<ApiResult<bool>> remove(int id) async {
    try {
      await _rest.post('/rpc/warehouse_memo_remove', data: {'p_id': id});
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }
}

final warehouseMemosRepositoryProvider =
    Provider<WarehouseMemosRepository>((ref) => WarehouseMemosRepositoryImpl(ref.watch(restDioProvider)));
