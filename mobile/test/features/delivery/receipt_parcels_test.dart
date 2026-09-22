// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/delivery/domain/reconciliation.dart';

void main() {
  group('ReceivedParcel (§12, 0067)', () {
    test('sends only the fields that were filled in', () {
      final json = ReceivedParcel(
        quantity: 20,
        lotCode: 'L-A',
        expiry: DateTime(2026, 12, 20),
        locationCode: 'RECV-01',
      ).toJson();

      expect(json['quantity'], 20);
      expect(json['lot_code'], 'L-A');
      // A date, not a timestamp: the server column is a date and a timezone
      // would be a lie about what was read off the carton.
      expect(json['expiry'], '2026-12-20');
      expect(json['location_code'], 'RECV-01');
      // Absent rather than null, so the server's own defaults apply.
      expect(json.containsKey('serial_number'), isFalse);
      expect(json.containsKey('status'), isFalse);
      expect(json.containsKey('note'), isFalse);
    });

    test('an empty string is the same as not filled in', () {
      final json = ReceivedParcel(quantity: 1, lotCode: '', note: '').toJson();

      expect(json.containsKey('lot_code'), isFalse);
      expect(json.containsKey('note'), isFalse);
    });

    test('damage is sent as a status, and only ever downward (0072)', () {
      final json =
          ReceivedParcel(quantity: 4, statusCode: 'DAMAGED').toJson();

      expect(json['status'], 'DAMAGED');
    });
  });

  group('CountedItem with parcels', () {
    test('tracks what is attributed and what is not', () {
      const item = CountedItem(
        janCode: '4901234567890',
        quantity: 40,
        source: CountSource.scan,
        parcels: [
          ReceivedParcel(quantity: 20, lotCode: 'L-A'),
          ReceivedParcel(quantity: 15, lotCode: 'L-B'),
        ],
      );

      expect(item.parcelledQuantity, 35);
      // The five nobody attributed: the part that will land as one unspecified
      // parcel, which the screen shows rather than hides.
      expect(item.unattributedQuantity, 5);
      expect(item.isOverParcelled, isFalse);
    });

    test('more in the parcels than on the line is the refusable state', () {
      const item = CountedItem(
        janCode: 'X',
        quantity: 10,
        source: CountSource.manual,
        parcels: [ReceivedParcel(quantity: 12)],
      );

      expect(item.isOverParcelled, isTrue);
      expect(item.unattributedQuantity, -2);
    });
  });
}
