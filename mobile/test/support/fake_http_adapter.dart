import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A minimal [HttpClientAdapter] test double: no real socket, no dependency
/// beyond `dio` itself. [handler] inspects the outgoing [RequestOptions] and
/// returns the canned response — or throws to simulate a transport failure
/// (Dio wraps a thrown non-DioException in [DioExceptionType.unknown]).
///
/// Recording every call lets a test assert not just the response handling
/// but what was actually sent (path, method, body, headers).
class FakeHttpClientAdapter implements HttpClientAdapter {
  FakeHttpClientAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  final List<RequestOptions> requests = [];

  /// A snapshot of each request's headers *at the moment it was sent* —
  /// unlike [requests], which holds the live [RequestOptions] and so shows
  /// every entry's *final* headers once Dio's 401-retry path mutates and
  /// re-fetches the same object in place.
  final List<Map<String, dynamic>> requestHeaders = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    requestHeaders.add(Map<String, dynamic>.of(options.headers));
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponseBody(Object? data, int statusCode) {
  return ResponseBody.fromString(
    jsonEncode(data),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}
