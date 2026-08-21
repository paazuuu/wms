import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Locales the app ships translations for. Japanese is the default.
const List<Locale> kSupportedLocales = [
  Locale('ja'),
  Locale('en'),
  Locale('zh'),
];

/// Holds the active [Locale] and persists the user's choice so it survives a
/// restart. Defaults to Japanese; the stored value (if any) is applied on boot.
class LocaleController extends StateNotifier<Locale> {
  LocaleController(this._storage) : super(const Locale('ja')) {
    _restore();
  }

  final FlutterSecureStorage _storage;
  static const _storageKey = 'app_locale';

  Future<void> _restore() async {
    try {
      final code = await _storage.read(key: _storageKey);
      if (code != null &&
          kSupportedLocales.any((l) => l.languageCode == code)) {
        state = Locale(code);
      }
    } catch (_) {
      // Keep the default locale if storage is unavailable.
    }
  }

  /// Switch to [locale] (must be one of [kSupportedLocales]) and persist it.
  Future<void> setLocale(Locale locale) async {
    if (!kSupportedLocales.any((l) => l.languageCode == locale.languageCode)) {
      return;
    }
    state = Locale(locale.languageCode);
    try {
      await _storage.write(key: _storageKey, value: locale.languageCode);
    } catch (_) {
      // Non-fatal: the in-memory choice still applies for this session.
    }
  }
}

final localeControllerProvider =
    StateNotifierProvider<LocaleController, Locale>((ref) {
  return LocaleController(const FlutterSecureStorage());
});
