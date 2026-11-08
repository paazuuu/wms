import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../../core/export/save_bytes.dart' show mimeTypeFor;
import '../../delivery/application/delivery_providers.dart';

/// Where the notes' files are kept (0207): <note id>/<file>.
const noteFileBucket = 'note-files';

/// What a note is on (0207).
enum NoteSubject {
  wishList('wish_list'),
  overseasSite('overseas_site');

  const NoteSubject(this.wire);
  final String wire;
}

class NoteFile extends Equatable {
  const NoteFile({required this.id, required this.name, required this.path, this.contentType, this.size});

  final int id;
  final String name;
  final String path;
  final String? contentType;
  final int? size;

  factory NoteFile.fromJson(Map<String, dynamic> j) => NoteFile(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: '${j['file_name'] ?? ''}',
        path: '${j['storage_path'] ?? ''}',
        contentType: j['content_type']?.toString(),
        size: (j['byte_size'] as num?)?.toInt(),
      );

  @override
  List<Object?> get props => [id, name, path];
}

/// A note on a record, with its files.
class RecordNote extends Equatable {
  const RecordNote({required this.id, this.body = '', this.createdAt, this.updatedAt, this.createdByName, this.files = const []});

  final int id;
  final String body;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdByName;
  final List<NoteFile> files;

  factory RecordNote.fromJson(Map<String, dynamic> j) => RecordNote(
        id: (j['id'] as num?)?.toInt() ?? 0,
        body: '${j['body'] ?? ''}',
        createdAt: DateTime.tryParse('${j['created_at'] ?? ''}')?.toLocal(),
        updatedAt: DateTime.tryParse('${j['updated_at'] ?? ''}')?.toLocal(),
        createdByName: j['created_by_name']?.toString(),
        files: [for (final f in (j['files'] as List? ?? const []).whereType<Map>()) NoteFile.fromJson(f.cast<String, dynamic>())],
      );

  @override
  List<Object?> get props => [id, body, updatedAt, files];
}

abstract class RecordNotesRepository {
  Future<ApiResult<List<RecordNote>>> list(NoteSubject subject, int subjectId);

  /// A new note ([id] null) or a note's words changed; its id.
  Future<ApiResult<int>> write({int? id, required NoteSubject subject, required int subjectId, required String body});
  Future<ApiResult<bool>> remove(int id);

  /// A file put with note [noteId].
  Future<ApiResult<int>> addFile(int noteId, String fileName, Uint8List bytes);
  Future<ApiResult<bool>> removeFile(int fileId);
  Future<ApiResult<Uint8List>> fileBytes(String path);
}

class RecordNotesRepositoryImpl implements RecordNotesRepository {
  RecordNotesRepositoryImpl(this._rest, this._storage);

  final Dio _rest;
  final Dio _storage;

  Future<ApiResult<T>> _rpc<T>(String name, Map<String, dynamic> body, T Function(Object? data) read) async {
    try {
      final r = await _rest.post('/rpc/$name', data: body);
      return ApiSuccess(read(r.data));
    } on DioException catch (e) {
      return mapDioError<T>(e);
    }
  }

  @override
  Future<ApiResult<List<RecordNote>>> list(NoteSubject subject, int subjectId) =>
      _rpc('record_notes_list', {'p_kind': subject.wire, 'p_subject_id': subjectId}, (d) => [
            for (final r in (d is List ? d : const []).whereType<Map>()) RecordNote.fromJson(r.cast<String, dynamic>()),
          ]);

  @override
  Future<ApiResult<int>> write({int? id, required NoteSubject subject, required int subjectId, required String body}) =>
      _rpc('record_note_write', {'p_id': id, 'p_kind': subject.wire, 'p_subject_id': subjectId, 'p_body': body},
          (d) => (d as num).toInt());

  @override
  Future<ApiResult<bool>> remove(int id) => _rpc('record_note_remove', {'p_id': id}, (d) => d == true);

  @override
  Future<ApiResult<int>> addFile(int noteId, String fileName, Uint8List bytes) async {
    final safe = fileName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
    final path = '$noteId/${DateTime.now().millisecondsSinceEpoch}-$safe';
    final type = mimeTypeFor(fileName);
    try {
      await _storage.post('/object/$noteFileBucket/$path', data: bytes, options: Options(headers: {'Content-Type': type}));
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
    return _rpc('record_note_file_add',
        {'p_note_id': noteId, 'p_path': path, 'p_name': fileName, 'p_type': type, 'p_size': bytes.length},
        (d) => (d as num).toInt());
  }

  @override
  Future<ApiResult<bool>> removeFile(int fileId) => _rpc('record_note_file_remove', {'p_id': fileId}, (d) => d == true);

  @override
  Future<ApiResult<Uint8List>> fileBytes(String path) async {
    try {
      final r = await _storage.get<List<int>>('/object/authenticated/$noteFileBucket/$path',
          options: Options(responseType: ResponseType.bytes));
      return ApiSuccess(Uint8List.fromList(r.data ?? const []));
    } on DioException catch (e) {
      return mapDioError<Uint8List>(e);
    }
  }
}

final recordNotesRepositoryProvider = Provider<RecordNotesRepository>(
    (ref) => RecordNotesRepositoryImpl(ref.watch(restDioProvider), ref.watch(storageDioProvider)));

final recordNotesProvider =
    FutureProvider.autoDispose.family<List<RecordNote>, (NoteSubject, int)>((ref, key) async {
  final r = await ref.watch(recordNotesRepositoryProvider).list(key.$1, key.$2);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});
