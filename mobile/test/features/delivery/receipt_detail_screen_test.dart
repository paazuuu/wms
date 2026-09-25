// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/delivery/application/delivery_providers.dart';
import 'package:wms_mobile/features/delivery/domain/receipt_detail.dart';
import 'package:wms_mobile/features/delivery/presentation/receipt_detail_screen.dart';

import '../../support/harness.dart';

/// The receipt 0067's own functional test produced: a line of 40 sent as two
/// lots plus the five nobody attributed, and a later parcel held for QC.
ReceiptDetail _receipt() => ReceiptDetail(
      reconciliationId: 12,
      deliveryPlanId: 3,
      deliveryNumber: 'DN-1',
      referenceNo: 'SUP-00001',
      supplierName: '文具商事',
      status: 'completed',
      createdAt: DateTime(2026, 9, 20, 10, 30),
      lines: [
        ReceiptLine(
          id: 30,
          janCode: '4901234567890',
          productId: 7,
          productName: 'ボールペン',
          plannedQuantity: 40,
          actualQuantity: 46,
          status: 'over',
          items: [
            ReceiptItem(
              id: 1,
              quantity: 20,
              lotId: 27,
              lotCode: 'L-A',
              expiry: DateTime(2026, 12, 20),
              locationId: 5,
              locationCode: 'RECV-01',
              movementId: 901,
            ),
            ReceiptItem(
              id: 2,
              quantity: 15,
              lotId: 28,
              lotCode: 'L-B',
              expiry: DateTime(2026, 10, 20),
              movementId: 902,
            ),
            ReceiptItem(id: 3, quantity: 5, movementId: 903),
            ReceiptItem(
              id: 4,
              quantity: 6,
              lotId: 29,
              lotCode: 'L-C',
              statusCode: 'QC_PENDING',
              statusName: '検品待ち',
              countsAvailable: false,
              movementId: 904,
              note: 'found later',
            ),
          ],
        ),
      ],
      unlinkedItems: [
        ReceiptItem(id: 9, quantity: 3, movementId: 905),
      ],
    );

Future<void> _pump(WidgetTester tester, FakeDeliveryRepository repo) async {
  final container = ProviderContainer(overrides: [
    deliveryRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  await pumpAppWith(
      tester, container, const ReceiptDetailScreen(reconciliationId: 12));
}

void main() {
  testWidgets('shows the receipt at all three of §12\'s levels', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    final repo = FakeDeliveryRepository([])..detail = _receipt();
    await _pump(tester, repo);

    expect(repo.lastDetailId, 12);
    // Level 1: the delivery.
    expect(find.text('DN-1'), findsOneWidget);
    expect(find.text('文具商事'), findsOneWidget);
    // Level 2: the line it answers.
    expect(find.text('ボールペン'), findsOneWidget);
    expect(find.text('予定 40 / 実績 46'), findsOneWidget);
    // Level 3: the parcels.
    expect(find.text('ロット L-A'), findsOneWidget);
    expect(find.text('ロット L-B'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('an unattributed parcel is named, not left blank', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    await _pump(tester, FakeDeliveryRepository([])..detail = _receipt());

    // The remainder the server posts when nobody recorded a lot. Naming it is
    // the difference between "5 of something" and "5 we cannot trace".
    expect(find.text('ロット未記録分'), findsNWidgets(2));

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('held stock is called out on the receipt that created it',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    await _pump(tester, FakeDeliveryRepository([])..detail = _receipt());

    // §13's held stock, at the point it came into being — the figure that
    // explains a receipt whose goods are on hand and unusable.
    expect(find.text('うち 6 点は出荷できません'), findsOneWidget);
    expect(find.text('検品待ち'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('every parcel points at the ledger row it posted (§5)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    await _pump(tester, FakeDeliveryRepository([])..detail = _receipt());

    // The §5 argument on screen: the stock came from the movement, and the
    // parcel only records where the movement came from.
    expect(find.text('在庫履歴 #901'), findsOneWidget);
    expect(find.text('在庫履歴 #904'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a parcel on no ordered line still appears', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    await _pump(tester, FakeDeliveryRepository([])..detail = _receipt());

    // A carton nobody ordered is exactly the thing you want to see, so it gets
    // its own section rather than vanishing from the read.
    expect(find.text('予定外の入荷'), findsOneWidget);
    expect(find.text('在庫履歴 #905'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a receipt with no parcels says so per line', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    await _pump(
      tester,
      FakeDeliveryRepository([])
        ..detail = ReceiptDetail(
          reconciliationId: 12,
          referenceNo: 'SUP-2',
          status: 'completed',
          lines: [
            ReceiptLine(
              id: 31,
              janCode: 'X',
              productName: 'ノート',
              plannedQuantity: 5,
              actualQuantity: 5,
              status: 'matched',
            ),
          ],
        ),
    );

    expect(find.text('ロット・シリアル未記録'), findsOneWidget);
    expect(find.textContaining('出荷できません'), findsNothing);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a receipt that cannot be read shows the error, not a blank page',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    // detail left null: the fake answers 404, as the RPC does for an id the
    // caller may not see.
    await _pump(tester, FakeDeliveryRepository([]));

    expect(find.textContaining('receipt not found'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'adding a parcel by hand sends the line, the quantity and the lot',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    final repo = FakeDeliveryRepository([])..detail = _receipt();
    await _pump(tester, repo);

    await tester.tap(find.byIcon(Icons.add_box_outlined));
    await tester.pumpAndSettle();

    expect(find.text('パーセルを記録'), findsOneWidget);
    // The product the button was on, so the operator knows what they are
    // recording without needing to remember the JAN.
    expect(find.text('ボールペン'), findsWidgets);

    await tester.enterText(find.widgetWithText(TextField, '数量'), '4');
    await tester.enterText(
        find.widgetWithText(TextField, 'ロット番号（任意）'), 'L-LATE');

    await tester.tap(find.widgetWithText(FilledButton, 'パーセル追加'));
    await tester.pumpAndSettle();

    expect(repo.lastRecordedItem?.reconciliationId, 12);
    expect(repo.lastRecordedItem?.janCode, '4901234567890');
    expect(repo.lastRecordedItem?.lineId, 30);
    expect(repo.lastRecordedItem?.quantity, 4);
    expect(repo.lastRecordedItem?.lotCode, 'L-LATE');

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a refused add shows the friendly reason, not the raw RPC text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    final repo = FakeDeliveryRepository([])
      ..detail = _receipt()
      ..failRecordItemWith = 'not permitted: receiving.confirm required';
    await _pump(tester, repo);

    await tester.tap(find.byIcon(Icons.add_box_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'パーセル追加'));
    await tester.pumpAndSettle();

    expect(find.textContaining('receiving.confirm'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
}
