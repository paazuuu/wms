import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/product/data/web_photos.dart';

/// 0166's web pictures in memory: [found] products get one; every call kept.
class FakeWebPhotoRepository implements WebPhotoRepository {
  FakeWebPhotoRepository({this.found = const {}});

  final Set<int> found;
  final calls = <({List<int> productIds, List<String> jans, String? pageUrl, bool again})>[];

  @override
  Future<ApiResult<List<WebPhotoResult>>> find(
      {List<int> productIds = const [], List<String> jans = const [], String? pageUrl, bool again = false}) async {
    calls.add((productIds: productIds, jans: jans, pageUrl: pageUrl, again: again));
    return ApiSuccess([
      for (final id in productIds) (productId: id, ok: found.contains(id), reason: found.contains(id) ? null : 'no_page', pageUrl: null),
    ]);
  }
}
