import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../delivery/application/delivery_providers.dart';

/// What one product's picture search came to (0166): added, or why not —
/// no page to take it from, the page names no picture, the shop refused.
typedef WebPhotoResult = ({int productId, bool ok, String? reason, String? pageUrl});

/// A product's picture from the web: the page its 商品名 was found on (or a
/// page given), that page's own picture (og:image), added to its photos.
abstract class WebPhotoRepository {
  /// Up to ten products, by id or by JAN; only those with no picture yet,
  /// unless [again] (a person asking for another one) or [pageUrl] is given.
  Future<ApiResult<List<WebPhotoResult>>> find({List<int> productIds, List<String> jans, String? pageUrl, bool again});
}

class WebPhotoRepositoryImpl implements WebPhotoRepository {
  WebPhotoRepositoryImpl(this._functions);

  final Dio _functions;

  @override
  Future<ApiResult<List<WebPhotoResult>>> find(
      {List<int> productIds = const [], List<String> jans = const [], String? pageUrl, bool again = false}) async {
    try {
      final r = await _functions.post('/jan-catalog/photos',
          data: {
            if (productIds.isNotEmpty) 'product_ids': productIds,
            if (jans.isNotEmpty) 'jans': jans,
            if (pageUrl != null) 'page_url': pageUrl,
            if (again) 'again': true,
          },
          options: Options(receiveTimeout: const Duration(minutes: 3)));
      final data = ((r.data as Map)['data'] as Map?) ?? const {};
      return ApiSuccess([
        for (final e in (data['results'] as List? ?? const []).whereType<Map>())
          (
            productId: (e['product_id'] as num?)?.toInt() ?? 0,
            ok: e['ok'] == true,
            reason: e['reason'] as String?,
            pageUrl: e['page_url'] as String?,
          ),
      ]);
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }
}

final webPhotoRepositoryProvider = Provider<WebPhotoRepository>((ref) => WebPhotoRepositoryImpl(ref.watch(deliveryDioProvider)));

/// Pictures for [jans] in tens, meanwhile; how many were added.
Future<int> findWebPhotos(WebPhotoRepository repo, List<String> jans) async {
  var added = 0;
  for (var i = 0; i < jans.length; i += 10) {
    final r = await repo.find(jans: jans.skip(i).take(10).toList());
    if (r case ApiSuccess(:final data)) added += data.where((x) => x.ok).length;
  }
  return added;
}
