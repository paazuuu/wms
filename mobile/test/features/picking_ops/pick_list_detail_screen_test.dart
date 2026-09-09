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

void main() {
  testWidgets('a short pick shows its own status, not plan rounded down',
      (tester) async {
    final repo = FakePickingRepository(list: _openList());

    await pumpApp(
      tester,
      const PickListDetailScreen(pickListId: 5),
      overrides: [pickingRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.tap(find.text('ボールペン'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '17');
    await tester.tap(find.widgetWithText(FilledButton, 'ピック数を記録'));
    await tester.pumpAndSettle();

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
    await tester.tap(find.text('ボールペン'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '20');
    await tester.tap(find.widgetWithText(FilledButton, 'ピック数を記録'));
    await tester.pumpAndSettle();

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

    await tester.tap(find.text('ボールペン'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '20');
    await tester.tap(find.widgetWithText(FilledButton, 'ピック数を記録'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ノート'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '10');
    await tester.tap(find.widgetWithText(FilledButton, 'ピック数を記録'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'ピッキング完了'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'ピッキング完了'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ピッキングを完了しました（0件不足・0件超過）'), findsOneWidget);
  });
}
