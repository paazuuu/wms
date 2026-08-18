import 'package:flutter/material.dart';

/// Raw palette + semantic tokens for the WMS design system.
///
/// Source: ui-ux-pro-max "Flat Design" style + "High contrast navy + blue"
/// palette, tuned for a glove-friendly warehouse field tool (WCAG AAA targets,
/// no gradients/shadows). Consume these through [ColorScheme]/[ThemeData] in
/// widgets — never reference the raw hex constants directly in UI code.
class AppColors {
  AppColors._();

  // Core palette (navy + blue).
  static const navy = Color(0xFF0F172A); // primary brand / headings
  static const navyInk = Color(0xFF020617); // foreground text
  static const slate = Color(0xFF334155); // secondary
  static const blue = Color(0xFF0369A1); // accent / CTA
  static const blueBright = Color(0xFF38BDF8); // dark-mode accent
  static const blueSky = Color(0xFF0EA5E9);

  // Neutrals.
  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF1F5F9);
  static const muted = Color(0xFFE8ECF1);
  static const border = Color(0xFFE2E8F0);
  static const borderStrong = Color(0xFFCBD5E1);
  static const mutedText = Color(0xFF475569);

  // Semantic status colors (OK / warning / NG) — not part of ColorScheme.
  static const success = Color(0xFF16A34A);
  static const successBg = Color(0xFFDCFCE7);
  static const successInk = Color(0xFF14532D);

  static const warning = Color(0xFFD97706);
  static const warningBg = Color(0xFFFEF3C7);
  static const warningInk = Color(0xFF78350F);

  static const danger = Color(0xFFDC2626);
  static const dangerBg = Color(0xFFFEE2E2);
  static const dangerInk = Color(0xFF7F1D1D);

  static const info = Color(0xFF0369A1);
  static const infoBg = Color(0xFFE0F2FE);
  static const infoInk = Color(0xFF0C4A6E);

  /// Light color scheme — blue as the interactive primary for strong
  /// action affordance; navy reserved for headings/inverse surfaces.
  static const light = ColorScheme(
    brightness: Brightness.light,
    primary: blue,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: infoBg,
    onPrimaryContainer: infoInk,
    secondary: slate,
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: border,
    onSecondaryContainer: Color(0xFF1E293B),
    tertiary: navy,
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFDDE3EC),
    onTertiaryContainer: navy,
    error: danger,
    onError: Color(0xFFFFFFFF),
    errorContainer: dangerBg,
    onErrorContainer: dangerInk,
    surface: surface,
    onSurface: navyInk,
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: background,
    surfaceContainer: surfaceAlt,
    surfaceContainerHigh: muted,
    surfaceContainerHighest: border,
    onSurfaceVariant: mutedText,
    outline: borderStrong,
    outlineVariant: border,
    inverseSurface: navy,
    onInverseSurface: background,
    inversePrimary: blueBright,
    shadow: Color(0x1A0F172A),
    scrim: Color(0x66020617),
  );

  /// Dark color scheme — navy surfaces, brightened blue accent.
  static const dark = ColorScheme(
    brightness: Brightness.dark,
    primary: blueBright,
    onPrimary: Color(0xFF082F49),
    primaryContainer: blue,
    onPrimaryContainer: infoBg,
    secondary: Color(0xFF94A3B8),
    onSecondary: navy,
    secondaryContainer: Color(0xFF334155),
    onSecondaryContainer: border,
    tertiary: border,
    onTertiary: navy,
    tertiaryContainer: Color(0xFF334155),
    onTertiaryContainer: background,
    error: Color(0xFFF87171),
    onError: Color(0xFF450A0A),
    errorContainer: Color(0xFF7F1D1D),
    onErrorContainer: dangerBg,
    surface: navy,
    onSurface: Color(0xFFF1F5F9),
    surfaceContainerLowest: navyInk,
    surfaceContainerLow: Color(0xFF141F33),
    surfaceContainer: Color(0xFF1E293B),
    surfaceContainerHigh: Color(0xFF334155),
    surfaceContainerHighest: Color(0xFF475569),
    onSurfaceVariant: borderStrong,
    outline: Color(0xFF475569),
    outlineVariant: Color(0xFF334155),
    inverseSurface: background,
    onInverseSurface: navy,
    inversePrimary: blue,
    shadow: Color(0xFF000000),
    scrim: Color(0xCC020617),
  );
}
