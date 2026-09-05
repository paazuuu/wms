import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'text_scale_controller.dart';

/// A text-size button that opens a menu to enlarge the whole app for on-site
/// readability (normal / large / extra-large / max). The active size is checked.
class TextScaleMenuButton extends ConsumerWidget {
  const TextScaleMenuButton({super.key, this.iconColor});

  final Color? iconColor;

  String _label(AppLocalizations l10n, double v) {
    if (v <= 1.0) return l10n.textSizeNormal;
    if (v <= 1.15) return l10n.textSizeLarge;
    if (v <= 1.3) return l10n.textSizeXLarge;
    return l10n.textSizeXXLarge;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(textScaleControllerProvider);

    return PopupMenuButton<double>(
      tooltip: l10n.textSizeMenu,
      icon: Icon(Icons.format_size, color: iconColor),
      onSelected: (v) =>
          ref.read(textScaleControllerProvider.notifier).setScale(v),
      itemBuilder: (context) => [
        for (final step in TextScaleController.steps)
          CheckedPopupMenuItem<double>(
            value: step,
            checked: (current - step).abs() < 0.01,
            child: Text(_label(l10n, step)),
          ),
      ],
    );
  }
}
