import 'package:dio/dio.dart';

import '../../../core/api/api_result.dart';
import '../../../core/storage/supabase_session_storage.dart';
import '../domain/auth_user.dart';

/// Authentication against Supabase Auth (GoTrue) — the app's real identity
/// system since 0024's auth bootstrap. Replaces the InventorOS Sanctum login
/// this screen used to call: that was a separate identity system that never
/// touched `auth.uid()`, so none of the schema's RBAC/self-approval checks
/// ever actually engaged even when someone was "logged in" there.
///
/// No self-service sign-up here (asked explicitly): accounts are created by
/// an admin outside the app (Supabase dashboard → Authentication → Add
/// user), and whoever signs in first becomes System Admin automatically —
/// see `bootstrap_first_admin` (0024).
abstract class AuthRepository {
  Future<ApiResult<AuthUser>> login(String email, String password);

  /// Validates the stored session (refreshing first if it's stale) and
  /// returns the current user, or a failure if there is none / it's dead.
  Future<ApiResult<AuthUser>> currentUser();

  Future<void> logout();
}

/// Maps a GoTrue error body — `{msg}`, `{error_description}` or
/// `{error_code, msg}` depending on version — to a readable message. GoTrue's
/// shape doesn't match the Laravel `{message, errors}` convention the shared
/// `mapDioError` expects, so this stays local to the auth feature.
ApiFailure<T> _mapAuthError<T>(DioException error) {
  final data = error.response?.data;
  String message = 'Sign-in failed. Please try again.';
  if (data is Map) {
    final msg = data['msg'] ?? data['error_description'] ?? data['error'];
    if (msg is String && msg.isNotEmpty) message = msg;
  } else if (error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout) {
    message = 'No connection to the server.';
  }
  return ApiFailure<T>(message: message, statusCode: error.response?.statusCode);
}

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._authDio, this._restDio, this._sessionStorage);

  /// GoTrue (`/auth/v1`) — sign-in, refresh, sign-out, current user.
  final Dio _authDio;

  /// PostgREST, used only to call `bootstrap_first_admin`/`my_roles` right
  /// after a session is established. Must be the *same* Dio the app's other
  /// Supabase calls use, so its auth interceptor picks up the session this
  /// login just wrote before these calls fire.
  final Dio _restDio;

  final SupabaseSessionStorage _sessionStorage;

  Future<List<String>> _bootstrapAndFetchRoles() async {
    try {
      await _restDio.post('/rpc/bootstrap_first_admin');
    } on DioException {
      // Non-fatal: if this fails, my_roles() below simply comes back empty
      // and the user sees "no role assigned yet" rather than being blocked
      // from signing in at all.
    }
    try {
      final response = await _restDio.post('/rpc/my_roles');
      final data = response.data;
      final rows = data is List
          ? (data.length == 1 && data.first is List ? data.first as List : data)
          : const [];
      return rows
          .whereType<Map>()
          .map((e) => e['code'] as String? ?? '')
          .where((c) => c.isNotEmpty)
          .toList();
    } on DioException {
      return const [];
    }
  }

  @override
  Future<ApiResult<AuthUser>> login(String email, String password) async {
    try {
      final response = await _authDio.post(
        '/token',
        queryParameters: {'grant_type': 'password'},
        data: {'email': email, 'password': password},
      );
      final body = response.data as Map<String, dynamic>;
      await _sessionStorage.write(SupabaseSession.fromGoTrue(body));

      final userJson = (body['user'] as Map).cast<String, dynamic>();
      final roles = await _bootstrapAndFetchRoles();
      return ApiSuccess(AuthUser.fromGoTrue(userJson, roles: roles));
    } on DioException catch (e) {
      return _mapAuthError<AuthUser>(e);
    }
  }

  @override
  Future<ApiResult<AuthUser>> currentUser() async {
    final session = await _sessionStorage.read();
    if (session == null) {
      return const ApiFailure(message: 'Not signed in', statusCode: 401);
    }
    try {
      // The shared interceptor on _authDio (registered alongside _restDio's)
      // refreshes automatically if the stored session is stale; this call
      // both validates it and confirms the account still exists.
      final response = await _authDio.get('/user');
      final userJson = (response.data as Map).cast<String, dynamic>();
      final roles = await _bootstrapAndFetchRoles();
      return ApiSuccess(AuthUser.fromGoTrue(userJson, roles: roles));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _sessionStorage.clear();
      }
      return _mapAuthError<AuthUser>(e);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _authDio.post('/logout');
    } on DioException catch (_) {
      // Best-effort: clear the local session regardless of whether the
      // server round trip succeeded.
    } finally {
      await _sessionStorage.clear();
    }
  }
}
