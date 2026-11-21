import 'dart:typed_data';

import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/reading_audit/data/reading_audit_repository.dart';
import 'package:wms_mobile/features/reading_audit/domain/reading_audit.dart';

/// 読み取り検査 in memory, as the server keeps it (0224): one per reading,
/// none for a reading with nothing to say, a removed one stays removed.
class FakeReadingAuditRepository implements ReadingAuditRepository {
  FakeReadingAuditRepository([List<ReadingAudit> start = const []]) {
    for (final a in start) {
      final id = a.serverId ?? ++_next;
      _kept[a.id] = a.serverId == null ? _withId(a, id) : a;
    }
  }

  final _kept = <String, ReadingAudit>{};
  final removedIds = <int>{};
  final files = <int, (String, Uint8List)>{};
  int saves = 0;
  int _next = 100;

  /// What the list would show, newest first.
  List<ReadingAudit> get kept => [
        for (final a in _kept.values)
          if (!removedIds.contains(a.serverId) && a.issues.isNotEmpty) a,
      ]..sort((x, y) => y.at.compareTo(x.at));

  ReadingAudit _withId(ReadingAudit a, int id, {String? path, int? size}) => ReadingAudit(
        id: a.id, at: a.at, source: a.source, fileName: a.fileName, byAi: a.byAi, supplier: a.supplier,
        lineCount: a.lineCount, issues: a.issues, serverId: id, filePath: path ?? a.filePath,
        fileSize: size ?? a.fileSize, byName: a.byName ?? 'テスト担当',
      );

  @override
  Future<ApiResult<AuditKept>> save(ReadingAudit a) async {
    saves++;
    final old = _kept[a.id];
    if (old == null) {
      if (a.issues.isEmpty) return const ApiSuccess((id: null, hasFile: false));
      final kept = _withId(a, ++_next);
      _kept[a.id] = kept;
      return ApiSuccess((id: kept.serverId, hasFile: false));
    }
    if (!removedIds.contains(old.serverId)) {
      _kept[a.id] = _withId(a, old.serverId!, path: old.filePath, size: old.fileSize);
    }
    return ApiSuccess((id: old.serverId, hasFile: old.filePath != null));
  }

  @override
  Future<ApiResult<bool>> attach(int id, String fileName, Uint8List bytes) async {
    final e = _kept.entries.where((e) => e.value.serverId == id).firstOrNull;
    if (e == null || e.value.filePath != null) return const ApiSuccess(false);
    files[id] = (fileName, bytes);
    _kept[e.key] = _withId(e.value, id, path: '$id/$fileName', size: bytes.length);
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<List<ReadingAudit>>> list() async => ApiSuccess(kept);

  @override
  Future<ApiResult<int>> remove(List<int> ids) async {
    var n = 0;
    for (final id in ids) {
      if (_kept.values.any((a) => a.serverId == id) && removedIds.add(id)) n++;
    }
    return ApiSuccess(n);
  }

  @override
  Future<ApiResult<Uint8List>> fileBytes(String path) async {
    final id = int.tryParse(path.split('/').first);
    final f = files[id];
    return f == null ? const ApiFailure(message: 'not found') : ApiSuccess(f.$2);
  }
}
