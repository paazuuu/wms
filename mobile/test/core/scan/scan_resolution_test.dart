import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/scan/scan_resolution.dart';

void main() {
  group('ScanResolution', () {
    test('a product barcode carries the product, its unit and the multiplier',
        () {
      // A case code: one scan is twelve pieces, and 0059 derives that 12 from
      // the product's own BOX conversion rather than from a free number.
      final hit = ScanResolution.fromJson(const {
        'kind': 'product',
        'barcode': '14901234567895',
        'barcode_type': 'CASE',
        'quantity_per_scan': 12,
        'uom': 'BOX',
        'base_uom': 'PCS',
        'is_primary': false,
        'product_id': 7,
        'jan_code': '4901234567890',
        'sku': 'PEN-001',
        'name': 'ボールペン',
        'tracking_mode': 'UNTRACKED',
        'status': 'active',
      });

      expect(hit.kind, ScanKind.product);
      expect(hit.isGoods, isTrue);
      expect(hit.productId, 7);
      expect(hit.uom, 'BOX');
      expect(hit.baseUom, 'PCS');
      expect(hit.isPrimary, isFalse);
      // The number a counting screen adds per scan.
      expect(hit.countedQuantity, 12);
    });

    test('a plain JAN counts one', () {
      final hit = ScanResolution.fromJson(const {
        'kind': 'product',
        'barcode': '4901234567890',
        'barcode_type': 'JAN',
        'quantity_per_scan': 1,
        'is_primary': true,
        'product_id': 7,
        'name': 'ボールペン',
      });
      expect(hit.countedQuantity, 1);
      expect(hit.isPrimary, isTrue);
      expect(hit.uom, isNull);
    });

    test('a serial resolves to one unit of its product, with its lot', () {
      final hit = ScanResolution.fromJson(const {
        'kind': 'serial',
        'barcode': 'SN-0042',
        'serial_id': 5,
        'serial_number': 'SN-0042',
        'serial_status': 'IN_STOCK',
        'lot_id': 3,
        'lot_code': 'A-2024/05',
        'expiry_date': '2027-03-31',
        'quantity_per_scan': 1,
        'base_uom': 'PCS',
        'product_id': 7,
        'name': 'ボールペン',
        'tracking_mode': 'LOT_AND_SERIAL',
      });

      expect(hit.kind, ScanKind.serial);
      expect(hit.isGoods, isTrue);
      expect(hit.serialNumber, 'SN-0042');
      expect(hit.serialStatus, 'IN_STOCK');
      expect(hit.lotCode, 'A-2024/05');
      expect(hit.expiryDate, DateTime.parse('2027-03-31'));
      // One serial is one physical unit, whatever the payload says.
      expect(hit.countedQuantity, 1);
      expect(hit.productId, 7);
    });

    test('a location carries what may be done there', () {
      final hit = ScanResolution.fromJson(const {
        'kind': 'location',
        'barcode': 'SHELFZ1R01S3',
        'location_id': 9,
        'code': 'Z1-R-01-S3',
        'name': '棚3',
        'location_type': 'PICKING',
        'warehouse_id': 1,
        'bin_id': 4,
        'zone_id': null,
        'is_active': true,
        'pickable': true,
        'receivable': false,
        'quarantine': false,
        'is_virtual': false,
      });

      expect(hit.kind, ScanKind.location);
      // Not goods: a put-away screen wants this, a counting screen does not.
      expect(hit.isGoods, isFalse);
      expect(hit.countedQuantity, 0);
      expect(hit.locationCode, 'Z1-R-01-S3');
      expect(hit.locationType, 'PICKING');
      expect(hit.binId, 4);
      expect(hit.pickable, isTrue);
      expect(hit.receivable, isFalse);
    });

    test('an unrecognised code is a kind, not an error', () {
      final hit = ScanResolution.fromJson(const {
        'kind': 'unknown',
        'barcode': '9999999999999',
      });
      expect(hit.kind, ScanKind.unknown);
      expect(hit.isUnknown, isTrue);
      expect(hit.isGoods, isFalse);
      expect(hit.countedQuantity, 0);
      expect(hit.productId, isNull);
    });

    test('a kind this build does not know reads as unknown, not as a crash', () {
      // Forward compatibility: a later migration may add a kind (a pallet, a
      // carton) and an older build must degrade rather than throw.
      final hit = ScanResolution.fromJson(const {
        'kind': 'pallet',
        'barcode': 'PAL-1',
      });
      expect(hit.kind, ScanKind.unknown);
      expect(hit.barcode, 'PAL-1');
    });

    test('empty strings come back as null, not as blanks on screen', () {
      final hit = ScanResolution.fromJson(const {
        'kind': 'product',
        'barcode': '4901234567890',
        'sku': '',
        'uom': '   ',
        'name': 'ペン',
      });
      expect(hit.sku, isNull);
      expect(hit.uom, isNull);
      expect(hit.name, 'ペン');
    });
  });
}
