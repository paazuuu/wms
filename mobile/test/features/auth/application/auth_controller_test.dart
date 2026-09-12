import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/core/api/supabase_auth_interceptor.dart';
import 'package:wms_mobile/core/storage/supabase_session_storage.dart';
import 'package:wms_mobile/features/auth/application/auth_controller.dart';
import 'package:wms_mobile/features/auth/data/auth_repository.dart';
import 'package:wms_mobile/features/auth/domain/auth_user.dart';

class _InMemoryStore implements SecureKeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// Scriptable [AuthRepository]: each field is consulted once per call so a
/// test can assert both the state transition and that the controller called
/// through with the right arguments.
class _ScriptedAuthRepository implements AuthRepository {
  ApiResult<AuthUser> currentUserResult = const ApiFailure(message: 'Not signed in', statusCode: 401);
  ApiResult<AuthUser> Function(String email, String password)? onLogin;
  bool loggedOut = false;

  @override
  Future<ApiResult<AuthUser>> currentUser() async => currentUserResult;

  @override
  Future<ApiResult<AuthUser>> login(String email, String password) async {
    return onLogin!(email, password);
  }

  @override
  Future<void> logout() async {
    loggedOut = true;
  }
}

const _user = AuthUser(id: 'u1', email: 'a@example.com', name: 'Ada', roles: ['picker']);

void main() {
  late _ScriptedAuthRepository repository;
  late SupabaseTokenRefresher refresher;

  setUp(() {
    repository = _ScriptedAuthRepository();
    refresher = SupabaseTokenRefresher(
      storage: SupabaseSessionStorage(_InMemoryStore()),
      refresh: (_) async => null,
    );
  });

  test('restores to unauthenticated when there is no valid session', () async {
    repository.currentUserResult =
        const ApiFailure(message: 'Not signed in', statusCode: 401);
    final controller = AuthController(repository, refresher);

    await pumpEventQueue();

    expect(controller.state.status, AuthStatus.unauthenticated);
    expect(controller.state.user, isNull);
  });

  test('restores to authenticated when a valid session already exists',
      () async {
    repository.currentUserResult = const ApiSuccess(_user);
    final controller = AuthController(repository, refresher);

    await pumpEventQueue();

    expect(controller.state.status, AuthStatus.authenticated);
    expect(controller.state.user, _user);
  });

  group('login', () {
    test('a successful login authenticates and clears any previous error',
        () async {
      repository.currentUserResult =
          const ApiFailure(message: 'Not signed in', statusCode: 401);
      final controller = AuthController(repository, refresher);
      await pumpEventQueue();

      repository.onLogin = (email, password) {
        expect(email, 'a@example.com');
        expect(password, 'secret');
        return const ApiSuccess(_user);
      };
      final ok = await controller.login('a@example.com', 'secret');

      expect(ok, isTrue);
      expect(controller.state.status, AuthStatus.authenticated);
      expect(controller.state.user, _user);
      expect(controller.state.isSubmitting, isFalse);
      expect(controller.state.error, isNull);
    });

    test('a failed login surfaces the error and stays unauthenticated',
        () async {
      repository.currentUserResult =
          const ApiFailure(message: 'Not signed in', statusCode: 401);
      final controller = AuthController(repository, refresher);
      await pumpEventQueue();

      repository.onLogin = (_, __) =>
          const ApiFailure(message: 'Invalid login credentials', statusCode: 400);
      final ok = await controller.login('a@example.com', 'wrong');

      expect(ok, isFalse);
      expect(controller.state.status, AuthStatus.unauthenticated);
      expect(controller.state.error, 'Invalid login credentials');
      expect(controller.state.isSubmitting, isFalse);
    });
  });

  test('logout calls the repository and resets to a clean unauthenticated state',
      () async {
    repository.currentUserResult = const ApiSuccess(_user);
    final controller = AuthController(repository, refresher);
    await pumpEventQueue();
    expect(controller.state.status, AuthStatus.authenticated);

    await controller.logout();

    expect(repository.loggedOut, isTrue);
    expect(controller.state, const AuthState(status: AuthStatus.unauthenticated));
  });

  test('registers itself as the shared refresher\'s onSignedOut callback',
      () async {
    repository.currentUserResult = const ApiSuccess(_user);
    final controller = AuthController(repository, refresher);
    await pumpEventQueue();
    expect(controller.state.status, AuthStatus.authenticated);

    // Simulates a dead refresh token discovered by any Supabase-facing Dio
    // client, not just one the controller itself triggered.
    await refresher.onSignedOut?.call();

    expect(controller.state.status, AuthStatus.unauthenticated);
    expect(controller.state.user, isNull);
  });
}
