import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// Central [ThemeData] for the WMS app.
///
/// Design language: Astryx **Neutral** (github.com/paazuuu/astryx) — muted
/// and minimal: a grey page with white (or #262626) surfaces, hairline
/// borders rather than shadows, a monochrome accent (black on light,
/// near-white on dark) and colour kept for state; Figtree on a 14px base
/// with a 1.2 ratio; radii 6 (inner) / 10 (controls) / 12 (containers);
/// 40px controls; quick 125ms motion.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(AppColors.light);
  static ThemeData dark() => _build(AppColors.dark);

  static const _text = TextStyle(fontFamily: AppFonts.sans, fontFamilyFallback: AppFonts.fallback);

  static ThemeData _build(ColorScheme scheme) {
    final isLight = scheme.brightness == Brightness.light;
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surfaceContainerLow,
      canvasColor: scheme.surface,
      fontFamily: AppFonts.sans,
      fontFamilyFallback: AppFonts.fallback,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      hoverColor: scheme.onSurface.withValues(alpha: 0.05), // --color-overlay-hover
      highlightColor: scheme.onSurface.withValues(alpha: 0.10), // --color-overlay-pressed
    );

    final rControl = BorderRadius.circular(AppSpacing.radiusMd);
    final rContainer = BorderRadius.circular(AppSpacing.radiusLg);
    final rSheet = BorderRadius.circular(AppSpacing.radiusXl);
    final hairline = BorderSide(color: scheme.outlineVariant);
    const controlSize = Size(64, AppSpacing.control);
    final buttonText = _text.copyWith(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0);
    // Neutral's raised layers: a soft two-step shadow (--shadow-med).
    final popShadow = [
      BoxShadow(color: Colors.black.withValues(alpha: isLight ? 0.05 : 0.35), blurRadius: 4, offset: const Offset(0, 2)),
      BoxShadow(color: Colors.black.withValues(alpha: isLight ? 0.10 : 0.50), blurRadius: 12, offset: const Offset(0, 4)),
    ];

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, scheme),

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: _text.copyWith(fontSize: 18, fontWeight: FontWeight.w700, color: scheme.onSurface),
        shape: Border(bottom: hairline),
      ),

      // Cards: the container — a hairline edge, no shadow.
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: rContainer, side: hairline),
      ),

      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),

      // Buttons are 40px tall and only as wide as their label: a full-width
      // minimum made any button placed in a Row ask for an infinite width.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: controlSize,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(borderRadius: rControl),
          textStyle: buttonText,
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: controlSize,
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          side: hairline,
          shape: RoundedRectangleBorder(borderRadius: rControl),
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: controlSize,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          side: BorderSide(color: isLight ? AppColors.borderStrong : AppColors.n35),
          foregroundColor: scheme.onSurface,
          backgroundColor: scheme.surface,
          shape: RoundedRectangleBorder(borderRadius: rControl),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.control),
          foregroundColor: scheme.onSurface,
          shape: RoundedRectangleBorder(borderRadius: rControl),
          textStyle: buttonText,
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(AppSpacing.control),
          foregroundColor: scheme.onSurface,
          shape: RoundedRectangleBorder(borderRadius: rControl),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        highlightElevation: 3,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        extendedTextStyle: buttonText.copyWith(fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: rContainer),
      ),

      // Inputs: on the surface, an emphasized edge, a 2px accent ring.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        border: OutlineInputBorder(borderRadius: rControl, borderSide: BorderSide(color: scheme.outline)),
        enabledBorder: OutlineInputBorder(
          borderRadius: rControl,
          borderSide: BorderSide(color: isLight ? AppColors.borderStrong : AppColors.n35),
        ),
        focusedBorder: OutlineInputBorder(borderRadius: rControl, borderSide: BorderSide(color: scheme.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: rControl, borderSide: BorderSide(color: scheme.error, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: rControl, borderSide: BorderSide(color: scheme.error, width: 2)),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: scheme.onSurface),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: rControl),
      ),

      // Tabs: secondary text, the chosen one in the primary text colour over
      // a 2px accent line.
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: scheme.outlineVariant,
        labelStyle: _text.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: _text.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
        overlayColor: WidgetStatePropertyAll(scheme.onSurface.withValues(alpha: 0.05)),
      ),

      // Segmented control: a muted track, the chosen segment raised to the
      // surface.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
          textStyle: WidgetStatePropertyAll(buttonText.copyWith(fontSize: 13)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: rControl)),
          side: WidgetStatePropertyAll(hairline),
          backgroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? scheme.surface : scheme.surfaceContainerHigh),
          foregroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? scheme.onSurface : scheme.onSurfaceVariant),
        ),
      ),

      // Badges and filters: pills on the grey fill; a chosen one in the accent.
      chipTheme: ChipThemeData(
        backgroundColor: scheme.secondaryContainer,
        selectedColor: scheme.primary,
        checkmarkColor: scheme.onPrimary,
        side: BorderSide.none,
        labelStyle: _text.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSecondaryContainer),
        secondaryLabelStyle: _text.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onPrimary),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),

      dataTableTheme: DataTableThemeData(
        headingTextStyle: _text.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
        dataTextStyle: _text.copyWith(fontSize: 14, color: scheme.onSurface),
        dividerThickness: 1,
        headingRowColor: WidgetStatePropertyAll(scheme.surfaceContainer),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: _text.copyWith(color: scheme.onInverseSurface, fontSize: 14),
        actionTextColor: scheme.onInverseSurface,
        shape: RoundedRectangleBorder(borderRadius: rContainer),
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: scheme.shadow,
        shape: RoundedRectangleBorder(borderRadius: rSheet, side: isLight ? BorderSide.none : hairline),
        titleTextStyle: _text.copyWith(fontSize: 18, fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: rContainer, side: hairline),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(scheme.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: rContainer, side: hairline)),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: AppColors.blue.withValues(alpha: isLight ? 0.22 : 0.40),
        selectionHandleColor: scheme.primary,
      ),
      focusColor: AppColors.blue.withValues(alpha: isLight ? 0.18 : 0.30),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(8),
        radius: const Radius.circular(8),
        thumbColor: WidgetStateProperty.resolveWith((states) => scheme.onSurfaceVariant.withValues(
            alpha: states.contains(WidgetState.dragged) || states.contains(WidgetState.hovered) ? 0.7 : 0.35)),
        trackColor: WidgetStatePropertyAll(scheme.surfaceContainer),
        trackBorderColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: AppSpacing.xs + 2),
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          boxShadow: popShadow,
        ),
        textStyle: _text.copyWith(fontSize: 13, height: 1.45, color: scheme.onInverseSurface),
      ),
      // A box's edge reads at 3:1 when empty, so an unticked row is seen.
      checkboxTheme: CheckboxThemeData(
        side: BorderSide(color: scheme.outline, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm - 2)),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStatePropertyAll(scheme.outlineVariant),
      ),
      badgeTheme: BadgeThemeData(backgroundColor: scheme.error, textColor: scheme.onError),

      // Quick, quiet page transitions (Neutral's motion is snappier than
      // the default).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Neutral's scale: a 14px base, ratio 1.2 (12 · 14 · 16.8 · 20.2 · 24.2 ·
  /// 29 · 34.8 · 41.8), bold headings, 1.5 line height for running text.
  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    TextStyle? s(TextStyle? t, double size, FontWeight w, {double? h, double ls = 0}) => t?.copyWith(
        fontFamily: AppFonts.sans,
        fontFamilyFallback: AppFonts.fallback,
        fontSize: size,
        fontWeight: w,
        height: h,
        letterSpacing: ls);
    final t = base
        .copyWith(
          displayLarge: s(base.displayLarge, 42, FontWeight.w700, h: 1.15, ls: -0.5),
          displayMedium: s(base.displayMedium, 35, FontWeight.w700, h: 1.15, ls: -0.4),
          displaySmall: s(base.displaySmall, 29, FontWeight.w700, h: 1.2, ls: -0.3),
          headlineLarge: s(base.headlineLarge, 29, FontWeight.w700, h: 1.2, ls: -0.3),
          headlineMedium: s(base.headlineMedium, 24, FontWeight.w700, h: 1.25, ls: -0.2),
          headlineSmall: s(base.headlineSmall, 20, FontWeight.w700, h: 1.3),
          titleLarge: s(base.titleLarge, 18, FontWeight.w700, h: 1.3),
          titleMedium: s(base.titleMedium, 16, FontWeight.w600, h: 1.35),
          titleSmall: s(base.titleSmall, 14, FontWeight.w600, h: 1.4),
          bodyLarge: s(base.bodyLarge, 16, FontWeight.w400, h: 1.5),
          bodyMedium: s(base.bodyMedium, 14, FontWeight.w400, h: 1.5),
          bodySmall: s(base.bodySmall, 12, FontWeight.w400, h: 1.45),
          labelLarge: s(base.labelLarge, 14, FontWeight.w600, h: 1.3),
          labelMedium: s(base.labelMedium, 12, FontWeight.w600, h: 1.3),
          labelSmall: s(base.labelSmall, 11, FontWeight.w600, h: 1.3, ls: 0.2),
        )
        .apply(
          fontFamily: AppFonts.sans,
          fontFamilyFallback: AppFonts.fallback,
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        );
    // Figures of one width, so quantities and prices line up in tables.
    TextStyle? n(TextStyle? x) => x?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return t.copyWith(
      displayLarge: n(t.displayLarge),
      displayMedium: n(t.displayMedium),
      displaySmall: n(t.displaySmall),
      headlineLarge: n(t.headlineLarge),
      headlineMedium: n(t.headlineMedium),
      headlineSmall: n(t.headlineSmall),
      titleLarge: n(t.titleLarge),
      titleMedium: n(t.titleMedium),
      titleSmall: n(t.titleSmall),
      bodyLarge: n(t.bodyLarge),
      bodyMedium: n(t.bodyMedium),
      bodySmall: n(t.bodySmall),
      labelLarge: n(t.labelLarge),
      labelMedium: n(t.labelMedium),
      labelSmall: n(t.labelSmall),
    );
  }
}
