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

  /// Corner radii (flat design → moderate, consistent rounding).
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;

  /// Minimum interactive size. WCAG/Material minimum is 44–48px; we bump to
  /// 52 so controls stay tappable with warehouse gloves.
  static const double minTouch = 52;
}

/// Bundled font families (see pubspec `fonts:`).
class AppFonts {
  AppFonts._();

  /// Fira Sans — UI text and labels.
  static const String sans = 'Fira Sans';

  /// Fira Code — monospace for codes, barcodes and quantities so digits align.
  static const String mono = 'Fira Code';
}
