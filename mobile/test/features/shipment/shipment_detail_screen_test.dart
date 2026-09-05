// Test fixtures are plain JSON-shaped literals.
// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/shipment/application/shipment_providers.dart';
import 'package:wms_mobile/features/shipment/domain/shipment.dart';
import 'package:wms_mobile/features/shipment/presentation/shipment_detail_screen.dart';

import '../../support/harness.dart';

Shipment _shipment() => Shipment.fromJson(<String, dynamic>{
      'id': 1,
      'shipment_number': 'S-100',
      'customer_name': 'アクメ商事',
      'reference_no': 'ACME-00001',
      'status': 'open',
      'lines': <dynamic>[
        <String, dynamic>{
          'id': 1,
          'jan_code': '4902505632037',
          'product_name': 'ペン',
          'quantity': 100,
        },
      ],
      'cartons': <dynamic>[
        <String, dynamic>{
          'id': 9,
          'carton_no': 1,
          'label': 'A-1',
          'items': <dynamic>[
            <String, dynamic>{
              'jan_code': '4902505632037',
              'product_name': 'ペン',
              'quantity': 60,
            },
          ],
        },
      ],
    });

void main() {
  testWidgets('shows header, carton and the confirm action', (tester) async {
    await pumpApp(
      tester,
      const ShipmentDetailScreen(shipmentId: 1),
      overrides: [
        shipmentRepositoryProvider
            .overrideWithValue(FakeShipmentRepository([_shipment()])),
      ],
    );

    // Header shows the customer and reference.
    expect(find.text('アクメ商事'), findsOneWidget);
    expect(find.textContaining('ACME-00001'), findsWidgets);
    // The line and carton render.
    expect(find.text('ペン'), findsWidgets);
    expect(find.textContaining('段ボール #1'), findsOneWidget);
    // Sticky confirm action for an open shipment.
    expect(find.text('出庫確定'), findsOneWidget);
  });
}
