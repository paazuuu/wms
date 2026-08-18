import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/tracking/domain/product_batch.dart';
import 'package:wms_mobile/features/tracking/domain/product_serial.dart';

void main() {
  group('ProductBatch.fromJson', () {
    test('parses a full batch payload', () {
      final batch = ProductBatch.fromJson(const {
        'id': 7,
        'product_id': 3,
        'batch_number': 'LOT-2026-08',
        'quantity': 120,
        'manufactured_date': '2026-01-10',
        'expiry_date': '2027-01-10',
        'is_expired': false,
        'notes': 'first run',
      });

      expect(batch.id, 7);
      expect(batch.productId, 3);
      expect(batch.batchNumber, 'LOT-2026-08');
      expect(batch.quantity, 120);
      expect(batch.expiryDate, '2027-01-10');
      expect(batch.isExpired, isFalse);
      expect(batch.displayNumber, 'LOT-2026-08');
    });

    test('falls back to #id when batch number is missing', () {
      final batch = ProductBatch.fromJson(const {'id': 42, 'product_id': 3});

      expect(batch.displayNumber, '#42');
      expect(batch.quantity, 0);
      expect(batch.isExpired, isFalse);
      expect(batch.batchNumber, isNull);
    });

    test('coerces string product_id and numeric quantity', () {
      final batch = ProductBatch.fromJson(const {
        'id': 1,
        'product_id': '9',
        'quantity': 5.0,
      });

      expect(batch.productId, 9);
      expect(batch.quantity, 5);
    });
  });

  group('ProductSerial.fromJson', () {
    test('parses a full serial payload', () {
      final serial = ProductSerial.fromJson(const {
        'id': 11,
        'product_id': 3,
        'serial_number': 'SN-0001',
        'status': 'available',
        'notes': 'sealed',
      });

      expect(serial.id, 11);
      expect(serial.productId, 3);
      expect(serial.serialNumber, 'SN-0001');
      expect(serial.status, 'available');
      expect(serial.displayNumber, 'SN-0001');
    });

    test('falls back to #id when serial number is missing', () {
      final serial = ProductSerial.fromJson(const {'id': 5, 'product_id': 3});

      expect(serial.displayNumber, '#5');
      expect(serial.serialNumber, isNull);
      expect(serial.status, isNull);
    });
  });
}
