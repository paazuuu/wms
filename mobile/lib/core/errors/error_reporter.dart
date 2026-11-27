import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'client_info_io.dart' if (dart.library.js_interop) 'client_info_web.dart' as client;

/// エラーログ (0227): errors the app runs into — a request refused or failed,
/// a screen that could not be drawn, an error nothing caught — sent to the
/// server (app_error_log) for the system administrator to look into.
///
/// Nothing is sent until [sender] is set (main does, once signed-in requests
/// can be made); tests never set it. Never throws, never waits on the screen:
/// a report that cannot be sent is kept (at most [_keepMax]) and tried again
/// with the next one.
class ErrorReporter {
  ErrorReporter._();

  static final ErrorReporter instance = ErrorReporter._();

  /// Sends one report; true when the server took it.
  Future<bool> Function(Map<String, dynamic> report)? sender;

  /// The screen open, as the app's router has it (the phone and desktop apps
  /// have no address bar); the browser's address when not set.
  String Function()? place;

  String _placeNow() {
    try {
      final p = place?.call();
      if (p != null && p.isNotEmpty) return p.length > 300 ? p.substring(0, 300) : p;
    } catch (_) {
      // The router not ready yet: the browser's address instead.
    }
    return client.placeNow();
  }

  static const _keepMax = 50;
  static const _sameWithin = Duration(seconds: 30);
  static const _perMinute = 20;

  final _pending = <Map<String, dynamic>>[];
  final _lastSent = <String, DateTime>{};
  final _recent = <DateTime>[];
  bool _sending = false;

  /// Reports made since start, newest last (for tests and the debug console).
  final List<Map<String, dynamic>> made = [];

  /// [kind]: api, flutter or uncaught.
  void report(String kind, String message, {String? detail, String? request, int? status}) {
    final text = message.trim();
    if (text.isEmpty) return;
    final now = DateTime.now();
    final key = '$kind|$request|$status|$text';
    final last = _lastSent[key];
    if (last != null && now.difference(last) < _sameWithin) return;
    _recent.removeWhere((t) => now.difference(t) > const Duration(minutes: 1));
    if (_recent.length >= _perMinute) return;
    _recent.add(now);
    _lastSent[key] = now;
    if (_lastSent.length > 500) _lastSent.remove(_lastSent.keys.first);
    final r = <String, dynamic>{
      'kind': kind,
      'message': _cut(text, 2000),
      if (detail != null && detail.trim().isNotEmpty) 'detail': _cut(detail.trim(), 8000),
      if (request != null) 'request': _cut(request, 300),
      if (status != null) 'status': status,
      'place': _placeNow(),
      'client': _cut([if (kIsWeb) 'web', defaultTargetPlatform.name, client.clientInfo()].where((s) => s.isNotEmpty).join(' / '), 300),
    };
    made.add(r);
    if (made.length > 100) made.removeAt(0);
    if (sender == null) return;
    _pending.add(r);
    if (_pending.length > _keepMax) _pending.removeAt(0);
    unawaited(_flush());
  }

  Future<void> _flush() async {
    final send = sender;
    if (_sending || send == null) return;
    _sending = true;
    try {
      while (_pending.isNotEmpty) {
        final ok = await send(_pending.first).catchError((Object _) => false);
        if (!ok) break;
        _pending.removeAt(0);
      }
    } finally {
      _sending = false;
    }
  }

  /// For tests: forget what was made and kept.
  @visibleForTesting
  void reset() {
    made.clear();
    _pending.clear();
    _lastSent.clear();
    _recent.clear();
    sender = null;
    place = null;
  }

  static String _cut(String s, int max) => s.length <= max ? s : s.substring(0, max);
}

/// The path a request went to, without what follows '?'.
String _pathOf(RequestOptions o) {
  final p = o.path;
  final q = p.indexOf('?');
  return q < 0 ? p : p.substring(0, q);
}

/// What the server said, in its own words (PostgREST, a function, storage).
@visibleForTesting
({String message, String? detail}) serverWords(DioException e) {
  final data = e.response?.data;
  if (data is Map) {
    final m = data['message'] ?? data['error_description'] ?? data['error'] ?? data['msg'];
    final more = [data['details'], data['hint'], data['code']].where((v) => v != null && '$v'.isNotEmpty).join(' / ');
    if (m != null && '$m'.trim().isNotEmpty) return (message: '$m', detail: more.isEmpty ? null : more);
  }
  if (data is String && data.trim().isNotEmpty) return (message: data.trim(), detail: null);
  final status = e.response?.statusCode;
  return (
    message: e.message ?? (status != null ? 'HTTP $status' : e.type.name),
    detail: e.type.name,
  );
}

/// Every request that ends in an error, put on the エラーログ. Added after the
/// sign-in interceptor, so a request it retried and saved is not one. Not:
/// a request cancelled, a sign-in that ran out (401), or the log's own call.
class ErrorLogInterceptor extends Interceptor {
  ErrorLogInterceptor([ErrorReporter? reporter]) : _reporter = reporter ?? ErrorReporter.instance;

  final ErrorReporter _reporter;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final o = err.requestOptions;
    final path = _pathOf(o);
    final status = err.response?.statusCode;
    if (err.type != DioExceptionType.cancel && status != 401 && !path.contains('app_error_log')) {
      final w = serverWords(err);
      _reporter.report('api', w.message, detail: w.detail, request: '${o.method} $path', status: status);
    }
    handler.next(err);
  }
}

/// Screen errors and errors nothing caught, put on the エラーログ as well as
/// shown as before.
void installErrorReporting() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    previous?.call(details);
    ErrorReporter.instance.report(
      'flutter',
      details.exceptionAsString(),
      detail: [
        if (details.context != null) details.context!.toDescription(),
        if (details.library != null) details.library!,
        if (details.stack != null) details.stack.toString(),
      ].join('\n'),
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorReporter.instance.report('uncaught', error.toString(), detail: stack.toString());
    return false;
  };
}
