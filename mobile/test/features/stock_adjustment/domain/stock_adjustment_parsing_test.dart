import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/stock_adjustment/domain/adjustment_type.dart';
import 'package:wms_mobile/features/stock_adjustment/domain/stock_adjustment.dart';

void main() {
  group('StockAdjustment.fromJson', () {
    test('parses a full adjustment with nested product', () {
      final adj = StockAdjustment.fromJson(const {
        'id': 3,
        'product_id': 100,
        'type': 'damage',
        'quantity_before': 50,
        'quantity_after': 45,
        'adjustment_quantity': -5,
        'reason': 'Dropped pallet',
        'notes': 'Two cartons crushed',
        'product': {'id': 100, 'name': 'Widget A'},
        'created_at': '2026-08-08T10:00:00+00:00',
      });

      expect(adj.id, 3);
      expect(adj.productId, 100);
      expect(adj.type, AdjustmentType.damage);
      expect(adj.quantityBefore, 50);
      expect(adj.quantityAfter, 45);
      expect(adj.adjustmentQuantity, -5);
      expect(adj.reason, 'Dropped pallet');
      expect(adj.productName, 'Widget A');
      expect(adj.isIncrease, isFalse);
    });

    test('treats a positive adjustment as an increase', () {
      final adj = StockAdjustment.fromJson(const {
        'id': 1,
        'product_id': 2,
        'type': 'manual',
        'quantity_before': 10,
        'quantity_after': 18,
        'adjustment_quantity': 8,
      });

      expect(adj.isIncrease, isTrue);
      expect(adj.type, AdjustmentType.manual);
      expect(adj.productName, isNull);
    });
  });

  group('AdjustmentType', () {
    test('maps the reserved return keyword to/from the wire value', () {
      expect(AdjustmentType.returned.wire, 'return');
      expect(AdjustmentType.fromWire('return'), AdjustmentType.returned);
    });

    test('falls back to manual for unknown wire values', () {
      expect(AdjustmentType.fromWire('mystery'), AdjustmentType.manual);
      expect(AdjustmentType.fromWire(null), AdjustmentType.manual);
    });
  });
}
