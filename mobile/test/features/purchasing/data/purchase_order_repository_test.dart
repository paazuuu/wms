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

    test(
        'createDeliveryPlan() posts the id and note to create_delivery_plan_from_purchase_order',
        () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(
            {'delivery_plan_id': 42, 'purchase_order_id': 9, 'lines': 3}, 200);
      });
      final repo = PurchaseOrderRepositoryImpl(_dio(adapter));

      final result = await repo.createDeliveryPlan(9, note: '入荷予定を作成');

      expect(captured.path, '/rpc/create_delivery_plan_from_purchase_order');
      final body = captured.data as Map;
      expect(body['p_purchase_order_id'], 9);
      expect(body['p_note'], '入荷予定を作成');
      result.when(
        success: (created) {
          expect(created.deliveryPlanId, 42);
          expect(created.lines, 3);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('a second createDeliveryPlan() call is refused by the unique plan',
        () async {
      final adapter = FakeHttpClientAdapter((_) => jsonResponseBody(
            {'message': 'duplicate key value violates unique constraint'},
            400,
          ));
      final repo = PurchaseOrderRepositoryImpl(_dio(adapter));

      final result = await repo.createDeliveryPlan(9);

      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.message, contains('duplicate key')),
      );
    });

    test('linkDeliveryPlan() posts both ids to link_delivery_plan_to_purchase_order',
        () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(true, 200);
      });
      final repo = PurchaseOrderRepositoryImpl(_dio(adapter));

      final result = await repo.linkDeliveryPlan(9, 42);

      expect(captured.path, '/rpc/link_delivery_plan_to_purchase_order');
      final body = captured.data as Map;
      expect(body['p_purchase_order_id'], 9);
      expect(body['p_delivery_plan_id'], 42);
      result.when(
        success: (ok) => expect(ok, isTrue),
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('show() reads per-line receipt progress and the orders it was bought for',
        () async {
      final adapter = FakeHttpClientAdapter((_) => jsonResponseBody({
            'id': 9,
            'status': 'APPROVED',
            'po_number': 'PO-000009',
            'supplier_name': 'X',
            'warehouse_id': 1,
            'delivery_plan_id': 30,
            'delivery_plans': [
              {'id': 29, 'delivery_number': 'DP-000029', 'status': 'completed'},
              {'id': 30, 'delivery_number': 'DP-000030', 'status': 'open'},
            ],
            'lines': [
              {
                'id': 1,
                'jan_code': '4988601001053',
                'quantity': 10,
                'planned': 10,
                'received': 6,
                'demands': [
                  {
                    'sales_order_line_id': 9,
                    'sales_order_id': 7,
                    'so_number': 'SO-000007',
                    'customer_name': '顧客A',
                    'quantity': 4,
                  }
                ],
              }
            ],
          }, 200));
      final repo = PurchaseOrderRepositoryImpl(_dio(adapter));

      final result = await repo.show(9);

      result.when(
        success: (po) {
          expect(po.deliveryPlans, hasLength(2));
          expect(po.hasUnplannedQuantity, isFalse);
          expect(po.lines.single.received, 6);
          expect(po.lines.single.demands.single.soNumber, 'SO-000007');
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });
  });
}
