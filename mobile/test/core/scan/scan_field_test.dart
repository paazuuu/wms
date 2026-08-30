import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/scan/scan_field.dart';
import 'package:wms_mobile/l10n/app_localizations.dart';

Widget _host({required Widget child, Size size = const Size(1200, 800)}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('submits the trimmed value, then clears and keeps focus',
      (tester) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    String? submitted;

    await tester.pumpWidget(_host(
      child: ScanField(
        controller: controller,
        focusNode: focus,
        onSubmitted: (v) => submitted = v,
      ),
    ));

    await tester.enterText(find.byType(TextField), '  4901234567894  ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(submitted, '4901234567894');
    expect(controller.text, isEmpty);
    expect(focus.hasFocus, isTrue);
  });

  testWidgets('keeps the text when clearOnSubmit is false', (tester) async {
    final controller = TextEditingController();
    String? submitted;

    await tester.pumpWidget(_host(
      child: ScanField(
        controller: controller,
        clearOnSubmit: false,
        onSubmitted: (v) => submitted = v,
      ),
    ));

    await tester.enterText(find.byType(TextField), 'ABC123');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(submitted, 'ABC123');
    expect(controller.text, 'ABC123');
  });

  testWidgets('does not fire onSubmitted for an empty / whitespace value',
      (tester) async {
    var calls = 0;

    await tester.pumpWidget(_host(
      child: ScanField(onSubmitted: (_) => calls++),
    ));

    await tester.enterText(find.byType(TextField), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(calls, 0);
  });

  testWidgets('autofocusOnWide focuses the field on a wide layout',
      (tester) async {
    final focus = FocusNode();

    await tester.pumpWidget(_host(
      size: const Size(1200, 800),
      child: ScanField(
        focusNode: focus,
        autofocusOnWide: true,
        onSubmitted: (_) {},
      ),
    ));
    await tester.pump();

    expect(focus.hasFocus, isTrue);
  });

  testWidgets('autofocusOnWide does not focus the field on a narrow layout',
      (tester) async {
    final focus = FocusNode();

    await tester.pumpWidget(_host(
      size: const Size(500, 900),
      child: ScanField(
        focusNode: focus,
        autofocusOnWide: true,
        onSubmitted: (_) {},
      ),
    ));
    await tester.pump();

    expect(focus.hasFocus, isFalse);
  });
}
