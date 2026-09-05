import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/shipment/data/shipment_print.dart';
import 'package:wms_mobile/features/shipment/domain/sender_profile.dart';
import 'package:wms_mobile/features/shipment/domain/shipment.dart';

void main() {
  const profile = SenderProfile(
    companyName: '山田倉庫株式会社',
    postalCode: '100-0001',
    phone: '03-1234-5678',
    fax: '03-1234-5679',
    registrationNumber: 'T1234567890123',
    disabled: {'fax'}, // present but off by default
  );

  test('defaultEnabled excludes empty and disabled fields', () {
    final on = profile.defaultEnabled;
    expect(on.contains('company'), isTrue);
    expect(on.contains('phone'), isTrue);
    expect(on.contains('fax'), isFalse); // disabled
    expect(on.contains('address'), isFalse); // empty
  });

  test('printText adds the right prefixes', () {
    expect(profile.printText('postal'), '〒100-0001');
    expect(profile.printText('phone'), 'TEL: 03-1234-5678');
    expect(profile.printText('regno'), '登録番号: T1234567890123');
    expect(profile.printText('company'), '山田倉庫株式会社');
    expect(profile.printText('address'), ''); // empty
  });

  test('lines respects an explicit selection', () {
    final lines = profile.lines(only: {'company', 'fax'});
    expect(lines.map((l) => l.key), ['company', 'fax']);
    expect(lines.last.text, 'FAX: 03-1234-5679');
  });

  test('round-trips through JSON', () {
    final back = SenderProfile.decode(profile.encode());
    expect(back.companyName, profile.companyName);
    expect(back.disabled, profile.disabled);
  });

  test('empty profile prints nothing', () {
    const empty = SenderProfile();
    expect(empty.isEmpty, isTrue);
    expect(empty.defaultEnabled, isEmpty);
  });

  test('sender block appears on the delivery slip when selected', () {
    const printer = ShipmentPrinter();
    final shipment = Shipment.fromJson(<String, dynamic>{
      'id': 1,
      'shipment_number': 'S-1',
      'customer_name': 'アクメ商事',
      'status': 'open',
      'lines': <dynamic>[
        <String, dynamic>{'id': 1, 'jan_code': '4902505632037', 'quantity': 5},
      ],
      'cartons': <dynamic>[],
    });
    final html = printer.deliverySlipHtml(shipment, sender: profile.lines());
    expect(html.contains('山田倉庫株式会社'), isTrue);
    expect(html.contains('TEL: 03-1234-5678'), isTrue);
    expect(html.contains('FAX'), isFalse); // fax disabled by default
  });
}
