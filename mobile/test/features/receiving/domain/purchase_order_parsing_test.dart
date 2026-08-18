import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/receiving/domain/purchase_order.dart';
import 'package:wms_mobile/features/receiving/domain/purchase_order_item.dart';

void main() {
  group('PurchaseOrder.fromJson', () {
    test('parses a full purchase order with nested supplier and items', () {
      final po = PurchaseOrder.fromJson(const {
        'id': 7,
        'po_number': 'PO-2026-007',
        'status': 'partial',
        'status_label': 'Partially received',
        'supplier': {'id': 3, 'name': 'Acme Supply'},
        'order_date': '2026-08-01',
        'expected_date': '2026-08-10',
        'currency': 'JPY',
        'total': 12500,
        'items_count': 2,
        'can_receive_items': true,
        'items': [
          {
            'id': 11,
            'product_id': 100,
            'product_name': 'Widget A',
            'sku': 'WID-A',
            'quantity_ordered': 10,
            'quantity_received': 4,
            'remaining_quantity': 6,
            'is_fully_received': false,
          },
          {
            'id': 12,
            'product_id': 101,
            'product_name': 'Widget B',
            'sku': 'WID-B',
            'quantity_ordered': 5,
            'quantity_received': 5,
            'remaining_quantity': 0,
            'is_fully_received': true,
          },
        ],
      });

      expect(po.id, 7);
      expect(po.poNumber, 'PO-2026-007');
      expect(po.status, PurchaseOrderStatus.partial);
      expect(po.statusLabel, 'Partially received');
      expect(po.supplierName, 'Acme Supply');
      expect(po.currency, 'JPY');
      expect(po.total, '12500');
      expect(po.itemsCount, 2);
      expect(po.canReceiveItems, isTrue);
      expect(po.items, hasLength(2));
    });

    test('receivableItems keeps only lines with quantity remaining', () {
      final po = PurchaseOrder.fromJson(const {
        'id': 1,
        'po_number': 'PO-1',
        'status': 'sent',
        'items': [
          {
            'id': 1,
            'product_name': 'Has remaining',
            'sku': 'A',
            'quantity_ordered': 10,
            'quantity_received': 3,
            'remaining_quantity': 7,
          },
          {
            'id': 2,
            'product_name': 'Fully received',
            'sku': 'B',
            'quantity_ordered': 4,
            'quantity_received': 4,
            'remaining_quantity': 0,
          },
        ],
      });

      final receivable = po.receivableItems;
      expect(receivable, hasLength(1));
      expect(receivable.single.id, 1);
    });

    test('tolerates missing/null optional fields', () {
      final po = PurchaseOrder.fromJson(const {'id': 9, 'status': null});

      expect(po.id, 9);
      expect(po.poNumber, '');
      expect(po.status, PurchaseOrderStatus.draft);
      expect(po.supplierName, isNull);
      expect(po.items, isEmpty);
      expect(po.canReceiveItems, isFalse);
    });

    test('unknown status falls back to draft', () {
      expect(parsePurchaseOrderStatus('mystery'), PurchaseOrderStatus.draft);
      expect(parsePurchaseOrderStatus(null), PurchaseOrderStatus.draft);
      expect(parsePurchaseOrderStatus('received'),
          PurchaseOrderStatus.received);
    });
  });

  group('PurchaseOrderItem.fromJson', () {
    test('coerces stringified numeric quantities', () {
      final item = PurchaseOrderItem.fromJson(const {
        'id': 5,
        'product_id': '42',
        'product_name': 'Coerced',
        'sku': 'C',
        'quantity_ordered': '20',
        'quantity_received': '5',
        'remaining_quantity': '15',
      });

      expect(item.productId, 42);
      expect(item.quantityOrdered, 20);
      expect(item.quantityReceived, 5);
      expect(item.remainingQuantity, 15);
    });
  });
}
