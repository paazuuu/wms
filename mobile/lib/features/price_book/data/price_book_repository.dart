import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/price_book.dart';

/// 価格台帳 (0124), apart from the product master.
abstract class PriceBookRepository {
  Future<ApiResult<List<PriceBookItem>>> list({String? search});

  /// Every term the item has had, newest first per supplier and branch.
  Future<ApiResult<List<PriceBookTerm>>> history(int itemId);

  /// Read lines (import-plan's) into the price book; with [partnerId], their
  /// prices become that supplier's terms for [branch] from [validFrom].
  Future<ApiResult<PriceBookImported>> import(
    List<Map<String, dynamic>> lines, {
    int? partnerId,
    String? branch,
    DateTime? validFrom,
    String? sourceFile,
  });

  /// A term set by hand; resolves to the item's history.
  Future<ApiResult<List<PriceBookTerm>>> addTerm(int itemId, Map<String, dynamic> term);

  /// Items into the product master; resolves to (created, linked, skipped).
  Future<ApiResult<({int created, int linked, int skipped})>> toProducts(List<int> ids);

  /// Removes items from the price book only (their terms go with them).
  Future<ApiResult<int>> delete(List<int> ids);

  /// Master products not in the price book yet (0125).
  Future<ApiResult<List<MasterCandidate>>> masterCandidates({String? search});

  /// Master products into the price book with their spec, pictures and each
  /// supplier's terms; resolves to (created, terms, skipped).
  Future<ApiResult<({int created, int terms, int skipped})>> fromMaster(List<int> productIds);

  /// Corrects an item: only the keys given change (0125).
  Future<ApiResult<bool>> update(int itemId, Map<String, dynamic> fields);
}

String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class PriceBookRepositoryImpl implements PriceBookRepository {
  PriceBookRepositoryImpl(this._rest);

  final Dio _rest;

  dynamic _one(dynamic data) => data is List && data.isNotEmpty && data.first is! Map ? data.first : data;

  List<Map<String, dynamic>> _rows(dynamic data) {
    final raw = data is List && data.length == 1 && data.first is List ? data.first : data;
    return [for (final e in (raw as List? ?? const []).whereType<Map>()) e.cast<String, dynamic>()];
  }

  @override
  Future<ApiResult<List<PriceBookItem>>> list({String? search}) async {
    try {
      final r = await _rest.post('/rpc/price_book_list', data: {'p_search': search});
      return ApiSuccess([for (final e in _rows(r.data)) PriceBookItem.fromJson(e)]);
    } on DioException catch (e) {
      return mapDioError<List<PriceBookItem>>(e);
    }
  }

  @override
  Future<ApiResult<List<PriceBookTerm>>> history(int itemId) async {
    try {
      final r = await _rest.post('/rpc/price_book_term_history', data: {'p_item_id': itemId});
      return ApiSuccess([for (final e in _rows(r.data)) PriceBookTerm.fromJson(e)]);
    } on DioException catch (e) {
      return mapDioError<List<PriceBookTerm>>(e);
    }
  }

  @override
  Future<ApiResult<PriceBookImported>> import(
    List<Map<String, dynamic>> lines, {
    int? partnerId,
    String? branch,
    DateTime? validFrom,
    String? sourceFile,
  }) async {
    try {
      final r = await _rest.post('/rpc/price_book_import', data: {
        'p_lines': lines,
        'p_partner_id': partnerId,
        'p_branch': branch,
        'p_valid_from': validFrom == null ? null : _day(validFrom),
        'p_source_file': sourceFile,
      });
      final j = _one(r.data);
      return ApiSuccess(PriceBookImported.fromJson((j as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<PriceBookImported>(e);
    }
  }

  @override
  Future<ApiResult<List<PriceBookTerm>>> addTerm(int itemId, Map<String, dynamic> term) async {
    try {
      final r = await _rest.post('/rpc/price_book_add_term', data: {'p_item_id': itemId, 'p': term});
      return ApiSuccess([for (final e in _rows(r.data)) PriceBookTerm.fromJson(e)]);
    } on DioException catch (e) {
      return mapDioError<List<PriceBookTerm>>(e);
    }
  }

  @override
  Future<ApiResult<({int created, int linked, int skipped})>> toProducts(List<int> ids) async {
    try {
      final r = await _rest.post('/rpc/price_book_to_products', data: {'p_ids': ids});
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
        '/price_book_items',
        queryParameters: {'id': 'in.(${ids.join(',')})'},
        options: Options(headers: {'Prefer': 'return=representation'}),
      );
      return ApiSuccess(r.data is List ? (r.data as List).length : ids.length);
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
  }

  @override
  Future<ApiResult<List<MasterCandidate>>> masterCandidates({String? search}) async {
    try {
      final r = await _rest.post('/rpc/price_book_master_candidates', data: {'p_search': search});
      return ApiSuccess([for (final e in _rows(r.data)) MasterCandidate.fromJson(e)]);
    } on DioException catch (e) {
      return mapDioError<List<MasterCandidate>>(e);
    }
  }

  @override
  Future<ApiResult<({int created, int terms, int skipped})>> fromMaster(List<int> productIds) async {
    try {
      final r = await _rest.post('/rpc/price_book_from_master', data: {'p_ids': productIds});
      final j = (_one(r.data) as Map).cast<String, dynamic>();
      int n(String k) => (j[k] as num?)?.toInt() ?? 0;
      return ApiSuccess((created: n('created'), terms: n('terms'), skipped: n('skipped')));
    } on DioException catch (e) {
      return mapDioError<({int created, int terms, int skipped})>(e);
    }
  }

  @override
  Future<ApiResult<bool>> update(int itemId, Map<String, dynamic> fields) async {
    try {
      await _rest.post('/rpc/price_book_update_item', data: {'p_id': itemId, 'p': fields});
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }
}
