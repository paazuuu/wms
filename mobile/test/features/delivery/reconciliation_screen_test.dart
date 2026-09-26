import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/delivery/application/delivery_providers.dart';
import 'package:wms_mobile/features/delivery/domain/delivery_plan.dart';
import 'package:wms_mobile/features/delivery/domain/delivery_plan_line.dart';
import 'package:wms_mobile/features/delivery/presentation/reconciliation_screen.dart';
import 'package:wms_mobile/features/purchasing/application/purchase_order_providers.dart';
import 'package:wms_mobile/features/purchasing/domain/purchase_order.dart';

import '../../support/harness.dart';

DeliveryPlan _plan() => const DeliveryPlan(
      id: 1,
      deliveryNumber: '0901',
      lines: [
        DeliveryPlanLine(
            id: 10,
            janCode: '4902505632037',
            productName: 'Pen',
            plannedQuantity: 5),
      ],
    );

void main() {
  testWidgets(
      'a permission-denied reconcile shows the friendly message, not the raw RPC text (§34)',
      (tester) async {
    final repo = FakeDeliveryRepository([_plan()])
      ..failWith = 'not permitted: receiving.confirm required';

    await pumpApp(
      tester,
      const ReconciliationScreen(planId: 1),
      overrides: [deliveryRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.pumpAndSettle();

    // Scan the full planned quantity so the plan closes clean (no outstanding
    // remainder), then confirm.
    await tester.enterText(find.byType(TextField), '4902505632037');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.enterText(find.byType(TextField), '4902505632037');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
    }

    await tester.tap(find.text('照合を完了'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完了'));
    await tester.pumpAndSettle();

    expect(find.text('この操作を行う権限がありません。'), findsOneWidget);
    expect(find.textContaining('receiving.confirm'), findsNothing);
  });

  testWidgets('a counted line offers §12 parcels, and shows what is unattributed',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeDeliveryRepository([_plan()]);

    await pumpApp(
      tester,
      const ReconciliationScreen(planId: 1),
      overrides: [deliveryRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.pumpAndSettle();

    // Nothing counted yet: a parcel of a line nobody has counted is a quantity
    // with extra steps, so it is not offered.
    expect(find.text('パーセル追加'), findsNothing);

    for (var i = 0; i < 5; i++) {
      await tester.enterText(find.byType(TextField).first, '4902505632037');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('パーセル追加'), findsOneWidget);
    expect(find.text('ロット・シリアル未記録'), findsOneWidget);

    // Record three of the five on a lot.
    await tester.tap(find.text('パーセル追加'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '数量'), '3');
    await tester.enterText(find.widgetWithText(TextField, 'ロット番号（任意）'), 'L-A');
    await tester.tap(find.widgetWithText(FilledButton, 'パーセル追加'));
    await tester.pumpAndSettle();

    // The parcel is listed, and the remainder is stated rather than hidden —
    // it is the part that will land as one unattributed parcel.
    expect(find.textContaining('L:L-A'), findsOneWidget);
    expect(find.text('未記録 2'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('removing a parcel leaves the counted quantity alone',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeDeliveryRepository([_plan()]);

    await pumpApp(
      tester,
      const ReconciliationScreen(planId: 1),
      overrides: [deliveryRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 5; i++) {
      await tester.enterText(find.byType(TextField).first, '4902505632037');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await tester.tap(find.text('パーセル追加'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '数量'), '5');
    await tester.tap(find.widgetWithText(FilledButton, 'パーセル追加'));
    await tester.pumpAndSettle();

    expect(find.text('全数記録済み'), findsOneWidget);

    await tester.tap(find.byTooltip('このパーセルを削除'));
    await tester.pumpAndSettle();

    // The five are still counted: the operator may have mis-keyed the lot on
    // cartons that did arrive.
    expect(find.text('ロット・シリアル未記録'), findsOneWidget);
    expect(find.text('5'), findsWidgets);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'an imported plan can be linked to the purchase order it delivers (0084)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final purchases = FakePurchaseOrderRepository(orders: const [
      PurchaseOrder(
        id: 9,
        status: PurchaseOrderStatus.approved,
        poNumber: 'PO-000009',
        supplierName: '新東光通商株式会社',
        warehouseId: 1,
      ),
    ]);
    await pumpApp(
      tester,
      const ReconciliationScreen(planId: 1),
      overrides: [
        deliveryRepositoryProvider.overrideWithValue(FakeDeliveryRepository([_plan()])),
        purchaseOrderRepositoryProvider.overrideWithValue(purchases),
      ],
    );

    await tester.tap(find.byTooltip('発注に紐付け'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PO-000009'));
    await tester.pumpAndSettle();

    expect(purchases.lastLink, (purchaseOrderId: 9, deliveryPlanId: 1));
    expect(find.text('PO-000009 に紐付けました'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
}
