import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../delivery/application/delivery_providers.dart';
import '../../product/data/spec_lookup.dart';

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
    this.kind = 'icata',
    this.fileName,
  });

  /// icata (a viewer URL, read again monthly) or pdf (read in the browser).
  final String kind;
  final String? fileName;
  bool get isPdf => kind == 'pdf';

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
        kind: j['kind']?.toString() ?? 'icata',
        fileName: j['file_name'] as String?,
      );

  @override
  List<Object?> get props =>
      [id, url, maker, name, published, pageCount, pagesRead, entryCount, syncedAt, syncError, kind, fileName];
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
    this.weightG,
    this.weightSource,
    this.weightText,
    this.weightBasis,
    this.weightUrl,
    this.weightEstimated = false,
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

  /// The weight as it stands (0155): a person's on a product of this JAN
  /// ([weightSource] manual / measured), else the catalog's ('catalog'), else
  /// what the AI found on the web ('ai').
  final double? weightG;
  final String? weightSource;

  /// As printed (11.5g／パック), or the note kept with it.
  final String? weightText;

  /// product, package (梱包込み) or pack (a pack of refills).
  final String? weightBasis;
  final String? weightUrl;

  /// The AI's figure is a guess, with no page behind it.
  final bool weightEstimated;

  /// A JAN its maker's catalog does not list: perhaps read wrong.
  bool get missing => !found && covered;

  /// Nothing yet: the AI may be asked.
  bool get needsWeight => weightG == null;

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
        weightG: (j['weight_g'] as num?)?.toDouble(),
        weightSource: j['weight_source'] as String?,
        weightText: j['weight_text'] as String?,
        weightBasis: j['weight_basis'] as String?,
        weightUrl: j['weight_url'] as String?,
        weightEstimated: j['weight_estimated'] == true,
      );

  JanCatalogHit withWeight(double? g,
          {String? source, String? text, String? basis, String? url, bool estimated = false}) =>
      JanCatalogHit(
        jan: jan,
        found: found,
        covered: covered,
        maker: maker,
        catalogName: catalogName,
        codeHint: codeHint,
        lineText: lineText,
        pageNumber: pageNumber,
        pageUrl: pageUrl,
        weightG: g,
        weightSource: source,
        weightText: text,
        weightBasis: basis,
        weightUrl: url,
        weightEstimated: estimated,
      );

  @override
  List<Object?> get props => [
        jan,
        found,
        covered,
        maker,
        catalogName,
        codeHint,
        lineText,
        pageNumber,
        pageUrl,
        weightG,
        weightSource,
        weightText,
        weightBasis,
        weightUrl,
        weightEstimated,
      ];
}

abstract class JanCatalogRepository {
  Future<ApiResult<List<JanCatalog>>> list();

  /// A viewer catalog read from its first page, 40 pages a call (0157),
  /// [onProgress] told how far.
  Future<ApiResult<JanCatalog>> sync(String url, {void Function(int page, int pages)? onProgress});
  Future<ApiResult<void>> delete(int id);

  /// The catalogs' word on each JAN (13 digits) asked about, with its weight.
  Future<ApiResult<Map<String, JanCatalogHit>>> lookup(Iterable<String> jans);

  /// What the AI found for JANs with no weight, kept apart (0155); products
  /// of those JANs with nothing better take it.
  Future<ApiResult<int>> saveAiWeights(List<AiWeight> found);

  /// A PDF catalog read in the browser: begun (what it had is cleared), its
  /// pages' text sent a few at a time, finished.
  Future<ApiResult<JanCatalog>> pdfStart(PdfCatalogStart start);
  Future<ApiResult<({int entries, int weights})>> pdfPages(int catalogId, List<PdfPageText> pages);
  Future<ApiResult<JanCatalog>> pdfFinish(int catalogId, int pagesRead);
}

/// One JAN's weight as the AI found it.
class AiWeight extends Equatable {
  const AiWeight({
    required this.jan,
    this.weightG,
    this.basis,
    this.sourceUrl,
    this.confidence,
    this.estimated = false,
    this.note,
    this.name,
  });

  final String jan;
  final double? weightG;
  final String? basis;
  final String? sourceUrl;
  final double? confidence;
  final bool estimated;
  final String? note;
  final String? name;

  Map<String, dynamic> toJson() => {
        'jan': jan,
        if (weightG != null) 'weight_g': weightG,
        if (basis != null) 'weight_basis': basis,
        if (sourceUrl != null) 'source_url': sourceUrl,
        if (confidence != null) 'confidence': confidence,
        'estimated': estimated,
        if (note != null) 'note': note,
        if (name != null) 'name': name,
      };

  @override
  List<Object?> get props => [jan, weightG, basis, sourceUrl, confidence, estimated, note, name];
}

/// A PDF catalog about to be read.
class PdfCatalogStart {
  const PdfCatalogStart({
    required this.sha256,
    required this.fileName,
    required this.pageCount,
    this.name,
    this.maker,
    this.url,
  });

  final String sha256;
  final String fileName;
  final int pageCount;
  final String? name;
  final String? maker;

  /// Where it can be opened (for a page link): optional.
  final String? url;

  Map<String, dynamic> toJson() => {
        'sha256': sha256,
        'file_name': fileName,
        'page_count': pageCount,
        if (name != null && name!.trim().isNotEmpty) 'name': name!.trim(),
        if (maker != null && maker!.trim().isNotEmpty) 'maker': maker!.trim(),
        if (url != null && url!.trim().isNotEmpty) 'url': url!.trim(),
      };
}

