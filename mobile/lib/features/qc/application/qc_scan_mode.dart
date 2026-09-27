import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/supabase_session_storage.dart';

/// Whether a scan during inspection counts one piece (0100) or only picks the
/// line so its quantity can be typed. Goods usually arrive in cartons of
/// hundreds, so it is off unless the operator turns it on; the choice is kept
/// on the device, like the language and text size.
class ScanCountsPieceController extends StateNotifier<bool> {
  ScanCountsPieceController(this._storage) : super(false) {
    _restore();
  }

  final SecureKeyValueStore _storage;
  static const _storageKey = 'qc_scan_counts_piece';

  Future<void> _restore() async {
    try {
      final raw = await _storage.read(_storageKey);
      if (raw != null) state = raw == 'true';
    } catch (_) {
      // Keep the default if storage is unavailable.
    }
  }

  Future<void> set(bool value) async {
    state = value;
    try {
      await _storage.write(_storageKey, '$value');
    } catch (_) {
      // Non-fatal: the in-memory choice still applies for this session.
    }
  }
}

final scanCountsPieceProvider =
    StateNotifierProvider<ScanCountsPieceController, bool>((ref) {
  return ScanCountsPieceController(const FlutterSecureKeyValueStore());
});
