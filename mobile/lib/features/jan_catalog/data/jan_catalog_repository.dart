import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../delivery/application/delivery_providers.dart';

/// A maker's catalog read for its JAN codes (0153).
class JanCatalog extends Equatable {
  const JanCatalog({
    required this.id,
    required this.url,
    this.maker,
    this.name,
    this.published,
    this.pageCount,
    this.pagesRead = 0,
    this.entryCount = 0,
    this.syncedAt,
    this.syncError,
  });

  final int id;
  final String url;
  final String? maker;
  final String? name;
  final String? published;
  final int? pageCount;
  final int pagesRead;
  final int entryCount;
  final DateTime? syncedAt;
  final String? syncError;

  factory JanCatalog.fromJson(Map<String, dynamic> j) => JanCatalog(
        id: (j['id'] as num).toInt(),
        url: j['url']?.toString() ?? '',
        maker: j['maker'] as String?,
        name: j['name'] as String?,
        published: j['published'] as String?,
        pageCount: (j['page_count'] as num?)?.toInt(),
        pagesRead: (j['pages_read'] as num?)?.toInt() ?? 0,
        entryCount: (j['entry_count'] as num?)?.toInt() ?? 0,
        syncedAt: j['synced_at'] == null ? null : DateTime.tryParse(j['synced_at'].toString())?.toLocal(),
        syncError: j['sync_error'] as String?,
      );

  @override
  List<Object?> get props => [id, url, maker, name, published, pageCount, pagesRead, entryCount, syncedAt, syncError];
}

/// What a catalog says of one JAN: listed (and where), or not — and, when
/// not, whether a catalog of its maker is here at all ([covered]).
class JanCatalogHit extends Equatable {
  const JanCatalogHit({
    required this.jan,
    required this.found,
    required this.covered,
    this.maker,
    this.catalogName,
    this.codeHint,
    this.lineText,
    this.pageNumber,
    this.pageUrl,
  });

  final String jan;
  final bool found;
  final bool covered;
  final String? maker;
  final String? catalogName;

  /// What is printed before the JAN: the 品番, or its end (color, size).
  final String? codeHint;
  final String? lineText;
  final String? pageNumber;
  final String? pageUrl;

  /// A JAN its maker's catalog does not list: perhaps read wrong.
  bool get missing => !found && covered;

  factory JanCatalogHit.fromJson(Map<String, dynamic> j) => JanCatalogHit(
        jan: j['jan']?.toString() ?? '',
        found: j['found'] == true,
        covered: j['covered'] == true,
        maker: j['maker'] as String?,
        catalogName: j['catalog_name'] as String?,
        codeHint: j['code_hint'] as String?,
        lineText: j['line_text'] as String?,
        pageNumber: j['page_number'] as String?,
        pageUrl: j['page_url'] as String?,
      );

  @override
  List<Object?> get props => [jan, found, covered, maker, catalogName, codeHint, lineText, pageNumber, pageUrl];
}

abstract class JanCatalogRepository {
  Future<ApiResult<List<JanCatalog>>> list();
  Future<ApiResult<JanCatalog>> sync(String url);
  Future<ApiResult<void>> delete(int id);

  /// The catalogs' word on each JAN (13 digits) asked about.
  Future<ApiResult<Map<String, JanCatalogHit>>> lookup(Iterable<String> jans);
}

class JanCatalogRepositoryImpl implements JanCatalogRepository {
  JanCatalogRepositoryImpl(this._functions, this._rest);

  final Dio _functions;
  final Dio _rest;

  @override
  Future<ApiResult<List<JanCatalog>>> list() async {
    try {
      final r = await _functions.get('/jan-catalog');
      final rows = ((r.data as Map)['data'] as List?) ?? const [];
      return ApiSuccess([for (final x in rows) JanCatalog.fromJson((x as Map).cast<String, dynamic>())]);
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<JanCatalog>> sync(String url) async {
    try {
      // A whole catalog (300 pages) takes a while to read.
      final r = await _functions.post('/jan-catalog/sync',
          data: {'url': url}, options: Options(receiveTimeout: const Duration(minutes: 3)));
      return ApiSuccess(JanCatalog.fromJson(((r.data as Map)['data'] as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<void>> delete(int id) async {
    try {
      await _functions.delete('/jan-catalog/$id');
      return const ApiSuccess(null);
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<Map<String, JanCatalogHit>>> lookup(Iterable<String> jans) async {
    final asked = {
      for (final j in jans)
        if (RegExp(r'^\d{13}$').hasMatch(j)) j
    }.toList();
    if (asked.isEmpty) return const ApiSuccess({});
    try {
      final r = await _rest.post('/rpc/jan_catalog_lookup', data: {'p_jans': asked});
      final rows = (r.data as List?) ?? const [];
      return ApiSuccess({
        for (final x in rows)
          if (x is Map) x['jan'].toString(): JanCatalogHit.fromJson(x.cast<String, dynamic>()),
      });
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }
}

final janCatalogRepositoryProvider = Provider<JanCatalogRepository>(
    (ref) => JanCatalogRepositoryImpl(ref.watch(deliveryDioProvider), ref.watch(restDioProvider)));

final janCatalogsProvider = FutureProvider.autoDispose<List<JanCatalog>>((ref) async {
  final r = await ref.watch(janCatalogRepositoryProvider).list();
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

/// Looks the JANs up, quietly: no catalog word (or no reach) is an empty map.
Future<Map<String, JanCatalogHit>> lookupJans(JanCatalogRepository repo, Iterable<String> jans) async {
  final r = await repo.lookup(jans);
  return r.when(success: (d) => d, failure: (_) => const {});
}
