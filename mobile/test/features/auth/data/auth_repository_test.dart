import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/storage/supabase_session_storage.dart';
import 'package:wms_mobile/features/auth/data/auth_repository.dart';

import '../../../support/fake_http_adapter.dart';

class _InMemoryStore implements SecureKeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  late SupabaseSessionStorage sessionStorage;
  late Dio authDio;
  late Dio restDio;
  late FakeHttpClientAdapter authAdapter;
  late FakeHttpClientAdapter restAdapter;
  late AuthRepositoryImpl repository;

  void setAuthHandler(ResponseBody Function(RequestOptions) handler) {
    authAdapter = FakeHttpClientAdapter(handler);
    authDio.httpClientAdapter = authAdapter;
  }

  void setRestHandler(ResponseBody Function(RequestOptions) handler) {
    restAdapter = FakeHttpClientAdapter(handler);
    restDio.httpClientAdapter = restAdapter;
  }

  ResponseBody defaultRestHandler(RequestOptions options) {
    if (options.path == '/rpc/bootstrap_first_admin') {
      return jsonResponseBody(true, 200);
    }
    if (options.path == '/rpc/my_roles') {
      return jsonResponseBody([
        {'code': 'picker', 'name': 'Picker'},
      ], 200);
    }
    throw StateError('unexpected rest call: ${options.path}');
  }

  setUp(() {
    sessionStorage = SupabaseSessionStorage(_InMemoryStore());
    authDio = Dio();
    restDio = Dio();
    setRestHandler(defaultRestHandler);
    repository = AuthRepositoryImpl(authDio, restDio, sessionStorage);
  });

  group('login', () {
    test('a successful password grant stores the session and returns the user with roles',
        () async {
      setAuthHandler((options) {
        expect(options.path, '/token');
        expect(options.queryParameters['grant_type'], 'password');
        expect(options.data, {'email': 'a@example.com', 'password': 'secret'});
        return jsonResponseBody({
          'access_token': 'access-1',
          'refresh_token': 'refresh-1',
          'expires_in': 3600,
          'user': {
            'id': 'user-uuid-1',
            'email': 'a@example.com',
            'user_metadata': {'name': 'Ada'},
          },
        }, 200);
      });

      final result = await repository.login('a@example.com', 'secret');

      result.when(
        success: (user) {
          expect(user.id, 'user-uuid-1');
          expect(user.email, 'a@example.com');
          expect(user.name, 'Ada');
          expect(user.roles, ['picker']);
        },
        failure: (f) => fail('expected success, got ${f.message}'),
      );

      final stored = await sessionStorage.read();
      expect(stored?.accessToken, 'access-1');
      expect(stored?.refreshToken, 'refresh-1');
    });

    test('bootstrap_first_admin failing is non-fatal to login', () async {
      setAuthHandler((_) => jsonResponseBody({
            'access_token': 'access-1',
            'refresh_token': 'refresh-1',
            'expires_in': 3600,
            'user': {'id': 'u1', 'email': 'a@example.com'},
          }, 200));
      setRestHandler((options) {
        if (options.path == '/rpc/bootstrap_first_admin') {
          return jsonResponseBody({'message': 'already bootstrapped'}, 500);
        }
        return defaultRestHandler(options);
      });

      final result = await repository.login('a@example.com', 'secret');

      result.when(
        success: (user) => expect(user.roles, ['picker']),
        failure: (f) => fail('expected success, got ${f.message}'),
      );
    });

    test('my_roles failing leaves the user signed in with no roles', () async {
      setAuthHandler((_) => jsonResponseBody({
            'access_token': 'access-1',
            'refresh_token': 'refresh-1',
            'expires_in': 3600,
            'user': {'id': 'u1', 'email': 'a@example.com'},
          }, 200));
      setRestHandler((options) {
        if (options.path == '/rpc/my_roles') {
          return jsonResponseBody({'message': 'boom'}, 500);
        }
        return defaultRestHandler(options);
      });

      final result = await repository.login('a@example.com', 'secret');

      result.when(
        success: (user) => expect(user.roles, isEmpty),
        failure: (f) => fail('expected success, got ${f.message}'),
      );
    });

    test('my_roles wrapped in an extra list layer is unwrapped', () async {
      setAuthHandler((_) => jsonResponseBody({
            'access_token': 'access-1',
            'refresh_token': 'refresh-1',
            'expires_in': 3600,
            'user': {'id': 'u1', 'email': 'a@example.com'},
          }, 200));
      setRestHandler((options) {
        if (options.path == '/rpc/my_roles') {
          return jsonResponseBody([
            [
              {'code': 'system_admin', 'name': 'System Admin'},
            ],
          ], 200);
        }
        return defaultRestHandler(options);
      });

      final result = await repository.login('a@example.com', 'secret');

      result.when(
        success: (user) => expect(user.roles, ['system_admin']),
        failure: (f) => fail('expected success, got ${f.message}'),
      );
    });

    test('invalid credentials surface GoTrue\'s own message', () async {
      setAuthHandler((_) => jsonResponseBody({
            'error': 'invalid_grant',
            'error_description': 'Invalid login credentials',
          }, 400));

      final result = await repository.login('a@example.com', 'wrong');

      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) {
          expect(f.message, 'Invalid login credentials');
          expect(f.statusCode, 400);
        },
      );
      expect(await sessionStorage.read(), isNull);
    });

    test('a connection error gets a readable message, not a raw exception',
        () async {
      authAdapter = FakeHttpClientAdapter(
          (_) => throw const SocketExceptionStub());
      authDio.httpClientAdapter = authAdapter;

      final result = await repository.login('a@example.com', 'secret');

      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.message, isNotEmpty),
      );
    });
  });

  group('currentUser', () {
    test('fails immediately when no session is stored', () async {
      final result = await repository.currentUser();

      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) {
          expect(f.message, 'Not signed in');
          expect(f.statusCode, 401);
        },
      );
    });

    test('validates the stored session against /user and refetches roles',
        () async {
      await sessionStorage.write(SupabaseSession(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ));
      setAuthHandler((options) {
        expect(options.path, '/user');
        return jsonResponseBody({'id': 'u1', 'email': 'a@example.com'}, 200);
      });

      final result = await repository.currentUser();

      result.when(
        success: (user) {
          expect(user.id, 'u1');
          expect(user.roles, ['picker']);
        },
        failure: (f) => fail('expected success, got ${f.message}'),
      );
    });

    test('a 401 from /user clears the stored session', () async {
      await sessionStorage.write(SupabaseSession(
        accessToken: 'dead-token',
        refreshToken: 'refresh-1',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ));
      setAuthHandler((_) => jsonResponseBody({'msg': 'invalid token'}, 401));

      final result = await repository.currentUser();

      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.statusCode, 401),
      );
      expect(await sessionStorage.read(), isNull);
    });
  });

  group('logout', () {
    test('clears the session even when the server call fails', () async {
      await sessionStorage.write(SupabaseSession(
        accessToken: 'a',
        refreshToken: 'r',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ));
      setAuthHandler((_) => jsonResponseBody({'message': 'server error'}, 500));

      await repository.logout();

      expect(await sessionStorage.read(), isNull);
    });

    test('clears the session on a successful server call', () async {
      await sessionStorage.write(SupabaseSession(
        accessToken: 'a',
        refreshToken: 'r',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ));
      setAuthHandler((options) {
        expect(options.path, '/logout');
        return jsonResponseBody(null, 204);
      });

      await repository.logout();

      expect(await sessionStorage.read(), isNull);
    });
  });
}

/// Thrown by a [FakeHttpClientAdapter] to simulate a transport-level failure
/// (no response at all) — Dio surfaces this as [DioExceptionType.unknown].
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
