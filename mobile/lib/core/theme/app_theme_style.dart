import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The designs an operator can choose, each one of Astryx's themes
/// (github.com/paazuuu/astryx, packages/themes/*), carried over to Flutter.
/// Only colour, corners and typeface change; sizes and layout stay the same
/// in every design, so no screen moves when the design does.
enum AppThemeStyle { neutral, matcha, stone, chocolate, y2k }

/// One mode (light or dark) of an Astryx theme, in its own token names.
class AstryxTokens {
  const AstryxTokens({
    required this.accent,
    required this.onAccent,
    required this.body,
    required this.surface,
    required this.card,
    required this.muted,
    required this.gray,
    required this.textPrimary,
    required this.textSecondary,
    required this.textGray,
    required this.border,
    required this.borderEmphasized,
    required this.info,
    required this.textInfo,
    required this.textError,
    required this.error,
    required this.shadow,
    required this.overlay,
  });

  final Color accent; // --color-accent
  final Color onAccent; // --color-on-accent
  final Color body; // --color-background-body
  final Color surface; // --color-background-surface
  final Color card; // --color-background-card
  final Color muted; // --color-background-muted
  final Color gray; // --color-background-gray
  final Color textPrimary;
  final Color textSecondary;
  final Color textGray;
  final Color border; // hairlines
  final Color borderEmphasized; // a control's edge
  final Color info;
  final Color textInfo;
  final Color textError;
  final Color error;
  final Color shadow;
  final Color overlay;
}

/// Everything that differs between the designs.
class AppThemeSpec {
  const AppThemeSpec({
    required this.style,
    required this.light,
    required this.dark,
    required this.bodyFont,
    required this.headingFont,
    required this.radiusInner,
    required this.radiusControl,
    required this.radiusContainer,
    required this.radiusSheet,
    this.pill = true,
    this.cardLight,
    this.cardDark,
  });

  final AppThemeStyle style;
  final ColorScheme light;
  final ColorScheme dark;

  /// Running text, labels, buttons.
  final String bodyFont;

  /// Page titles and headings.
  final String headingFont;

  final double radiusInner;
  final double radiusControl;
  final double radiusContainer;
  final double radiusSheet;

  /// Chips as round pills (every design but Y2K, which is square).
  final bool pill;

  ColorScheme scheme(Brightness b) => b == Brightness.light ? light : dark;

  /// Card fill when it is not the surface (Chocolate's beige cards, the
  /// raised cards of the dark designs).
  final Color? cardLight;
  final Color? cardDark;

  Color card(Brightness b) => (b == Brightness.light ? cardLight : cardDark) ?? scheme(b).surface;

  static AppThemeSpec of(AppThemeStyle style) => switch (style) {
        AppThemeStyle.neutral => neutral,
        AppThemeStyle.matcha => matcha,
        AppThemeStyle.stone => stone,
        AppThemeStyle.chocolate => chocolate,
        AppThemeStyle.y2k => y2k,
      };

  /// Neutral: the scheme tuned by hand in [AppColors].
  static const neutral = AppThemeSpec(
    style: AppThemeStyle.neutral,
    light: AppColors.light,
    dark: AppColors.dark,
    bodyFont: 'Figtree',
    headingFont: 'Figtree',
    radiusInner: 6,
    radiusControl: 10,
    radiusContainer: 12,
    radiusSheet: 16,
  );

  /// Matcha — natural: olive ink on a cream page, sage borders.
  static final matcha = AppThemeSpec(
    style: AppThemeStyle.matcha,
    light: schemeFrom(Brightness.light, const AstryxTokens(
      accent: Color(0xFF3E481D), onAccent: Color(0xFFFFFFFF),
      body: Color(0xFFF0F0E0), surface: Color(0xFFFFFFFF), card: Color(0xFFFFFFFF),
      muted: Color(0xFFF0F0E0), gray: Color(0x33707E46),
      textPrimary: Color(0xFF3E481D), textSecondary: Color(0xFF707E46), textGray: Color(0xFF3E481D),
      border: Color(0xFFDCE3CE), borderEmphasized: Color(0xFFB7C29E),
      info: Color(0xFF3A5E8C), textInfo: Color(0xFF2E4A6E),
      error: Color(0xFFFD0000), textError: Color(0xFFCC0000),
      shadow: Color(0x1A3E481D), overlay: Color(0x803E481D),
    )),
    dark: schemeFrom(Brightness.dark, const AstryxTokens(
      accent: Color(0xFFC0CBA9), onAccent: Color(0xFF3E481D),
      body: Color(0xFF12140E), surface: Color(0xFF1A1C14), card: Color(0xFF1E2016),
      muted: Color(0xFF3E481D), gray: Color(0x335A6440),
      textPrimary: Color(0xFFC0CBA9), textSecondary: Color(0xFF94A468), textGray: Color(0xFFC0CBA9),
      border: Color(0x1AC0CBA9), borderEmphasized: Color(0xFF5A6440),
      info: Color(0xFFA7C9E3), textInfo: Color(0xFF8DBCE0),
      error: Color(0xFFFF5C5C), textError: Color(0xFFFF7A7A),
      shadow: Color(0x4D000000), overlay: Color(0xCC3E481D),
    )),
    bodyFont: 'DM Sans',
    headingFont: 'DM Sans',
    radiusInner: 6,
    radiusControl: 12,
    radiusContainer: 18,
    radiusSheet: 24,
    cardDark: const Color(0xFF1E2016),
  );

