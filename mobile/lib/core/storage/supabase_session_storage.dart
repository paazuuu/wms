import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// One Supabase Auth session: the pair GoTrue hands back from a password or
/// refresh grant, plus when the access token actually expires.
class SupabaseSession {
  const SupabaseSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  /// True once the token is within [skew] of expiring — the point at which a
  /// caller should refresh proactively rather than wait for a 401.
  bool isExpiring({Duration skew = const Duration(seconds: 60)}) =>
      DateTime.now().isAfter(expiresAt.subtract(skew));

  factory SupabaseSession.fromGoTrue(Map<String, dynamic> json) {
    final expiresIn = json['expires_in'] as int? ?? 3600;
    return SupabaseSession(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }
}

/// A minimal encrypted key-value store — just enough surface for
/// [SupabaseSessionStorage], kept separate from [FlutterSecureStorage]
/// itself so a test can supply an in-memory stand-in instead of driving the
/// real platform keychain/keystore plugin (which has no test-harness
/// implementation and simply never replies outside a real app).
abstract class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  const FlutterSecureKeyValueStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Persists the current Supabase session in the platform keychain/keystore
/// (encrypted storage on Web) — separate from [TokenStorage], which holds the
/// unrelated (and now unused) InventorOS Sanctum token.
class SupabaseSessionStorage {
  SupabaseSessionStorage([SecureKeyValueStore? store])
      : _store = store ?? const FlutterSecureKeyValueStore();

  static const _accessKey = 'sb_access_token';
  static const _refreshKey = 'sb_refresh_token';
  static const _expiresKey = 'sb_expires_at';

  final SecureKeyValueStore _store;

  /// The keychain/keystore backend is platform code an interceptor can't
  /// control: on a desktop target with no keyring daemon reachable it can
  /// stall rather than fail, and every network request on an authenticated
  /// Dio client goes through [read] first. Bounding it keeps a missing
  /// keyring a "signed out" state instead of hanging the whole app.
  static const _timeout = Duration(seconds: 5);

  Future<SupabaseSession?> read() async {
    try {
      final access = await _store.read(_accessKey).timeout(_timeout);
      final refresh = await _store.read(_refreshKey).timeout(_timeout);
      final expiresRaw = await _store.read(_expiresKey).timeout(_timeout);
      if (access == null || refresh == null || expiresRaw == null) return null;
      final expiresAt = DateTime.tryParse(expiresRaw);
      if (expiresAt == null) return null;
      return SupabaseSession(
          accessToken: access, refreshToken: refresh, expiresAt: expiresAt);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(SupabaseSession session) async {
    try {
      await _store.write(_accessKey, session.accessToken).timeout(_timeout);
      await _store.write(_refreshKey, session.refreshToken).timeout(_timeout);
      await _store
          .write(_expiresKey, session.expiresAt.toIso8601String())
          .timeout(_timeout);
    } catch (_) {
      // Best-effort: a session that fails to persist just won't survive a
      // restart, rather than crashing the sign-in flow that just succeeded.
    }
  }

  Future<void> clear() async {
    try {
      await _store.delete(_accessKey).timeout(_timeout);
      await _store.delete(_refreshKey).timeout(_timeout);
      await _store.delete(_expiresKey).timeout(_timeout);
    } catch (_) {
      // Best-effort, as above.
    }
  }
}
