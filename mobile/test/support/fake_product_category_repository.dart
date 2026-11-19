import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/product/data/product_category_repository.dart';

/// Categories (0218) without a server: the tree given, the paths [paths]
/// says for a JAN, and what was asked and saved kept to look at.
class FakeProductCategoryRepository implements ProductCategoryRepository {
  FakeProductCategoryRepository({this.nodes = const [], this.paths = const {}});

  List<CategoryNode> nodes;
  final Map<String, List<String>> paths;
  final asked = <CategoryAsk>[];
  final applied = <(CategoryAsk, List<String>)>[];
  final set = <(int, List<String>)>[];
  final renamed = <(int, String)>[];

  @override
  Future<ApiResult<List<CategoryNode>>> tree() async => ApiSuccess(nodes);

  @override
  Future<ApiResult<Map<int, List<String>>>> classify(List<CategoryAsk> asks) async {
    asked.addAll(asks);
    return ApiSuccess({
      for (final (i, a) in asks.indexed)
        if (paths[a.jan] case final p?) i: p,
    });
  }

  @override
  Future<ApiResult<int>> apply(List<(CategoryAsk, List<String>)> found) async {
    applied.addAll(found);
    return ApiSuccess(found.length);
  }

  @override
  Future<ApiResult<bool>> setCategory(int productId, List<String> path) async {
    set.add((productId, path));
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<bool>> rename(int id, String name) async {
    renamed.add((id, name));
    return const ApiSuccess(true);
  }
}
