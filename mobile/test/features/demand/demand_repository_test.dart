import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/demand/data/demand_repository.dart';
import 'package:wms_mobile/features/demand/domain/open_demand.dart';

import '../../support/fake_http_adapter.dart';

Dio _dio(FakeHttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://x.test/rest/v1'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('DemandRepositoryImpl', () {
    test('openDemand() reads open_demand with its per-order lines', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody([
          {
            'warehouse_id': 1,
            'product_id': 7,
            'jan_code': '4988601001053',
            'product_name': 'ノート',
            'ordered': 12,
            'promised': 3,
            'shipped': 0,
            'backordered': 9,
            'available': 0,
            'incoming': 6,
            'can_fill_now': 0,
            'to_purchase': 3,
            'preferred_supplier_id': null,
            'lines': [
              {
                'sales_order_line_id': 9,
                'sales_order_id': 7,
                'so_number': 'SO-000007',
                'customer_name': '顧客A',
                'ordered': 5,
                'promised': 3,
                'shipped': 0,
                'backordered': 2,
                'on_order': 2,
              }
            ],
          }
        ], 200);
      });
      final repo = DemandRepositoryImpl(_dio(adapter));

      final result = await repo.openDemand(warehouseId: 1);

      expect(captured.path, '/rpc/open_demand');
      expect((captured.data as Map)['p_warehouse_id'], 1);
      result.when(
        success: (items) {
          final item = items.single;
          expect(item.backordered, 9);
          expect(item.incoming, 6);
          expect(item.toPurchase, 3);
          expect(item.preferredSupplierId, isNull);
          expect(item.lines.single.soNumber, 'SO-000007');
          expect(item.lines.single.onOrder, 2);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('fillBackorders() posts the narrowing it was given', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody({
          'reserved_units': 2,
          'filled': [
            {
              'sales_order_line_id': 10,
              'sales_order_id': 8,
              'so_number': 'SO-000008',
              'jan_code': '4988601001053',
              'reserved': 2,
              'still_backordered': 5,
            }
          ],
        }, 200);
      });
      final repo = DemandRepositoryImpl(_dio(adapter));

      final result = await repo.fillBackorders(
          warehouseId: 1, salesOrderLineId: 10, quantity: 2);

      expect(captured.path, '/rpc/fill_backorders');
      final body = captured.data as Map;
      expect(body['p_warehouse_id'], 1);
      expect(body['p_product_id'], isNull);
      expect(body['p_sales_order_line_id'], 10);
      expect(body['p_quantity'], 2);
      result.when(
        success: (fill) {
          expect(fill.reservedUnits, 2);
          expect(fill.filled.single.stillBackordered, 5);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('createPurchaseOrder() posts to create_purchase_order_from_demand',
        () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(
            {'purchase_order_id': 9, 'lines': 1, 'links': 2}, 200);
      });
      final repo = DemandRepositoryImpl(_dio(adapter));

      final result = await repo.createPurchaseOrder(
        supplierName: '新東光通商株式会社',
        supplierId: 5,
        warehouseId: 1,
        lines: const [DemandPurchaseLine(janCode: '4988601001053', quantity: 6)],
      );

      expect(captured.path, '/rpc/create_purchase_order_from_demand');
      final body = captured.data as Map;
      expect(body['p_supplier_name'], '新東光通商株式会社');
      expect(body['p_supplier_id'], 5);
      expect((body['p_lines'] as List).single['quantity'], 6);
      result.when(
        success: (created) {
          expect(created.purchaseOrderId, 9);
          expect(created.links, 2);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });
  });
}