  /// Stone — business: slate ink on a cool grey page, square-ish corners.
  static final stone = AppThemeSpec(
    style: AppThemeStyle.stone,
    light: schemeFrom(Brightness.light, const AstryxTokens(
      accent: Color(0xFF25252A), onAccent: Color(0xFFFFFFFF),
      body: Color(0xFFF0F0F7), surface: Color(0xFFFFFFFF), card: Color(0xFFFFFFFF),
      muted: Color(0xFFE2E2E8), gray: Color(0xFFE2E2E8),
      textPrimary: Color(0xFF25252A), textSecondary: Color(0xFF5F5F64), textGray: Color(0xFF46464E),
      border: Color(0xFFE2E2E8), borderEmphasized: Color(0xFF848489),
      info: Color(0xFF516074), textInfo: Color(0xFF344861),
      error: Color(0xFF603C37), textError: Color(0xFF603C37),
      shadow: Color(0x1A25252A), overlay: Color(0x8025252A),
    )),
    dark: schemeFrom(Brightness.dark, const AstryxTokens(
      accent: Color(0xFFF0F0F9), onAccent: Color(0xFF25252A),
      body: Color(0xFF101018), surface: Color(0xFF1B1B21), card: Color(0xFF25252A),
      muted: Color(0xFF3A3A42), gray: Color(0xFF525159),
      textPrimary: Color(0xFFF0F0F9), textSecondary: Color(0xFFABABB3), textGray: Color(0xFFE2E2E8),
      border: Color(0x1AF0F0F9), borderEmphasized: Color(0xFF5E5E64),
      info: Color(0xFF9AADC7), textInfo: Color(0xFFD5E4F8),
      error: Color(0xFFE0BDB8), textError: Color(0xFFF7DBD7),
      shadow: Color(0x4D000000), overlay: Color(0xCC25252A),
    )),
    bodyFont: 'Figtree',
    headingFont: 'Montserrat',
    radiusInner: 4,
    radiusControl: 8,
    radiusContainer: 12,
    radiusSheet: 16,
    cardDark: const Color(0xFF25252A),
  );

  /// Chocolate — warm: brown accent, cream page, beige cards, a serif head.
  static final chocolate = AppThemeSpec(
    style: AppThemeStyle.chocolate,
    light: schemeFrom(Brightness.light, const AstryxTokens(
      accent: Color(0xFF8C5927), onAccent: Color(0xFFFFFFFF),
      body: Color(0xFFFFFCF7), surface: Color(0xFFFFFCF7), card: Color(0xFFEDE4D4),
      muted: Color(0xFFEDE4D4), gray: Color(0x33B88859),
      textPrimary: Color(0xFF4A3520), textSecondary: Color(0xFFB88859), textGray: Color(0xFF4A3520),
      border: Color(0xFFC4AC95), borderEmphasized: Color(0xFFB88859),
      info: Color(0xFF3A5E8C), textInfo: Color(0xFF2E4A6E),
      error: Color(0xFFFD0000), textError: Color(0xFFCC0000),
      shadow: Color(0x1A4A3520), overlay: Color(0x804A3520),
    )),
    dark: schemeFrom(Brightness.dark, const AstryxTokens(
      accent: Color(0xFFD4A06A), onAccent: Color(0xFF4A3520),
      body: Color(0xFF141010), surface: Color(0xFF1C1610), card: Color(0xFF2A2018),
      muted: Color(0xFF2A2018), gray: Color(0x336B5540),
      textPrimary: Color(0xFFEDE4D4), textSecondary: Color(0xFFC4A882), textGray: Color(0xFFEDE4D4),
      border: Color(0x1AEDE4D4), borderEmphasized: Color(0xFF6B5540),
      info: Color(0xFF7BA8D4), textInfo: Color(0xFF8DBCE0),
      error: Color(0xFFFF5C5C), textError: Color(0xFFFF7A7A),
      shadow: Color(0x4D000000), overlay: Color(0xCC140E0A),
    )),
    bodyFont: 'Albert Sans',
    headingFont: 'Fraunces',
    radiusInner: 6,
    radiusControl: 10,
    radiusContainer: 12,
    radiusSheet: 16,
    cardLight: const Color(0xFFEDE4D4),
    cardDark: const Color(0xFF2A2018),
  );

