import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/locale_controller.dart';
import 'core/router/app_router.dart';
import 'core/ui/popconfirm.dart';
import 'core/ui/selectable_app.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/appearance_controller.dart';
import 'core/theme/text_scale_controller.dart';
import 'l10n/app_localizations.dart';

class WmsApp extends ConsumerWidget {
  const WmsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider);
    final textScale = ref.watch(textScaleControllerProvider);
    final look = ref.watch(appearanceControllerProvider);
    // A popconfirm opens beside the button that was clicked.
    PopconfirmAnchor.install();

    return MaterialApp.router(
      routerConfig: ref.watch(goRouterProvider),
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // The design and brightness chosen in the theme menu (palette icon).
      theme: AppTheme.light(look.style),
      darkTheme: AppTheme.dark(look.style),
      themeMode: look.mode,
      // Apply the operator's text-size choice on top of the OS setting so the
      // whole app scales consistently for on-site readability.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        // At "normal" respect the OS accessibility scale; once the operator
        // picks a larger app size, apply it explicitly.
        return MediaQuery(
          data: media.copyWith(
            textScaler: textScale == 1.0
                ? media.textScaler
                : TextScaler.linear(textScale),
          ),
          // Every text on screen — names, codes, labels — can be selected
          // and copied, so a JAN or 品番 never has to be typed out again.
          // Scanning is unaffected: the hardware scanner and shortcuts
          // listen on HardwareKeyboard, not on focus.
          child: SelectableApp(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}

/// App brand mark: a rounded tile in the accent (black on light, near-white
/// on dark — Astryx Neutral) with a warehouse glyph.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(
        Icons.inventory_2_outlined,
        color: scheme.onPrimary,
        size: size * 0.55,
      ),
    );
  }
}
