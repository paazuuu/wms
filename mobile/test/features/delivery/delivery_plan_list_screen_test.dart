import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/delivery/application/delivery_providers.dart';
import 'package:wms_mobile/features/delivery/domain/delivery_plan.dart';
import 'package:wms_mobile/features/delivery/domain/delivery_plan_status.dart';
import 'package:wms_mobile/features/delivery/presentation/delivery_plan_list_screen.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';

import '../../support/harness.dart';

DeliveryPlan _plan(int id, String number, DeliveryPlanStatus status,
        {String? supplier}) =>
    DeliveryPlan(
      id: id,
      deliveryNumber: number,
      supplierName: supplier,
      status: status,
      lineCount: 3,
    );

void main() {
  testWidgets('an open plan can be deleted, and only an open one', (tester) async {
    final repo = FakeDeliveryRepository([
      _plan(1, '20260829-事前', DeliveryPlanStatus.open, supplier: '事前予定(Excel)'),
      _plan(2, 'D-002', DeliveryPlanStatus.partial, supplier: 'B社'),
    ]);
    await pumpApp(tester, const DeliveryPlanListScreen(),
        overrides: [deliveryRepositoryProvider.overrideWithValue(repo)]);

    // A plan already received against has no delete.
    expect(find.byKey(const ValueKey('plan-menu-2')), findsNothing);
    // Uploading again is one labelled button away.
    expect(find.byKey(const ValueKey('plan-import')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plan-menu-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('この予定を削除'));
    await tester.pumpAndSettle();
    expect(find.textContaining('「20260829-事前」を削除しますか'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('plan-delete-confirm')));
    await tester.pumpAndSettle();

    expect(repo.deleted, [1]);
    expect(find.text('20260829-事前'), findsNothing);
    expect(find.text('D-002'), findsOneWidget);
  });

  testWidgets('lists plans and filters by status chip', (tester) async {
    await pumpApp(
      tester,
      const DeliveryPlanListScreen(),
      overrides: [
        deliveryRepositoryProvider.overrideWithValue(
          FakeDeliveryRepository([
            _plan(1, 'D-001', DeliveryPlanStatus.open, supplier: 'A社'),
            _plan(2, 'D-002', DeliveryPlanStatus.partial, supplier: 'B社'),
          ]),
        ),
      ],
    );

    // Both plans visible under "All".
    expect(find.text('D-001'), findsOneWidget);
    expect(find.text('D-002'), findsOneWidget);

    // Filter to 部分納品 (partial) — only D-002 remains.
    await tester.tap(find.text('部分納品').first);
    await tester.pumpAndSettle();
    expect(find.text('D-002'), findsOneWidget);
    expect(find.text('D-001'), findsNothing);
  });

  testWidgets('receiving follows the current warehouse (§4)', (tester) async {
    final repo = FakeDeliveryRepository([
      _plan(1, 'D-001', DeliveryPlanStatus.open, supplier: 'A社'),
    ]);

    await pumpApp(
      tester,
      const DeliveryPlanListScreen(),
      overrides: [
        deliveryRepositoryProvider.overrideWithValue(repo),
        // Switching the current warehouse must switch Receiving with it.
        activeWarehouseIdProvider.overrideWith((_) => 3),
      ],
    );

    expect(repo.lastWarehouseId, 3);
  });

  testWidgets('the "all warehouses" scope sends no warehouse filter',
      (tester) async {
    final repo = FakeDeliveryRepository([
      _plan(1, 'D-001', DeliveryPlanStatus.open, supplier: 'A社'),
    ]);

    await pumpApp(
      tester,
      const DeliveryPlanListScreen(),
      overrides: [deliveryRepositoryProvider.overrideWithValue(repo)],
    );

    // A deliberate company-wide view, not a forgotten filter.
    expect(repo.lastWarehouseId, isNull);
  });
}
