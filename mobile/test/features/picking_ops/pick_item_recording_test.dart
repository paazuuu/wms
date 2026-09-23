import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/picking_ops/application/picking_ops_providers.dart';
import 'package:wms_mobile/features/picking_ops/domain/pick_list.dart';
import 'package:wms_mobile/features/picking_ops/presentation/pick_list_detail_screen.dart';

import '../../support/harness.dart';

/// §16/0074's parcel-level recording: `pick_task_candidates` advises which lot
/// to take, and `record_pick_item` *adds* a parcel rather than overwriting the
/// task's total — so a second recording pass tops up what is still
/// outstanding, not the whole plan again.
PickList _openList({String? pickingRule}) => PickList(
      id: 5,
      shipmentPlanId: 9,
      shipmentNumber: 'SHIP-0009',
      customerName: 'テスト商店',
      status: PickListStatus.picking,
      tasks: [
        PickTask(
          id: 21,
          janCode: '4901234567894',
          productId: 71,
          productName: 'ボールペン',
          plannedQuantity: 20,
          pickingRule: pickingRule,
        ),
      ],
    );

Future<void> _scanToConfirm(WidgetTester tester, String janCode) async {
  await tester.enterText(find.byType(TextField).first, janCode);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

/// Opens the record dialog for the (single) task, scans it, fills the
/// quantity and lot fields when given, and submits.
Future<void> _recordItem(
  WidgetTester tester, {
  String? quantity,
  String? lotCode,
}) async {
  await tester.tap(find.text('ボールペン'));
  await tester.pumpAndSettle();
  await _scanToConfirm(tester, '4901234567894');
  if (quantity != null) {
    await tester.enterText(find.byType(TextField).first, quantity);
  }
  if (lotCode != null) {
    await tester.enterText(find.byType(TextField).last, lotCode);
  }
  await tester.tap(find.widgetWithText(FilledButton, 'ピック数を記録'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'recording two parcels for one task shows both, each with a remove button',
      (tester) async {
    final repo = FakePickingRepository(list: _openList());

    await pumpApp(
      tester,
      const PickListDetailScreen(pickListId: 5),
      overrides: [pickingRepositoryProvider.overrideWithValue(repo)],
    );

    await _recordItem(tester, quantity: '12', lotCode: 'L-A');
    expect(repo.lastRecordedItemQuantity, 12);
    expect(repo.lastRecordedItemLotCode, 'L-A');
    expect(find.textContaining('L:L-A'), findsOneWidget);
    expect(find.textContaining('× 12'), findsOneWidget);
    // Fully unattributed-free so far: nothing left over 12 was recorded as 12.
    expect(find.textContaining('未記録'), findsNothing);

    await _recordItem(tester, lotCode: 'L-B');
    expect(repo.lastRecordedItemQuantity, 8); // topped up to the plan, not 20 again
    expect(find.textContaining('L:L-A'), findsOneWidget);
    expect(find.textContaining('L:L-B'), findsOneWidget);
    expect(find.textContaining('× 8'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNWidgets(2));
    expect(find.text('完了'), findsOneWidget); // 12 + 8 == planned 20
  });

  testWidgets(
      'the quantity field prefills with what is still outstanding, not the plan',
      (tester) async {
    final repo = FakePickingRepository(list: _openList());

    await pumpApp(
      tester,
      const PickListDetailScreen(pickListId: 5),
      overrides: [pickingRepositoryProvider.overrideWithValue(repo)],
    );

    // First pass: nothing picked yet, so the field starts at the full plan.
    await tester.tap(find.text('ボールペン'));
    await tester.pumpAndSettle();
    await _scanToConfirm(tester, '4901234567894');
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '20');
    await tester.enterText(find.byType(TextField).first, '14');
    await tester.tap(find.widgetWithText(FilledButton, 'ピック数を記録'));
    await tester.pumpAndSettle();

    // Second pass: the field now starts at what is left, not 20 again.
    await tester.tap(find.text('ボールペン'));
    await tester.pumpAndSettle();
    await _scanToConfirm(tester, '4901234567894');
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '6');
  });

  testWidgets('removing a recorded parcel takes it back off the task',
      (tester) async {
    final repo = FakePickingRepository(list: _openList());

    await pumpApp(
      tester,
      const PickListDetailScreen(pickListId: 5),
      overrides: [pickingRepositoryProvider.overrideWithValue(repo)],
    );

    await _recordItem(tester, quantity: '12', lotCode: 'L-A');
    expect(find.textContaining('L:L-A'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(repo.lastRemovedItemId, isNotNull);
    expect(find.textContaining('L:L-A'), findsNothing);

    // Outstanding is back to the full plan for a fresh recording.
    await tester.tap(find.text('ボールペン'));
    await tester.pumpAndSettle();
    await _scanToConfirm(tester, '4901234567894');
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '20');
  });

  testWidgets('the server\'s picking-rule advice is shown before recording',
      (tester) async {
    final repo = FakePickingRepository(list: _openList())
      ..candidatesResult = const PickCandidates(
        rule: 'FEFO',
        requested: 20,
        short: 0,
        candidates: [
          PickCandidate(
            stockUnitId: 900,
            quantity: 20,
            free: 20,
            take: 20,
            lotId: 3,
            lotCode: 'L-EXP',
            expiryDate: '2027-01-01',
            reason: '期限が近い順（FEFO）: 2027-01-01',
          ),
        ],
      );

    await pumpApp(
      tester,
      const PickListDetailScreen(pickListId: 5),
      overrides: [pickingRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.tap(find.text('ボールペン'));
    await tester.pumpAndSettle();

    expect(find.text('期限が近い順（FEFO）: 2027-01-01'), findsOneWidget);
    // The suggested lot pre-fills the lot code field.
    expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        'L-EXP');
  });
}
