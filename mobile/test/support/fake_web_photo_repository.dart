import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/product/data/web_photos.dart';

/// 0166's web pictures in memory: [found] products get one; every call kept.
class FakeWebPhotoRepository implements WebPhotoRepository {
  FakeWebPhotoRepository({this.found = const {}, this.kept = const {}});

  final Set<int> found;

  /// JAN → picture link, as kept (0179).
  final Map<String, String> kept;
  final janCalls = <({List<String> jans, bool look})>[];
  final calls = <({List<int> productIds, List<String> jans, String? pageUrl, bool again})>[];

  @override
  Future<ApiResult<List<WebPhotoResult>>> find(
      {List<int> productIds = const [], List<String> jans = const [], String? pageUrl, bool again = false}) async {
    calls.add((productIds: productIds, jans: jans, pageUrl: pageUrl, again: again));
    return ApiSuccess([
      for (final id in productIds) (productId: id, ok: found.contains(id), reason: found.contains(id) ? null : 'no_page', pageUrl: null),
    ]);
  }

  @override
  Future<ApiResult<Map<String, String>>> janPhotos(List<String> jans, {bool look = false}) async {
    janCalls.add((jans: jans, look: look));
    return ApiSuccess({for (final j in jans) if (kept[j] case final u?) j: u});
  }
}
