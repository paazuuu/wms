import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../delivery/application/delivery_providers.dart';
import '../domain/product.dart';

/// A product to find the name of (0164): its JAN, and what else is known.
class NameAsk extends Equatable {
  const NameAsk({required this.jan, this.maker, this.code, this.name});

  final String jan;
  final String? maker;
  final String? code;
  final String? name;

  Map<String, dynamic> toJson(int index) => {
        'index': index,
        'jan': jan,
        if (maker != null) 'maker': maker,
        if (code != null) 'code': code,
        if (name != null) 'name': name,
      };

  @override
  List<Object?> get props => [jan, maker, code, name];
}

/// The name the web gave for a JAN — or why there is none.
class FoundName extends Equatable {
  const FoundName({
    required this.jan,
    this.name,
    this.series,
    this.maker,
    this.sourceUrl,
    this.confidence,
    this.note,
    this.errorKind,
  });

  final String jan;
  final String? name;
  final String? series;
  final String? maker;
  final String? sourceUrl;
  final double? confidence;
  final String? note;

  /// Set when the lookup itself failed (quota, no key, …): not an answer.
  final String? errorKind;

  factory FoundName.fromJson(Map<String, dynamic> j) => FoundName(
        jan: '${j['jan'] ?? ''}',
        name: j['name'] as String?,
        series: j['series'] as String?,
        maker: j['maker'] as String?,
        sourceUrl: j['source_url'] as String?,
        confidence: (j['confidence'] as num?)?.toDouble(),
        note: j['note'] as String?,
        errorKind: j['error_kind'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'jan': jan,
        'name': name,
        'series': series,
        'maker': maker,
        'source_url': sourceUrl,
        'confidence': confidence,
        'note': note,
      };

  @override
  List<Object?> get props => [jan, name, series, maker, sourceUrl, confidence, note, errorKind];
}

/// The most JANs one lookup call takes.
const nameLookupBatchSize = 5;

abstract class MarketNameRepository {
  /// Up to [nameLookupBatchSize] JANs looked up on the web; nothing saved.
  Future<ApiResult<({List<FoundName> results, bool searchUnavailable})>> lookup(List<NameAsk> asks);

  /// Kept per JAN, and taken onto the products (and 価格台帳 lines) that have
  /// only their 品番 for a name. [applied]: products named.
  Future<ApiResult<({int saved, int applied})>> save(List<FoundName> found);
}

class MarketNameRepositoryImpl implements MarketNameRepository {
  MarketNameRepositoryImpl(this._rest, this._functions);

  final Dio _rest;
  final Dio _functions;

  @override
  Future<ApiResult<({List<FoundName> results, bool searchUnavailable})>> lookup(List<NameAsk> asks) async {
    final asked = asks.take(nameLookupBatchSize).toList();
    try {
      final r = await _functions.post(
        '/import-plan',
        data: {
          'mode': 'lookup_names',
          'items': [for (final (i, a) in asked.indexed) a.toJson(i)],
        },
        options: Options(contentType: Headers.jsonContentType, receiveTimeout: const Duration(seconds: 280)),
      );
      final data = ((r.data as Map)['data'] as Map).cast<String, dynamic>();
      return ApiSuccess((
        results: [
          for (final e in (data['results'] as List? ?? const []).whereType<Map>())
            FoundName.fromJson(e.cast<String, dynamic>()),
        ],
        searchUnavailable: data['search_unavailable'] == true,
      ));
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<({int saved, int applied})>> save(List<FoundName> found) async {
    try {
      final r = await _rest.post('/rpc/jan_name_save', data: {
        'p': [for (final f in found) f.toJson()],
      });
      final m = (r.data as Map?) ?? const {};
      return ApiSuccess((saved: (m['saved'] as num?)?.toInt() ?? 0, applied: (m['applied'] as num?)?.toInt() ?? 0));
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }
}

final marketNameRepositoryProvider = Provider<MarketNameRepository>(
    (ref) => MarketNameRepositoryImpl(ref.watch(restDioProvider), ref.watch(deliveryDioProvider)));

/// What a run of lookups came to: how many asked, how many names found, how
/// many products took one, and what stopped it early (a key, the quota, no
/// web search), if anything.
typedef NameFindOutcome = ({int asked, int found, int applied, String? stoppedBy});

/// Failures after which asking further only fails again.
const _stopKinds = {'quota', 'auth', 'no_key', 'limit', 'search_unavailable'};

/// Names found for [asks], [nameLookupBatchSize] at a time, each batch saved
/// as it comes (an answer without a name too, so the JAN is not asked again;
/// a failed lookup is not saved).
Future<NameFindOutcome> findMarketNames(
  MarketNameRepository repo,
  List<NameAsk> asks, {
  void Function(int done, int total)? onProgress,
}) async {
  var found = 0, applied = 0, done = 0;
  String? stopped;
  for (var i = 0; i < asks.length && stopped == null; i += nameLookupBatchSize) {
    final batch = asks.skip(i).take(nameLookupBatchSize).toList();
    final r = await repo.lookup(batch);
    switch (r) {
      case ApiSuccess(:final data):
        final answers = [for (final f in data.results) if (f.errorKind == null && f.jan.isNotEmpty) f];
        found += answers.where((f) => (f.name ?? '').trim().isNotEmpty).length;
        if (answers.isNotEmpty) {
          final s = await repo.save(answers);
          if (s case ApiSuccess(:final data)) applied += data.applied;
        }
        stopped = data.searchUnavailable
            ? 'search_unavailable'
            : data.results.map((f) => f.errorKind).whereType<String>().where(_stopKinds.contains).firstOrNull;
      case ApiFailure(:final message):
        stopped = message;
    }
    done += batch.length;
    onProgress?.call(done.clamp(0, asks.length), asks.length);
  }
  return (asked: asks.length, found: found, applied: applied, stoppedBy: stopped);
}

/// A product with only its 品番 (or JAN, or nothing) for a name.
bool lacksName(Product p) {
  final name = p.name.trim();
  final code = p.sku?.trim() ?? '';
  return name.isEmpty || name == p.janCode || (code.isNotEmpty && name == code);
}

NameAsk nameAskFor(Product p) => NameAsk(jan: p.janCode, maker: p.maker, code: p.sku, name: p.name);
