import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/supabase_auth_interceptor.dart';
import 'package:wms_mobile/core/storage/supabase_session_storage.dart';

class _InMemoryStore implements SecureKeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

SupabaseSession _session({int expiresInSeconds = 3600}) => SupabaseSession(
      accessToken: 'stale-access',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.now().add(Duration(seconds: expiresInSeconds)),
    );

void main() {
  group('SupabaseTokenRefresher.ensureFresh', () {
    test('returns the same session unchanged when not expiring', () async {
      final refresher = SupabaseTokenRefresher(
        storage: SupabaseSessionStorage(_InMemoryStore()),
        refresh: (_) async => fail('refresh should not be called'),
      );
      final session = _session(expiresInSeconds: 3600);

      final result = await refresher.ensureFresh(session);
      expect(result, same(session));
    });

    test('refreshes and persists the new session when expiring', () async {
      final store = _InMemoryStore();
      final storage = SupabaseSessionStorage(store);
      final refreshed = SupabaseSession(
        accessToken: 'fresh-access',
        refreshToken: 'fresh-refresh',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      var refreshCalls = 0;
      final refresher = SupabaseTokenRefresher(
        storage: storage,
        refresh: (token) async {
          refreshCalls++;
          expect(token, 'refresh-token');
          return refreshed;
        },
      );

      final result = await refresher.ensureFresh(_session(expiresInSeconds: 10));

      expect(refreshCalls, 1);
      expect(result, same(refreshed));
      final persisted = await storage.read();
      expect(persisted?.accessToken, 'fresh-access');
    });

    test('clears storage and calls onSignedOut when the refresh grant fails',
        () async {
      final store = _InMemoryStore();
      final storage = SupabaseSessionStorage(store);
      await storage.write(_session(expiresInSeconds: 10));
      var signedOutCalls = 0;
      final refresher = SupabaseTokenRefresher(
        storage: storage,
        refresh: (_) async => null,
      );
      refresher.onSignedOut = () async => signedOutCalls++;

      final result = await refresher.ensureFresh(_session(expiresInSeconds: 10));

      expect(result, isNull);
      expect(signedOutCalls, 1);
      expect(await storage.read(), isNull);
    });

    test('a missing onSignedOut callback does not throw on refresh failure',
        () async {
      final refresher = SupabaseTokenRefresher(
        storage: SupabaseSessionStorage(_InMemoryStore()),
        refresh: (_) async => null,
      );

      await expectLater(
        refresher.ensureFresh(_session(expiresInSeconds: 10)),
        completion(isNull),
      );
    });
  });

  group('SupabaseTokenRefresher.force / coalescing', () {
    test('two concurrent calls share a single in-flight refresh', () async {
      var refreshCalls = 0;
      final refresher = SupabaseTokenRefresher(
        storage: SupabaseSessionStorage(_InMemoryStore()),
        refresh: (_) async {
          refreshCalls++;
          // Yield so both callers' futures are genuinely in flight together.
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return SupabaseSession(
            accessToken: 'fresh',
            refreshToken: 'fresh-refresh',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          );
        },
      );
      final session = _session();

      final results = await Future.wait([
        refresher.force(session),
        refresher.force(session),
      ]);

      expect(refreshCalls, 1);
      expect(results[0], same(results[1]));
    });

    test('a later call starts a new refresh once the first has settled',
        () async {
      var refreshCalls = 0;
      final refresher = SupabaseTokenRefresher(
        storage: SupabaseSessionStorage(_InMemoryStore()),
        refresh: (_) async {
          refreshCalls++;
          return SupabaseSession(
            accessToken: 'fresh-$refreshCalls',
            refreshToken: 'fresh-refresh',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          );
        },
      );
      final session = _session();

      await refresher.force(session);
      await refresher.force(session);

      expect(refreshCalls, 2);
    });
  });
}
