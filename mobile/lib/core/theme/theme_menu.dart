import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'app_spacing.dart';
import 'app_theme_style.dart';
import 'appearance_controller.dart';

String themeStyleLabel(AppLocalizations l10n, AppThemeStyle s) => switch (s) {
      AppThemeStyle.neutral => l10n.themeNeutral,
      AppThemeStyle.matcha => l10n.themeMatcha,
      AppThemeStyle.stone => l10n.themeStone,
      AppThemeStyle.chocolate => l10n.themeChocolate,
      AppThemeStyle.y2k => l10n.themeY2k,
    };

String themeStyleHint(AppLocalizations l10n, AppThemeStyle s) => switch (s) {
      AppThemeStyle.neutral => l10n.themeNeutralHint,
      AppThemeStyle.matcha => l10n.themeMatchaHint,
      AppThemeStyle.stone => l10n.themeStoneHint,
      AppThemeStyle.chocolate => l10n.themeChocolateHint,
      AppThemeStyle.y2k => l10n.themeY2kHint,
    };

/// The palette button beside the text size: pick one of the five designs
/// and light / dark / the device's choice. Applies at once and is kept on
/// this device.
class ThemeMenuButton extends ConsumerWidget {
  const ThemeMenuButton({super.key, this.iconColor});

  final Color? iconColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final look = ref.watch(appearanceControllerProvider);
    final brightness = Theme.of(context).brightness;
    final header = Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

    return PopupMenuButton<Object>(
      key: const ValueKey('theme-menu'),
      tooltip: l10n.themeMenu,
      icon: Icon(Icons.palette_outlined, color: iconColor),
      constraints: const BoxConstraints(minWidth: 340, maxWidth: 420),
      onSelected: (v) {
        final c = ref.read(appearanceControllerProvider.notifier);
        if (v is AppThemeStyle) c.setStyle(v);
        if (v is ThemeMode) c.setMode(v);
      },
      itemBuilder: (context) => [
        PopupMenuItem<Object>(enabled: false, height: 32, child: Text(l10n.themeStyleHeader, style: header)),
        for (final s in AppThemeStyle.values)
          PopupMenuItem<Object>(
            key: ValueKey('theme-style-${s.name}'),
            value: s,
            height: 56,
            child: Row(children: [
              SizedBox(width: 24, child: s == look.style ? const Icon(Icons.check, size: 20) : null),
              const SizedBox(width: AppSpacing.sm),
              _Swatch(spec: AppThemeSpec.of(s), brightness: brightness),
              const SizedBox(width: AppSpacing.md),
              Flexible(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(themeStyleLabel(l10n, s)),
                  Text(themeStyleHint(l10n, s),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ]),
              ),
            ]),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<Object>(enabled: false, height: 32, child: Text(l10n.themeModeHeader, style: header)),
        for (final (m, label, icon) in [
          (ThemeMode.system, l10n.themeModeSystem, Icons.brightness_auto_outlined),
          (ThemeMode.light, l10n.themeModeLight, Icons.light_mode_outlined),
          (ThemeMode.dark, l10n.themeModeDark, Icons.dark_mode_outlined),
        ])
          PopupMenuItem<Object>(
            key: ValueKey('theme-mode-${m.name}'),
            value: m,
            child: Row(children: [
              SizedBox(width: 24, child: m == look.mode ? const Icon(Icons.check, size: 20) : null),
              const SizedBox(width: AppSpacing.sm),
              Icon(icon, size: 20),
              const SizedBox(width: AppSpacing.md),
              Text(label),
            ]),
          ),
      ],
    );
  }
}

/// A design at a glance: its page, its card and its accent.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.spec, required this.brightness});

  final AppThemeSpec spec;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final s = spec.scheme(brightness);
    return Container(
      width: 44,
      height: 28,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: s.surfaceContainerLow,
        borderRadius: BorderRadius.circular(spec.radiusInner),
        border: Border.all(color: s.outline),
      ),
      child: Row(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: spec.card(brightness),
              borderRadius: BorderRadius.circular(spec.radiusInner / 2),
            ),
          ),
        ),
        const SizedBox(width: 3),
        Container(
          width: 12,
          decoration: BoxDecoration(color: s.primary, borderRadius: BorderRadius.circular(spec.radiusInner / 2)),
        ),
      ]),
    );
  }
}
