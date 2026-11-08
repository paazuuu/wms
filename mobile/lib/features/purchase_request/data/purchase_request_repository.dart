import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../../core/export/save_bytes.dart' show mimeTypeFor;
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
    String? customerName,
    int? destinationId,
    DateTime? wantedBy,
  });

  Future<ApiResult<List<PurchaseRequest>>> list();

  /// 完了 ('closed') or open again ('draft') (0205).
  Future<ApiResult<bool>> setStatus(int id, String status);

  /// The open lists added up by product (0205).
  Future<ApiResult<List<WishSummary>>> summary({int? warehouseId});
  Future<ApiResult<PurchaseRequest>> get(int id);
  Future<ApiResult<bool>> remove(int id);

  /// The customer's file put in the bucket (0206): its path.
  Future<ApiResult<String>> upload(String fileName, Uint8List bytes);

  /// The file a list was read from: name, path, size, fingerprint, sheet,
  /// columns.
  Future<ApiResult<bool>> setFile(int id, Map<String, dynamic> file);

  /// A kept file's bytes.
  Future<ApiResult<Uint8List>> fileBytes(String storagePath);
}

/// The bucket the customers' wish lists are kept in (0206).
const wishFileBucket = 'wish-files';

class PurchaseRequestRepositoryImpl implements PurchaseRequestRepository {
  PurchaseRequestRepositoryImpl(this._rest, [this._storage]);

  final Dio _rest;
  final Dio? _storage;

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
    String? customerName,
    int? destinationId,
    DateTime? wantedBy,
  }) =>
      _rpc('purchase_request_save', {
        'p': {
          if (id != null) 'id': id,
          'customer_name': customerName,
          'destination_id': destinationId,
          'wanted_by': wantedBy == null ? null : _day(wantedBy),
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
  Future<ApiResult<bool>> setStatus(int id, String status) =>
      _rpc('purchase_request_set_status', {'p_id': id, 'p_status': status}, (d) => d == true);

  @override
  Future<ApiResult<List<WishSummary>>> summary({int? warehouseId}) => _rpc('purchase_requests_summary',
      {'p_warehouse_id': warehouseId}, (d) => [for (final r in _rows(d)) WishSummary.fromJson(r)]);

  @override
  Future<ApiResult<PurchaseRequest>> get(int id) =>
      _rpc('purchase_request_get', {'p_id': id}, (d) => PurchaseRequest.fromJson((d as Map).cast<String, dynamic>()));

  @override
  Future<ApiResult<bool>> remove(int id) =>
      _rpc('purchase_request_remove', {'p_id': id}, (d) => d == true || (d is List && d.firstOrNull == true));

  @override
  Future<ApiResult<String>> upload(String fileName, Uint8List bytes) async {
    final safe = fileName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
    final path = 'wish/${DateTime.now().millisecondsSinceEpoch}-$safe';
    try {
      await _storage!.post('/object/$wishFileBucket/$path',
          data: bytes, options: Options(headers: {'Content-Type': mimeTypeFor(fileName)}));
      return ApiSuccess(path);
    } on DioException catch (e) {
      return mapDioError<String>(e);
    }
  }

  @override
  Future<ApiResult<bool>> setFile(int id, Map<String, dynamic> file) =>
      _rpc('purchase_request_set_file', {'p_id': id, 'p_file': file}, (d) => d == true);

  @override
  Future<ApiResult<Uint8List>> fileBytes(String storagePath) async {
    try {
      final r = await _storage!.get<List<int>>('/object/authenticated/$wishFileBucket/$storagePath',
          options: Options(responseType: ResponseType.bytes));
      return ApiSuccess(Uint8List.fromList(r.data ?? const []));
    } on DioException catch (e) {
      return mapDioError<Uint8List>(e);
    }
  }
}

final purchaseRequestRepositoryProvider =
    Provider<PurchaseRequestRepository>((ref) => PurchaseRequestRepositoryImpl(ref.watch(restDioProvider), ref.watch(storageDioProvider)));

final purchaseRequestsProvider = FutureProvider.autoDispose<List<PurchaseRequest>>((ref) async {
  final r = await ref.watch(purchaseRequestRepositoryProvider).list();
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

/// The open lists added up by product, for a warehouse or all (0205).
final wishSummaryProvider = FutureProvider.autoDispose.family<List<WishSummary>, int?>((ref, warehouseId) async {
  final r = await ref.watch(purchaseRequestRepositoryProvider).summary(warehouseId: warehouseId);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});
