import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/product/data/product_repository.dart';

import '../../../support/fake_http_adapter.dart';

Dio _dio(FakeHttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://x.test/rest/v1'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('ProductRepositoryImpl', () {
    test('list() posts the search/status filter to list_products', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody([
          {
            'id': 1,
            'jan_code': '4902505632037',
            'name': 'ボールペン',
            'category': '文房具',
            'price': 150,
            'status': 'active',
          }
        ], 200);
      });
      final repo = ProductRepositoryImpl(_dio(adapter));

      final result = await repo.list(search: 'ペン', status: 'active');

      expect(captured.path, '/rpc/list_products');
      final body = captured.data as Map;
      expect(body['p_search'], 'ペン');
      expect(body['p_status'], 'active');
      result.when(
        success: (products) {
          expect(products, hasLength(1));
          expect(products.single.name, 'ボールペン');
          expect(products.single.price, 150.0);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('create() posts jan_code/name/category/price to create_product',
        () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(7, 200);
      });
      final repo = ProductRepositoryImpl(_dio(adapter));

      final result = await repo.create(
        janCode: '4901234567890',
        name: 'テストペン',
        category: '文房具',
        price: 300,
      );

      expect(captured.path, '/rpc/create_product');
      final body = captured.data as Map;
      expect(body['p_jan_code'], '4901234567890');
      expect(body['p_name'], 'テストペン');
      expect(body['p_category'], '文房具');
      expect(body['p_price'], 300);
      result.when(
        success: (id) => expect(id, 7),
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('setStatus() posts id/status to set_product_status', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(true, 200);
      });
      final repo = ProductRepositoryImpl(_dio(adapter));

      final result = await repo.setStatus(7, 'inactive');

      expect(captured.path, '/rpc/set_product_status');
      final body = captured.data as Map;
      expect(body['p_id'], 7);
      expect(body['p_status'], 'inactive');
      result.when(
        success: (ok) => expect(ok, isTrue),
        failure: (f) => fail('expected success, got $f'),
      );
    });
  });
}
