import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/work_orders/domain/work_order.dart';
import 'package:wms_mobile/features/work_orders/domain/work_order_item.dart';

void main() {
  group('WorkOrder.fromJson', () {
    test('parses a full work order with product and components', () {
      final order = WorkOrder.fromJson(const {
        'id': 5,
        'work_order_number': 'WO-005',
        'status': 'in_progress',
        'product_id': 3,
        'product': {'name': 'Gift Box', 'sku': 'KIT-1'},
        'quantity': 10,
        'quantity_produced': 4,
        'started_at': '2026-08-05T08:00:00+00:00',
        'items': [
          {
            'id': 1,
            'product_id': 7,
            'quantity_required': '20.00',
            'quantity_consumed': '8.00',
            'product': {'name': 'Ribbon', 'sku': 'RB-1', 'stock': 100},
          },
        ],
      });

      expect(order.id, 5);
      expect(order.workOrderNumber, 'WO-005');
      expect(order.status, WorkOrderStatus.inProgress);
      expect(order.productName, 'Gift Box');
      expect(order.quantity, 10);
      expect(order.quantityProduced, 4);
      expect(order.items, hasLength(1));
      expect(order.items.first.productName, 'Ribbon');
      expect(order.items.first.quantityRequired, 20);
      expect(order.items.first.quantityConsumed, 8);
      expect(order.items.first.quantityRemaining, 12);
      expect(order.items.first.stock, 100);
    });

    test('defaults status to draft and items to empty', () {
      final order = WorkOrder.fromJson(const {'id': 9, 'status': 'weird'});

      expect(order.status, WorkOrderStatus.draft);
      expect(order.workOrderNumber, '#9');
      expect(order.items, isEmpty);
      expect(order.quantityProduced, isNull);
    });

    test('maps every known status string', () {
      expect(parseWorkOrderStatus('pending'), WorkOrderStatus.pending);
      expect(parseWorkOrderStatus('completed'), WorkOrderStatus.completed);
      expect(parseWorkOrderStatus('cancelled'), WorkOrderStatus.cancelled);
      expect(parseWorkOrderStatus(null), WorkOrderStatus.draft);
    });
  });

  group('formatQuantity', () {
    test('drops the decimal for whole numbers', () {
      expect(formatQuantity(20), '20');
      expect(formatQuantity(2.5), '2.5');
    });
  });
}
