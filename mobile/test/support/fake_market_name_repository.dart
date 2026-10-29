import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/product/data/market_names.dart';

/// 0164's name lookup in memory: [names] is what the web gives per JAN
/// (missing: found nothing); every batch asked and saved is kept.
class FakeMarketNameRepository implements MarketNameRepository {
  FakeMarketNameRepository({this.names = const {}, this.failWith, this.searchUnavailable = false, this.before = const {}});

  final Map<String, String> names;

  /// Answers kept from before (asked earlier), by JAN.
  final Map<String, FoundName> before;
  final String? failWith;
  final bool searchUnavailable;
  final List<List<NameAsk>> asked = [];
  final List<List<FoundName>> saved = [];

  @override
  Future<ApiResult<({List<FoundName> results, bool searchUnavailable})>> lookup(List<NameAsk> asks) async {
    asked.add(asks);
    if (failWith != null) return ApiFailure(message: failWith!);
    return ApiSuccess((
      results: [
        for (final a in asks)
          searchUnavailable
              ? FoundName(jan: a.jan, errorKind: 'search_unavailable')
              : FoundName(jan: a.jan, name: names[a.jan], confidence: names.containsKey(a.jan) ? 0.9 : null),
      ],
      searchUnavailable: searchUnavailable,
    ));
  }

  /// Names typed by hand, by product.
  final setNames = <int, String?>{};

  @override
  Future<ApiResult<void>> setMarketName(int productId, String? name) async {
    setNames[productId] = name;
    return const ApiSuccess(null);
  }

  @override
  Future<ApiResult<Map<String, FoundName>>> cached(List<String> jans) async =>
      ApiSuccess({for (final j in jans) if (before[j] case final f?) j: f});

  @override
  Future<ApiResult<({int saved, int applied})>> save(List<FoundName> found) async {
    saved.add(found);
    return ApiSuccess((saved: found.length, applied: found.where((f) => f.name != null).length));
  }
}
