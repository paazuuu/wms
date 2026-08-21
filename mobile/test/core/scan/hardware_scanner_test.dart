import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/scan/hardware_scanner.dart';

const _digitKeys = <String, LogicalKeyboardKey>{
  '0': LogicalKeyboardKey.digit0,
  '1': LogicalKeyboardKey.digit1,
  '2': LogicalKeyboardKey.digit2,
  '3': LogicalKeyboardKey.digit3,
  '4': LogicalKeyboardKey.digit4,
  '5': LogicalKeyboardKey.digit5,
  '6': LogicalKeyboardKey.digit6,
  '7': LogicalKeyboardKey.digit7,
  '8': LogicalKeyboardKey.digit8,
  '9': LogicalKeyboardKey.digit9,
};

/// Simulate a handheld scanner: type each digit as a fast key press.
Future<void> _typeDigits(String code) async {
  for (final ch in code.split('')) {
    final key = _digitKeys[ch]!;
    await simulateKeyDownEvent(key, character: ch);
    await simulateKeyUpEvent(key);
  }
}

Future<void> _pressEnter() async {
  await simulateKeyDownEvent(LogicalKeyboardKey.enter);
  await simulateKeyUpEvent(LogicalKeyboardKey.enter);
}

void main() {
  testWidgets('captures a fast scan burst when nothing is focused',
      (tester) async {
    String? scanned;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HardwareScanner(
          onScan: (code) => scanned = code,
          child: const SizedBox.expand(),
        ),
      ),
    ));

    await _typeDigits('4901234');
    await _pressEnter();
    await tester.pump();

    expect(scanned, '4901234');
  });

  testWidgets('defers to a focused text field (no scan captured)',
      (tester) async {
    String? scanned;
    final fieldFocus = FocusNode();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HardwareScanner(
          onScan: (code) => scanned = code,
          child: TextField(focusNode: fieldFocus),
        ),
      ),
    ));

    // Focus the field (as tapping into it would), then confirm before typing.
    fieldFocus.requestFocus();
    await tester.pump();
    expect(fieldFocus.hasFocus, isTrue);

    await _typeDigits('4901234');
    await _pressEnter();
    await tester.pump();

    expect(scanned, isNull);
  });

  testWidgets('a single key + Enter is not treated as a scan', (tester) async {
    String? scanned;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HardwareScanner(
          onScan: (code) => scanned = code,
          child: const SizedBox.expand(),
        ),
      ),
    ));

    await _typeDigits('7');
    await _pressEnter();
    await tester.pump();

    expect(scanned, isNull);
  });

  testWidgets('does not capture when disabled', (tester) async {
    String? scanned;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HardwareScanner(
          enabled: false,
          onScan: (code) => scanned = code,
          child: const SizedBox.expand(),
        ),
      ),
    ));

    await _typeDigits('4901234');
    await _pressEnter();
    await tester.pump();

    expect(scanned, isNull);
  });
}
