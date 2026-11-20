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
}

class JanByCodeRepositoryImpl implements JanByCodeRepository {
  JanByCodeRepositoryImpl(this._rest);

  final Dio _rest;

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
    Provider<JanByCodeRepository>((ref) => JanByCodeRepositoryImpl(ref.watch(restDioProvider)));

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

/// Looks up the rows' missing JANs by 品番 and fills them in; [rows] as they
/// are when nothing is found or the lookup fails.
Future<List<ReadRow>> fillJansByCode(JanByCodeRepository repo, List<ReadRow> rows) async {
  final r = await repo.find(rows);
  return switch (r) {
    ApiSuccess(:final data) when data.isNotEmpty => withJansByCode(rows, data),
    _ => rows,
  };
}
