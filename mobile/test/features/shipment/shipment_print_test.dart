// Test fixtures are plain JSON-shaped literals.
// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/shipment/data/shipment_print.dart';
import 'package:wms_mobile/features/shipment/domain/shipment.dart';
import 'package:wms_mobile/features/transfers/domain/transfer_order.dart';

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

  test('a carton where every parcel agrees on one lot prints that lot', () {
    final oneLot = Shipment.fromJson({
      'id': 2,
      'shipment_number': 'S-2',
      'customer_name': 'アクメ商事',
      'status': 'packing',
      'lines': [],
      'cartons': [
        {
          'id': 20,
          'carton_no': 1,
          'items': [
            {
              'jan_code': '4902505632037',
              'product_name': 'ボールペン',
              'quantity': 10,
              'lot_code': 'L-A',
            },
            {
              'jan_code': '4902505632037',
              'product_name': 'ボールペン',
              'quantity': 5,
              'lot_code': 'L-A',
            },
          ],
        },
      ],
    });

    final values =
        printer.cartonLabelValues(oneLot, oneLot.cartons.first);
    expect(values['lot'], 'L-A');

    final html = printer.cartonLabelHtml(oneLot, oneLot.cartons.first);
    expect(html.contains('ロット L-A'), isTrue);
  });

  test('a carton split across two lots of the same JAN prints no lot row',
      () {
    final twoLots = Shipment.fromJson({
      'id': 3,
      'shipment_number': 'S-3',
      'customer_name': 'アクメ商事',
      'status': 'packing',
      'lines': [],
      'cartons': [
        {
          'id': 30,
          'carton_no': 1,
          'items': [
            {
              'jan_code': '4902505632037',
              'product_name': 'ボールペン',
              'quantity': 10,
              'lot_code': 'L-A',
            },
            {
              'jan_code': '4902505632037',
              'product_name': 'ボールペン',
              'quantity': 5,
              'lot_code': 'L-B',
            },
          ],
        },
      ],
    });

    final values =
        printer.cartonLabelValues(twoLots, twoLots.cartons.first);
    expect(values['lot'], isNull);

    // The template's own row is dropped entirely, not printed blank.
    final html = printer.cartonLabelHtml(twoLots, twoLots.cartons.first);
    expect(html.contains('ロット'), isFalse);
  });

  test('a transfer prints the same 送り状 as a shipment, with origin and destination country (0087)', () {
    final transfer = TransferOrder.fromJson({
      'id': 3,
      'transfer_number': 'TR-000003',
      'source_warehouse_id': 1,
      'source_warehouse_name': '東京倉庫',
      'destination_warehouse_id': 2,
      'destination_warehouse_name': '上海倉庫',
      'destination_country_code': 'CN',
      'destination_address': '上海市',
      'cross_border': true,
      'exports': true,
      'status': 'EXPORTED',
      'shipped_at': '2026-09-26T03:00:00Z',
      'lines': [
        {'id': 1, 'jan_code': '4902505632037', 'product_name': 'ボールペン', 'requested_quantity': 10, 'picked_quantity': 8},
        {'id': 2, 'jan_code': '4900000000000', 'product_name': '消しゴム', 'requested_quantity': 5, 'picked_quantity': 0},
      ],
    });
    final html = printer.transferSlipHtml(transfer);
    final slip = printer.deliverySlipHtml(shipment);

    // One layout: the same title and table head as a shipment's slip.
    expect(html.contains('送&nbsp;り&nbsp;状'), isTrue);
    expect(slip.contains('送&nbsp;り&nbsp;状'), isTrue);
    expect(html.contains('<th>JAN</th><th>品名</th><th>規格</th><th class="num">数量</th>'), isTrue);
    expect(html.contains('上海倉庫'), isTrue);
    expect(html.contains('上海市'), isTrue);
    expect(html.contains('出荷元：東京倉庫'), isTrue);
    expect(html.contains('仕向国：CN'), isTrue);
    expect(html.contains('出庫番号：TR-000003'), isTrue);
    // What actually left: 8, and the line nothing was picked for is left off.
    expect(html.contains('<td class="num">8</td>'), isTrue);
    expect(html.contains('消しゴム'), isFalse);
  });
}
