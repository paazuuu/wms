import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../delivery/application/delivery_providers.dart';

/// How a category path is written: "文房具 > ペン > ボールペン".
const categorySeparator = ' > ';

/// A path typed by a person — "文房具>ペン", "文房具 ＞ ペン", "文房具/ペン" —
/// as its steps.
List<String> parseCategoryPath(String text) => [
      for (final s in text.split(RegExp(r'\s*[>＞/／›]\s*')))
        if (s.trim().isNotEmpty) s.trim(),
    ];

/// One node of the category tree (0218): its path from the top, and how
/// many products sit in it and under it.
class CategoryNode extends Equatable {
  const CategoryNode({required this.id, required this.path, this.parentId, this.products = 0, this.total = 0});

  final int id;
  final int? parentId;
  final List<String> path;
  final int products;
  final int total;

  String get name => path.isEmpty ? '' : path.last;
  int get depth => path.length - 1;
  String get label => path.join(categorySeparator);

  factory CategoryNode.fromJson(Map<String, dynamic> j) => CategoryNode(
        id: (j['id'] as num?)?.toInt() ?? 0,
        parentId: (j['parent_id'] as num?)?.toInt(),
        path: [for (final s in (j['path'] as List? ?? const [])) '$s'],
        products: (j['products'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [id, parentId, path, products, total];
}

/// A product to place in the tree, by its JAN or id.
class CategoryAsk extends Equatable {
  const CategoryAsk({this.jan, this.productId, this.name, this.maker, this.code});

  final String? jan;
  final int? productId;
  final String? name;
  final String? maker;
  final String? code;

  Map<String, dynamic> toJson(int index) => {
        'index': index,
        if (jan != null) 'jan': jan,
        if (name != null) 'name': name,
        if (maker != null) 'maker': maker,
        if (code != null) 'code': code,
      };

  @override
  List<Object?> get props => [jan, productId, name, maker, code];
}

/// The most products one classification call takes.
const categoryBatchSize = 30;

abstract class ProductCategoryRepository {
  Future<ApiResult<List<CategoryNode>>> tree();

  /// Each ask's path, by its index in [asks]; nothing saved.
  Future<ApiResult<Map<int, List<String>>>> classify(List<CategoryAsk> asks);

  /// The AI's paths taken by products with no category or the AI's own
  /// (a person's stays). How many products took one.
  Future<ApiResult<int>> apply(List<(CategoryAsk, List<String>)> found);

  /// A person's category for a product; an empty path takes it off.
  Future<ApiResult<bool>> setCategory(int productId, List<String> path);

  Future<ApiResult<bool>> rename(int id, String name);
}

class ProductCategoryRepositoryImpl implements ProductCategoryRepository {
  ProductCategoryRepositoryImpl(this._rest, this._functions);

  final Dio _rest;
  final Dio _functions;

  @override
  Future<ApiResult<List<CategoryNode>>> tree() async {
    try {
      final r = await _rest.post('/rpc/product_category_tree');
      return ApiSuccess([
        for (final e in (r.data is List ? r.data as List : const []).whereType<Map>())
          CategoryNode.fromJson(e.cast<String, dynamic>()),
      ]);
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<Map<int, List<String>>>> classify(List<CategoryAsk> asks) async {
    try {
      final r = await _functions.post(
        '/import-plan',
        data: {
          'mode': 'classify',
          'items': [for (final (i, a) in asks.take(categoryBatchSize).indexed) a.toJson(i)],
        },
        options: Options(contentType: Headers.jsonContentType, receiveTimeout: const Duration(seconds: 120)),
      );
      final data = ((r.data as Map)['data'] as Map?) ?? const {};
      return ApiSuccess({
        for (final e in (data['results'] as List? ?? const []).whereType<Map>())
          (e['index'] as num).toInt(): [for (final s in (e['path'] as List? ?? const [])) '$s'],
      });
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<int>> apply(List<(CategoryAsk, List<String>)> found) async {
    try {
      final r = await _rest.post('/rpc/product_categories_apply', data: {
        'p': [
          for (final (a, path) in found)
            {
              if (a.productId != null) 'product_id': a.productId else 'jan': a.jan,
              'path': path,
            },
        ],
      });
      return ApiSuccess((r.data as num?)?.toInt() ?? 0);
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<bool>> setCategory(int productId, List<String> path) async {
    try {
      final r = await _rest.post('/rpc/product_set_category',
          data: {'p_product_id': productId, 'p_path': path, 'p_source': 'manual'});
      return ApiSuccess(r.data == true);
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<bool>> rename(int id, String name) async {
    try {
      final r = await _rest.post('/rpc/product_category_rename', data: {'p_id': id, 'p_name': name});
      return ApiSuccess(r.data == true);
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }
}

final productCategoryRepositoryProvider = Provider<ProductCategoryRepository>(
    (ref) => ProductCategoryRepositoryImpl(ref.watch(restDioProvider), ref.watch(deliveryDioProvider)));

final categoryTreeProvider = FutureProvider.autoDispose<List<CategoryNode>>((ref) async =>
    (await ref.watch(productCategoryRepositoryProvider).tree())
        .when(success: (d) => d, failure: (f) => throw Exception(f.message)));

/// What a run of classifications came to.
typedef CategoryRunOutcome = ({int asked, int found, int applied, String? stoppedBy, Map<String, List<String>> byJan});

/// [asks] placed in the tree in batches and saved as they come; stops at
/// the first failure (no key, the day's limit …).
Future<CategoryRunOutcome> classifyAndSave(
  ProductCategoryRepository repo,
  List<CategoryAsk> asks, {
  void Function(int done, int total)? onProgress,
}) async {
  var found = 0, applied = 0, done = 0;
  String? stopped;
  final byJan = <String, List<String>>{};
  for (var i = 0; i < asks.length && stopped == null; i += categoryBatchSize) {
    final batch = asks.skip(i).take(categoryBatchSize).toList();
    final r = await repo.classify(batch);
    switch (r) {
      case ApiSuccess(:final data):
        final pairs = [
          for (final e in data.entries)
            if (e.key >= 0 && e.key < batch.length && e.value.isNotEmpty) (batch[e.key], e.value),
        ];
        found += pairs.length;
        for (final (a, path) in pairs) {
          if (a.jan != null) byJan[a.jan!] = path;
        }
        if (pairs.isNotEmpty) {
          final s = await repo.apply(pairs);
          if (s case ApiSuccess(:final data)) applied += data;
        }
      case ApiFailure(:final message):
        stopped = message;
    }
    done += batch.length;
    onProgress?.call(done.clamp(0, asks.length), asks.length);
  }
  return (asked: asks.length, found: found, applied: applied, stoppedBy: stopped, byJan: byJan);
}
