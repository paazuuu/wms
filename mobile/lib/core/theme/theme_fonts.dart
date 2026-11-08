import 'package:flutter/services.dart';

import 'app_theme_style.dart';

/// The other designs' typefaces, fetched the first time a design is chosen.
/// They are plain assets (pubspec `assets:`), not `fonts:`, so nobody pays
/// for them at start-up; until one has arrived, text shows in the fallback
/// and switches over by itself.
class ThemeFonts {
  ThemeFonts._();

  static const _dir = 'assets/fonts/themes';

  /// Family → its files (Latin letters only; Japanese and Chinese keep the
  /// device's fonts in every design).
  static const Map<String, List<String>> _files = {
    'DM Sans': ['DMSans-400.ttf', 'DMSans-600.ttf', 'DMSans-700.ttf'],
    'Montserrat': ['Montserrat-600.ttf', 'Montserrat-700.ttf'],
    'Albert Sans': ['AlbertSans-400.ttf', 'AlbertSans-600.ttf', 'AlbertSans-700.ttf'],
    'Fraunces': ['Fraunces-600.ttf', 'Fraunces-700.ttf'],
    'Poppins': ['Poppins-400.ttf', 'Poppins-600.ttf', 'Poppins-700.ttf'],
  };

  static final _loaded = <String, Future<void>>{};

  /// Loads what [style] needs; a family already loaded is not fetched again.
  static Future<void> ensure(AppThemeStyle style) async {
    final spec = AppThemeSpec.of(style);
    await Future.wait({spec.bodyFont, spec.headingFont}.where(_files.containsKey).map(_load));
  }

  static Future<void> _load(String family) => _loaded.putIfAbsent(family, () async {
        try {
          final loader = FontLoader(family);
          for (final f in _files[family]!) {
            loader.addFont(rootBundle.load('$_dir/$f'));
          }
          await loader.load();
        } catch (_) {
          // Missing or blocked: the fallback font stays, nothing else breaks.
          _loaded.remove(family);
        }
      });
}
