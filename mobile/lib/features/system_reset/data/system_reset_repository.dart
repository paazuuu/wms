import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../delivery/application/delivery_providers.dart' show deliveryDioProvider, restDioProvider;

/// What is in the environment now, by kind (0175): what a reset would empty.
typedef ResetCounts = Map<String, int>;

/// What can be emptied besides what was done (0175).
class ResetOptions {
  const ResetOptions({this.products = true, this.suppliers = false, this.lookups = false, this.logs = true});

  final bool products;
  final bool suppliers;
  final bool lookups;
  final bool logs;

  ResetOptions copyWith({bool? products, bool? suppliers, bool? lookups, bool? logs}) => ResetOptions(
        products: products ?? this.products,
        suppliers: suppliers ?? this.suppliers,
        lookups: lookups ?? this.lookups,
        logs: logs ?? this.logs,
      );

  Map<String, dynamic> toJson() => {'products': products, 'suppliers': suppliers, 'lookups': lookups, 'logs': logs};
}

/// What a reset did: the counts before and after, and the files removed.
class ResetResult {
  const ResetResult({required this.before, required this.after, this.filesRemoved = 0, this.filesFailed = 0});

  final ResetCounts before;
  final ResetCounts after;
  final int filesRemoved;
  final int filesFailed;

  static ResetCounts countsOf(Object? j) {
    if (j is! Map) return const {};
    final out = <String, int>{};
    for (final e in j.entries) {
      if (e.value is num) out['${e.key}'] = (e.value as num).toInt();
      if (e.value is Map) {
        out['${e.key}'] = (e.value as Map).values.whereType<num>().fold(0, (s, n) => s + n.toInt());
      }
    }
    return out;
  }

  factory ResetResult.fromJson(Map<String, dynamic> j) {
    var removed = 0, failed = 0;
    for (final f in (j['files'] as Map? ?? const {}).values) {
      if (f is Map) {
        removed += (f['removed'] as num?)?.toInt() ?? 0;
        failed += (f['failed'] as num?)?.toInt() ?? (f.containsKey('error') ? 1 : 0);
      }
    }
    return ResetResult(before: countsOf(j['before']), after: countsOf(j['after']), filesRemoved: removed, filesFailed: failed);
  }
}

abstract class SystemResetRepository {
  Future<ApiResult<ResetCounts>> preview();

  /// Empties the environment; [confirm] must be 「初期化」.
  Future<ApiResult<ResetResult>> reset(String confirm, ResetOptions options);
}

class SystemResetRepositoryImpl implements SystemResetRepository {
  SystemResetRepositoryImpl(this._rest, this._functions);

  final Dio _rest;
  final Dio _functions;

  @override
  Future<ApiResult<ResetCounts>> preview() async {
    try {
      final r = await _rest.post('/rpc/system_reset_preview', data: const {});
      return ApiSuccess(ResetResult.countsOf(r.data));
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<ResetResult>> reset(String confirm, ResetOptions options) async {
    try {
      final r = await _functions.post(
        '/system-reset',
        data: {'confirm': confirm, ...options.toJson()},
        options: Options(contentType: Headers.jsonContentType, receiveTimeout: const Duration(seconds: 150)),
      );
      return ApiSuccess(ResetResult.fromJson(((r.data as Map)['data'] as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }
}

final systemResetRepositoryProvider = Provider<SystemResetRepository>(
    (ref) => SystemResetRepositoryImpl(ref.watch(restDioProvider), ref.watch(deliveryDioProvider)));

final systemResetPreviewProvider = FutureProvider.autoDispose<ResetCounts>((ref) async {
  final r = await ref.watch(systemResetRepositoryProvider).preview();
  return switch (r) {
    ApiSuccess(:final data) => data,
    ApiFailure(:final message) => throw Exception(message),
  };
});
