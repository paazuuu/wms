import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'locale_controller.dart';

/// A globe button that opens a menu to switch the app language
/// (Japanese / English / Chinese). The active language is checked.
class LanguageMenuButton extends ConsumerWidget {
  const LanguageMenuButton({super.key, this.iconColor});

  final Color? iconColor;

  String _nameFor(AppLocalizations l10n, String code) {
    switch (code) {
      case 'ja':
        return l10n.languageJapanese;
      case 'en':
        return l10n.languageEnglish;
      case 'zh':
        return l10n.languageChinese;
      default:
        return code;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(localeControllerProvider);

    return PopupMenuButton<Locale>(
      tooltip: l10n.languageTooltip,
      icon: Icon(Icons.language, color: iconColor),
      onSelected: (locale) =>
          ref.read(localeControllerProvider.notifier).setLocale(locale),
      itemBuilder: (context) => [
        for (final locale in kSupportedLocales)
          CheckedPopupMenuItem<Locale>(
            value: locale,
            checked: current.languageCode == locale.languageCode,
            child: Text(_nameFor(l10n, locale.languageCode)),
          ),
      ],
    );
  }
}
