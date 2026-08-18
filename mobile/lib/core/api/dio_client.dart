import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';

/// Builds the shared [Dio] instance: base URL, timeouts, and an interceptor
/// that attaches the bearer token and clears it on 401.
class DioClient {
  DioClient(this._tokenStorage, {this.onUnauthorized});

  final TokenStorage _tokenStorage;
  final Future<void> Function()? onUnauthorized;

  Dio build() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: {'Accept': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.read();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await _tokenStorage.clear();
            await onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );

    return dio;
  }
}
