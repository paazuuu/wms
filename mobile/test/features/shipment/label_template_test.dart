import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/shipment/data/shipment_print.dart';
import 'package:wms_mobile/features/shipment/domain/carton.dart';
import 'package:wms_mobile/features/shipment/domain/label_template.dart';
import 'package:wms_mobile/features/shipment/domain/sender_profile.dart';
import 'package:wms_mobile/features/shipment/domain/shipment.dart';
import 'package:wms_mobile/features/shipment/domain/shipment_line.dart';

Shipment _shipment({List<Carton> cartons = const []}) => Shipment(
      id: 1,
      shipmentNumber: 'SHP-000123',
      customerName: 'アクメ商事',
      lines: const [
        ShipmentLine(id: 1, janCode: '4988601001053', productName: 'ペン', quantity: 24),
        ShipmentLine(id: 2, janCode: '4901234567890', productName: 'ノート', quantity: 10),
      ],
      cartons: cartons,
    );

Carton _carton(int no, List<CartonItem> items) =>
    Carton(id: no, cartonNo: no, items: items);

void main() {
  group('LabelTemplate', () {
    test('fills variables and trims whitespace around them', () {
      expect(
        LabelTemplate.fill('箱 {{carton_no}} / {{ carton_total }}',
            {'carton_no': '2', 'carton_total': ' 10 '}),
        '箱 2 / 10',
      );
    });

    test('an unknown or null variable renders empty, never as {{name}}', () {
      // A label with a literal {{lot}} printed on it is worse than one with the
      // row left out.
      expect(LabelTemplate.fill('ロット {{lot}}', {}), 'ロット ');
      expect(LabelTemplate.fill('ロット {{lot}}', {'lot': null}), 'ロット ');
    });

    test('render drops rows whose variables all came out empty', () {
      const t = LabelTemplate(
        id: 't',
        name: 't',
        lines: ['{{company}}', 'JAN {{jan}}', 'ロット {{lot}}', '数量 {{quantity}}'],
      );

      expect(
        t.render({'company': '', 'jan': '4988601001053', 'quantity': '24'}),
        ['JAN 4988601001053', '数量 24'],
      );
    });

    test('renderQr/renderCode return null when the payload is empty', () {
      const t = LabelTemplate(
          id: 't', name: 't', codeVariable: '{{jan}}', qrVariable: '{{sku}}', lines: []);

      expect(t.renderCode({'jan': '4988601001053'}), '4988601001053');
      expect(t.renderCode({}), isNull);
      expect(t.renderQr({}), isNull);
    });

    test('the carton template carries the box identity in its QR (§17)', () {
      final qr = LabelTemplates.carton.renderQr({
        'shipment_no': 'SHP-000123',
        'carton_no': '2',
        'carton_total': '10',
      });

      expect(qr, 'SHP:SHP-000123|BOX:2/10');
    });
  });

  group('ShipmentPrinter carton labels', () {
    const printer = ShipmentPrinter();

    test('a single-SKU box names the item and carries its JAN', () {
      final carton = _carton(1, const [
        CartonItem(janCode: '4988601001053', productName: 'ペン', quantity: 24),
      ]);
      final shipment = _shipment(cartons: [carton]);

      final values = printer.cartonLabelValues(shipment, carton,
          sender: const [SenderLine('company', 'テスト株式会社')],
          warehouseName: '東京倉庫');

      expect(values['product_name'], 'ペン');
      expect(values['jan'], '4988601001053');
      expect(values['quantity'], '24');
      expect(values['carton_no'], '1');
      expect(values['carton_total'], '1');
      expect(values['company'], 'テスト株式会社');
      expect(values['warehouse'], '東京倉庫');
    });

    test('a mixed box says how many kinds are inside instead of naming one',
        () {
      final carton = _carton(1, const [
        CartonItem(janCode: '4988601001053', productName: 'ペン', quantity: 4),
        CartonItem(janCode: '4901234567890', productName: 'ノート', quantity: 2),
      ]);
      final shipment = _shipment(cartons: [carton]);

      final values = printer.cartonLabelValues(shipment, carton);

      // Printing one of the two names would be a label that lies about the rest.
      expect(values['product_name'], '2 品目');
      expect(values['jan'], isNull);
      expect(values['quantity'], '6');
    });

    test('the label HTML has the QR, the rows, and no empty lot row', () {
      final carton = _carton(2, const [
        CartonItem(janCode: '4988601001053', productName: 'ペン', quantity: 24),
      ]);
      final shipment = _shipment(cartons: [carton, _carton(1, const [])]);

      final html = printer.cartonLabelHtml(shipment, carton);

      expect(html, contains('SHP-000123'));
      expect(html, contains('箱 2 / 2'));
      expect(html, contains('数量 24'));
      // A QR and a barcode are both drawn as inline SVG — no network fetch.
      expect(html, contains('<svg'));
      expect(html, isNot(contains('{{')));
      expect(html, isNot(contains('ロット')));
    });

    test('every carton label lands in one document, one page each', () {
      final cartons = [
        _carton(1, const [CartonItem(janCode: '4988601001053', quantity: 24)]),
        _carton(2, const [CartonItem(janCode: '4901234567890', quantity: 10)]),
      ];
      final shipment = _shipment(cartons: cartons);

      final html = printer.allCartonLabelsHtml(shipment);

      expect(html, contains('箱 1 / 2'));
      expect(html, contains('箱 2 / 2'));
      // One <html> shell, two labels.
      expect('<!doctype html>'.allMatches(html).length, 1);
      expect('class="label"'.allMatches(html).length, 2);
    });

    test('escapes customer names that contain markup', () {
      final carton = _carton(1, const [
        CartonItem(janCode: '4988601001053', quantity: 1),
      ]);
      final shipment = Shipment(
        id: 1,
        shipmentNumber: 'SHP-1',
        customerName: '<script>x</script>',
        cartons: [carton],
      );

      final html = printer.cartonLabelHtml(shipment, carton);

      expect(html, isNot(contains('<script>')));
      expect(html, contains('&lt;script&gt;'));
    });
  });
}
