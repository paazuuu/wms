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

  /// A name to show and take: found, and the AI sure enough (as the
  /// database takes it, 0164).
  bool get usable => (name ?? '').trim().isNotEmpty && (confidence ?? 0) >= 0.6;

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

  /// What was found before for [jans] (asked before, a name or not).
  Future<ApiResult<Map<String, FoundName>>> cached(List<String> jans);

  /// The 商品名 typed by a person (0166); empty: none again (its 品番 stands
  /// in, so it can be looked up again).
  Future<ApiResult<void>> setMarketName(int productId, String? name);

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
  Future<ApiResult<void>> setMarketName(int productId, String? name) async {
    try {
      await _rest.post('/rpc/set_product_market_name', data: {'p_product_id': productId, 'p_name': name});
      return const ApiSuccess(null);
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<Map<String, FoundName>>> cached(List<String> jans) async {
    final ok = [for (final j in jans.toSet()) if (RegExp(r'^[0-9]{8,14}$').hasMatch(j)) j];
    if (ok.isEmpty) return const ApiSuccess({});
    try {
      final out = <String, FoundName>{};
      for (var i = 0; i < ok.length; i += 100) {
        final r = await _rest.get('/jan_name_lookups', queryParameters: {
          'select': 'jan,name,series,maker,source_url,confidence,note',
          'jan': 'in.(${ok.skip(i).take(100).join(',')})',
        });
        for (final e in (r.data as List? ?? const []).whereType<Map>()) {
          final f = FoundName.fromJson(e.cast<String, dynamic>());
          out[f.jan] = f;
        }
      }
      return ApiSuccess(out);
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
typedef NameFindOutcome = ({int asked, int found, int applied, String? stoppedBy, Map<String, FoundName> answers});

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
  final answers = <String, FoundName>{};
  for (var i = 0; i < asks.length && stopped == null; i += nameLookupBatchSize) {
    final batch = asks.skip(i).take(nameLookupBatchSize).toList();
    final r = await repo.lookup(batch);
    switch (r) {
      case ApiSuccess(:final data):
        found += batchAnswers(answers, data.results);
        final kept = [for (final f in data.results) if (f.errorKind == null && f.jan.isNotEmpty) f];
        if (kept.isNotEmpty) {
          final s = await repo.save(kept);
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
  return (asked: asks.length, found: found, applied: applied, stoppedBy: stopped, answers: answers);
}

/// [results]' answers into [into] (by JAN); how many of them named the item.
int batchAnswers(Map<String, FoundName> into, List<FoundName> results) {
  var named = 0;
  for (final f in results) {
    if (f.errorKind != null || f.jan.isEmpty) continue;
    into[f.jan] = f;
    if (f.usable) named++;
  }
  return named;
}

/// A code as compared (0166): full-width letters and digits made plain,
/// upper case, nothing but letters and digits — so UMR05S.33, UMR05S 33 and
/// ＵＭＲ０５Ｓ－３３ are one code.
String codeKey(String s) => String.fromCharCodes(s.runes.map((c) => c >= 0xFF01 && c <= 0xFF5E ? c - 0xFEE0 : c))
    .toUpperCase()
    .replaceAll(RegExp(r'[^A-Z0-9]'), '');

bool sameCode(String a, String b) {
  final k = codeKey(a);
  return k.isNotEmpty && k == codeKey(b);
}

/// The 商品名 — the name shops show (0164) — when the product has one: its
/// 基本名, else its name; none when that is only its 品番 or JAN.
String? marketNameOf(Product p) {
  bool code(String t) => t.isEmpty || t == p.janCode || (p.sku != null && sameCode(t, p.sku!));
  final b = p.baseName?.trim() ?? '';
  if (b.isNotEmpty) return code(b) ? null : b;
  final n = p.name.trim();
  return code(n) ? null : n;
}

/// A product with only its 品番 (or JAN, or nothing) for a 商品名.
bool lacksName(Product p) => marketNameOf(p) == null;

NameAsk nameAskFor(Product p) => NameAsk(jan: p.janCode, maker: p.maker, code: p.sku, name: p.name);
