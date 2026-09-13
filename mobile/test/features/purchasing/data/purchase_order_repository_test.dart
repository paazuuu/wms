import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/purchasing/data/purchase_order_repository.dart';
import 'package:wms_mobile/features/purchasing/domain/purchase_order.dart';

import '../../../support/fake_http_adapter.dart';

Dio _dio(FakeHttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://x.test/rest/v1'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('PurchaseOrderRepositoryImpl', () {
    test('create() posts supplier/warehouse/lines to create_purchase_order',
        () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(9, 200);
      });
      final repo = PurchaseOrderRepositoryImpl(_dio(adapter));

      final result = await repo.create(
        supplierName: 'テスト仕入先',
        warehouseId: 1,
        lines: const [
          PurchaseOrderLineDraft(janCode: '4988601001053', quantity: 10, unitPrice: 120),
        ],
        expectedDate: DateTime(2026, 1, 15),
        note: 'メモ',
      );

      expect(captured.path, '/rpc/create_purchase_order');
      final body = captured.data as Map;
      expect(body['p_supplier_name'], 'テスト仕入先');
      expect(body['p_warehouse_id'], 1);
      expect(body['p_expected_date'], '2026-01-15');
      expect(body['p_note'], 'メモ');
      final lines = body['p_lines'] as List;
      expect(lines, hasLength(1));
      expect((lines.first as Map)['jan_code'], '4988601001053');
      expect((lines.first as Map)['quantity'], 10);
      result.when(
        success: (id) => expect(id, 9),
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('list() posts the warehouse/status filter to purchase_order_index',
        () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody([
          {
            'id': 1,
            'po_number': 'PO-000001',
            'supplier_name': 'テスト仕入先',
            'warehouse_id': 1,
            'warehouse_name': '東京倉庫',
            'status': 'DRAFT',
            'line_count': 2,
            'total_amount': 1200,
          }
        ], 200);
      });
      final repo = PurchaseOrderRepositoryImpl(_dio(adapter));

      final result = await repo.list(warehouseId: 1, status: 'DRAFT');

      expect(captured.path, '/rpc/purchase_order_index');
      final body = captured.data as Map;
      expect(body['p_warehouse_id'], 1);
      expect(body['p_status'], 'DRAFT');
      result.when(
        success: (orders) {
          expect(orders, hasLength(1));
          expect(orders.single.poNumber, 'PO-000001');
          expect(orders.single.status, PurchaseOrderStatus.draft);
          expect(orders.single.lineCount, 2);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('approve() posts the id to approve_purchase_order', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(true, 200);
      });
      final repo = PurchaseOrderRepositoryImpl(_dio(adapter));

      final result = await repo.approve(9);

      expect(captured.path, '/rpc/approve_purchase_order');
      expect((captured.data as Map)['p_id'], 9);
      result.when(
        success: (ok) => expect(ok, isTrue),
        failure: (f) => fail('expected success, got $f'),
      );
    });
  });
}
