/// Spacing, radius and touch-target tokens (8pt grid).
///
/// A single source of truth keeps gaps consistent across screens — the
/// ui-ux-pro-max "Layout" rule: use fixed spacing tokens, not ad-hoc numbers.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Corner radii (Astryx Neutral): inner parts 6, controls 10, containers
  /// 12, a sheet or dialog 16.
  static const double radiusSm = 6;
  static const double radiusMd = 10;
  static const double radiusLg = 12;
  static const double radiusXl = 16;

  /// A control's height on a desk (Astryx md); fields and buttons on the
  /// floor keep [minTouch] where a screen asks for it.
  static const double control = 40;

  /// Minimum interactive size. WCAG/Material minimum is 44–48px; we bump to
  /// 52 so controls stay tappable with warehouse gloves.
  static const double minTouch = 52;
}

/// Bundled font families (see pubspec `fonts:`).
class AppFonts {
  AppFonts._();

  /// Figtree — UI text and labels (Astryx Neutral's typeface).
  static const String sans = 'Figtree';

  /// Fira Code — monospace for codes, barcodes and quantities so digits align.
  static const String mono = 'Fira Code';

  /// Tried after either of the above: half-width katakana (ｺｸﾖ, ﾊﾞｲﾝﾀﾞｰ),
  /// which suppliers still print. Bundled because on the web the system
  /// fallback fetches these in several pieces and some of them drew as □.
  static const List<String> fallback = ['WMS Kana'];
}
