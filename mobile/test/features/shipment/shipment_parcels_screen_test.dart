// Test fixtures are plain domain-object literals.
// ignore_for_file: prefer_const_constructors
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/shipment/application/shipment_providers.dart';
import 'package:wms_mobile/features/shipment/domain/shipment_parcel.dart';
import 'package:wms_mobile/features/shipment/presentation/shipment_parcels_screen.dart';

import '../../support/harness.dart';

/// §0075's recall-traceability read: which lots and serials actually left on
/// this shipment, and when — including a reversal shown as it happened.
void main() {
  testWidgets('the empty state explains that nothing has shipped yet',
      (tester) async {
    final repo = FakeShipmentRepository([]);

    await pumpApp(
      tester,
      const ShipmentParcelsScreen(shipmentId: 1),
      overrides: [shipmentRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.text('まだ出荷されていません'), findsOneWidget);
  });

  testWidgets(
      'shows what left the building, lot and serial, and a reversal as it happened',
      (tester) async {
    final repo = FakeShipmentRepository([])
      ..parcelsFixture = [
        ShipmentParcel(
          movementId: 501,
          movementType: 'SHIP',
          janCode: '4900000000001',
          productName: 'ペン',
          quantity: 30,
          lotCode: 'L-B',
          expiryDate: '2027-01-01',
          binCode: 'R-01-A',
        ),
        ShipmentParcel(
          movementId: 502,
          movementType: 'SHIP',
          janCode: '4900000000002',
          productName: 'ノート',
          quantity: 1,
          serialNumber: 'SN-001',
        ),
        ShipmentParcel(
          movementId: 503,
          movementType: 'SHIP_CANCEL',
          janCode: '4900000000001',
          productName: 'ペン',
          quantity: -10,
          lotCode: 'L-B',
        ),
      ];

    await pumpApp(
      tester,
      const ShipmentParcelsScreen(shipmentId: 1),
      overrides: [shipmentRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.text('+30'), findsOneWidget);
    expect(find.textContaining('L:L-B'), findsWidgets);
    expect(find.textContaining('(2027-01-01)'), findsOneWidget);
    expect(find.textContaining('S/N:SN-001'), findsOneWidget);
    expect(find.textContaining('R-01-A'), findsOneWidget);

    // The reversal is shown, signed, and tagged — not hidden.
    expect(find.text('-10'), findsOneWidget);
    expect(find.text('取消分'), findsOneWidget);
  });
}
