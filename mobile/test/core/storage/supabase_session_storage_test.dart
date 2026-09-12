import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/storage/supabase_session_storage.dart';

/// In-memory [SecureKeyValueStore] — the real platform plugin has no
/// test-harness backend (see the class doc on [SecureKeyValueStore]).
class _InMemoryStore implements SecureKeyValueStore {
  final Map<String, String> values = {};

  /// When set, every call throws instead of touching [values] — simulates a
  /// genuinely broken/unreachable keychain.
  Object? failWith;

  @override
  Future<String?> read(String key) async {
    if (failWith != null) throw failWith!;
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWith != null) throw failWith!;
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (failWith != null) throw failWith!;
    values.remove(key);
  }
}

void main() {
  group('SupabaseSession', () {
    test('fromGoTrue computes expiresAt from expires_in', () {
      final before = DateTime.now();
      final session = SupabaseSession.fromGoTrue({
        'access_token': 'a',
        'refresh_token': 'r',
        'expires_in': 3600,
      });
      final after = DateTime.now();

      expect(session.accessToken, 'a');
      expect(session.refreshToken, 'r');
      expect(
        session.expiresAt.isAfter(before.add(const Duration(seconds: 3599))),
        isTrue,
      );
      expect(
        session.expiresAt.isBefore(after.add(const Duration(seconds: 3601))),
        isTrue,
      );
    });

    test('fromGoTrue defaults expires_in to 3600 when absent', () {
      final session = SupabaseSession.fromGoTrue({
        'access_token': 'a',
        'refresh_token': 'r',
      });
      final remaining = session.expiresAt.difference(DateTime.now());
      expect(remaining.inMinutes, greaterThanOrEqualTo(59));
    });

    test('isExpiring is false well before expiry', () {
      final session = SupabaseSession(
        accessToken: 'a',
        refreshToken: 'r',
        expiresAt: DateTime.now().add(const Duration(minutes: 30)),
      );
      expect(session.isExpiring(), isFalse);
    });

    test('isExpiring is true within the default 60s skew', () {
      final session = SupabaseSession(
        accessToken: 'a',
        refreshToken: 'r',
        expiresAt: DateTime.now().add(const Duration(seconds: 30)),
      );
      expect(session.isExpiring(), isTrue);
    });

    test('isExpiring is true once already past expiry', () {
      final session = SupabaseSession(
        accessToken: 'a',
        refreshToken: 'r',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      expect(session.isExpiring(), isTrue);
    });
  });

  group('SupabaseSessionStorage', () {
    late _InMemoryStore store;
    late SupabaseSessionStorage storage;

    setUp(() {
      store = _InMemoryStore();
      storage = SupabaseSessionStorage(store);
    });

    test('read returns null when nothing has been written', () async {
      expect(await storage.read(), isNull);
    });

    test('write then read round-trips the session', () async {
      final session = SupabaseSession(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
        expiresAt: DateTime.utc(2030, 1, 1, 12, 0, 0),
      );
      await storage.write(session);

      final read = await storage.read();
      expect(read, isNotNull);
      expect(read!.accessToken, 'access-1');
      expect(read.refreshToken, 'refresh-1');
      expect(read.expiresAt, DateTime.utc(2030, 1, 1, 12, 0, 0));
    });

    test('clear removes all three keys so read returns null again', () async {
      await storage.write(SupabaseSession(
        accessToken: 'a',
        refreshToken: 'r',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ));
      await storage.clear();
      expect(await storage.read(), isNull);
    });

    test('read is null if only some keys are present (partial write)',
        () async {
      store.values['sb_access_token'] = 'a';
      store.values['sb_refresh_token'] = 'r';
      // sb_expires_at deliberately missing.
      expect(await storage.read(), isNull);
    });

    test('read returns null rather than throwing when the backing store is unreachable',
        () async {
      store.failWith = Exception('keychain unavailable');
      expect(await storage.read(), isNull);
    });

    test('write swallows a backing-store failure instead of throwing',
        () async {
      store.failWith = Exception('keychain unavailable');
      await expectLater(
        storage.write(SupabaseSession(
          accessToken: 'a',
          refreshToken: 'r',
          expiresAt: DateTime.now(),
        )),
        completes,
      );
    });

    test('clear swallows a backing-store failure instead of throwing',
        () async {
      store.failWith = Exception('keychain unavailable');
      await expectLater(storage.clear(), completes);
    });
  });
}
