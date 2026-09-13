import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/picking_ops/application/picking_ops_providers.dart';
import 'package:wms_mobile/features/picking_ops/domain/pick_list.dart';
import 'package:wms_mobile/features/picking_ops/presentation/pick_list_detail_screen.dart';

import '../../support/harness.dart';

PickList _openList() => const PickList(
      id: 5,
      shipmentPlanId: 9,
      shipmentNumber: 'SHIP-0009',
      customerName: 'テスト商店',
      status: PickListStatus.picking,
      tasks: [
        PickTask(
          id: 21,
          janCode: '4901234567894',
          productName: 'ボールペン',
          plannedQuantity: 20,
        ),
        PickTask(
          id: 22,
          janCode: '4901234567895',
          productName: 'ノート',
          plannedQuantity: 10,
        ),
      ],
    );

/// §16's gate: the quantity field and the record button stay disabled until
/// the task's own JAN has been scanned. The dialog's scan field accepts a
/// wedge scanner's submit, which is what this drives.
Future<void> _scanToConfirm(WidgetTester tester, String janCode) async {
  await tester.enterText(find.byType(TextField).first, janCode);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

Future<void> _recordPick(
  WidgetTester tester, {
  required String productName,
  required String janCode,
  required String quantity,
}) async {
  await tester.tap(find.text(productName));
  await tester.pumpAndSettle();
  await _scanToConfirm(tester, janCode);
  await tester.enterText(find.byType(TextField).last, quantity);
  await tester.tap(find.widgetWithText(FilledButton, 'ピック数を記録'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a short pick shows its own status, not plan rounded down',
      (tester) async {
    final repo = FakePickingRepository(list: _openList());

    await pumpApp(
      tester,
      const PickListDetailScreen(pickListId: 5),
      overrides: [pickingRepositoryProvider.overrideWithValue(repo)],
    );

    await _recordPick(tester,
        productName: 'ボールペン', janCode: '4901234567894', quantity: '17');

    expect(repo.lastRecordedQuantity, 17);
    expect(find.text('不足'), findsOneWidget);
    expect(find.text('-3'), findsOneWidget);
  });

  testWidgets('completing with a pending task is refused', (tester) async {
    final repo = FakePickingRepository(list: _openList());

    await pumpApp(
      tester,
      const PickListDetailScreen(pickListId: 5),
      overrides: [pickingRepositoryProvider.overrideWithValue(repo)],
    );

    // Only pick one of the two tasks.
    await _recordPick(tester,
        productName: 'ボールペン', janCode: '4901234567894', quantity: '20');

    await tester.tap(find.widgetWithText(FilledButton, 'ピッキング完了'));
    await tester.pumpAndSettle();

    expect(find.text('未ピックの明細があるため完了できません'), findsOneWidget);
    expect(repo.refusedIncomplete, isFalse); // the tap never reached the server
  });

  testWidgets('completing with every task picked hands off to packing',
      (tester) async {
    final repo = FakePickingRepository(list: _openList());

    await pumpApp(
      tester,
      const PickListDetailScreen(pickListId: 5),
      overrides: [pickingRepositoryProvider.overrideWithValue(repo)],
    );

    await _recordPick(tester,
        productName: 'ボールペン', janCode: '4901234567894', quantity: '20');
    await _recordPick(tester,
        productName: 'ノート', janCode: '4901234567895', quantity: '10');

    await tester.tap(find.widgetWithText(FilledButton, 'ピッキング完了'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'ピッキング完了'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ピッキングを完了しました（0件不足・0件超過）'), findsOneWidget);
  });

  testWidgets('a quantity cannot be recorded before the JAN is scanned',
      (tester) async {
    final repo = FakePickingRepository(list: _openList());

    await pumpApp(
      tester,
      const PickListDetailScreen(pickListId: 5),
      overrides: [pickingRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.tap(find.text('ボールペン'));
    await tester.pumpAndSettle();

    expect(find.text('数量を確定するには対象のJANをスキャンしてください'), findsOneWidget);
    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'ピック数を記録'));
    expect(button.onPressed, isNull);

    // Tapping it anyway changes nothing — the dialog stays open, unrecorded.
    await tester.tap(find.widgetWithText(FilledButton, 'ピック数を記録'));
    await tester.pumpAndSettle();
    expect(repo.lastRecordedQuantity, isNull);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('scanning a different JAN keeps the gate shut', (tester) async {
    final repo = FakePickingRepository(list: _openList());

    await pumpApp(
      tester,
      const PickListDetailScreen(pickListId: 5),
      overrides: [pickingRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.tap(find.text('ボールペン'));
    await tester.pumpAndSettle();
    // The other task's JAN — a real picking mistake, not a typo.
    await _scanToConfirm(tester, '4901234567895');

    expect(find.text('別の商品です（対象: 4901234567894）'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'ピック数を記録'))
            .onPressed,
        isNull);

    // The right JAN then opens it.
    await _scanToConfirm(tester, '4901234567894');
    expect(find.text('スキャン確認済み'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'ピック数を記録'))
            .onPressed,
        isNotNull);
  });

  testWidgets('+1 / +5 build the quantity up once the scan is confirmed',
      (tester) async {
    final repo = FakePickingRepository(list: _openList());

    await pumpApp(
      tester,
      const PickListDetailScreen(pickListId: 5),
      overrides: [pickingRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.tap(find.text('ボールペン'));
    await tester.pumpAndSettle();
    await _scanToConfirm(tester, '4901234567894');
    await tester.enterText(find.byType(TextField).last, '0');
    await tester.tap(find.widgetWithText(OutlinedButton, '+5'));
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, '+1'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'ピック数を記録'));
    await tester.pumpAndSettle();

    expect(repo.lastRecordedQuantity, 6);
  });
}
