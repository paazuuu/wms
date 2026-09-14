import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/delivery/application/delivery_providers.dart';
import 'package:wms_mobile/features/delivery/domain/delivery_plan.dart';
import 'package:wms_mobile/features/delivery/domain/delivery_plan_line.dart';
import 'package:wms_mobile/features/delivery/presentation/reconciliation_screen.dart';

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
}
