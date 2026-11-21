import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../../core/export/save_bytes.dart' show mimeTypeFor;
import '../../delivery/application/delivery_providers.dart';
import '../domain/reading_audit.dart';

/// 読み取り検査 on the server (0224): its own table and bucket, joined to
/// nothing else — products, stock and the rest are never touched. Removing
/// erases a reading and its file for good (the reading-audit function).
const readingAuditBucket = 'reading-audits';

/// What keeping a reading answered: its id (null: nothing to keep) and
/// whether its file is already there.
typedef AuditKept = ({int? id, bool hasFile});

abstract class ReadingAuditRepository {
  /// Keeps [a], or updates the reading with its id (`client_id`).
  Future<ApiResult<AuditKept>> save(ReadingAudit a);

  /// The file read, kept with reading [id] (once).
  Future<ApiResult<bool>> attach(int id, String fileName, Uint8List bytes);

  /// The readings kept, newest first.
  Future<ApiResult<List<ReadingAudit>>> list();

  /// Erased for good, files and all (the reading-audit function); how many.
  Future<ApiResult<int>> remove(List<int> ids);

  Future<ApiResult<Uint8List>> fileBytes(String path);
}

class ReadingAuditRepositoryImpl implements ReadingAuditRepository {
  ReadingAuditRepositoryImpl(this._rest, this._storage, this._functions);

  final Dio _rest;
  final Dio _storage;
  final Dio _functions;

  Future<ApiResult<T>> _rpc<T>(String name, Map<String, dynamic> body, T Function(Object? data) read) async {
    try {
      final r = await _rest.post('/rpc/$name', data: body);
      return ApiSuccess(read(r.data));
    } on DioException catch (e) {
      return mapDioError<T>(e);
    }
  }

  @override
  Future<ApiResult<AuditKept>> save(ReadingAudit a) => _rpc('reading_audit_save', {'p': a.toSave()}, (d) {
        final m = d is Map ? d : const {};
        return (id: (m['id'] as num?)?.toInt(), hasFile: m['has_file'] == true);
      });

  @override
  Future<ApiResult<bool>> attach(int id, String fileName, Uint8List bytes) async {
    final safe = fileName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
    final path = '$id/${DateTime.now().millisecondsSinceEpoch}-$safe';
    final type = mimeTypeFor(fileName);
    try {
      await _storage.post('/object/$readingAuditBucket/$path', data: bytes, options: Options(headers: {'Content-Type': type}));
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
    return _rpc('reading_audit_attach', {'p_id': id, 'p_path': path, 'p_type': type, 'p_size': bytes.length},
        (d) => d == true);
  }

  @override
  Future<ApiResult<List<ReadingAudit>>> list() => _rpc('reading_audits_list', const {'p_limit': 1000}, (d) => [
        for (final r in (d is List ? d : const []).whereType<Map>()) ReadingAudit.fromServer(r.cast<String, dynamic>()),
      ]);

  @override
  Future<ApiResult<int>> remove(List<int> ids) async {
    try {
      final r = await _functions.post('/reading-audit', data: {'ids': ids});
      final m = r.data is Map ? r.data as Map : const {};
      // Erased, or — when a file would not go — at least out of the list.
      final out = {
        for (final v in [...(m['removed'] as List? ?? const []), ...(m['kept'] as List? ?? const [])])
          if (v is num) v.toInt(),
      };
      return ApiSuccess(ids.where(out.contains).length);
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
  }

  @override
  Future<ApiResult<Uint8List>> fileBytes(String path) async {
    try {
      final r = await _storage.get<List<int>>('/object/authenticated/$readingAuditBucket/$path',
          options: Options(responseType: ResponseType.bytes));
      return ApiSuccess(Uint8List.fromList(r.data ?? const []));
    } on DioException catch (e) {
      return mapDioError<Uint8List>(e);
    }
  }
}

final readingAuditRepositoryProvider = Provider<ReadingAuditRepository>(
    (ref) => ReadingAuditRepositoryImpl(
        ref.watch(restDioProvider), ref.watch(storageDioProvider), ref.watch(deliveryDioProvider)));

final readingAuditsProvider = FutureProvider.autoDispose<List<ReadingAudit>>((ref) async =>
    (await ref.watch(readingAuditRepositoryProvider).list())
        .when(success: (d) => d, failure: (f) => throw Exception(f.message)));

/// Keeps readings as the screens make them, in the background: one reading
/// at a time in order (read, then checked), its file uploaded once. A
/// failure here never stops the work on the screen.
class ReadingAuditRecorder {
  ReadingAuditRecorder(this._repo);

  final ReadingAuditRepository _repo;
  final _queue = <String, Future<void>>{};
  final _filed = <String>{};

  Future<void> keep(ReadingAudit a, {Uint8List? bytes}) {
    final next = (_queue[a.id] ?? Future<void>.value()).then((_) => _keep(a, bytes)).catchError((Object _) {});
    _queue[a.id] = next;
    return next;
  }

  Future<void> _keep(ReadingAudit a, Uint8List? bytes) async {
    final r = await _repo.save(a);
    if (r case ApiSuccess(:final data)) {
      final id = data.id;
      if (id == null || data.hasFile || bytes == null || bytes.isEmpty || _filed.contains(a.id)) return;
      _filed.add(a.id);
      final up = await _repo.attach(id, a.fileName, bytes);
      if (up is ApiFailure) _filed.remove(a.id);
    }
  }
}

final readingAuditRecorderProvider =
    Provider<ReadingAuditRecorder>((ref) => ReadingAuditRecorder(ref.watch(readingAuditRepositoryProvider)));

/// A fresh id for one reading.
String newReadingAuditId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);
