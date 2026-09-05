import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/delivery/application/delivery_providers.dart';
import 'package:wms_mobile/features/delivery/domain/delivery_plan.dart';
import 'package:wms_mobile/features/delivery/domain/delivery_plan_status.dart';
import 'package:wms_mobile/features/delivery/presentation/delivery_plan_list_screen.dart';

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
}
