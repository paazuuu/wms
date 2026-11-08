import 'package:flutter/material.dart';

/// Raw palette + semantic tokens for the WMS design system.
///
/// Source: Astryx **Neutral** (github.com/paazuuu/astryx,
/// packages/themes/neutral): a muted, minimal grey ramp with a monochrome
/// accent (black on light, near-white on dark) and colour kept for state —
/// info, success, warning, error. The values are Neutral's own
/// (astryx-oklch-v1 ramps); consume them through [ColorScheme]/[ThemeData]
/// and [StatusColors] in widgets — never the raw hex constants in UI code.
class AppColors {
  AppColors._();

  // Neutral ramp (light and dark share it): 0 black … 100 white.
  static const n0 = Color(0xFF000000);
  static const n5 = Color(0xFF111111);
  static const n10 = Color(0xFF1B1B1B);
  static const n15 = Color(0xFF262626);
  static const n20 = Color(0xFF303030);
  static const n30 = Color(0xFF474747);
  static const n35 = Color(0xFF525252);
  static const n45 = Color(0xFF6A6A6A);
  static const n55 = Color(0xFF848484);
  static const n65 = Color(0xFF9E9E9E);
  static const n80 = Color(0xFFC6C6C6);
  static const n85 = Color(0xFFD4D4D4);
  static const n90 = Color(0xFFE2E2E2);
  static const n95 = Color(0xFFF1F1F1);
  static const n100 = Color(0xFFFFFFFF);

  // Kept names (a few charts and badges read them directly).
  static const navy = n10;
  static const navyInk = n0;
  static const slate = n30;
  static const blue = Color(0xFF0074E2); // --color-info (light)
  static const blueBright = Color(0xFF6D9CFE); // --color-info (dark)
  static const blueSky = Color(0xFF529FFF);

  // Neutrals.
  static const background = n95; // --color-background-body
  static const surface = n100; // --color-background-surface / card
  static const surfaceAlt = n95; // --color-background-muted
  static const muted = n90; // --color-background-gray
  static const border = Color(0x14000000); // --color-border (black 8%)
  static const borderStrong = n85; // --color-border-emphasized
  static const mutedText = n30; // --color-text-secondary

  // Semantic status colors — Neutral's reviewed status fills.
  static const success = Color(0xFF198100);
  static const successBg = Color(0xFFCBEECA); // green 90
  static const successInk = Color(0xFF00490B); // green 25

  static const warning = Color(0xFFFFCE2F);
  static const warningBg = Color(0xFFFFE193); // yellow 90
  static const warningInk = Color(0xFF4B3900); // yellow 25

  static const danger = Color(0xFFC9303A);
  static const dangerBg = Color(0xFFFFC4BE); // red 85
  static const dangerInk = Color(0xFF76000C); // red 25

  static const info = Color(0xFF0074E2);
  static const infoBg = Color(0xFFB9D7FF); // blue 85
  static const infoInk = Color(0xFF003978); // blue 25

  /// Light: white surfaces on a #f1f1f1 page, black accent, black text,
  /// #474747 secondary text, hairline 8% borders.
  static const light = ColorScheme(
    brightness: Brightness.light,
    primary: n10, // --color-accent
    onPrimary: n100, // --color-on-accent
    primaryContainer: n90, // a selected row, a chosen nav item
    onPrimaryContainer: n5,
    secondary: n30,
    onSecondary: n100,
    secondaryContainer: n90, // --color-background-gray
    onSecondaryContainer: n10, // --color-text-gray
    tertiary: info, // links and info, the one blue
    onTertiary: n100,
    tertiaryContainer: infoBg,
    onTertiaryContainer: infoInk,
    error: danger,
    onError: n100,
    errorContainer: dangerBg,
    onErrorContainer: dangerInk,
    surface: n100,
    onSurface: n0, // --color-text-primary
    surfaceContainerLowest: n100,
    surfaceContainerLow: n95, // --color-background-body
    surfaceContainer: n95, // --color-background-muted
    surfaceContainerHigh: n90,
    surfaceContainerHighest: n90,
    onSurfaceVariant: n30, // --color-text-secondary
    // Control edges (inputs, outlined buttons, checkboxes) keep 3:1 on
    // white (WCAG 1.4.11); hairlines between things stay at 8%.
    outline: n55,
    outlineVariant: Color(0x14000000),
    inverseSurface: n10,
    onInverseSurface: n100,
    inversePrimary: n95,
    shadow: Color(0x1A000000), // --color-shadow
    scrim: Color(0x80000000), // --color-overlay
  );

  /// Dark: #1b1b1b page, #262626 surfaces, near-white accent and text,
  /// #9e9e9e secondary text, hairline 10% borders.
  static const dark = ColorScheme(
    brightness: Brightness.dark,
    primary: n95, // --color-accent
    onPrimary: n5, // --color-on-accent
    primaryContainer: n30, // --color-accent-muted
    onPrimaryContainer: n100,
    secondary: n65,
    onSecondary: n5,
    secondaryContainer: n20, // --color-background-gray
    onSecondaryContainer: Color(0xFFD4D4D4), // --color-text-gray
    tertiary: blueBright,
    onTertiary: n5,
    tertiaryContainer: Color(0x3D88BCFF),
    onTertiaryContainer: Color(0xFFA1CAFF),
    error: Color(0xFFFF705D),
    onError: n5,
    errorContainer: Color(0x3DFF9890),
    onErrorContainer: Color(0xFFFFAEA7),
    surface: n15, // --color-background-surface
    onSurface: n100,
    surfaceContainerLowest: n5,
    surfaceContainerLow: n10, // --color-background-body
    surfaceContainer: n10, // --color-background-muted
    surfaceContainerHigh: n20,
    surfaceContainerHighest: n30,
    onSurfaceVariant: n65, // --color-text-secondary
    // Control edges at 3:1 or more on the #262626 surfaces.
    outline: Color(0xFF7A7A7A),
    outlineVariant: Color(0x1AFFFFFF),
    inverseSurface: n95,
    onInverseSurface: n10,
    inversePrimary: n10,
    shadow: Color(0x4D000000),
    scrim: Color(0xCC000000),
  );
}

/// OK / caution colours that read on either theme: as text they keep 4.5:1
/// (Neutral's --color-text-success / -warning); the containers are its
/// muted status fills.
extension StatusColors on ColorScheme {
  bool get _light => brightness == Brightness.light;

  /// Done, fine, in stock.
  Color get success => _light ? const Color(0xFF2F7D33) : const Color(0xFF90CA90);

  /// Needs a look or a choice; not wrong.
  Color get warning => _light ? const Color(0xFF836700) : const Color(0xFFEEC448);

  Color get successContainer => _light ? AppColors.successBg : const Color(0x3D90CA90);
  Color get onSuccessContainer => _light ? AppColors.successInk : const Color(0xFF90CA90);
  Color get warningContainer => _light ? AppColors.warningBg : const Color(0x3DE2B623);
  Color get onWarningContainer => _light ? AppColors.warningInk : const Color(0xFFEEC448);

  /// A row marked as not taken in, as a tint the text still reads on.
  Color get errorTint => error.withValues(alpha: _light ? 0.12 : 0.22);
}
