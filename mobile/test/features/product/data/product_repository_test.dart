import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/product/data/product_repository.dart';
import 'package:wms_mobile/features/product/domain/product.dart';

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

    test('list() reads the identity and unit keys 0057-0059 added', () async {
      final adapter = FakeHttpClientAdapter((_) => jsonResponseBody([
            {
              'id': 7,
              'jan_code': '4901234567890',
              'name': 'ボールペン',
              'sku': 'PEN-001',
              'tracking_mode': 'LOT',
              'status': 'active',
              'base_uom': {'id': 1, 'code': 'PCS', 'name': '個'},
              'uoms': [
                {
                  'code': 'PCS',
                  'name': '個',
                  'conversion_factor': 1,
                  'is_base': true
                },
                {
                  'code': 'BOX',
                  'name': '箱',
                  'conversion_factor': 12,
                  'is_base': false
                },
              ],
              'barcodes': [
                {
                  'id': 11,
                  'barcode': '4901234567890',
                  'barcode_type': 'JAN',
                  'is_primary': true,
                  'quantity_per_scan': 1,
                  'uom': null,
                },
                {
                  'id': 12,
                  'barcode': '14901234567895',
                  'barcode_type': 'CASE',
                  'is_primary': false,
                  'quantity_per_scan': 12,
                  'uom': 'BOX',
                },
              ],
            }
          ], 200));
      final repo = ProductRepositoryImpl(_dio(adapter));

      final result = await repo.list();

      result.when(
        success: (products) {
          final p = products.single;
          expect(p.sku, 'PEN-001');
          expect(p.trackingMode, TrackingMode.lot);
          expect(p.trackingMode.tracksLot, isTrue);
          expect(p.trackingMode.tracksSerial, isFalse);
          expect(p.baseUom?.code, 'PCS');
          // The base unit is a row like any other, so it is filtered out of the
          // pack units rather than being a special case at every call site.
          expect(p.uoms, hasLength(2));
          expect(p.packUoms.single.code, 'BOX');
          expect(p.packUoms.single.conversionFactor, 12);
          expect(p.barcodes, hasLength(2));
          expect(p.alternateBarcodes.single.barcode, '14901234567895');
          expect(p.alternateBarcodes.single.quantityPerScan, 12);
          expect(p.alternateBarcodes.single.uom, 'BOX');
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('list() still reads a row that predates the new keys', () async {
      // Additive migrations mean an older or partial payload must not throw:
      // absent keys fall back to the defaults the old model had.
      final adapter = FakeHttpClientAdapter((_) => jsonResponseBody([
            {'id': 1, 'jan_code': '4901234567890', 'name': 'ペン'}
          ], 200));
      final repo = ProductRepositoryImpl(_dio(adapter));

      final result = await repo.list();

      result.when(
        success: (products) {
          final p = products.single;
          expect(p.sku, isNull);
          expect(p.trackingMode, TrackingMode.untracked);
          expect(p.baseUom, isNull);
          expect(p.uoms, isEmpty);
          expect(p.barcodes, isEmpty);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('setIdentity() posts sku/tracking_mode to set_product_identity',
        () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(true, 200);
      });
      final repo = ProductRepositoryImpl(_dio(adapter));

      final result = await repo.setIdentity(
        id: 7,
        sku: 'PEN-001',
        trackingMode: TrackingMode.lotAndSerial,
      );

      expect(captured.path, '/rpc/set_product_identity');
      final body = captured.data as Map;
      expect(body['p_id'], 7);
      expect(body['p_sku'], 'PEN-001');
      // The wire format is the server's code, not the Dart enum name.
      expect(body['p_tracking_mode'], 'LOT_AND_SERIAL');
      result.when(
        success: (ok) => expect(ok, isTrue),
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('setIdentity() sends null for a field left alone', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(true, 200);
      });
      final repo = ProductRepositoryImpl(_dio(adapter));

      await repo.setIdentity(id: 7, trackingMode: TrackingMode.expiry);

      final body = captured.data as Map;
      expect(body['p_sku'], isNull);
      expect(body['p_tracking_mode'], 'EXPIRY');
    });

    test('addBarcode() names the unit, which makes the conversion authoritative',
        () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(12, 200);
      });
      final repo = ProductRepositoryImpl(_dio(adapter));

      final result = await repo.addBarcode(
        productId: 7,
        barcode: '14901234567895',
        barcodeType: 'CASE',
        uomCode: 'BOX',
      );

      expect(captured.path, '/rpc/add_product_barcode');
      final body = captured.data as Map;
      expect(body['p_product_id'], 7);
      expect(body['p_barcode'], '14901234567895');
      expect(body['p_barcode_type'], 'CASE');
      expect(body['p_uom_code'], 'BOX');
      // Passed but ignored by the server when a unit is named (0059) — sent
      // anyway because the parameter is positional in the RPC's signature.
      expect(body['p_quantity_per_scan'], 1);
      result.when(
        success: (id) => expect(id, 12),
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('removeBarcode() posts the barcode id', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(true, 200);
      });
      final repo = ProductRepositoryImpl(_dio(adapter));

      await repo.removeBarcode(12);

      expect(captured.path, '/rpc/remove_product_barcode');
      expect((captured.data as Map)['p_barcode_id'], 12);
    });

    test('setUom() posts the pack size to set_product_uom', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(true, 200);
      });
      final repo = ProductRepositoryImpl(_dio(adapter));

      await repo.setUom(productId: 7, uomCode: 'BOX', conversionFactor: 12);

      expect(captured.path, '/rpc/set_product_uom');
      final body = captured.data as Map;
      expect(body['p_product_id'], 7);
      expect(body['p_uom_code'], 'BOX');
      expect(body['p_conversion_factor'], 12);
    });

    test('listUoms() reads the unit vocabulary', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody([
          {'id': 1, 'code': 'PCS', 'name': '個', 'uom_type': 'COUNT'},
          {'id': 4, 'code': 'BOX', 'name': '箱', 'uom_type': 'COUNT'},
        ], 200);
      });
      final repo = ProductRepositoryImpl(_dio(adapter));

      final result = await repo.listUoms();

      expect(captured.path, '/rpc/list_uoms');
      result.when(
        success: (uoms) {
          expect(uoms.map((u) => u.code), ['PCS', 'BOX']);
          expect(uoms.last.name, '箱');
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });
  });
}
