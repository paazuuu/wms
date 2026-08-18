import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/sales_orders/domain/sales_order.dart';

void main() {
  group('SalesOrder.fromJson', () {
    test('maps a fully populated payload with line items', () {
      const json = {
        'id': 9,
        'order_number': 'SO-0009',
        'source': 'shopify',
        'status': 'processing',
        'customer_name': 'Jane Doe',
        'customer_email': 'jane@buyer.test',
        'customer_address': '5 Elm St',
        'subtotal': '40.00',
        'tax': '2.00',
        'shipping': '5.00',
        'total': '47.00',
        'currency': 'USD',
        'order_date': '2026-08-01T00:00:00+00:00',
        'notes': 'Rush',
        'items_count': 2,
        'items': [
          {
            'id': 1,
            'product_id': 3,
            'product_name': 'Widget',
            'sku': 'WID-1',
            'quantity': 2,
            'unit_price': '20.00',
            'total': '40.00',
          },
        ],
      };

      final order = SalesOrder.fromJson(json);

      expect(order.id, 9);
      expect(order.orderNumber, 'SO-0009');
      expect(order.source, 'shopify');
      expect(order.status, SalesOrderStatus.processing);
      expect(order.customerName, 'Jane Doe');
      expect(order.total, '47.00');
      expect(order.currency, 'USD');
      expect(order.itemsCount, 2);
      expect(order.items, hasLength(1));
      expect(order.items.first.productName, 'Widget');
      expect(order.items.first.quantity, 2);
      expect(order.items.first.total, '40.00');
    });

    test('unknown / missing status falls back to pending', () {
      expect(
        SalesOrder.fromJson(const {'id': 1, 'status': 'weird'}).status,
        SalesOrderStatus.pending,
      );
      expect(
        SalesOrder.fromJson(const {'id': 1}).status,
        SalesOrderStatus.pending,
      );
    });

    test('coerces numeric money and defaults items to empty', () {
      const json = {
        'id': 2,
        'order_number': 'SO-2',
        'total': 12.5,
        'currency': 'CAD',
      };

      final order = SalesOrder.fromJson(json);

      expect(order.total, '12.5');
      expect(order.displayTotal, 'CAD 12.5');
      expect(order.items, isEmpty);
    });

    test('displayTotal returns dash when total absent', () {
      expect(
        SalesOrder.fromJson(const {'id': 3, 'order_number': 'SO-3'})
            .displayTotal,
        '—',
      );
    });
  });
}
