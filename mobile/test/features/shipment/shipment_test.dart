import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/shipment/domain/shipment.dart';
import 'package:wms_mobile/features/shipment/domain/shipment_status.dart';

void main() {
  final json = {
    'id': 7,
    'shipment_number': 'S-0001',
    'customer_name': 'Acme',
    'reference_no': 'ACME-00001',
    'status': 'packing',
    'lines': [
      {'id': 1, 'jan_code': '4902505632037', 'product_name': 'Pen', 'quantity': 100},
      {'id': 2, 'jan_code': '4901480241418', 'product_name': 'Stapler', 'quantity': 20},
    ],
    'cartons': [
      {
        'id': 11,
        'carton_no': 1,
        'label': 'A-1',
        'items': [
          {'jan_code': '4902505632037', 'quantity': 60, 'shipment_line_id': 1},
        ],
      },
      {
        'id': 12,
        'carton_no': 2,
        'items': [
          {'jan_code': '4902505632037', 'quantity': 40, 'shipment_line_id': 1},
          {'jan_code': '4901480241418', 'quantity': 20, 'shipment_line_id': 2},
        ],
      },
    ],
  };

  test('parses lines, cartons and status', () {
    final s = Shipment.fromJson(json);
    expect(s.status, ShipmentStatus.packing);
    expect(s.lineCount, 2);
    expect(s.totalUnits, 120);
    expect(s.cartons.length, 2);
    expect(s.cartons.first.cartonNo, 1);
    expect(s.cartons.first.totalUnits, 60);
  });

  test('packedByJan sums a line split across cartons', () {
    final s = Shipment.fromJson(json);
    final packed = s.packedByJan;
    expect(packed['4902505632037'], 100); // 60 + 40, fully packed
    expect(packed['4901480241418'], 20);
  });

  test('cartons are ordered by carton number', () {
    final s = Shipment.fromJson(json);
    expect(s.cartons.map((c) => c.cartonNo), [1, 2]);
  });
}
