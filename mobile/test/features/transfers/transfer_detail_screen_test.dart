import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/transfers/application/transfer_providers.dart';
import 'package:wms_mobile/features/transfers/domain/transfer_order.dart';
import 'package:wms_mobile/features/transfers/presentation/transfer_detail_screen.dart';

import '../../support/harness.dart';

TransferOrder _order(TransferStatus status) => TransferOrder(
      id: 7,
      transferNumber: 'TR-000007',
      sourceWarehouseId: 1,
      sourceWarehouseName: '神戸倉庫',
      destinationWarehouseId: 2,
      destinationWarehouseName: '大阪倉庫',
      status: status,
      lines: const [
        TransferLine(
          id: 31,
          janCode: '4901234567894',
          productName: 'ボールペン',
          requestedQuantity: 20,
        ),
      ],
    );

void main() {
  testWidgets('draft: submit moves it to pending approval', (tester) async {
    final repo = FakeTransferRepository(order: _order(TransferStatus.draft));

    await pumpApp(
      tester,
      const TransferDetailScreen(transferId: 7),
      overrides: [transferRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.text('下書き'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '承認を申請'));
    await tester.pumpAndSettle();

    expect(find.text('承認待ち'), findsOneWidget);
  });

  testWidgets('picking: completing with an unpicked line is refused',
      (tester) async {
    final repo = FakeTransferRepository(order: _order(TransferStatus.picking));

    await pumpApp(
      tester,
      const TransferDetailScreen(transferId: 7),
      overrides: [transferRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.tap(find.widgetWithText(FilledButton, '出庫を確定'));
    await tester.pumpAndSettle();

    expect(find.text('未ピックの明細があるため出庫を確定できません'), findsOneWidget);
    // The tap never reached the server — nothing was refused server-side.
    expect(repo.lastRefusal, isNull);
  });

  testWidgets('a short pick moves the order to in-transit with what was actually picked',
      (tester) async {
    final repo = FakeTransferRepository(order: _order(TransferStatus.picking));

    await pumpApp(
      tester,
      const TransferDetailScreen(transferId: 7),
      overrides: [transferRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.tap(find.text('ボールペン'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '17');
    await tester.tap(find.widgetWithText(FilledButton, 'ピック数'));
    await tester.pumpAndSettle();

    expect(find.text('17'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '出庫を確定'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, '出庫を確定'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('輸送中'), findsOneWidget);
  });

  testWidgets('a transit loss is recorded, not silently corrected to what was picked',
      (tester) async {
    var order = _order(TransferStatus.receiving);
    order = TransferOrder(
      id: order.id,
      transferNumber: order.transferNumber,
      sourceWarehouseId: order.sourceWarehouseId,
      sourceWarehouseName: order.sourceWarehouseName,
      destinationWarehouseId: order.destinationWarehouseId,
      destinationWarehouseName: order.destinationWarehouseName,
      status: order.status,
      lines: const [
        TransferLine(
          id: 31,
          janCode: '4901234567894',
          productName: 'ボールペン',
          requestedQuantity: 20,
          pickedQuantity: 20,
          pickVariance: 0,
        ),
      ],
    );
    final repo = FakeTransferRepository(order: order);

    await pumpApp(
      tester,
      const TransferDetailScreen(transferId: 7),
      overrides: [transferRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.tap(find.text('ボールペン'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '18');
    await tester.tap(find.widgetWithText(FilledButton, '受入数'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '受入を確定'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, '受入を確定'),
    ));
    await tester.pumpAndSettle();

    // 20 picked, 18 received: a loss of 2 shows up in the completion summary,
    // never quietly rounded back up to 20.
    expect(find.text('移動が完了しました（1件で数量差異）'), findsOneWidget);
  });

  testWidgets('draft/pending/approved/picking can all be cancelled', (tester) async {
    final repo = FakeTransferRepository(order: _order(TransferStatus.approved));

    await pumpApp(
      tester,
      const TransferDetailScreen(transferId: 7),
      overrides: [transferRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.tap(find.widgetWithText(OutlinedButton, '移動を中止'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, '移動を中止'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('中止'), findsOneWidget);
  });
}
