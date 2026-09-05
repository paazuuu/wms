import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/shipment/data/shipment_print.dart';
import 'package:wms_mobile/features/shipment/domain/shipment.dart';

void main() {
  const printer = ShipmentPrinter();

  final shipment = Shipment.fromJson({
    'id': 1,
    'shipment_number': 'S-1',
    'customer_name': 'アクメ商事',
    'reference_no': 'ACME-00001',
    'status': 'packing',
    'lines': [
      {'id': 1, 'jan_code': '4902505632037', 'product_name': 'ボールペン', 'quantity': 100, 'unit_price': 80, 'amount': 8000},
    ],
    'cartons': [
      {
        'id': 9,
        'carton_no': 1,
        'label': 'A-1',
        'items': [
          {'jan_code': '4902505632037', 'product_name': 'ボールペン', 'quantity': 60},
        ],
      },
    ],
  });

  test('carton HTML embeds a barcode SVG for the JAN', () {
    final html = printer.cartonHtml(shipment, shipment.cartons.first);
    expect(html.contains('<svg'), isTrue);
    expect(html.contains('4902505632037'), isTrue);
    expect(html.contains('段ボール #1 / 1'), isTrue);
  });

  test('delivery slip shows recipient, amounts and totals', () {
    final html = printer.deliverySlipHtml(shipment);
    expect(html.contains('アクメ商事'), isTrue);
    expect(html.contains('御中'), isTrue);
    expect(html.contains('¥8000'), isTrue); // line + total amount
    expect(html.contains('ACME-00001'), isTrue);
  });

  test('overall list stays text-only (no barcode column)', () {
    final html = printer.overallHtml(shipment);
    expect(html.contains('<svg'), isFalse);
    expect(html.contains('出庫リスト'), isTrue);
  });
}
