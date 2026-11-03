import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error_mapper.dart';
import '../../core/api/api_result.dart';
import '../../core/export/save_bytes.dart' show mimeTypeFor;
import '../delivery/application/delivery_providers.dart';

/// The bucket notes' files are kept in (0186), a folder per note.
const memoFileBucket = 'memo-files';

/// Which メモ (0185): a day's on the カレンダー, or the 掲示板's.
enum MemoKind {
  calendar('calendar'),
  board('board');

  const MemoKind(this.wire);
  final String wire;

  static MemoKind fromWire(String? v) => v == 'calendar' ? MemoKind.calendar : MemoKind.board;
}

/// A file kept with a note (0186).
class MemoFile extends Equatable {
  const MemoFile({required this.id, required this.path, required this.name, this.type, this.size, this.uploadedAt, this.uploadedBy});

  final int id;
  final String path;
  final String name;
  final String? type;
  final int? size;
  final DateTime? uploadedAt;
  final String? uploadedBy;

  /// What a browser is given to show it.
  String get contentType => (type ?? '').isNotEmpty ? type! : mimeTypeFor(name);

  bool get isImage => contentType.startsWith('image/');

  factory MemoFile.fromJson(Map<String, dynamic> j) => MemoFile(
        id: (j['id'] as num?)?.toInt() ?? 0,
        path: '${j['path'] ?? ''}',
        name: '${j['name'] ?? ''}',
        type: j['type']?.toString(),
        size: (j['size'] as num?)?.toInt(),
        uploadedAt: DateTime.tryParse('${j['uploaded_at'] ?? ''}')?.toLocal(),
        uploadedBy: j['uploaded_by_name']?.toString(),
      );

  @override
  List<Object?> get props => [id, path, name, type, size];
}

/// A note kept for one warehouse (0184): on a day chosen for the カレンダー,
/// or on the 掲示板 (its day the one it was written).
class WarehouseMemo extends Equatable {
  const WarehouseMemo({
    required this.id,
    required this.warehouseId,
    required this.body,
    required this.day,
    this.kind = MemoKind.board,
    this.warehouseName,
    this.createdAt,
    this.createdByName,
    this.updatedAt,
    this.updatedByName,
    this.files = const [],
  });

  final int id;
  final MemoKind kind;
  final int warehouseId;
  final String? warehouseName;
  final String body;

  /// The day it is on: chosen for the カレンダー, written for the 掲示板.
  final DateTime day;
  final DateTime? createdAt;
  final String? createdByName;
  final DateTime? updatedAt;
  final String? updatedByName;
  final List<MemoFile> files;

  factory WarehouseMemo.fromJson(Map<String, dynamic> j) {
    int n(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
    String? s(Object? v) => v == null || '$v'.trim().isEmpty ? null : '$v'.trim();
    final d = DateTime.tryParse('${j['day'] ?? ''}') ?? DateTime(2000);
    return WarehouseMemo(
      id: n(j['id']),
      kind: MemoKind.fromWire(s(j['kind'])),
      warehouseId: n(j['warehouse_id']),
      warehouseName: s(j['warehouse_name']),
      body: '${j['body'] ?? ''}',
      day: DateTime(d.year, d.month, d.day),
      createdAt: DateTime.tryParse('${j['created_at'] ?? ''}')?.toLocal(),
      createdByName: s(j['created_by_name']),
      updatedAt: DateTime.tryParse('${j['updated_at'] ?? ''}')?.toLocal(),
      updatedByName: s(j['updated_by_name']),
      files: [
        for (final f in (j['files'] as List? ?? const []).whereType<Map>()) MemoFile.fromJson(f.cast<String, dynamic>()),
      ],
    );
  }

  @override
  List<Object?> get props => [id, kind, warehouseId, body, day, createdAt, updatedAt, files];
}

/// メモ (0184–0186): notes per warehouse — on the カレンダー or the 掲示板 —
/// written, changed, taken away, with their files; read by day and found
/// by their words (or their files' names).
abstract class WarehouseMemosRepository {
  /// [warehouseId] null: every warehouse one may see.
  Future<ApiResult<List<WarehouseMemo>>> list(MemoKind kind,
      {int? warehouseId, DateTime? from, DateTime? to, String? query});

  /// A new note ([id] null) or that note changed: its id. [date] is the
  /// カレンダー's day.
  Future<ApiResult<int>> save(
      {int? id, required MemoKind kind, required int warehouseId, required String body, DateTime? date});

  Future<ApiResult<bool>> remove(int id);

  /// A file put with note [memoId].
  Future<ApiResult<bool>> addFile(int memoId, String fileName, Uint8List bytes);

  Future<ApiResult<bool>> removeFile(int fileId);

  /// A file's bytes, to show or save.
  Future<ApiResult<Uint8List>> fileBytes(MemoFile file);
}

class WarehouseMemosRepositoryImpl implements WarehouseMemosRepository {
  WarehouseMemosRepositoryImpl(this._rest, this._storage);

  final Dio _rest;
  final Dio _storage;

  String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<ApiResult<List<WarehouseMemo>>> list(MemoKind kind,
      {int? warehouseId, DateTime? from, DateTime? to, String? query}) async {
    try {
      final r = await _rest.post('/rpc/warehouse_memos_search', data: {
        'p_kind': kind.wire,
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
  Future<ApiResult<int>> save(
      {int? id, required MemoKind kind, required int warehouseId, required String body, DateTime? date}) async {
    try {
      final r = await _rest.post('/rpc/warehouse_memo_write', data: {
        'p_id': id,
        'p_kind': kind.wire,
        'p_warehouse_id': warehouseId,
        'p_body': body,
        'p_memo_date': date == null ? null : _day(date),
      });
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

  @override
  Future<ApiResult<bool>> addFile(int memoId, String fileName, Uint8List bytes) async {
    final safe = fileName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
    final path = '$memoId/${DateTime.now().millisecondsSinceEpoch}-$safe';
    final type = mimeTypeFor(fileName);
    try {
      await _storage.post('/object/$memoFileBucket/$path', data: bytes, options: Options(headers: {'Content-Type': type}));
      await _rest.post('/rpc/warehouse_memo_file_add', data: {
        'p_memo_id': memoId,
        'p_path': path,
        'p_name': fileName,
        'p_type': type,
        'p_size': bytes.length,
      });
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<bool>> removeFile(int fileId) async {
    try {
      await _rest.post('/rpc/warehouse_memo_file_remove', data: {'p_id': fileId});
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<Uint8List>> fileBytes(MemoFile file) async {
    try {
      final r = await _storage.get<List<int>>('/object/authenticated/$memoFileBucket/${file.path}',
          options: Options(responseType: ResponseType.bytes));
      return ApiSuccess(Uint8List.fromList(r.data ?? const []));
    } on DioException catch (e) {
      return mapDioError<Uint8List>(e);
    }
  }
}

final warehouseMemosRepositoryProvider = Provider<WarehouseMemosRepository>(
    (ref) => WarehouseMemosRepositoryImpl(ref.watch(restDioProvider), ref.watch(storageDioProvider)));
