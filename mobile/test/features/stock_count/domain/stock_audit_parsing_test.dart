import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/stock_count/domain/stock_audit.dart';
import 'package:wms_mobile/features/stock_count/domain/stock_audit_item.dart';

void main() {
  group('StockAudit.fromJson', () {
    test('parses a full audit with nested location and items', () {
      final audit = StockAudit.fromJson(const {
        'id': 4,
        'audit_number': 'SC-004',
        'name': 'August cycle',
        'status': 'in_progress',
        'audit_type': 'cycle',
        'warehouse_location': {'id': 2, 'name': 'Aisle A', 'code': 'A'},
        'started_at': '2026-08-01T09:00:00+00:00',
        'items_count': 2,
        'items': [
          {
            'id': 10,
            'product_id': 3,
            'system_quantity': 100,
            'counted_quantity': 98,
            'discrepancy': -2,
            'product': {'name': 'Widget', 'sku': 'SKU-3'},
            'location': {'name': 'Aisle A'},
          },
        ],
      });

      expect(audit.id, 4);
      expect(audit.auditNumber, 'SC-004');
      expect(audit.status, StockAuditStatus.inProgress);
      expect(audit.locationName, 'Aisle A');
      expect(audit.itemsCount, 2);
      expect(audit.items, hasLength(1));
      expect(audit.items.first.productName, 'Widget');
    });

    test('defaults status to draft and items to empty', () {
      final audit = StockAudit.fromJson(const {'id': 9, 'status': 'unknown'});

      expect(audit.status, StockAuditStatus.draft);
      expect(audit.auditNumber, '#9');
      expect(audit.items, isEmpty);
    });

    test('maps every known status string', () {
      expect(parseStockAuditStatus('completed'), StockAuditStatus.completed);
      expect(parseStockAuditStatus('cancelled'), StockAuditStatus.cancelled);
      expect(parseStockAuditStatus('draft'), StockAuditStatus.draft);
      expect(parseStockAuditStatus(null), StockAuditStatus.draft);
    });
  });

  group('StockAuditItem', () {
    test('computes effective discrepancy from counted − system', () {
      final item = StockAuditItem.fromJson(const {
        'id': 1,
        'product_id': 3,
        'system_quantity': 50,
        'counted_quantity': 47,
      });

      expect(item.isCounted, isTrue);
      expect(item.effectiveDiscrepancy, -3);
    });

    test('treats a missing count as uncounted with zero discrepancy', () {
      final item = StockAuditItem.fromJson(const {
        'id': 2,
        'product_id': 3,
        'system_quantity': 50,
      });

      expect(item.isCounted, isFalse);
      expect(item.effectiveDiscrepancy, 0);
    });
  });
}
