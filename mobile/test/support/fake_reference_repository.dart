import 'dart:convert';
import 'dart:typed_data';

import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/jan_catalog/data/reference_repository.dart';

/// 参照資料 (0160) in memory.
class FakeReferenceRepository implements ReferenceRepository {
  FakeReferenceRepository({List<ReferenceSource>? sources, Map<String, Object>? files})
      : sources = sources ?? [],
        files = files ?? {};

  final List<ReferenceSource> sources;

  /// A kept file's content by path (JSON-able, or a string).
  final Map<String, Object> files;
  final added = <String>[];
  final savedAgain = <int>[];

  @override
  Future<ApiResult<List<ReferenceSource>>> list() async => ApiSuccess(List.of(sources));

  @override
  Future<ApiResult<void>> addSite({required String url, String? title, String? maker, String? note}) async {
    added.add(url);
    sources.add(ReferenceSource(id: 100 + sources.length, kind: 'site', url: url, title: title, note: note));
    return const ApiSuccess(null);
  }

  @override
  Future<ApiResult<void>> saveAgain(int sourceId) async {
    savedAgain.add(sourceId);
    return const ApiSuccess(null);
  }

  @override
  Future<ApiResult<void>> delete(int sourceId) async {
    sources.removeWhere((s) => s.id == sourceId);
    return const ApiSuccess(null);
  }

  @override
  Future<ApiResult<Uint8List>> fileBytes(String path) async {
    final f = files[path];
    if (f == null) return const ApiFailure(message: 'not found', statusCode: 404);
    return ApiSuccess(Uint8List.fromList(utf8.encode(f is String ? f : jsonEncode(f))));
  }

  @override
  Future<ApiResult<String>> signedUrl(String path) async => ApiSuccess('https://example.invalid/$path');
}
