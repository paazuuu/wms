import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/catalog.dart';

/// 商品ライブラリー (0124), apart from the product master.
abstract class CatalogRepository {
  Future<ApiResult<List<CatalogItem>>> list({String? search});

  /// Every term the item has had, newest first per supplier and branch.
  Future<ApiResult<List<CatalogTerm>>> history(int itemId);

  /// Read lines (import-plan's) into the library; with [partnerId], their
  /// prices become that supplier's terms for [branch] from [validFrom].
  Future<ApiResult<CatalogImported>> import(
    List<Map<String, dynamic>> lines, {
    int? partnerId,
    String? branch,
    DateTime? validFrom,
    String? sourceFile,
  });

  /// A term set by hand; resolves to the item's history.
  Future<ApiResult<List<CatalogTerm>>> addTerm(int itemId, Map<String, dynamic> term);

  /// Items into the product master; resolves to (created, linked, skipped).
  Future<ApiResult<({int created, int linked, int skipped})>> toProducts(List<int> ids);

  /// Removes items from the library only (their terms go with them).
  Future<ApiResult<int>> delete(List<int> ids);
}

String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class CatalogRepositoryImpl implements CatalogRepository {
  CatalogRepositoryImpl(this._rest);

  final Dio _rest;

  dynamic _one(dynamic data) => data is List && data.isNotEmpty && data.first is! Map ? data.first : data;

  List<Map<String, dynamic>> _rows(dynamic data) {
    final raw = data is List && data.length == 1 && data.first is List ? data.first : data;
    return [for (final e in (raw as List? ?? const []).whereType<Map>()) e.cast<String, dynamic>()];
  }

  @override
  Future<ApiResult<List<CatalogItem>>> list({String? search}) async {
    try {
      final r = await _rest.post('/rpc/catalog_list', data: {'p_search': search});
      return ApiSuccess([for (final e in _rows(r.data)) CatalogItem.fromJson(e)]);
    } on DioException catch (e) {
      return mapDioError<List<CatalogItem>>(e);
    }
  }

  @override
  Future<ApiResult<List<CatalogTerm>>> history(int itemId) async {
    try {
      final r = await _rest.post('/rpc/catalog_term_history', data: {'p_item_id': itemId});
      return ApiSuccess([for (final e in _rows(r.data)) CatalogTerm.fromJson(e)]);
    } on DioException catch (e) {
      return mapDioError<List<CatalogTerm>>(e);
    }
  }

  @override
  Future<ApiResult<CatalogImported>> import(
    List<Map<String, dynamic>> lines, {
    int? partnerId,
    String? branch,
    DateTime? validFrom,
    String? sourceFile,
  }) async {
    try {
      final r = await _rest.post('/rpc/catalog_import', data: {
        'p_lines': lines,
        'p_partner_id': partnerId,
        'p_branch': branch,
        'p_valid_from': validFrom == null ? null : _day(validFrom),
        'p_source_file': sourceFile,
      });
      final j = _one(r.data);
      return ApiSuccess(CatalogImported.fromJson((j as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<CatalogImported>(e);
    }
  }

  @override
  Future<ApiResult<List<CatalogTerm>>> addTerm(int itemId, Map<String, dynamic> term) async {
    try {
      final r = await _rest.post('/rpc/catalog_add_term', data: {'p_item_id': itemId, 'p': term});
      return ApiSuccess([for (final e in _rows(r.data)) CatalogTerm.fromJson(e)]);
    } on DioException catch (e) {
      return mapDioError<List<CatalogTerm>>(e);
    }
  }

  @override
  Future<ApiResult<({int created, int linked, int skipped})>> toProducts(List<int> ids) async {
    try {
      final r = await _rest.post('/rpc/catalog_to_products', data: {'p_ids': ids});
      final j = (_one(r.data) as Map).cast<String, dynamic>();
      int n(String k) => (j[k] as num?)?.toInt() ?? 0;
      return ApiSuccess((created: n('created'), linked: n('linked'), skipped: n('skipped')));
    } on DioException catch (e) {
      return mapDioError<({int created, int linked, int skipped})>(e);
    }
  }

  @override
  Future<ApiResult<int>> delete(List<int> ids) async {
    if (ids.isEmpty) return const ApiSuccess(0);
    try {
      // A row delete under the table's policy (product.manage); the terms
      // go with the item.
      final r = await _rest.delete(
        '/catalog_items',
        queryParameters: {'id': 'in.(${ids.join(',')})'},
        options: Options(headers: {'Prefer': 'return=representation'}),
      );
      return ApiSuccess(r.data is List ? (r.data as List).length : ids.length);
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
  }
}
