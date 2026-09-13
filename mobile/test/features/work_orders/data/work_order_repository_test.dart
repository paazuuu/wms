import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/work_orders/data/work_order_repository.dart';
import 'package:wms_mobile/features/work_orders/domain/work_order.dart';

import '../../../support/fake_http_adapter.dart';

Dio _dio(FakeHttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://x.test/rest/v1'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('WorkOrderRepositoryImpl', () {
    test('create() posts warehouse/output/components to create_work_order',
        () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(9, 200);
      });
      final repo = WorkOrderRepositoryImpl(_dio(adapter));

      final result = await repo.create(
        warehouseId: 1,
        outputJanCode: 'WOTEST-OUT',
        outputQuantity: 5,
        components: const [
          WorkOrderComponentDraft(janCode: 'WOTEST-COMP', quantityRequired: 20),
        ],
        outputProductName: 'テストキット',
        note: 'メモ',
      );

      expect(captured.path, '/rpc/create_work_order');
      final body = captured.data as Map;
      expect(body['p_warehouse_id'], 1);
      expect(body['p_output_jan_code'], 'WOTEST-OUT');
      expect(body['p_output_quantity'], 5);
      expect(body['p_output_product_name'], 'テストキット');
      final components = body['p_components'] as List;
      expect(components, hasLength(1));
      expect((components.first as Map)['jan_code'], 'WOTEST-COMP');
      expect((components.first as Map)['quantity_required'], 20);
      result.when(
        success: (id) => expect(id, 9),
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('list() posts the warehouse/status filter to work_order_index',
        () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody([
          {
            'id': 1,
            'wo_number': 'WO-000001',
            'warehouse_id': 1,
            'warehouse_name': '東京倉庫',
            'output_jan_code': 'WOTEST-OUT',
            'output_product_name': 'テストキット',
            'output_quantity': 5,
            'status': 'DRAFT',
            'component_count': 1,
          }
        ], 200);
      });
      final repo = WorkOrderRepositoryImpl(_dio(adapter));

      final result = await repo.list(warehouseId: 1, status: 'DRAFT');

      expect(captured.path, '/rpc/work_order_index');
      final body = captured.data as Map;
      expect(body['p_warehouse_id'], 1);
      expect(body['p_status'], 'DRAFT');
      result.when(
        success: (orders) {
          expect(orders, hasLength(1));
          expect(orders.single.woNumber, 'WO-000001');
          expect(orders.single.status, WorkOrderStatus.draft);
          expect(orders.single.componentCount, 1);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('complete() posts the id to complete_work_order', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody({'work_order_id': 9}, 200);
      });
      final repo = WorkOrderRepositoryImpl(_dio(adapter));

      final result = await repo.complete(9);

      expect(captured.path, '/rpc/complete_work_order');
      expect((captured.data as Map)['p_id'], 9);
      result.when(
        success: (ok) => expect(ok, isTrue),
        failure: (f) => fail('expected success, got $f'),
      );
    });
  });
}
