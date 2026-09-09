import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/picking_ops/application/picking_ops_providers.dart';
import 'package:wms_mobile/features/picking_ops/domain/pick_list.dart';
import 'package:wms_mobile/features/picking_ops/presentation/pick_list_index_screen.dart';
import 'package:wms_mobile/features/shipment/application/shipment_providers.dart';
import 'package:wms_mobile/features/shipment/domain/shipment.dart';

import '../../support/harness.dart';

void main() {
  testWidgets('starting a pick asks which open shipment, then opens it',
      (tester) async {
    const shipment = Shipment(
      id: 9,
      shipmentNumber: 'SHIP-0009',
      customerName: 'テスト商店',
      lines: [],
    );
    final list = PickList(
      id: 5,
      shipmentPlanId: 9,
      shipmentNumber: shipment.shipmentNumber,
      customerName: shipment.customerName,
      status: PickListStatus.picking,
      tasks: const [
        PickTask(
          id: 21,
          janCode: '4901234567894',
          productName: 'ボールペン',
          plannedQuantity: 20,
        ),
      ],
    );
    final shipmentRepo = FakeShipmentRepository([shipment]);
    final pickingRepo = FakePickingRepository(list: list, started: false);

    await pumpApp(
      tester,
      const PickListIndexScreen(),
      overrides: [
        shipmentRepositoryProvider.overrideWithValue(shipmentRepo),
        pickingRepositoryProvider.overrideWithValue(pickingRepo),
      ],
    );

    expect(find.text('ピッキング対象がありません。'), findsOneWidget);

    await tester.tap(find.text('ピッキング開始'));
    await tester.pumpAndSettle();

    expect(find.text('SHIP-0009'), findsWidgets);
    await tester.tap(find.text('テスト商店').first);
    await tester.pumpAndSettle();

    // The new pick list's own detail screen is now showing.
    expect(find.text('ボールペン'), findsOneWidget);
  });
}