  /// Y2K — pop: a periwinkle page, charcoal ink, hard edges, no rounding.
  static final y2k = AppThemeSpec(
    style: AppThemeStyle.y2k,
    light: schemeFrom(Brightness.light, const AstryxTokens(
      accent: Color(0xFF2D241B), onAccent: Color(0xFFFFFFFF),
      body: Color(0xFFCCCFFA), surface: Color(0xFFFFFFFF), card: Color(0xFFFFFFFF),
      muted: Color(0xFFF1E6DB), gray: Color(0xFFF1E6DB),
      textPrimary: Color(0xFF2D241B), textSecondary: Color(0xFF675D52), textGray: Color(0xFF4F453B),
      border: Color(0xFF382E24), borderEmphasized: Color(0xFF382E24),
      info: Color(0xFF00649B), textInfo: Color(0xFF003454),
      error: Color(0xFFFFC3C3), textError: Color(0xFF880023),
      shadow: Color(0x1A2D241B), overlay: Color(0x802D241B),
    )),
    dark: schemeFrom(Brightness.dark, const AstryxTokens(
      accent: Color(0xFFEDEFFC), onAccent: Color(0xFF16182B),
      body: Color(0xFF0E0F1A), surface: Color(0xFF16182B), card: Color(0xFF16182B),
      muted: Color(0xFF1F2238), gray: Color(0xFF2B2F4A),
      textPrimary: Color(0xFFEDEFFC), textSecondary: Color(0xFFA6ACD6), textGray: Color(0xFFEDEFFC),
      border: Color(0x1AEDEFFC), borderEmphasized: Color(0xFF636889),
      info: Color(0xFF70C1FF), textInfo: Color(0xFF70C1FF),
      error: Color(0xFFFFC3C3), textError: Color(0xFFFF969A),
      shadow: Color(0x4D000000), overlay: Color(0xCC0E0F1A),
    )),
    bodyFont: 'Poppins',
    headingFont: 'Poppins',
    radiusInner: 0,
    radiusControl: 0,
    radiusContainer: 0,
    radiusSheet: 0,
    pill: false,
  );


  /// An Astryx mode as a Material [ColorScheme]. Text that Astryx leaves
  /// light (Chocolate's tan secondary text, Matcha's sage) is darkened just
  /// enough to keep 4.5:1 on its surfaces, and control edges 3:1, so a
  /// warehouse screen stays readable in every design.
  static ColorScheme schemeFrom(Brightness b, AstryxTokens t) {
    final light = b == Brightness.light;
    Color solid(Color c, [Color? on]) => Color.alphaBlend(c, on ?? t.surface);
    final card = solid(t.card);
    final page = solid(t.body);
    final gray = solid(t.gray);
    Color readable(Color c, double ratio) => _ensureContrast(c, [t.surface, card, page], ratio, light);
    final secondary = readable(t.textSecondary, 4.5);
    return ColorScheme(
      brightness: b,
      primary: t.accent,
      onPrimary: t.onAccent,
      primaryContainer: solid(t.accent.withValues(alpha: light ? 0.12 : 0.22)),
      onPrimaryContainer: t.textPrimary,
      secondary: secondary,
      onSecondary: t.surface,
      secondaryContainer: gray,
      onSecondaryContainer: readable(t.textGray, 4.5),
      tertiary: readable(t.info, 3),
      onTertiary: light ? const Color(0xFFFFFFFF) : t.surface,
      tertiaryContainer: solid(t.info.withValues(alpha: light ? 0.18 : 0.24)),
      onTertiaryContainer: readable(t.textInfo, 4.5),
      error: readable(t.textError, 4.5),
      onError: light ? const Color(0xFFFFFFFF) : t.surface,
      errorContainer: solid(t.error.withValues(alpha: light ? 0.22 : 0.24)),
      onErrorContainer: readable(t.textError, 4.5),
      surface: t.surface,
      onSurface: t.textPrimary,
      surfaceContainerLowest: t.surface,
      surfaceContainerLow: page,
      surfaceContainer: solid(t.muted),
      surfaceContainerHigh: gray,
      surfaceContainerHighest: solid(t.textPrimary.withValues(alpha: 0.14)),
      onSurfaceVariant: secondary,
      outline: readable(t.borderEmphasized, 3),
      outlineVariant: t.border,
      inverseSurface: t.accent,
      onInverseSurface: t.onAccent,
      inversePrimary: t.onAccent,
      shadow: t.shadow,
      scrim: t.overlay,
    );
  }

  /// Moves [c] toward black (light) or white (dark) until it reads at
  /// [ratio] on every background in [on].
  static Color _ensureContrast(Color c, List<Color> on, double ratio, bool light) {
    final target = light ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    var out = c;
    for (var i = 0; i < 20 && on.any((bg) => _contrast(out, bg) < ratio); i++) {
      out = Color.lerp(out, target, 0.08)!;
    }
    return out;
  }

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }
}
