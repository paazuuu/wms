import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/exceptions/data/exception_repository.dart';
import 'package:wms_mobile/features/exceptions/domain/warehouse_exception.dart';

import '../../support/fake_http_adapter.dart';

Dio _dio(FakeHttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://x.test/rest/v1'));
  dio.httpClientAdapter = adapter;
  return dio;
}

/// What 0071's own functional test produced from one messy delivery.
Object _openPayload() => [
      {
        'exception_id': 1,
        'exception_type': 'LOT_MISSING',
        'exception_name': 'ロット未記録',
        'category': 'RECEIVING',
        'severity': 'BLOCKER',
        'requires_resolution': true,
        'severity_rank': 0,
        'status': 'OPEN',
        'warehouse_id': 1,
        'reconciliation_id': 12,
        'reconciliation_line_id': 30,
        'receipt_item_id': 44,
        'product_id': 7,
        'jan_code': '4901234567890',
        'product_name': 'ボールペン',
        'quantity': 10,
        'note': 'LOT 管理の商品にロットが記録されていない',
        'reference_no': 'SUP-00001',
        'delivery_number': 'DN-1',
        'supplier_name': '文具商事',
        'created_at': '2026-09-20T10:30:00Z',
      },
      {
        'exception_id': 2,
        'exception_type': 'EXPIRY_TOO_SOON',
        'exception_name': '期限が近い',
        'category': 'RECEIVING',
        'severity': 'WARNING',
        'requires_resolution': true,
        'severity_rank': 1,
        'status': 'ACKNOWLEDGED',
        'warehouse_id': 1,
        'product_id': 7,
        'lot_id': 27,
        'lot_code': 'NEAR',
        'expiry_date': '2026-09-28',
        'quantity': 20,
        'created_at': '2026-09-20T10:31:00Z',
        'acknowledged_at': '2026-09-20T11:00:00Z',
      },
    ];

