import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../delivery/application/delivery_providers.dart';
import '../domain/purchase_request.dart';

/// 入荷希望リスト (0140).
abstract class PurchaseRequestRepository {
  /// Every product of 商品マスタ with its stock ([warehouseId], or every
  /// warehouse allowed) and [supplierId]'s names for it.
  Future<ApiResult<List<RequestCandidate>>> candidates({int? warehouseId, int? supplierId});

  Future<ApiResult<RequestSaved>> save({
    int? id,
    int? supplierId,
    int? warehouseId,
    String? title,
    String? note,
    DateTime? replyBy,
    required List<RequestRow> lines,
    Map<String, dynamic>? settings,
  });

  Future<ApiResult<List<PurchaseRequest>>> list();
  Future<ApiResult<PurchaseRequest>> get(int id);
  Future<ApiResult<bool>> remove(int id);
}

class PurchaseRequestRepositoryImpl implements PurchaseRequestRepository {
  PurchaseRequestRepositoryImpl(this._rest);

  final Dio _rest;

  Future<ApiResult<T>> _rpc<T>(String name, Map<String, dynamic> body, T Function(Object? data) read) async {
    try {
      final r = await _rest.post('/rpc/$name', data: body);
      return ApiSuccess(read(r.data));
    } on DioException catch (e) {
      return mapDioError<T>(e);
    }
  }

  static List<Map<String, dynamic>> _rows(Object? d) => [
        for (final e in (d is List ? d : const []).whereType<Map>()) e.cast<String, dynamic>(),
      ];

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<ApiResult<List<RequestCandidate>>> candidates({int? warehouseId, int? supplierId}) =>
      _rpc('request_candidates', {'p_warehouse_id': warehouseId, 'p_supplier_id': supplierId},
          (d) => [for (final r in _rows(d)) RequestCandidate.fromJson(r)]);

  @override
  Future<ApiResult<RequestSaved>> save({
    int? id,
    int? supplierId,
    int? warehouseId,
    String? title,
    String? note,
    DateTime? replyBy,
    required List<RequestRow> lines,
    Map<String, dynamic>? settings,
  }) =>
      _rpc('purchase_request_save', {
        'p': {
          if (id != null) 'id': id,
          'supplier_id': supplierId,
          'warehouse_id': warehouseId,
          'title': title,
          'note': note,
          'reply_by': replyBy == null ? null : _day(replyBy),
          'settings': settings,
          'lines': [for (final l in lines) l.toJson()],
        },
      }, (d) => RequestSaved.fromJson((d as Map).cast<String, dynamic>()));

  @override
  Future<ApiResult<List<PurchaseRequest>>> list() =>
      _rpc('purchase_requests_list', const {'p_limit': 200}, (d) => [for (final r in _rows(d)) PurchaseRequest.fromJson(r)]);

  @override
  Future<ApiResult<PurchaseRequest>> get(int id) =>
      _rpc('purchase_request_get', {'p_id': id}, (d) => PurchaseRequest.fromJson((d as Map).cast<String, dynamic>()));

  @override
  Future<ApiResult<bool>> remove(int id) =>
      _rpc('purchase_request_remove', {'p_id': id}, (d) => d == true || (d is List && d.firstOrNull == true));
}

final purchaseRequestRepositoryProvider =
    Provider<PurchaseRequestRepository>((ref) => PurchaseRequestRepositoryImpl(ref.watch(restDioProvider)));

final purchaseRequestsProvider = FutureProvider.autoDispose<List<PurchaseRequest>>((ref) async {
  final r = await ref.watch(purchaseRequestRepositoryProvider).list();
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});
