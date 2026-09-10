import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/dio_client.dart';
import 'api/supabase_auth_interceptor.dart';
import 'config/app_config.dart';
import 'storage/supabase_session_storage.dart';
import 'storage/token_storage.dart';

/// Core singletons shared across features.

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final dioProvider = Provider<Dio>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  return DioClient(tokenStorage).build();
});

final supabaseSessionStorageProvider =
    Provider<SupabaseSessionStorage>((ref) => SupabaseSessionStorage());

/// Performs the GoTrue refresh-token grant on a bare, interceptor-free Dio —
/// it must not go through [SupabaseAuthInterceptor] itself, or a refresh
/// would try to refresh its own (already-stale) token to authorize itself.
Future<SupabaseSession?> _goTrueRefresh(String refreshToken) async {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.authBaseUrl,
    connectTimeout: AppConfig.connectTimeout,
    receiveTimeout: AppConfig.receiveTimeout,
    headers: {'Accept': 'application/json', 'apikey': AppConfig.supabaseAnonKey},
  ));
  try {
    final response = await dio.post(
      '/token',
      queryParameters: {'grant_type': 'refresh_token'},
      data: {'refresh_token': refreshToken},
    );
    return SupabaseSession.fromGoTrue((response.data as Map).cast<String, dynamic>());
  } on DioException {
    return null;
  }
}

/// One refresher shared by every Supabase-facing Dio client, so a token near
/// expiry is refreshed exactly once even when several requests fire close
/// together — see [SupabaseTokenRefresher] for why sharing matters.
///
/// [onSignedOut] is set by the auth layer once it exists (a plain mutable
/// field rather than a provider dependency, to avoid every Supabase Dio
/// client needing to watch the auth controller just to wire this callback).
final supabaseTokenRefresherProvider = Provider<SupabaseTokenRefresher>((ref) {
  final storage = ref.watch(supabaseSessionStorageProvider);
  return SupabaseTokenRefresher(storage: storage, refresh: _goTrueRefresh);
});
