import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/sales/data/sales_order_repository.dart';
import 'package:wms_mobile/features/sales/domain/sales_order.dart';

import '../../../support/fake_http_adapter.dart';

Dio _dio(FakeHttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://x.test/rest/v1'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('SalesOrderRepositoryImpl', () {
    test('create() posts customer/warehouse/lines to create_sales_order',
        () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(9, 200);
      });
      final repo = SalesOrderRepositoryImpl(_dio(adapter));

      final result = await repo.create(
        customerName: 'テスト顧客',
        warehouseId: 1,
        lines: const [
          SalesOrderLineDraft(janCode: '4988601001053', quantity: 4, unitPrice: 150),
        ],
        requestedShipDate: DateTime(2026, 2, 1),
        note: 'メモ',
      );

      expect(captured.path, '/rpc/create_sales_order');
      final body = captured.data as Map;
      expect(body['p_customer_name'], 'テスト顧客');
      expect(body['p_warehouse_id'], 1);
      expect(body['p_requested_ship_date'], '2026-02-01');
      expect(body['p_note'], 'メモ');
      final lines = body['p_lines'] as List;
      expect(lines, hasLength(1));
      expect((lines.first as Map)['jan_code'], '4988601001053');
      expect((lines.first as Map)['quantity'], 4);
      result.when(
        success: (id) => expect(id, 9),
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('list() posts the warehouse/status filter to sales_order_index',
        () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody([
          {
            'id': 1,
            'so_number': 'SO-000001',
            'customer_name': 'テスト顧客',
            'warehouse_id': 1,
            'warehouse_name': '東京倉庫',
            'status': 'DRAFT',
            'line_count': 2,
            'total_amount': 600,
          }
        ], 200);
      });
      final repo = SalesOrderRepositoryImpl(_dio(adapter));

      final result = await repo.list(warehouseId: 1, status: 'DRAFT');

      expect(captured.path, '/rpc/sales_order_index');
      final body = captured.data as Map;
      expect(body['p_warehouse_id'], 1);
      expect(body['p_status'], 'DRAFT');
      result.when(
        success: (orders) {
          expect(orders, hasLength(1));
          expect(orders.single.soNumber, 'SO-000001');
          expect(orders.single.status, SalesOrderStatus.draft);
          expect(orders.single.lineCount, 2);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('approve() posts the id to approve_sales_order', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(true, 200);
      });
      final repo = SalesOrderRepositoryImpl(_dio(adapter));

      final result = await repo.approve(9);

      expect(captured.path, '/rpc/approve_sales_order');
      expect((captured.data as Map)['p_id'], 9);
      result.when(
        success: (ok) => expect(ok, isTrue),
        failure: (f) => fail('expected success, got $f'),
      );
    });
  });
}
