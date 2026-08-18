import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/inspection/domain/attachment.dart';
import 'package:wms_mobile/features/inspection/domain/inspection.dart';
import 'package:wms_mobile/features/inspection/domain/inspection_item.dart';

void main() {
  group('Inspection.fromJson', () {
    test('parses nested items and attachments', () {
      final inspection = Inspection.fromJson(const {
        'id': 7,
        'code': 'INS-000007',
        'type': 'receiving',
        'status': 'failed',
        'note': 'inbound',
        'purchase_order_id': 42,
        'items': [
          {
            'id': 1,
            'inspection_id': 7,
            'match_result': 'ng',
            'expected_barcode': '4901234567894',
            'scanned_barcode': '0000000000000',
            'expected_quantity': 5,
            'actual_quantity': 3,
            'ng_reason': 'barcode_mismatch',
          },
        ],
        'attachments': [
          {
            'id': 11,
            'category': 'image',
            'mime_type': 'image/jpeg',
            'original_name': 'photo.jpg',
            'url': 'https://cdn/x.jpg',
          },
        ],
      });

      expect(inspection.id, 7);
      expect(inspection.status, InspectionStatus.failed);
      expect(inspection.purchaseOrderId, 42);
      expect(inspection.items.single.matchResult, MatchResult.ng);
      expect(inspection.items.single.ngReason, 'barcode_mismatch');
      expect(inspection.attachments.single.isImage, isTrue);
    });

    test('defaults status to pending and tolerates missing collections', () {
      final inspection = Inspection.fromJson(const {
        'id': 1,
        'code': 'INS-000001',
        'type': 'other',
        'status': 'unknown-value',
      });

      expect(inspection.status, InspectionStatus.pending);
      expect(inspection.items, isEmpty);
      expect(inspection.attachments, isEmpty);
    });
  });

  group('Attachment.fromJson', () {
    test('maps category and image flag', () {
      final pdf = Attachment.fromJson(const {
        'id': 2,
        'category': 'pdf',
        'mime_type': 'application/pdf',
        'original_name': 'doc.pdf',
        'url': 'https://cdn/doc.pdf',
      });
      expect(pdf.isImage, isFalse);
      expect(pdf.category, 'pdf');
    });
  });
}
