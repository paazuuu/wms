import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';

/// One shortcut, as shown in the help sheet.
@immutable
class ShortcutHint {
  const ShortcutHint(this.keys, this.description);

  /// Already-formatted key combination, e.g. "Ctrl + K".
  final String keys;
  final String description;
}

/// The shortcuts this app defines, in the order they are worth learning.
///
/// Written out here rather than derived from the bindings map, because the
/// two are not one-to-one: nine Alt+digit bindings are one line an operator
/// needs to read ("Alt + 1…9"). Deriving it would either list nine near
/// identical rows or need a grouping rule more complex than the list itself.
///
/// The cost is real: add a binding and this list must be updated too, or the
/// shortcut exists but is undiscoverable. Nothing enforces that automatically.
List<ShortcutHint> shortcutHints(AppLocalizations l10n, {required bool isMac}) {
  final mod = isMac ? '⌘' : 'Ctrl';
  return [
    ShortcutHint('$mod + K', l10n.shortcutFocusScan),
    ShortcutHint('$mod + B', l10n.shortcutToggleSidebar),
    ShortcutHint('$mod + Shift + F', l10n.shortcutGlobalSearch),
    ShortcutHint('Alt + 1…9', l10n.shortcutSwitchTab),
    ShortcutHint('F1', l10n.shortcutShowHelp),
  ];
}

/// Lists the keyboard shortcuts.
///
/// A dialog rather than a settings page: it is read once, mid-task, and
/// dismissed. Reachable by F1 and by the top bar's keyboard button, because a
/// shortcut list only discoverable *via* a shortcut helps nobody who does not
/// already know it exists.
class ShortcutsHelpDialog extends StatelessWidget {
  const ShortcutsHelpDialog({super.key, required this.isMac});

  final bool isMac;

  static Future<void> show(BuildContext context, {required bool isMac}) {
    return showDialog<void>(
      context: context,
      builder: (_) => ShortcutsHelpDialog(isMac: isMac),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.shortcutsTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final hint in shortcutHints(l10n, isMac: isMac))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Container(
                      constraints: const BoxConstraints(minWidth: 108),
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Text(
                        hint.keys,
                        style: theme.textTheme.labelMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: Text(hint.description)),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}
