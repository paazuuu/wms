import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/reports/domain/report_result.dart';
import 'package:wms_mobile/features/reports/domain/saved_report.dart';

void main() {
  group('SavedReport.fromJson', () {
    test('parses a full report summary', () {
      final report = SavedReport.fromJson(const {
        'id': 2,
        'name': 'Low stock',
        'description': 'Items below minimum',
        'data_source': 'products',
        'is_shared': true,
        'is_owner': false,
        'creator_name': 'Alice',
        'columns_count': 4,
        'filters_count': 1,
        'chart_type': 'bar',
        'updated_at': '2026-08-01T00:00:00Z',
      });

      expect(report.id, 2);
      expect(report.name, 'Low stock');
      expect(report.dataSource, 'products');
      expect(report.isShared, isTrue);
      expect(report.isOwner, isFalse);
      expect(report.columnsCount, 4);
    });

    test('falls back to a placeholder name and safe defaults', () {
      final report = SavedReport.fromJson(const {'id': 9});

      expect(report.name, 'Untitled report');
      expect(report.isShared, isFalse);
      expect(report.columnsCount, 0);
    });
  });

  group('ReportResult.fromJson', () {
    test('parses report meta, labels, and rows', () {
      final result = ReportResult.fromJson(const {
        'report': {
          'id': 2,
          'name': 'Low stock',
          'columns': ['sku', 'stock'],
        },
        'column_labels': {'sku': 'SKU', 'stock': 'On hand'},
        'rows': [
          {'sku': 'A-1', 'stock': 3},
          {'sku': 'B-2', 'stock': null},
        ],
        'total': 2,
      });

      expect(result.id, 2);
      expect(result.name, 'Low stock');
      expect(result.columns, ['sku', 'stock']);
      expect(result.labelFor('sku'), 'SKU');
      expect(result.labelFor('unknown'), 'unknown');
      expect(result.total, 2);
      expect(result.cell(result.rows.first, 'stock'), '3');
      expect(result.cell(result.rows[1], 'stock'), '—');
    });

    test('defaults to empty columns and rows when absent', () {
      final result = ReportResult.fromJson(const {
        'report': {'id': 1, 'name': 'Empty'},
      });

      expect(result.columns, isEmpty);
      expect(result.rows, isEmpty);
      expect(result.total, 0);
    });
  });
}
