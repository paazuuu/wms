import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/delivery/application/delivery_providers.dart';
import '../api/api_error_mapper.dart';
import '../api/api_result.dart';

/// A measure's verdict (0133): good / warn / bad, or unknown with no data.
enum AiVerdict { good, warn, bad, unknown }

AiVerdict aiVerdict(Object? v) => switch ('$v') {
      'good' => AiVerdict.good,
      'warn' => AiVerdict.warn,
      'bad' => AiVerdict.bad,
      _ => AiVerdict.unknown,
    };

double? _d(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
int _i(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
DateTime? _t(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();

/// One of the four measures `ai_health` judges by, with its thresholds.
class AiMeasure extends Equatable {
  const AiMeasure({
    required this.key,
    required this.value,
    required this.good,
    required this.warn,
    required this.higherIsBetter,
    required this.verdict,
  });

  /// availability / latency_p95 / agreement / totals_match.
  final String key;
  final double? value;
  final double good;
  final double warn;
  final bool higherIsBetter;
  final AiVerdict verdict;

  factory AiMeasure.fromJson(Map<String, dynamic> j) => AiMeasure(
        key: '${j['key']}',
        value: _d(j['value']),
        good: _d(j['good']) ?? 0,
        warn: _d(j['warn']) ?? 0,
        higherIsBetter: j['higher_is_better'] != false,
        verdict: aiVerdict(j['verdict']),
      );

  @override
  List<Object?> get props => [key, value, verdict];
}

class AiCallError extends Equatable {
  const AiCallError({required this.at, this.kind, this.status, this.task, this.message});

  final DateTime? at;
  final String? kind;
  final int? status;
  final String? task;
  final String? message;

  factory AiCallError.fromJson(Map<String, dynamic> j) => AiCallError(
        at: _t(j['called_at']),
        kind: j['error_kind'] as String?,
        status: j['http_status'] is num ? (j['http_status'] as num).toInt() : null,
        task: j['task'] as String?,
        message: j['error'] as String?,
      );

  @override
  List<Object?> get props => [at, kind, status, task, message];
}

/// `ai_health(p_hours)` (0133): is the AI working, and how well.
class AiHealth extends Equatable {
  const AiHealth({
    required this.overall,
    required this.measures,
    this.blocking,
    this.total = 0,
    this.ok = 0,
    this.failed = 0,
    this.p50Ms,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.lastCallAt,
    this.lastOkAt,
    this.files = 0,
    this.aiFiles = 0,
    this.errorsByKind = const {},
    this.recentErrors = const [],
  });

  final AiVerdict overall;

  /// no_key / auth / quota when the last call failed for one of them.
  final String? blocking;
  final List<AiMeasure> measures;
  final int total;
  final int ok;
  final int failed;
  final double? p50Ms;
  final int inputTokens;
  final int outputTokens;
  final DateTime? lastCallAt;
  final DateTime? lastOkAt;
  final int files;
  final int aiFiles;
  final Map<String, int> errorsByKind;
  final List<AiCallError> recentErrors;

  factory AiHealth.fromJson(Map<String, dynamic> j) {
    final calls = (j['calls'] as Map?)?.cast<String, dynamic>() ?? const {};
    final docs = (j['documents'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AiHealth(
      overall: aiVerdict(j['overall']),
      blocking: j['blocking'] as String?,
      measures: [
        for (final m in (j['measures'] as List? ?? const []).whereType<Map>())
          AiMeasure.fromJson(m.cast<String, dynamic>()),
      ],
      total: _i(calls['total']),
      ok: _i(calls['ok']),
      failed: _i(calls['failed']),
      p50Ms: _d(calls['p50_ms']),
      inputTokens: _i(calls['input_tokens']),
      outputTokens: _i(calls['output_tokens']),
      lastCallAt: _t(calls['last_call_at']),
      lastOkAt: _t(calls['last_ok_at']),
      files: _i(docs['files']),
      aiFiles: _i(docs['ai_files']),
      errorsByKind: {
        for (final e in ((j['errors_by_kind'] as Map?) ?? const {}).entries) '${e.key}': _i(e.value),
      },
      recentErrors: [
        for (final e in (j['recent_errors'] as List? ?? const []).whereType<Map>())
          AiCallError.fromJson(e.cast<String, dynamic>()),
      ],
    );
  }

  @override
  List<Object?> get props => [overall, blocking, measures, total, ok, failed, recentErrors];
}

/// 接続テスト's answer.
class AiPingResult extends Equatable {
  const AiPingResult({required this.ok, required this.model, required this.latencyMs, this.errorKind, this.message});

  final bool ok;
  final String model;
  final int latencyMs;
  final String? errorKind;
  final String? message;

  factory AiPingResult.fromJson(Map<String, dynamic> j) => AiPingResult(
        ok: j['ok'] == true,
        model: '${j['model'] ?? ''}',
        latencyMs: _i(j['latency_ms']),
        errorKind: j['error_kind'] as String?,
        message: j['message'] as String?,
      );

  @override
  List<Object?> get props => [ok, model, latencyMs, errorKind];
}

abstract class AiHealthRepository {
  Future<ApiResult<AiHealth>> health(int hours);
  Future<ApiResult<AiPingResult>> ping();
}

class AiHealthRepositoryImpl implements AiHealthRepository {
  AiHealthRepositoryImpl({required Dio rest, required Dio functions})
      : _rest = rest,
        _functions = functions;

  final Dio _rest;
  final Dio _functions;

  @override
  Future<ApiResult<AiHealth>> health(int hours) async {
    try {
      final r = await _rest.post('/rpc/ai_health', data: {'p_hours': hours});
      final m = r.data is List && (r.data as List).isNotEmpty ? (r.data as List).first : r.data;
      return ApiSuccess(AiHealth.fromJson((m as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<AiHealth>(e);
    }
  }

  @override
  Future<ApiResult<AiPingResult>> ping() async {
    try {
      final r = await _functions.post(
        '/import-plan',
        data: {'mode': 'ai_ping'},
        options: Options(contentType: Headers.jsonContentType, receiveTimeout: const Duration(seconds: 60)),
      );
      return ApiSuccess(AiPingResult.fromJson(((r.data as Map)['data'] as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<AiPingResult>(e);
    }
  }
}

final aiHealthRepositoryProvider = Provider<AiHealthRepository>((ref) => AiHealthRepositoryImpl(
      rest: ref.watch(restDioProvider),
      functions: ref.watch(deliveryDioProvider),
    ));

/// The period judged, in hours: 24 h, 7 days (default) or 30 days.
final aiHealthHoursProvider = StateProvider.autoDispose<int>((ref) => 168);

final aiHealthProvider = FutureProvider.autoDispose<AiHealth>((ref) async {
  final hours = ref.watch(aiHealthHoursProvider);
  final r = await ref.watch(aiHealthRepositoryProvider).health(hours);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});
