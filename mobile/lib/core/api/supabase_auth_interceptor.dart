import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/supabase_session_storage.dart';

/// Refreshes the stored Supabase session and coalesces concurrent refresh
/// attempts into one network call — shared across every Dio client that
/// talks to Supabase, not per-client, because GoTrue can rotate the refresh
/// token on each use: two clients refreshing the same stale token at once
/// would otherwise race, and the loser's "valid" refresh token would already
/// be dead.
class SupabaseTokenRefresher {
  SupabaseTokenRefresher({
    required this.storage,
    required this.refresh,
    this.onSignedOut,
  });

  final SupabaseSessionStorage storage;
  final Future<SupabaseSession?> Function(String refreshToken) refresh;

  /// Set by the auth layer once it exists, so a dead refresh token (expired
  /// or revoked, not just momentarily stale) drops the app back to the login
  /// screen immediately instead of leaving it authenticated-but-broken until
  /// the next restart's session check.
  Future<void> Function()? onSignedOut;

  Future<SupabaseSession?>? _inFlight;

  /// Returns the session unchanged if it still has headroom, otherwise
  /// refreshes it (or signs out if the refresh itself fails).
  Future<SupabaseSession?> ensureFresh(SupabaseSession session) async {
    if (!session.isExpiring()) return session;
    return force(session);
  }

  /// Refreshes regardless of the session's remaining headroom — used by the
  /// 401 retry path, where the proactive check already said "fresh" but the
  /// server disagreed.
  Future<SupabaseSession?> force(SupabaseSession session) {
    return _inFlight ??= _doRefresh(session);
  }

  Future<SupabaseSession?> _doRefresh(SupabaseSession session) async {
    try {
      final refreshed = await refresh(session.refreshToken);
      if (refreshed != null) {
        await storage.write(refreshed);
        return refreshed;
      }
      await storage.clear();
      await onSignedOut?.call();
      return null;
    } finally {
      _inFlight = null;
    }
  }
}

/// Attaches the signed-in user's Supabase access token to every request on
/// this [Dio], refreshing it first (via the shared [refresher]) when it's
/// about to expire — so PostgREST and the Edge Functions see the real
/// `auth.uid()` instead of the anon key's (which has none). This is what
/// actually activates the RBAC/self-approval checks built throughout the
/// schema.
///
/// Falls back to the anon key alone when signed out (every read RPC already
/// granted to `anon` keeps working exactly as it did before real sign-in).
///
/// Attach with [attachTo] (not `dio.interceptors.add` directly) so the 401
/// retry path can re-issue the request on this same [Dio] instance.
class SupabaseAuthInterceptor extends Interceptor {
  SupabaseAuthInterceptor({required this.storage, required this.refresher});

  final SupabaseSessionStorage storage;
  final SupabaseTokenRefresher refresher;

  Dio? _dio;

  void attachTo(Dio dio) {
    _dio = dio;
    dio.interceptors.add(this);
  }

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final session = await storage.read();
    if (session != null) {
      final fresh = await refresher.ensureFresh(session);
      options.headers['Authorization'] = fresh != null
          // Refresh failed: fall back to the anon key rather than send a
          // token already known to be dead.
          ? 'Bearer ${fresh.accessToken}'
          : 'Bearer ${AppConfig.supabaseAnonKey}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    // Defense in depth: a request that raced ahead of a proactive refresh (or
    // hit clock drift) gets exactly one retry with a forced refresh, replayed
    // on the same Dio instance so the rest of its interceptor chain applies.
    final dio = _dio;
    final response = err.response;
    final request = err.requestOptions;
    if (dio != null &&
        response?.statusCode == 401 &&
        request.extra['sb_retried'] != true) {
      final session = await storage.read();
      if (session != null) {
        final refreshed = await refresher.force(session);
        if (refreshed != null) {
          request.extra['sb_retried'] = true;
          request.headers['Authorization'] = 'Bearer ${refreshed.accessToken}';
          try {
            final result = await dio.fetch(request);
            handler.resolve(result);
            return;
          } catch (_) {
            // Fall through to propagate the original error.
          }
        }
      }
    }
    handler.next(err);
  }
}
