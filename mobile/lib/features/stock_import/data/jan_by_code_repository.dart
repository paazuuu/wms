import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../delivery/application/delivery_providers.dart';
import '../domain/stock_file.dart';

/// A JAN found for a 品番 (0221): where it came from — our products
/// (library), a supplier's code for one (supplier), a maker's catalog.
typedef JanByCode = ({String jan, String source});

/// Many invoices print a maker and a 品番 but no JAN; the JAN is looked for
/// by the 品番. Nothing is written.
abstract class JanByCodeRepository {
  /// By line number, the JAN of each row that has a 品番 and no JAN, where
  /// one (and only one) is found.
  Future<ApiResult<Map<int, JanByCode>>> find(List<ReadRow> rows);

  /// The rows still without a JAN looked up on the web by the AI (0223), a
  /// few at a time; a 品番 not found lately is not asked about again.
  /// [onProgress]: rows asked about so far, of how many.
  Future<ApiResult<Map<int, JanByCode>>> findOnWeb(List<ReadRow> rows,
      {void Function(int done, int total)? onProgress});
}

class JanByCodeRepositoryImpl implements JanByCodeRepository {
  JanByCodeRepositoryImpl(this._rest, this._functions);

  final Dio _rest;
  final Dio _functions;

  /// Rows asked about per call, and calls at once.
  static const _batch = 3, _atOnce = 3;

  @override
  Future<ApiResult<Map<int, JanByCode>>> findOnWeb(List<ReadRow> rows,
      {void Function(int done, int total)? onProgress}) async {
    var asks = [
      for (final r in rows)
        if (r.jan.trim().isEmpty && r.code.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').length >= 3)
          {'index': r.lineNo, 'code': r.code.trim(), if (r.maker.trim().isNotEmpty) 'maker': r.maker.trim(),
           if (r.name.trim().isNotEmpty) 'name': r.name.trim()},
    ];
    if (asks.isEmpty) return const ApiSuccess({});
    try {
      // Looked for lately and not found: not again.
      final m = await _rest.post('/rpc/code_jan_recent_misses', data: {
        'p': [for (final a in asks) {'key': a['index'], 'code': a['code'], 'maker': a['maker']}],
      });
      final missed = {for (final k in (m.data is List ? m.data as List : const [])) (k as num).toInt()};
      asks = [for (final a in asks) if (!missed.contains(a['index'])) a].take(60).toList();
    } on DioException catch (e) {
      return mapDioError(e);
    }
    final out = <int, JanByCode>{};
    var done = 0;
    String? failure;
    final batches = [for (var i = 0; i < asks.length; i += _batch) asks.skip(i).take(_batch).toList()];
    onProgress?.call(0, asks.length);
    for (var i = 0; i < batches.length && failure == null; i += _atOnce) {
      await Future.wait([
        for (final b in batches.skip(i).take(_atOnce))
          () async {
            try {
              final r = await _functions.post('/import-plan',
                  data: {'mode': 'lookup_jans', 'items': b},
                  options: Options(contentType: Headers.jsonContentType, receiveTimeout: const Duration(seconds: 150)));
              final data = ((r.data as Map)['data'] as Map?) ?? const {};
              for (final e in (data['results'] as List? ?? const []).whereType<Map>()) {
                final jan = e['jan']?.toString();
                if (jan != null && jan.isNotEmpty && e['index'] is num) {
                  out[(e['index'] as num).toInt()] = (jan: jan, source: 'web');
                }
              }
              if (data['search_unavailable'] == true) failure ??= 'search_unavailable';
            } on DioException catch (e) {
              failure ??= e.message ?? 'error';
            }
            done += b.length;
            onProgress?.call(done, asks.length);
          }(),
      ]);
    }
    if (out.isEmpty && failure != null) return ApiFailure(message: failure!);
    return ApiSuccess(out);
  }

  @override
  Future<ApiResult<Map<int, JanByCode>>> find(List<ReadRow> rows) async {
    final asks = [
      for (final r in rows)
        if (r.jan.trim().isEmpty && r.code.trim().isNotEmpty)
          {'key': r.lineNo, 'code': r.code.trim(), if (r.maker.trim().isNotEmpty) 'maker': r.maker.trim()},
    ];
    if (asks.isEmpty) return const ApiSuccess({});
    try {
      final r = await _rest.post('/rpc/jans_by_code', data: {'p': asks});
      return ApiSuccess({
        for (final e in (r.data is List ? r.data as List : const []).whereType<Map>())
          if (e['key'] is num && e['jan'] != null)
            (e['key'] as num).toInt(): (jan: '${e['jan']}', source: '${e['source'] ?? ''}'),
      });
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }
}

final janByCodeRepositoryProvider =
    Provider<JanByCodeRepository>((ref) => JanByCodeRepositoryImpl(ref.watch(restDioProvider), ref.watch(deliveryDioProvider)));

/// [rows] with the JANs [found] filled in, each marked so a person checks it
/// beside the original ("jan_by_code:catalog" …); the rest as they were.
List<ReadRow> withJansByCode(List<ReadRow> rows, Map<int, JanByCode> found) => [
      for (final r in rows)
        if (found[r.lineNo] case final f? when r.jan.trim().isEmpty)
          r.copyWith(jan: f.jan, flags: [
            for (final x in r.flags)
              if (x != 'no_jan') x,
            'jan_by_code:${f.source}',
          ])
        else
          r,
    ];

/// Looks up the rows' missing JANs by 品番 and fills them in — what we hold
/// first (library, suppliers' codes, earlier files, catalogs, the web before),
/// then, when [web], the AI on the web for the rest. [rows] as they are where
/// nothing is found or a lookup fails.
Future<List<ReadRow>> fillJansByCode(JanByCodeRepository repo, List<ReadRow> rows,
    {bool web = false, void Function(int done, int total)? onWebProgress}) async {
  var out = rows;
  if (await repo.find(out) case ApiSuccess(:final data) when data.isNotEmpty) out = withJansByCode(out, data);
  if (!web) return out;
  if (await repo.findOnWeb(out, onProgress: onWebProgress) case ApiSuccess(:final data) when data.isNotEmpty) {
    out = withJansByCode(out, data);
  }
  return out;
}
