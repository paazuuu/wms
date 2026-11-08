import 'dart:typed_data';

import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/overseas_stock/data/overseas_stock_repository.dart';
import 'package:wms_mobile/features/overseas_stock/domain/overseas_stock.dart';
import 'package:wms_mobile/features/record_notes/data/record_notes_repository.dart';

/// Notes kept in memory, by subject.
class FakeRecordNotesRepository implements RecordNotesRepository {
  final Map<(NoteSubject, int), List<RecordNote>> notes = {};
  final List<(int, String, int)> files = [];
  final List<int> removed = [];
  final List<int> removedFiles = [];
  int _id = 0;
  int _file = 0;

  @override
  Future<ApiResult<List<RecordNote>>> list(NoteSubject subject, int subjectId) async =>
      ApiSuccess([...?notes[(subject, subjectId)]].reversed.toList());

  @override
  Future<ApiResult<int>> write({int? id, required NoteSubject subject, required int subjectId, required String body}) async {
    final list = notes.putIfAbsent((subject, subjectId), () => []);
    if (id == null) {
      final n = RecordNote(id: ++_id, body: body, createdByName: 'テスト担当', createdAt: DateTime(2026, 11, 8, 10));
      list.add(n);
      return ApiSuccess(n.id);
    }
    final i = list.indexWhere((n) => n.id == id);
    list[i] = RecordNote(id: id, body: body, createdByName: list[i].createdByName, files: list[i].files);
    return ApiSuccess(id);
  }

  @override
  Future<ApiResult<bool>> remove(int id) async {
    removed.add(id);
    for (final l in notes.values) {
      l.removeWhere((n) => n.id == id);
    }
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<int>> addFile(int noteId, String fileName, Uint8List bytes) async {
    files.add((noteId, fileName, bytes.length));
    final f = NoteFile(id: ++_file, name: fileName, path: '$noteId/$fileName');
    for (final l in notes.values) {
      final i = l.indexWhere((n) => n.id == noteId);
      if (i >= 0) l[i] = RecordNote(id: noteId, body: l[i].body, createdByName: l[i].createdByName, files: [...l[i].files, f]);
    }
    return ApiSuccess(f.id);
  }

  @override
  Future<ApiResult<bool>> removeFile(int fileId) async {
    removedFiles.add(fileId);
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<Uint8List>> fileBytes(String path) async => ApiSuccess(Uint8List.fromList([1, 2, 3]));
}

/// Sites abroad and their stock, kept in memory.
class FakeOverseasStockRepository implements OverseasStockRepository {
  FakeOverseasStockRepository({List<OverseasSite>? sites}) : siteList = sites ?? [];

  List<OverseasSite> siteList;
  final List<Map<String, dynamic>> saved = [];
  final List<(int, bool)> archived = [];
  final List<Map<String, dynamic>> imported = [];
  final List<int> undone = [];
  final List<String> uploads = [];
  List<OverseasImport> importList = const [];
  OverseasStock stock = const OverseasStock();
  List<OverseasProduct> products = const [];
  final List<String?> queries = [];
  Uint8List kept = Uint8List(0);

  @override
  Future<ApiResult<List<OverseasSite>>> sites({bool includeArchived = false}) async =>
      ApiSuccess([for (final s in siteList) if (includeArchived || !s.archived) s]);

  @override
  Future<ApiResult<int>> saveSite(Map<String, dynamic> site) async {
    saved.add(site);
    final id = site['id'] as int? ?? 100 + saved.length;
    siteList = [...siteList.where((s) => s.id != id), OverseasSite.fromJson({...site, 'id': id})];
    return ApiSuccess(id);
  }

  @override
  Future<ApiResult<bool>> archiveSite(int id, bool archived) async {
    this.archived.add((id, archived));
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<int>> import({
    required int siteId,
    required DateTime asOf,
    required List<OverseasLine> lines,
    String readBy = 'sheet',
    String? fileName,
    String? storagePath,
    int? fileSize,
    String? fingerprint,
    String? sheetName,
    Map<String, String>? columns,
    String? note,
  }) async {
    imported.add({
      'site': siteId,
      'as_of': asOf,
      'lines': lines,
      'read_by': readBy,
      'file_name': fileName,
      'path': storagePath,
      'sheet': sheetName,
      'columns': columns,
    });
    stock = OverseasStock(
      import: OverseasImport(id: 9, asOf: asOf, fileName: fileName, storagePath: storagePath, readBy: readBy,
          lineCount: lines.length, units: lines.fold<num>(0, (a, l) => a + l.quantity)),
      lines: lines,
    );
    return const ApiSuccess(9);
  }

  @override
  Future<ApiResult<List<OverseasImport>>> imports(int siteId) async => ApiSuccess(importList);

  @override
  Future<ApiResult<bool>> undo(int importId) async {
    undone.add(importId);
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<OverseasStock>> lines({int? importId, int? siteId}) async => ApiSuccess(stock);

  @override
  Future<ApiResult<List<OverseasProduct>>> overview({String? query}) async {
    queries.add(query);
    return ApiSuccess(products);
  }

  @override
  Future<ApiResult<String>> upload(int siteId, String fileName, Uint8List bytes) async {
    uploads.add(fileName);
    return ApiSuccess('$siteId/1-$fileName');
  }

  @override
  Future<ApiResult<Uint8List>> fileBytes(String storagePath) async => ApiSuccess(kept);

  final Map<int, String> readPaths = {};

  @override
  Future<ApiResult<bool>> setReadPath(int id, String path) async {
    readPaths[id] = path;
    return const ApiSuccess(true);
  }
}
