import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/supabase_auth_interceptor.dart';
import 'package:wms_mobile/core/config/app_config.dart';
import 'package:wms_mobile/core/storage/supabase_session_storage.dart';

import '../../support/fake_http_adapter.dart';

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
  late SupabaseSessionStorage storage;
  late SupabaseTokenRefresher refresher;
  late Future<SupabaseSession?> Function(String)? refreshImpl;
  late Dio dio;
  late FakeHttpClientAdapter adapter;

  setUp(() {
    storage = SupabaseSessionStorage(_InMemoryStore());
    refreshImpl = null;
    refresher = SupabaseTokenRefresher(
      storage: storage,
      refresh: (token) => refreshImpl!(token),
    );
    dio = Dio(BaseOptions(
      headers: {'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}'},
    ));
  });

  void useAdapter(ResponseBody Function(RequestOptions) handler) {
    adapter = FakeHttpClientAdapter(handler);
    dio.httpClientAdapter = adapter;
    SupabaseAuthInterceptor(storage: storage, refresher: refresher).attachTo(dio);
  }

  test('leaves the anon-key header untouched when signed out', () async {
    useAdapter((_) => jsonResponseBody({'ok': true}, 200));

    await dio.get('/anything');

    expect(
      adapter.requests.single.headers['Authorization'],
      'Bearer ${AppConfig.supabaseAnonKey}',
    );
  });

  test('sends the stored access token when the session is fresh', () async {
    await storage.write(SupabaseSession(
      accessToken: 'fresh-token',
      refreshToken: 'r',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    ));
    useAdapter((_) => jsonResponseBody({'ok': true}, 200));

    await dio.get('/anything');

    expect(adapter.requests.single.headers['Authorization'], 'Bearer fresh-token');
  });

  test('refreshes an expiring session before sending the request', () async {
    await storage.write(SupabaseSession(
      accessToken: 'stale-token',
      refreshToken: 'r',
      expiresAt: DateTime.now().add(const Duration(seconds: 5)),
    ));
    refreshImpl = (token) async {
      expect(token, 'r');
      return SupabaseSession(
        accessToken: 'refreshed-token',
        refreshToken: 'new-r',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
    };
    useAdapter((_) => jsonResponseBody({'ok': true}, 200));

    await dio.get('/anything');

    expect(adapter.requests.single.headers['Authorization'], 'Bearer refreshed-token');
    expect((await storage.read())?.accessToken, 'refreshed-token');
  });

  test('falls back to the anon key when a proactive refresh fails', () async {
    await storage.write(SupabaseSession(
      accessToken: 'stale-token',
      refreshToken: 'r',
      expiresAt: DateTime.now().add(const Duration(seconds: 5)),
    ));
    refreshImpl = (_) async => null;
    useAdapter((_) => jsonResponseBody({'ok': true}, 200));

    await dio.get('/anything');

    expect(
      adapter.requests.single.headers['Authorization'],
      'Bearer ${AppConfig.supabaseAnonKey}',
    );
  });

  test('retries once on a 401 with a forced refresh, then succeeds', () async {
    await storage.write(SupabaseSession(
      accessToken: 'stale-token',
      refreshToken: 'r',
      // Not expiring per the proactive check — the 401 is what triggers this.
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    ));
    refreshImpl = (_) async => SupabaseSession(
          accessToken: 'refreshed-token',
          refreshToken: 'new-r',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
    var callCount = 0;
    useAdapter((options) {
      callCount++;
      if (callCount == 1) return jsonResponseBody({'message': 'expired'}, 401);
      return jsonResponseBody({'ok': true}, 200);
    });

    final response = await dio.get('/anything');

    expect(response.statusCode, 200);
    expect(callCount, 2);
    expect(adapter.requestHeaders[0]['Authorization'], 'Bearer stale-token');
    expect(adapter.requestHeaders[1]['Authorization'], 'Bearer refreshed-token');
  });

  test('does not retry a request that already carries the retry flag',
      () async {
    await storage.write(SupabaseSession(
      accessToken: 'stale-token',
      refreshToken: 'r',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    ));
    var refreshCalls = 0;
    refreshImpl = (_) async {
      refreshCalls++;
      return SupabaseSession(
        accessToken: 'refreshed-token',
        refreshToken: 'new-r',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
    };
    var callCount = 0;
    useAdapter((options) {
      callCount++;
      return jsonResponseBody({'message': 'still expired'}, 401);
    });

    await expectLater(
      dio.get('/anything', options: Options(extra: {'sb_retried': true})),
      throwsA(isA<DioException>()),
    );

    expect(callCount, 1);
    expect(refreshCalls, 0);
  });
}
