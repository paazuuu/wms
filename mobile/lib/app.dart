import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/locale_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/text_scale_controller.dart';
import 'l10n/app_localizations.dart';

class WmsApp extends ConsumerWidget {
  const WmsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider);
    final textScale = ref.watch(textScaleControllerProvider);

    return MaterialApp.router(
      routerConfig: ref.watch(goRouterProvider),
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
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
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

/// App brand mark: a rounded navy tile with a warehouse/scan glyph. Uses an
/// SVG-quality Material icon (skill rule: no emoji as icons).
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
        color: scheme.tertiary,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(
        Icons.inventory_2_outlined,
        color: scheme.onTertiary,
        size: size * 0.55,
      ),
    );
  }
}
