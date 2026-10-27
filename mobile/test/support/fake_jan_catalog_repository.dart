import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/jan_catalog/data/jan_catalog_repository.dart';

/// JAN catalogs (0153) in memory: none unless a test puts some in.
class FakeJanCatalogRepository implements JanCatalogRepository {
  FakeJanCatalogRepository({List<JanCatalog>? catalogs, Map<String, JanCatalogHit>? hits})
      : catalogs = catalogs ?? [],
        hits = hits ?? {};

  final List<JanCatalog> catalogs;
  final Map<String, JanCatalogHit> hits;
  final synced = <String>[];
  final asked = <List<String>>[];

  /// What a sync gives back, else a catalog of 3 JANs.
  ApiResult<JanCatalog>? syncResult;

  @override
  Future<ApiResult<List<JanCatalog>>> list() async => ApiSuccess(List.of(catalogs));

  @override
  Future<ApiResult<JanCatalog>> sync(String url) async {
    synced.add(url);
    final r = syncResult ??
        ApiSuccess(JanCatalog(
            id: catalogs.where((c) => c.url == url).firstOrNull?.id ?? catalogs.length + 1,
            url: url,
            name: 'テスト総合カタログ',
            entryCount: 3,
            pagesRead: 2));
    if (r case ApiSuccess(:final data)) {
      catalogs
        ..removeWhere((c) => c.url == url)
        ..add(data);
    }
    return r;
  }

  @override
  Future<ApiResult<void>> delete(int id) async {
    catalogs.removeWhere((c) => c.id == id);
    return const ApiSuccess(null);
  }

  @override
  Future<ApiResult<Map<String, JanCatalogHit>>> lookup(Iterable<String> jans) async {
    final list = jans.toList();
    asked.add(list);
    return ApiSuccess({
      for (final j in list)
        if (hits[j] != null) j: hits[j]!,
    });
  }
}
