import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../delivery/application/delivery_providers.dart';

/// One error on the エラーログ (0227).
class AppErrorEntry extends Equatable {
  const AppErrorEntry({
    required this.id,
    required this.firstAt,
    required this.lastAt,
    required this.kind,
    required this.message,
    this.times = 1,
    this.detail,
    this.place,
    this.request,
    this.status,
    this.client,
    this.userName,
  });

  final int id;
  final DateTime firstAt;
  final DateTime lastAt;

  /// How often it came, within ten minutes of the last.
  final int times;

  /// api, flutter or uncaught.
  final String kind;
  final String message;
  final String? detail;

  /// The screen open (#/stock-file-import …).
  final String? place;

  /// POST /rpc/… for a request.
  final String? request;
  final int? status;
  final String? client;
  final String? userName;

  factory AppErrorEntry.fromJson(Map<String, dynamic> j) {
    DateTime at(Object? v) => (DateTime.tryParse('${v ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0)).toLocal();
    return AppErrorEntry(
      id: (j['id'] as num?)?.toInt() ?? 0,
      firstAt: at(j['first_at']),
      lastAt: at(j['last_at']),
      times: (j['times'] as num?)?.toInt() ?? 1,
      kind: '${j['kind'] ?? ''}',
      message: '${j['message'] ?? ''}',
      detail: j['detail']?.toString(),
      place: j['place']?.toString(),
      request: j['request']?.toString(),
      status: (j['status'] as num?)?.toInt(),
      client: j['client']?.toString(),
      userName: j['user_name']?.toString(),
    );
  }

  @override
  List<Object?> get props => [id, lastAt, times, kind, message, request, status];
}

abstract class ErrorLogRepository {
  /// The errors of the last [days] days (null: all), newest first.
  Future<ApiResult<List<AppErrorEntry>>> list({int? days});

  /// Erased for good (the app-error-log function): [ids], and/or every
  /// error older than [olderThanDays] days. How many went.
  Future<ApiResult<int>> remove({List<int> ids = const [], int? olderThanDays});
}

class ErrorLogRepositoryImpl implements ErrorLogRepository {
  ErrorLogRepositoryImpl(this._rest, this._functions);

  final Dio _rest;
  final Dio _functions;

  @override
  Future<ApiResult<List<AppErrorEntry>>> list({int? days}) async {
    try {
      final r = await _rest.post('/rpc/app_error_logs_list', data: {'p_days': days, 'p_limit': 2000});
      return ApiSuccess([
        for (final e in (r.data is List ? r.data as List : const []).whereType<Map>())
          AppErrorEntry.fromJson(e.cast<String, dynamic>()),
      ]);
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<int>> remove({List<int> ids = const [], int? olderThanDays}) async {
    try {
      final r = await _functions.post('/app-error-log', data: {
        if (ids.isNotEmpty) 'ids': ids,
        if (olderThanDays != null) 'older_than_days': olderThanDays,
      });
      final m = r.data is Map ? r.data as Map : const {};
      return ApiSuccess((m['removed'] as num?)?.toInt() ?? 0);
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }
}

final errorLogRepositoryProvider = Provider<ErrorLogRepository>(
    (ref) => ErrorLogRepositoryImpl(ref.watch(restDioProvider), ref.watch(deliveryDioProvider)));

/// The errors of the last [days] days (null: all).
final errorLogProvider = FutureProvider.autoDispose.family<List<AppErrorEntry>, int?>((ref, days) async =>
    (await ref.watch(errorLogRepositoryProvider).list(days: days))
        .when(success: (d) => d, failure: (f) => throw Exception(f.message)));
