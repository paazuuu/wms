// Test fixtures are plain JSON-shaped literals.
// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/shipment/application/shipment_providers.dart';
import 'package:wms_mobile/features/shipment/domain/shipment.dart';
import 'package:wms_mobile/features/shipment/presentation/shipment_list_screen.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';

import '../../support/harness.dart';

Shipment _shipment() => Shipment.fromJson(<String, dynamic>{
      'id': 1,
      'shipment_number': 'S-100',
      'customer_name': 'アクメ商事',
      'status': 'open',
    });

void main() {
  testWidgets('shipping follows the current warehouse (§4)', (tester) async {
    final repo = FakeShipmentRepository([_shipment()]);

    await pumpApp(
      tester,
      const ShipmentListScreen(),
      overrides: [
        shipmentRepositoryProvider.overrideWithValue(repo),
        // Switching the current warehouse must switch Shipping with it.
        activeWarehouseIdProvider.overrideWith((_) => 3),
      ],
    );

    expect(find.text('S-100'), findsOneWidget);
    expect(repo.lastWarehouseId, 3);
  });

  testWidgets('the "all warehouses" scope sends no warehouse filter',
      (tester) async {
    final repo = FakeShipmentRepository([_shipment()]);

    await pumpApp(
      tester,
      const ShipmentListScreen(),
      overrides: [shipmentRepositoryProvider.overrideWithValue(repo)],
    );

    // A deliberate company-wide view, not a forgotten filter.
    expect(repo.lastWarehouseId, isNull);
  });
}
