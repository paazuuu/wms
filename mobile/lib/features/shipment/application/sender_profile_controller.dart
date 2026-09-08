import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/sender_profile.dart';

/// Holds the saved sender (差出人) profile and persists it so the default
/// survives a restart. What actually prints is still chosen per print from
/// [SenderProfile.defaultEnabled].
class SenderProfileController extends StateNotifier<SenderProfile> {
  SenderProfileController(this._storage) : super(const SenderProfile()) {
    _restore();
  }

  final FlutterSecureStorage _storage;
  static const _storageKey = 'sender_profile';

  Future<void> _restore() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw != null && raw.isNotEmpty) state = SenderProfile.decode(raw);
    } catch (_) {
      // Keep the empty default if storage is unavailable.
    }
  }

  Future<void> save(SenderProfile profile) async {
    state = profile;
    try {
      await _storage.write(key: _storageKey, value: profile.encode());
    } catch (_) {
      // Non-fatal: the in-memory profile still applies for this session.
    }
  }
}

final senderProfileControllerProvider =
    StateNotifierProvider<SenderProfileController, SenderProfile>((ref) {
  return SenderProfileController(const FlutterSecureStorage());
});