void main() {
  group('ExceptionRepositoryImpl.open', () {
    test('keeps the server order and reads every field a row carries', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(_openPayload(), 200);
      });

      final result =
          await ExceptionRepositoryImpl(_dio(adapter)).open(warehouseId: 1);

      expect(captured.path, '/rpc/open_exceptions');
      final body = captured.data as Map;
      expect(body['p_warehouse_id'], 1);
      // A work queue by default, not a history.
      expect(body['p_include_closed'], isFalse);
      result.when(
        success: (rows) {
          expect(rows, hasLength(2));
          // The server sorts blockers first; the client must not re-sort, or the
          // two disagree as soon as the list is paged.
          expect(rows.first.exceptionType, 'LOT_MISSING');
          expect(rows.first.severity, ExceptionSeverity.blocker);
          expect(rows.first.isBlocker, isTrue);
          expect(rows.first.quantity, 10);
          expect(rows.first.deliveryNumber, 'DN-1');
          expect(rows.first.receiptItemId, 44);
          expect(rows.first.hasSource, isTrue);
          // OPEN can be acknowledged; ACKNOWLEDGED cannot, because it already is.
          expect(rows.first.canAcknowledge, isTrue);
          expect(rows.last.canAcknowledge, isFalse);
          expect(rows.last.isOpen, isTrue);
          expect(rows.last.lotCode, 'NEAR');
          expect(rows.last.expiryDate, DateTime(2026, 9, 28));
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('an unknown type still displays, using the name the server sent',
        () async {
      final adapter = FakeHttpClientAdapter((_) => jsonResponseBody([
            {
              'exception_id': 9,
              'exception_type': 'SOMETHING_NEW',
              'exception_name': '新しい種類',
              'category': 'OTHER',
              'severity': 'MYSTERY',
              'status': 'OPEN',
            }
          ], 200));

      final result = await ExceptionRepositoryImpl(_dio(adapter)).open();

      result.when(
        success: (rows) {
          // The vocabulary is data, so a code this build has never heard of must
          // not become a blank row.
          expect(rows.single.exceptionName, '新しい種類');
          // An unreadable severity falls back to WARNING rather than to nothing.
          expect(rows.single.severity, ExceptionSeverity.warning);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });
  });

  group('ExceptionRepositoryImpl.summary', () {
    test('reads the two headline numbers and the breakdown', () async {
      final adapter = FakeHttpClientAdapter((_) => jsonResponseBody({
            'open': 6,
            'blockers': 4,
            'by_type': [
              {
                'exception_type': 'QC_FAIL',
                'name': '検品不合格',
                'category': 'QC',
                'severity': 'BLOCKER',
                'open': 2,
              },
              {
                'exception_type': 'SHORTFALL',
                'name': '数量不足',
                'category': 'RECEIVING',
                'severity': 'WARNING',
                'open': 1,
              },
            ],
          }, 200));

      final result =
          await ExceptionRepositoryImpl(_dio(adapter)).summary(warehouseId: 1);

      result.when(
        success: (s) {
          expect(s.open, 6);
          expect(s.blockers, 4);
          expect(s.isClear, isFalse);
          expect(s.byType.first.exceptionType, 'QC_FAIL');
          expect(s.byType.first.open, 2);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('an empty summary is clear, not missing', () async {
      final adapter = FakeHttpClientAdapter(
          (_) => jsonResponseBody({'open': 0, 'blockers': 0, 'by_type': []}, 200));

      final result = await ExceptionRepositoryImpl(_dio(adapter)).summary();

      result.when(
        success: (s) => expect(s.isClear, isTrue),
        failure: (f) => fail('expected success, got $f'),
      );
    });
  });

  group('ExceptionRepositoryImpl writes', () {
    test('resolve sends the decision code and the note', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody({'status': 'RESOLVED'}, 200);
      });

      await ExceptionRepositoryImpl(_dio(adapter))
          .resolve(2, ExceptionResolution.scrapped, note: '破損のため廃棄');

      expect(captured.path, '/rpc/resolve_exception');
      final body = captured.data as Map;
      expect(body['p_exception_id'], 2);
      expect(body['p_resolution'], 'SCRAPPED');
      expect(body['p_note'], '破損のため廃棄');
    });

    test('the server refusing a missing note surfaces as a failure', () async {
      final adapter = FakeHttpClientAdapter((_) => jsonResponseBody(
            {'message': 'resolving as SCRAPPED needs a note saying what was done'},
            400,
          ));

      final result = await ExceptionRepositoryImpl(_dio(adapter))
          .resolve(2, ExceptionResolution.scrapped);

      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.message, contains('needs a note')),
      );
    });

    test('the three destructive decisions are the ones that need a note', () {
      // Mirrors 0071's check, so the form and the server agree about which.
      expect(ExceptionResolution.scrapped.needsNote, isTrue);
      expect(ExceptionResolution.returned.needsNote, isTrue);
      expect(ExceptionResolution.corrected.needsNote, isTrue);
      expect(ExceptionResolution.accepted.needsNote, isFalse);
      expect(ExceptionResolution.supplierClaim.needsNote, isFalse);
      expect(ExceptionResolution.noAction.needsNote, isFalse);
    });

    test('cancel carries the reason it was raised in error', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody({'status': 'CANCELLED'}, 200);
      });

      await ExceptionRepositoryImpl(_dio(adapter))
          .cancel(3, reason: 'スキャンミス');

      expect(captured.path, '/rpc/cancel_exception');
      expect((captured.data as Map)['p_reason'], 'スキャンミス');
    });

    test('raising one by hand returns the new id', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(42, 200);
      });

      final result = await ExceptionRepositoryImpl(_dio(adapter)).raise(
        exceptionType: 'DAMAGED_ON_ARRIVAL',
        warehouseId: 1,
        note: 'パレットが濡れていた',
        reconciliationId: 12,
        quantity: 2,
      );

      expect(captured.path, '/rpc/raise_exception');
      final body = captured.data as Map;
      expect(body['p_exception_type'], 'DAMAGED_ON_ARRIVAL');
      expect(body['p_quantity'], 2);
      result.when(
        success: (id) => expect(id, 42),
        failure: (f) => fail('expected success, got $f'),
      );
    });
  });
}
