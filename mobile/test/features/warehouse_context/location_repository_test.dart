import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/warehouse_context/data/location_repository.dart';

import '../../support/fake_http_adapter.dart';

Dio _dio(FakeHttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://x.test/rest/v1'));
  dio.httpClientAdapter = adapter;
  return dio;
}

/// `location_tree` for Zone → Aisle → Rack → Shelf: the depth §7 asks for, which
/// the old Warehouse → Zone → Bin shape could not express.
Object _treePayload() => [
      {
        'id': 1,
        'code': 'Z1',
        'name': 'ゾーン1',
        'location_type': 'STORAGE',
        'is_active': true,
        'pickable': true,
        'zone_id': 3,
        'bin_id': null,
        'on_hand': null,
        'children': [
          {
            'id': 2,
            'code': 'Z1-AISLE-1',
            'location_type': 'STORAGE',
            'is_active': true,
            'children': [
              {
                'id': 3,
                'code': 'Z1-R-01',
                'location_type': 'STORAGE',
                'is_active': true,
                'children': [
                  {
                    'id': 4,
                    'code': 'Z1-R-01-S3',
                    'name': '棚3',
                    'location_type': 'PICKING',
                    'barcode': 'SHELFZ1R01S3',
                    'is_active': true,
                    'pickable': true,
                    'bin_id': 11,
                    'on_hand': 30,
                    'children': [],
                  }
                ],
              }
            ],
          }
        ],
      },
      {
        'id': 5,
        'code': 'RECV-01',
        'name': '入荷エリア',
        'location_type': 'RECEIVING',
        'is_active': true,
        'pickable': false,
        'receivable': true,
        'is_virtual': true,
        'children': [],
      },
    ];

void main() {
  group('LocationRepositoryImpl.tree', () {
    test('reads the tree nested to its full depth', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(_treePayload(), 200);
      });

      final result = await LocationRepositoryImpl(_dio(adapter)).tree(1);

      expect(captured.path, '/rpc/location_tree');
      final body = captured.data as Map;
      expect(body['p_warehouse_id'], 1);
      expect(body['p_include_inactive'], isFalse);
      result.when(
        success: (roots) {
          expect(roots, hasLength(2));
          final zone = roots.first;
          // Four levels, arriving nested rather than rebuilt from parent ids.
          final shelf =
              zone.children.single.children.single.children.single;
          expect(shelf.code, 'Z1-R-01-S3');
          expect(shelf.locationType, 'PICKING');
          expect(shelf.barcode, 'SHELFZ1R01S3');
          // A bin carries its quantity; a rack is not somewhere stock is
          // counted, so it reports null rather than zero.
          expect(shelf.isBin, isTrue);
          expect(shelf.onHand, 30);
          expect(zone.onHand, isNull);
          expect(zone.isBin, isFalse);
          // descendants walks the whole subtree so no caller repeats the
          // recursion.
          expect(zone.descendants.length, 4);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('a virtual area carries its flags', () async {
      final adapter =
          FakeHttpClientAdapter((_) => jsonResponseBody(_treePayload(), 200));

      final result = await LocationRepositoryImpl(_dio(adapter)).tree(1);

      result.when(
        success: (roots) {
          final receiving = roots.last;
          expect(receiving.locationType, 'RECEIVING');
          expect(receiving.isVirtual, isTrue);
          expect(receiving.receivable, isTrue);
          expect(receiving.pickable, isFalse);
          expect(receiving.hasChildren, isFalse);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('asks for inactive nodes when told to', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody([], 200);
      });

      await LocationRepositoryImpl(_dio(adapter))
          .tree(1, includeInactive: true);

      expect((captured.data as Map)['p_include_inactive'], isTrue);
    });
  });

  group('LocationRepositoryImpl.types', () {
    test('reads each type with the defaults it hands a new location', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody([
          {
            'code': 'STORAGE',
            'name': '保管',
            'default_pickable': true,
            'default_receivable': false,
            'default_virtual': false,
          },
          {
            'code': 'RECEIVING',
            'name': '入荷',
            'default_pickable': false,
            'default_receivable': true,
            'default_virtual': true,
          },
        ], 200);
      });

      final result = await LocationRepositoryImpl(_dio(adapter)).types();

      expect(captured.path, '/rpc/list_location_types');
      result.when(
        success: (types) {
          expect(types.map((t) => t.code), ['STORAGE', 'RECEIVING']);
          // §8's point: the behaviour of a type is data, not a convention.
          expect(types.last.defaultReceivable, isTrue);
          expect(types.last.defaultPickable, isFalse);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });
  });

  group('LocationRepositoryImpl.create', () {
    test('names the parent by code, and leaves the flags to the type', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(9, 200);
      });

      final result = await LocationRepositoryImpl(_dio(adapter)).create(
        warehouseId: 1,
        code: 'Z1-R-02',
        name: 'ラック2',
        locationType: 'STORAGE',
        parentCode: 'Z1-AISLE-1',
      );

      expect(captured.path, '/rpc/create_location');
      final body = captured.data as Map;
      expect(body['p_code'], 'Z1-R-02');
      // A code, because that is what is printed on the rack the operator is
      // standing at.
      expect(body['p_parent_code'], 'Z1-AISLE-1');
      // Null flags mean "whatever this type says", which is what makes picking
      // RECEIVING one decision instead of six.
      expect(body['p_pickable'], isNull);
      expect(body['p_receivable'], isNull);
      result.when(
        success: (id) => expect(id, 9),
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('a cycle is refused by the server and surfaces as a failure', () async {
      final adapter = FakeHttpClientAdapter((_) => jsonResponseBody(
            {'message': 'location Z1-AISLE-1 cannot be its own ancestor'},
            400,
          ));

      final result = await LocationRepositoryImpl(_dio(adapter))
          .create(warehouseId: 1, code: 'X', parentCode: 'Z1-R-01-S3');

      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.message, contains('own ancestor')),
      );
    });
  });

  group('LocationRepositoryImpl.update', () {
    test('sends only what changed', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(true, 200);
      });

      await LocationRepositoryImpl(_dio(adapter))
          .update(locationId: 3, isActive: false);

      expect(captured.path, '/rpc/update_location');
      final body = captured.data as Map;
      expect(body['p_location_id'], 3);
      expect(body['p_is_active'], isFalse);
      // Everything else is null, which the RPC reads as "leave it alone" — so
      // switching a rack off cannot accidentally rewrite its type or parent.
      expect(body['p_location_type'], isNull);
      expect(body['p_parent_code'], isNull);
      expect(body['p_name'], isNull);
    });
  });
}
