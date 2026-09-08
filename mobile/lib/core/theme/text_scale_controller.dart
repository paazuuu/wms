import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Holds a global text-scale factor for on-site readability and persists the
/// operator's choice. Applied at the app root via a [MediaQuery] textScaler so
/// every screen scales together. Defaults to 1.0 (system-normal).
class TextScaleController extends StateNotifier<double> {
  TextScaleController(this._storage) : super(1.0) {
    _restore();
  }

  final FlutterSecureStorage _storage;
  static const _storageKey = 'text_scale';

  /// The selectable steps: normal, large, extra-large, max.
  static const steps = <double>[1.0, 1.15, 1.3, 1.5];

  Future<void> _restore() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      final v = double.tryParse(raw ?? '');
      if (v != null && v >= 1.0 && v <= 1.5) state = v;
    } catch (_) {
      // Keep the default scale if storage is unavailable.
    }
  }

  Future<void> setScale(double scale) async {
    final clamped = scale.clamp(1.0, 1.5).toDouble();
    state = clamped;
    try {
      await _storage.write(key: _storageKey, value: '$clamped');
    } catch (_) {
      // Non-fatal: the in-memory choice still applies for this session.
    }
  }
}

final textScaleControllerProvider =
    StateNotifierProvider<TextScaleController, double>((ref) {
  return TextScaleController(const FlutterSecureStorage());
});
