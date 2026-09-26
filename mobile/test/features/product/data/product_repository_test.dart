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
              'picking_rule': 'FIFO',
              'requires_inspection': true,
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
          expect(p.pickingRule, 'FIFO');
          expect(p.requiresInspection, isTrue);
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
          expect(p.pickingRule, 'FEFO');
          expect(p.requiresInspection, isFalse);
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

    test('setPickingRule() posts the product\'s own default to set_picking_rule',
        () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        // set_picking_rule returns jsonb (product_id/warehouse_id/rule/
        // effective), not a boolean — the client only cares that the call
        // succeeded, so the body content itself is not asserted here.
        return jsonResponseBody({
          'product_id': 7,
          'warehouse_id': null,
          'rule': 'FIFO',
          'effective': 'FIFO',
        }, 200);
      });
      final repo = ProductRepositoryImpl(_dio(adapter));

      final result = await repo.setPickingRule(productId: 7, rule: 'FIFO');

      expect(captured.path, '/rpc/set_picking_rule');
      final body = captured.data as Map;
      expect(body['p_product_id'], 7);
      // No warehouse override from this call — it sets the product's own
      // default, the same shape identity's own edit does.
      expect(body['p_warehouse_id'], isNull);
      expect(body['p_rule'], 'FIFO');
      result.when(
        success: (ok) => expect(ok, isTrue),
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test(
        'setInspectionRequirement() posts the product\'s own default to set_inspection_requirement',
        () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        // set_inspection_requirement also returns jsonb, not a boolean.
        return jsonResponseBody({
          'product_id': 7,
          'warehouse_id': null,
          'requires_inspection': true,
          'receiving_status': 'QC_PENDING',
        }, 200);
      });
      final repo = ProductRepositoryImpl(_dio(adapter));

      final result = await repo.setInspectionRequirement(
          productId: 7, requiresInspection: true);

      expect(captured.path, '/rpc/set_inspection_requirement');
      final body = captured.data as Map;
      expect(body['p_product_id'], 7);
      expect(body['p_requires_inspection'], isTrue);
      // No warehouse override from this call — same shape setPickingRule uses.
      expect(body['p_warehouse_id'], isNull);
      result.when(
        success: (ok) => expect(ok, isTrue),
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('setSerialStatus() posts the serial/status/note to set_serial_status',
        () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(true, 200);
      });
      final repo = ProductRepositoryImpl(_dio(adapter));

      final result = await repo.setSerialStatus(
          serialId: 5, status: 'HOLD', note: '再検品待ち');

      expect(captured.path, '/rpc/set_serial_status');
      final body = captured.data as Map;
      expect(body['p_serial_id'], 5);
      expect(body['p_status'], 'HOLD');
      expect(body['p_note'], '再検品待ち');
      result.when(
        success: (ok) => expect(ok, isTrue),
        failure: (f) => fail('expected success, got $f'),
      );
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

    test('removeUom() posts the product/unit to remove_product_uom', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(true, 200);
      });
      final repo = ProductRepositoryImpl(_dio(adapter));

      final result = await repo.removeUom(productId: 7, uomCode: 'BOX');

      expect(captured.path, '/rpc/remove_product_uom');
      final body = captured.data as Map;
      expect(body['p_product_id'], 7);
      expect(body['p_uom_code'], 'BOX');
      result.when(
        success: (ok) => expect(ok, isTrue),
        failure: (f) => fail('expected success, got $f'),
      );
    });
  });

  group('ProductRepositoryImpl.unlinkedJanCodes', () {
    test('reads the worklist, worst first, with its per-table breakdown',
        () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody([
          {
            'jan_code': '4900000000099',
            'seen_as': null,
            'total_rows': 12,
            'sources': {'stock_levels': 3, 'delivery_plan_lines': 9},
          },
        ], 200);
      });
      final repo = ProductRepositoryImpl(_dio(adapter));

      final result = await repo.unlinkedJanCodes(limit: 50);

      expect(captured.path, '/rpc/unlinked_jan_codes');
      expect((captured.data as Map)['p_limit'], 50);
      result.when(
        success: (rows) {
          final row = rows.single;
          expect(row.janCode, '4900000000099');
          expect(row.seenAs, isNull);
          expect(row.totalRows, 12);
          expect(row.sources['delivery_plan_lines'], 9);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });
  });

  group('ProductRepositoryImpl.productIdCoverage', () {
    test('reads the switch-over summary', () async {
      final adapter = FakeHttpClientAdapter((_) => jsonResponseBody({
            'tables': {
              'stock_levels': {'rows': 100, 'linked': 98, 'unlinked': 2},
            },
            'rows': 100,
            'linked': 98,
            'unlinked': 2,
            'ready_to_switch': false,
          }, 200));
      final repo = ProductRepositoryImpl(_dio(adapter));

      final result = await repo.productIdCoverage();

      result.when(
        success: (c) {
          expect(c.rows, 100);
          expect(c.linked, 98);
          expect(c.unlinked, 2);
          expect(c.readyToSwitch, isFalse);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('supplierNames()/setSupplierName() reach the 0087 RPCs', () async {
      final calls = <RequestOptions>[];
      final adapter = FakeHttpClientAdapter((options) {
        calls.add(options);
        if (options.path == '/rpc/list_supplier_product_names') {
          return jsonResponseBody([
            {'id': 5, 'supplier_id': 1, 'supplier_display_name': '新東光通商', 'product_id': 2,
             'jan_code': '4909999999999', 'supplier_code': 'SK-100', 'supplier_name': '大'}
          ], 200);
        }
        return jsonResponseBody(5, 200);
      });
      final repo = ProductRepositoryImpl(_dio(adapter));

      final list = await repo.supplierNames(supplierId: 1);
      final set = await repo.setSupplierName(
          supplierId: 1, productId: 2, supplierName: '大', supplierCode: 'SK-100');

      expect((calls[0].data as Map)['p_supplier_id'], 1);
      expect((calls[0].data as Map)['p_product_id'], isNull);
      list.when(
        success: (rows) {
          expect(rows.single.supplierCode, 'SK-100');
          expect(rows.single.janCode, '4909999999999');
        },
        failure: (f) => fail('$f'),
      );
      expect(calls[1].path, '/rpc/set_supplier_product_name');
      expect((calls[1].data as Map)['p_supplier_code'], 'SK-100');
      set.when(success: (id) => expect(id, 5), failure: (f) => fail('$f'));
    });

    test('a product row carries what each supplier calls it', () async {
      final adapter = FakeHttpClientAdapter((_) => jsonResponseBody([
            {'id': 2, 'jan_code': '4909999999999', 'name': '消しゴム',
             'supplier_names': [
               {'supplier_id': 1, 'supplier_display_name': '新東光通商',
                'supplier_code': 'SK-100', 'supplier_name': 'ケシゴム大'}
             ]}
          ], 200));
      final repo = ProductRepositoryImpl(_dio(adapter));

      final result = await repo.list(search: 'SK-100');

      result.when(
        success: (rows) => expect(rows.single.supplierNames.single.supplierName, 'ケシゴム大'),
        failure: (f) => fail('$f'),
      );
    });
  });
}