/// One PDF page's text: its runs, each [x, y (down the page), width, text].
class PdfPageText {
  const PdfPageText({required this.index, required this.items, this.label});

  final int index;
  final String? label;
  final List<List<Object>> items;

  Map<String, dynamic> toJson() => {'index': index, if (label != null) 'label': label, 'items': items};
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
  Future<ApiResult<JanCatalog>> sync(String url, {void Function(int page, int pages)? onProgress}) async {
    try {
      final r = await _functions.post('/jan-catalog/sync', data: {'url': url});
      final id = (((r.data as Map)['data'] as Map)['id'] as num).toInt();
      // 920 pages at 40 a call is 23 calls; a few more is something wrong.
      for (var i = 0; i < 60; i++) {
        final s = await _functions.post('/jan-catalog/step',
            data: {'catalog_id': id}, options: Options(receiveTimeout: const Duration(minutes: 3)));
        final d = ((s.data as Map)['data'] as Map).cast<String, dynamic>();
        final page = (d['page'] as num?)?.toInt() ?? 0, pages = (d['pages'] as num?)?.toInt() ?? 0;
        onProgress?.call(page, pages);
        if (d['done'] == true) {
          final c = d['catalog'];
          if (c is Map) {
            final cat = JanCatalog.fromJson(c.cast<String, dynamic>());
            return cat.entryCount == 0
                ? const ApiFailure(message: 'jan_catalog_empty', statusCode: 422)
                : ApiSuccess(cat);
          }
          return const ApiFailure(message: 'jan_catalog_empty', statusCode: 422);
        }
      }
      return const ApiFailure(message: 'jan_catalog_unreachable: too many steps');
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
      final r = await _rest.post('/rpc/jan_lookup', data: {'p_jans': asked});
      final rows = (r.data as List?) ?? const [];
      return ApiSuccess({
        for (final x in rows)
          if (x is Map) x['jan'].toString(): JanCatalogHit.fromJson(x.cast<String, dynamic>()),
      });
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<int>> saveAiWeights(List<AiWeight> found) async {
    if (found.isEmpty) return const ApiSuccess(0);
    try {
      final r = await _rest.post('/rpc/jan_weight_save', data: {
        'p_items': [for (final f in found) f.toJson()]
      });
      return ApiSuccess((r.data as num?)?.toInt() ?? 0);
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<JanCatalog>> pdfStart(PdfCatalogStart start) async {
    try {
      final r = await _functions.post('/jan-catalog/pdf/start', data: start.toJson());
      return ApiSuccess(JanCatalog.fromJson(((r.data as Map)['data'] as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<({int entries, int weights})>> pdfPages(int catalogId, List<PdfPageText> pages) async {
    try {
      final r = await _functions.post('/jan-catalog/pdf/pages',
          data: {
            'catalog_id': catalogId,
            'pages': [for (final p in pages) p.toJson()]
          },
          options: Options(receiveTimeout: const Duration(minutes: 2)));
      final d = ((r.data as Map)['data'] as Map?) ?? const {};
      return ApiSuccess((entries: (d['entries'] as num?)?.toInt() ?? 0, weights: (d['weights'] as num?)?.toInt() ?? 0));
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<JanCatalog>> pdfFinish(int catalogId, int pagesRead) async {
    try {
      final r =
          await _functions.post('/jan-catalog/pdf/finish', data: {'catalog_id': catalogId, 'pages_read': pagesRead});
      return ApiSuccess(JanCatalog.fromJson(((r.data as Map)['data'] as Map).cast<String, dynamic>()));
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

/// A row whose weight is wanted: its JAN and what the AI is told of it.
typedef WeightAsk = ({String jan, String? maker, String? name, String? code});

/// Weights the catalogs do not give, looked up by the AI on the web (a few
/// at a time), kept apart (jan_weight_save) and given back; [stopped] when
/// the AI's daily limit was reached.
Future<({List<AiWeight> found, bool stopped})> findWeightsWithAi(
    SpecLookupRepository spec, JanCatalogRepository repo, List<WeightAsk> asks) async {
  final found = <AiWeight>[];
  var stopped = false;
  for (var i = 0; i < asks.length && !stopped; i += specLookupBatchSize) {
    final batch = asks.sublist(i, (i + specLookupBatchSize).clamp(0, asks.length));
    final r = await spec.lookupMany([
      for (final a in batch)
        SpecLookupRequest(
          name: [a.name, a.code].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ').trim().isEmpty
              ? a.jan
              : [a.name, a.code].whereType<String>().where((s) => s.trim().isNotEmpty).join(' '),
          maker: a.maker,
          code: a.code,
          jan: a.jan,
        ),
    ]);
    switch (r) {
      case ApiSuccess(:final data):
        for (final (k, res) in data.results.indexed) {
          if (res.errorKind == 'limit') stopped = true;
          if (k >= batch.length || !res.hasWeight) continue;
          found.add(AiWeight(
            jan: batch[k].jan,
            weightG: res.weightG,
            basis: res.weightBasis,
            sourceUrl: res.estimated ? null : res.bestUrl,
            confidence: res.confidence,
            estimated: res.estimated,
            note: res.note,
            name: batch[k].name,
          ));
        }
      case ApiFailure(:final message):
        if (message.contains('limit')) stopped = true;
      // Anything else: these few go unfound, the rest are still asked.
    }
  }
  if (found.isNotEmpty) await repo.saveAiWeights(found);
  return (found: found, stopped: stopped);
}
