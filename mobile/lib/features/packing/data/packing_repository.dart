import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../../core/export/save_bytes.dart' show mimeTypeFor;
import '../../delivery/application/delivery_providers.dart';
import '../../outbound_file/data/outbound_file_repository.dart' show outboundFileBucket;
import '../domain/packing.dart';
import '../domain/packing_list_reader.dart' show PlField;

int? _ni(Object? v) => v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
double? _nd(Object? v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
String? _s(Object? v) {
  final t = v?.toString().trim();
  return t == null || t.isEmpty ? null : t;
}

/// A packing list kept (0192): the one uploaded as it came and the improved
/// one made from it, or one made here from the boxes.
class PackingListRecord extends Equatable {
  const PackingListRecord({
    required this.id,
    required this.warehouseId,
    required this.source,
    this.warehouseName,
    this.fileId,
    this.fileName,
    this.shippedOn,
    this.originalName,
    this.originalPath,
    this.improvedName,
    this.improvedPath,
    this.boxes,
    this.quantity,
    this.grossKg,
    this.cbm,
    this.note,
    this.createdAt,
    this.createdByName,
  });

  final int id;
  final int warehouseId;
  final String? warehouseName;
  final int? fileId;

  /// The shipping list it belongs to, if any.
  final String? fileName;
  final DateTime? shippedOn;

  /// 'upload' or 'generated'.
  final String source;
  final String? originalName;
  final String? originalPath;
  final String? improvedName;
  final String? improvedPath;
  final int? boxes;
  final int? quantity;
  final double? grossKg;
  final double? cbm;
  final String? note;
  final DateTime? createdAt;
  final String? createdByName;

  bool get uploaded => source == 'upload';

  String get title => originalName ?? improvedName ?? '#$id';

  factory PackingListRecord.fromJson(Map<String, dynamic> j) => PackingListRecord(
        id: _ni(j['id']) ?? 0,
        warehouseId: _ni(j['warehouse_id']) ?? 0,
        warehouseName: _s(j['warehouse_name']),
        fileId: _ni(j['file_id']),
        fileName: _s(j['file_name']),
        shippedOn: DateTime.tryParse('${j['shipped_on'] ?? ''}'),
        source: _s(j['source']) ?? 'upload',
        originalName: _s(j['original_name']),
        originalPath: _s(j['original_path']),
        improvedName: _s(j['improved_name']),
        improvedPath: _s(j['improved_path']),
        boxes: _ni(j['boxes']),
        quantity: _ni(j['quantity']),
        grossKg: _nd(j['gross_kg']),
        cbm: _nd(j['cbm']),
        note: _s(j['note']),
        createdAt: DateTime.tryParse('${j['created_at'] ?? ''}')?.toLocal(),
        createdByName: _s(j['created_by_name']),
      );

  @override
  List<Object?> get props => [id, source, originalPath, improvedPath, boxes, quantity];
}

/// 梱包 (0192): the products' own cases, a shipping list's boxes, and the
/// packing lists kept.
abstract class PackingRepository {
  Future<ApiResult<List<CasePack>>> casePacks();

  /// [source] 'packing_list' (learned) never overwrites one set by hand.
  Future<ApiResult<int>> saveCasePacks(List<CasePack> rows, {String source = 'manual'});

  Future<ApiResult<bool>> retireCasePack(int productId);

  Future<ApiResult<List<PackBox>>> boxes(int fileId);

  /// The boxes of a shipping list, all of them (those before are put aside).
  Future<ApiResult<int>> saveBoxes(int fileId, List<PackBox> boxes);

  /// One box changed on the floor: [fields] of carton_type_id, own_case,
  /// length_cm … gross_kg, note, checked, lines [{id, quantity, checked}].
  Future<ApiResult<bool>> updateBox(int id, Map<String, dynamic> fields);

  Future<ApiResult<int>> addList({
    required int warehouseId,
    required String source,
    int? fileId,
    String? originalName,
    String? originalPath,
    String? improvedName,
    String? improvedPath,
    int? boxes,
    int? quantity,
    double? grossKg,
    double? cbm,
    String? note,
  });

  Future<ApiResult<List<PackingListRecord>>> lists({int? fileId});

  Future<ApiResult<bool>> withdrawList(int id);

  /// A file put in the bucket under the warehouse: its path.
  Future<ApiResult<String>> upload(int warehouseId, String fileName, Uint8List bytes);

  Future<ApiResult<Uint8List>> fileBytes(String path);

  /// What the AI makes of a packing list's headings and a few rows.
  Future<ApiResult<Map<int, PlField>>> aiColumns(List<String> headers, List<List<String>> samples);
}

class PackingRepositoryImpl implements PackingRepository {
  PackingRepositoryImpl(this._rest, this._storage, this._functions);

  final Dio _rest;
  final Dio _storage;
  final Dio _functions;

  dynamic _unwrap(dynamic d) => d is List && d.length == 1 && d.first is List ? d.first : d;

  Future<ApiResult<T>> _call<T>(String rpc, Map<String, dynamic> args, T Function(dynamic) read) async {
    try {
      final r = await _rest.post('/rpc/$rpc', data: args);
      return ApiSuccess(read(r.data));
    } on DioException catch (e) {
      return mapDioError<T>(e);
    }
  }

  @override
  Future<ApiResult<List<CasePack>>> casePacks() => _call('case_packs_list', {}, (d) {
        final l = _unwrap(d);
        return [for (final e in (l as List? ?? const []).whereType<Map>()) CasePack.fromJson(e.cast<String, dynamic>())];
      });

  @override
  Future<ApiResult<int>> saveCasePacks(List<CasePack> rows, {String source = 'manual'}) =>
      _call('case_packs_save', {'p_rows': [for (final r in rows) r.toJson()], 'p_source': source}, (d) => _ni(d) ?? 0);

  @override
  Future<ApiResult<bool>> retireCasePack(int productId) =>
      _call('case_pack_retire', {'p_product_id': productId}, (d) => d == true);

  @override
  Future<ApiResult<List<PackBox>>> boxes(int fileId) => _call('outbound_packing_get', {'p_file_id': fileId}, (d) {
        final m = d is Map ? d : const {};
        return [for (final e in (m['boxes'] as List? ?? const []).whereType<Map>()) PackBox.fromJson(e.cast<String, dynamic>())];
      });

  @override
  Future<ApiResult<int>> saveBoxes(int fileId, List<PackBox> boxes) => _call(
      'outbound_packing_save', {'p_file_id': fileId, 'p_boxes': [for (final b in boxes) b.toJson()]}, (d) => _ni(d) ?? 0);

  @override
  Future<ApiResult<bool>> updateBox(int id, Map<String, dynamic> fields) =>
      _call('outbound_package_update', {'p_id': id, 'p': fields}, (d) => d == true);

  @override
  Future<ApiResult<int>> addList({
    required int warehouseId,
    required String source,
    int? fileId,
    String? originalName,
    String? originalPath,
    String? improvedName,
    String? improvedPath,
    int? boxes,
    int? quantity,
    double? grossKg,
    double? cbm,
    String? note,
  }) =>
      _call(
          'packing_list_add',
          {
            'p_warehouse_id': warehouseId,
            'p_source': source,
            'p_file_id': fileId,
            'p_original_name': originalName,
            'p_original_path': originalPath,
            'p_improved_name': improvedName,
            'p_improved_path': improvedPath,
            'p_boxes': boxes,
            'p_quantity': quantity,
            'p_gross_kg': grossKg,
            'p_cbm': cbm,
            'p_note': note,
          },
          (d) => _ni(d) ?? 0);

  @override
  Future<ApiResult<List<PackingListRecord>>> lists({int? fileId}) =>
      _call('packing_lists_list', {'p_file_id': fileId}, (d) {
        final l = _unwrap(d);
        return [for (final e in (l as List? ?? const []).whereType<Map>()) PackingListRecord.fromJson(e.cast<String, dynamic>())];
      });

  @override
  Future<ApiResult<bool>> withdrawList(int id) => _call('packing_list_withdraw', {'p_id': id}, (d) => d == true);

  @override
  Future<ApiResult<String>> upload(int warehouseId, String fileName, Uint8List bytes) async {
    final safe = fileName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
    final path = '$warehouseId/pl/${DateTime.now().millisecondsSinceEpoch}-$safe';
    try {
      await _storage.post('/object/$outboundFileBucket/$path',
          data: bytes, options: Options(headers: {'Content-Type': mimeTypeFor(fileName)}));
      return ApiSuccess(path);
    } on DioException catch (e) {
      return mapDioError<String>(e);
    }
  }

  @override
  Future<ApiResult<Uint8List>> fileBytes(String path) async {
    try {
      final r = await _storage.get<List<int>>('/object/authenticated/$outboundFileBucket/$path',
          options: Options(responseType: ResponseType.bytes));
      return ApiSuccess(Uint8List.fromList(r.data ?? const []));
    } on DioException catch (e) {
      return mapDioError<Uint8List>(e);
    }
  }

  @override
  Future<ApiResult<Map<int, PlField>>> aiColumns(List<String> headers, List<List<String>> samples) async {
    try {
      final r = await _functions.post('/packing-list', data: {'headers': headers, 'samples': samples});
      final d = r.data is Map ? (r.data as Map)['data'] : null;
      final out = <int, PlField>{};
      for (final c in ((d is Map ? d['columns'] : null) as List? ?? const []).whereType<Map>()) {
        final i = _ni(c['index']);
        final f = PlField.fromWire(_s(c['field']));
        if (i != null && f != null && !out.values.contains(f)) out[i] = f;
      }
      return ApiSuccess(out);
    } on DioException catch (e) {
      return mapDioError<Map<int, PlField>>(e);
    }
  }
}

final packingRepositoryProvider = Provider<PackingRepository>((ref) =>
    PackingRepositoryImpl(ref.watch(restDioProvider), ref.watch(storageDioProvider), ref.watch(deliveryDioProvider)));

final casePacksProvider = FutureProvider.autoDispose<List<CasePack>>((ref) async {
  final r = await ref.watch(packingRepositoryProvider).casePacks();
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

final packingBoxesProvider = FutureProvider.autoDispose.family<List<PackBox>, int>((ref, fileId) async {
  final r = await ref.watch(packingRepositoryProvider).boxes(fileId);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

/// Packing lists kept: for one shipping list, or all lately (null).
final packingListsProvider = FutureProvider.autoDispose.family<List<PackingListRecord>, int?>((ref, fileId) async {
  final r = await ref.watch(packingRepositoryProvider).lists(fileId: fileId);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});
