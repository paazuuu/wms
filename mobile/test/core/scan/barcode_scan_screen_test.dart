import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/scan/barcode_scan_screen.dart';
import 'package:wms_mobile/core/scan/scan_feedback.dart';

import '../../support/harness.dart';

/// Records what the operator would have heard/felt instead of hitting the
/// platform channels.
class _RecordingFeedback extends ScanFeedback {
  const _RecordingFeedback(this.log);

  final List<String> log;

  @override
  Future<void> success() async => log.add('success');

  @override
  Future<void> error() async => log.add('error');

  @override
  Future<void> duplicate() async => log.add('duplicate');
}

/// Hosts the scanner behind a button so pops can be observed.
class _Host extends StatelessWidget {
  const _Host({required this.open, required this.onResult});

  final BarcodeScanScreen Function() open;
  final void Function(String? code) onResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final code = await Navigator.of(context).push<String>(
              MaterialPageRoute(builder: (_) => open()),
            );
            onResult(code);
          },
          child: const Text('open'),
        ),
      ),
    );
  }
}

/// Holds the camera's `onCode` callback so a test can feed codes through the
/// real pipeline (validation → duplicate suppression → feedback → history)
/// without a camera.
class _Camera {
  ValueChanged<String>? emit;

  void call(String code) => emit!(code);

  Widget build(BuildContext context, ValueChanged<String> onCode) {
    emit = onCode;
    return const SizedBox.expand();
  }
}

Future<_Camera> _open(
  WidgetTester tester,
  BarcodeScanScreen Function(ScanCameraBuilder camera) build, {
  void Function(String? code)? onResult,
}) async {
  final camera = _Camera();
  await pumpApp(
    tester,
    _Host(
      open: () => build(camera.build),
      onResult: onResult ?? (_) {},
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return camera;
}

void main() {
  testWidgets('single-shot pops with the code and no confirmation step',
      (tester) async {
    final log = <String>[];
    String? result;
    final camera = await _open(
      tester,
      (camera) => BarcodeScanScreen(
          cameraBuilder: camera, feedback: _RecordingFeedback(log)),
      onResult: (code) => result = code,
    );

    camera('4901234567894');
    await tester.pumpAndSettle();

    expect(result, '4901234567894');
    expect(log, ['success']);
    // Popped straight back to the host — nothing to confirm.
    expect(find.byType(BarcodeScanScreen), findsNothing);
  });

  testWidgets('the wrong code is refused with the error tone and stays open',
      (tester) async {
    final log = <String>[];
    String? result;
    var popped = false;
    final camera = await _open(
      tester,
      (camera) => BarcodeScanScreen(
        cameraBuilder: camera,
        expectedCode: '4901234567894',
        feedback: _RecordingFeedback(log),
      ),
      onResult: (code) {
        popped = true;
        result = code;
      },
    );

    camera('9999999999999');
    await tester.pumpAndSettle();

    expect(log, ['error']);
    expect(popped, isFalse);
    expect(result, isNull);
    expect(find.text('別の商品です（対象: 4901234567894）'), findsOneWidget);

    // The right one then goes through.
    camera('4901234567894');
    await tester.pumpAndSettle();

    expect(log, ['error', 'success']);
    expect(result, '4901234567894');
  });

  testWidgets('a custom validate() reason is shown to the operator',
      (tester) async {
    final log = <String>[];
    final camera = await _open(
      tester,
      (camera) => BarcodeScanScreen(
        cameraBuilder: camera,
        continuous: true,
        validate: (code) => code.length == 13 ? null : 'JANは13桁です',
        feedback: _RecordingFeedback(log),
      ),
    );

    camera('123');
    await tester.pumpAndSettle();

    expect(log, ['error']);
    expect(find.text('JANは13桁です'), findsOneWidget);
  });

  testWidgets('continuous mode keeps scanning and suppresses a repeat',
      (tester) async {
    final log = <String>[];
    final scanned = <String>[];
    final camera = await _open(
      tester,
      (camera) => BarcodeScanScreen(
        cameraBuilder: camera,
        continuous: true,
        onScan: scanned.add,
        feedback: _RecordingFeedback(log),
      ),
    );

    camera('4901234567894');
    await tester.pumpAndSettle();
    // The camera re-decoding the same label must not count twice.
    camera('4901234567894');
    await tester.pumpAndSettle();
    camera('4901234567895');
    await tester.pumpAndSettle();

    expect(scanned, ['4901234567894', '4901234567895']);
    expect(log, ['success', 'duplicate', 'success']);
    // Still open, with a running count and the ignored scan visible in history.
    expect(find.byType(BarcodeScanScreen), findsOneWidget);
    expect(find.text('2 件読み取り'), findsOneWidget);
    expect(find.textContaining('重複（無視しました）'), findsOneWidget);
  });

  testWidgets('manual entry feeds the same validation as the camera',
      (tester) async {
    final log = <String>[];
    String? result;
    await _open(
      tester,
      (camera) => BarcodeScanScreen(
        cameraBuilder: camera,
        expectedCode: '4901234567894',
        feedback: _RecordingFeedback(log),
      ),
      onResult: (code) => result = code,
    );

    await tester.tap(find.text('手動入力'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '9999999999999');
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();

    // A typed code is not a way around the gate.
    expect(log, ['error']);
    expect(result, isNull);
    expect(find.text('別の商品です（対象: 4901234567894）'), findsOneWidget);

    await tester.tap(find.text('手動入力'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4901234567894');
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();

    expect(result, '4901234567894');
  });

  testWidgets('nothing scanned yet is a visible state', (tester) async {
    await _open(tester, (camera) => BarcodeScanScreen(cameraBuilder: camera));

    expect(find.text('まだ読み取りがありません'), findsOneWidget);
  });
}
