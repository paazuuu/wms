// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/scan/scan_context.dart';
import 'package:wms_mobile/core/scan/scan_resolution.dart';

/// What `resolve_barcode` returns for a shelf label scanned during put-away:
/// exactly what that step is waiting for.
Map<String, dynamic> _location() => {
      'kind': 'location',
      'barcode': 'A-01',
      'location_id': 5,
      'code': 'A-01',
      'location_type': 'PICKING',
      'warehouse_id': 1,
      'bin_id': 9,
      'context': 'PUTAWAY',
      'expected': true,
      'expected_rank': 1,
      'context_expects': ['location', 'product', 'lot', 'serial', 'task'],
    };

/// The same put-away step, handed a product barcode. It resolves, and it is
/// something put-away does use — just not the thing it asked for first.
Map<String, dynamic> _productDuringPutaway() => {
      'kind': 'product',
      'barcode': '4901234567890',
      'product_id': 7,
      'jan_code': '4901234567890',
      'name': 'ボールペン',
      'quantity_per_scan': 12,
      'uom': 'CASE',
      'base_uom': 'PCS',
      'requires_inspection': true,
      'context': 'PUTAWAY',
      'expected': true,
      'expected_rank': 2,
      'context_expects': ['location', 'product', 'lot', 'serial', 'task'],
    };

/// A shipment number during put-away: real code, wrong step.
Map<String, dynamic> _shipmentDuringPutaway() => {
      'kind': 'shipment',
      'barcode': 'SH-100',
      'shipment_plan_id': 3,
      'shipment_number': 'SH-100',
      'customer_name': '山田商店',
      'status': 'planned',
      'context': 'PUTAWAY',
      'expected': false,
      'context_expects': ['location', 'product', 'lot', 'serial', 'task'],
    };

Map<String, dynamic> _ambiguousLot() => {
      'kind': 'ambiguous',
      'barcode': 'SHARED-LOT',
      'would_be': 'lot',
      'reason': 'a lot code identifies a lot only within its product',
      'candidates': [
        {
          'lot_id': 1,
          'lot_code': 'SHARED-LOT',
          'product_id': 7,
          'jan_code': '4901111111111',
          'name': '商品A',
          'expiry_date': '2026-10-01',
        },
        {
          'lot_id': 2,
          'lot_code': 'SHARED-LOT',
          'product_id': 8,
          'jan_code': '4902222222222',
          'name': '商品B',
          'expiry_date': '2026-11-01',
        },
      ],
      'context': 'QC',
      'expected': false,
    };

void main() {
  group('ScanContext', () {
    test('reads the codes the server publishes, and shrugs at unknown ones', () {
      expect(ScanContext.fromCode('PUTAWAY'), ScanContext.putaway);
      // Case-insensitive, because the code arrives from JSON and from enums.
      expect(ScanContext.fromCode('putaway'), ScanContext.putaway);
      expect(ScanContext.fromCode('NOT_A_STEP'), isNull);
      expect(ScanContext.fromCode(null), isNull);
      expect(ScanContext.fromCode(''), isNull);
    });
  });

  group('ScanResolution in a context', () {
    test('a shelf label during put-away is what the step asked for', () {
      final r = ScanResolution.fromJson(_location());

      expect(r.kind, ScanKind.location);
      expect(r.context, ScanContext.putaway);
      expect(r.expected, isTrue);
      expect(r.expectedRank, 1);
      expect(r.isOutOfContext, isFalse);
      expect(r.locationCode, 'A-01');
      // The whole ordered list comes back, so a screen can prompt with it.
      expect(r.contextExpects.first, ScanKind.location);
      expect(r.contextExpects, contains(ScanKind.task));
    });

    test('a product during put-away is expected, just not first', () {
      final r = ScanResolution.fromJson(_productDuringPutaway());

      // The distinction that matters: expected is membership, not first place.
      expect(r.expected, isTrue);
      expect(r.expectedRank, 2);
      expect(r.isOutOfContext, isFalse);
      // A case code still means twelve.
      expect(r.countedQuantity, 12);
      // And the screen can warn before the quantity is keyed, not after.
      expect(r.requiresInspection, isTrue);
    });

    test('a shipment number during put-away resolves but is out of context', () {
      final r = ScanResolution.fromJson(_shipmentDuringPutaway());

      expect(r.kind, ScanKind.shipment);
      expect(r.isUnknown, isFalse);
      // Not "I do not know this code" but "this is not what you need now",
      // which is a different thing to tell an operator.
      expect(r.isOutOfContext, isTrue);
      expect(r.isDocument, isTrue);
      expect(r.isGoods, isFalse);
      expect(r.shipmentNumber, 'SH-100');
      expect(r.documentStatus, 'planned');
      // Nothing to count: a shipment is not stock in your hand.
      expect(r.countedQuantity, 0);
    });

    test('an ambiguous lot hands back the candidates instead of guessing', () {
      final r = ScanResolution.fromJson(_ambiguousLot());

      expect(r.kind, ScanKind.ambiguous);
      expect(r.ambiguityReason, contains('only within its product'));
      expect(r.candidates, hasLength(2));
      expect(r.candidates.map((c) => c.name), ['商品A', '商品B']);
      expect(r.candidates.first.expiryDate, DateTime(2026, 10, 1));
      // It is not a failure, but it is not usable yet either.
      expect(r.isUnknown, isFalse);
      expect(r.countedQuantity, 0);
    });

    test('a lot resolved against a known product is exact', () {
      final r = ScanResolution.fromJson({
        'kind': 'lot',
        'barcode': 'L-A',
        'lot_id': 11,
        'lot_code': 'L-A',
        'expiry_date': '2026-12-31',
        'manufacture_date': '2026-01-05',
        'is_expired': false,
        'product_id': 7,
        'jan_code': '4901234567890',
        'name': 'ボールペン',
        'context': 'QC',
        'expected': true,
        'expected_rank': 1,
      });

      expect(r.kind, ScanKind.lot);
      expect(r.isGoods, isTrue);
      expect(r.lotId, 11);
      expect(r.expiryDate, DateTime(2026, 12, 31));
      expect(r.manufactureDate, DateTime(2026, 1, 5));
      expect(r.isExpired, isFalse);
      // A lot scan says *which*, not *how many*.
      expect(r.countedQuantity, 0);
    });

    test('a printed task label carries what it points at', () {
      final r = ScanResolution.fromJson({
        'kind': 'inspection',
        'task_type': 'inspection',
        'barcode': 'QC-3',
        'inspection_id': 3,
        'status': 'PENDING',
        'warehouse_id': 1,
        'reconciliation_id': 12,
        'context': 'QC',
        'expected': true,
        'expected_rank': 4,
      });

      expect(r.isTask, isTrue);
      expect(r.taskType, 'inspection');
      expect(r.inspectionId, 3);
      expect(r.reconciliationId, 12);
      expect(r.documentStatus, 'PENDING');
    });

    test('with no context nothing can be out of context', () {
      final r = ScanResolution.fromJson({
        'kind': 'product',
        'barcode': '4901234567890',
        'product_id': 7,
      });

      expect(r.context, isNull);
      expect(r.expected, isFalse);
      // The screen did not say what it wanted, so the resolver cannot say the
      // scan was wrong — and this must not read as a rejection.
      expect(r.isOutOfContext, isFalse);
    });
  });
}
