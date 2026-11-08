import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_theme_style.dart';
import 'theme_fonts.dart';

/// The design and brightness the operator chose, kept on this device
/// (following [TextScaleController]'s pattern). Defaults: Neutral, following
/// the device's light/dark setting.
@immutable
class Appearance {
  const Appearance({this.style = AppThemeStyle.neutral, this.mode = ThemeMode.system});

  final AppThemeStyle style;
  final ThemeMode mode;

  Appearance copyWith({AppThemeStyle? style, ThemeMode? mode}) =>
      Appearance(style: style ?? this.style, mode: mode ?? this.mode);

  @override
  bool operator ==(Object other) => other is Appearance && other.style == style && other.mode == mode;

  @override
  int get hashCode => Object.hash(style, mode);
}

class AppearanceController extends StateNotifier<Appearance> {
  AppearanceController(this._storage) : super(const Appearance()) {
    _restore();
  }

  final FlutterSecureStorage _storage;
  static const _styleKey = 'theme_style';
  static const _modeKey = 'theme_mode';

  Future<void> _restore() async {
    try {
      final style = AppThemeStyle.values.asNameMap()[await _storage.read(key: _styleKey) ?? ''];
      final mode = ThemeMode.values.asNameMap()[await _storage.read(key: _modeKey) ?? ''];
      if (!mounted) return;
      state = state.copyWith(style: style, mode: mode);
      if (style != null) await ThemeFonts.ensure(style);
    } catch (_) {
      // Keep the defaults if storage is unavailable.
    }
  }

  Future<void> setStyle(AppThemeStyle style) async {
    state = state.copyWith(style: style);
    await _save(_styleKey, style.name);
    await ThemeFonts.ensure(style);
  }

  Future<void> setMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    await _save(_modeKey, mode.name);
  }

  Future<void> _save(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      // Non-fatal: the choice still applies for this session.
    }
  }
}

final appearanceControllerProvider = StateNotifierProvider<AppearanceController, Appearance>(
  (ref) => AppearanceController(const FlutterSecureStorage()),
);
