// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/delivery/domain/reconciliation.dart';
import 'package:wms_mobile/features/delivery/presentation/parcel_sheet.dart';

import '../../support/harness.dart';

/// Opens the sheet the way the screen does and returns what it popped.
Future<ReceivedParcel?> _open(
  WidgetTester tester, {
  int? remaining = 5,
}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  ReceivedParcel? result;
  await pumpAppWith(
    tester,
    container,
    Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () async {
            result = await showModalBottomSheet<ReceivedParcel>(
              context: context,
              isScrollControlled: true,
              builder: (_) => ParcelSheet(
                janCode: '4901234567890',
                productName: 'ボールペン',
                remaining: remaining,
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('prefills the quantity with what is still unattributed',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    await _open(tester, remaining: 5);

    // The common case is "the rest of this line is one lot", so the remainder
    // is the default rather than 1.
    expect(find.widgetWithText(TextField, '5'), findsOneWidget);
    expect(find.text('ボールペン'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('records a lot with its expiry and where it went', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    ReceivedParcel? captured;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await pumpAppWith(
      tester,
      container,
      Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () async {
              captured = await showModalBottomSheet<ReceivedParcel>(
                context: context,
                isScrollControlled: true,
                builder: (_) => ParcelSheet(
                  janCode: '4901234567890',
                  productName: 'ボールペン',
                  remaining: 20,
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'ロット番号（任意）'), 'L-A');
    await tester.enterText(
        find.widgetWithText(TextField, '置いた場所（任意）'), 'RECV-01');
    await tester.tap(find.widgetWithText(FilledButton, 'パーセル追加'));
    await tester.pumpAndSettle();

    expect(captured?.quantity, 20);
    expect(captured?.lotCode, 'L-A');
    expect(captured?.locationCode, 'RECV-01');
    // Nothing named a status, so the product's own flag decides (0068/0072).
    expect(captured?.statusCode, isNull);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a wet carton is recorded as damaged', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    ReceivedParcel? captured;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await pumpAppWith(
      tester,
      container,
      Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () async {
              captured = await showModalBottomSheet<ReceivedParcel>(
                context: context,
                isScrollControlled: true,
                builder: (_) => ParcelSheet(
                    janCode: 'X', productName: 'X', remaining: 4),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('到着時に破損していた'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'パーセル追加'));
    await tester.pumpAndSettle();

    // DAMAGED is the only status offered, because 0072 refuses anything that
    // would make the parcel *less* restricted than its product requires.
    expect(captured?.statusCode, 'DAMAGED');

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a serial is stopped at more than one unit, before the server sees it',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    await _open(tester, remaining: 5);

    await tester.enterText(
        find.widgetWithText(TextField, 'シリアル番号（任意）'), 'SN-1');
    await tester.tap(find.widgetWithText(FilledButton, 'パーセル追加'));
    await tester.pumpAndSettle();

    expect(find.text('シリアルは1点ごとに記録します'), findsOneWidget);
    // Still open: the operator fixes the quantity rather than reading a 400.
    expect(find.widgetWithText(FilledButton, 'パーセル追加'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a zero quantity is refused', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    await _open(tester, remaining: 5);

    await tester.enterText(find.widgetWithText(TextField, '数量'), '0');
    await tester.tap(find.widgetWithText(FilledButton, 'パーセル追加'));
    await tester.pumpAndSettle();

    expect(find.text('数量を入力してください'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
}
