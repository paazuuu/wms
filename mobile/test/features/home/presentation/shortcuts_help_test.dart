import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/home/presentation/shortcuts_help.dart';
import 'package:wms_mobile/l10n/app_localizations.dart';

Future<AppLocalizations> _l10n(String locale) =>
    AppLocalizations.delegate.load(Locale(locale));

void main() {
  test('uses the Command symbol on macOS and Ctrl elsewhere', () async {
    final l10n = await _l10n('en');

    final mac = shortcutHints(l10n, isMac: true).map((h) => h.keys).toList();
    final other = shortcutHints(l10n, isMac: false).map((h) => h.keys).toList();

    // Telling a Mac operator to press Ctrl sends them to a key that does
    // nothing here and collides with text navigation.
    expect(mac, contains('⌘ + K'));
    expect(other, contains('Ctrl + K'));
    expect(mac.length, other.length);
  });

  test('every hint has a key combination and a description', () async {
    for (final locale in ['ja', 'en', 'zh']) {
      final l10n = await _l10n(locale);
      final hints = shortcutHints(l10n, isMac: false);
      expect(hints, isNotEmpty, reason: locale);
      for (final hint in hints) {
        expect(hint.keys.trim(), isNotEmpty, reason: '$locale ${hint.keys}');
        // A row with no description is a key combination the operator has to
        // guess the meaning of.
        expect(hint.description.trim(), isNotEmpty,
            reason: '$locale ${hint.keys}');
      }
    }
  });

  testWidgets('the dialog is localized, not English-only', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ShortcutsHelpDialog(isMac: false)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('キーボードショートカット'), findsOneWidget);
    expect(find.text('スキャン欄にカーソルを移動'), findsOneWidget);
    // The key names stay Latin — a keyboard's keys are labelled in Latin
    // whatever the UI language.
    expect(find.text('Ctrl + K'), findsOneWidget);
  });
}
