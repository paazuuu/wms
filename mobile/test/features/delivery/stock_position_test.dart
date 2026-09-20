import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/delivery/data/stock_repository.dart';
import 'package:wms_mobile/features/delivery/domain/stock_item.dart';
import 'package:wms_mobile/features/delivery/domain/stock_position.dart';

import '../../support/fake_http_adapter.dart';

Dio _dio(FakeHttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://x.test/rest/v1'));
  dio.httpClientAdapter = adapter;
  return dio;
}

/// `stock_position` for a product with 100 on hand, 50 quarantined and 30
/// promised — the shape §5 says the old single `on_hand` could not express.
Map<String, dynamic> _positionPayload() => {
      'product_id': 7,
      'warehouse_id': 1,
      'on_hand': 100,
      'reserved': 30,
      'available': 20,
      'allocated': 30,
      'by_status': [
        {
          'product_id': 7,
          'warehouse_id': 1,
          'on_hand': 100,
          'available': 50,
          'parcels': [
            {'status': 'OK', 'name': '良品', 'quantity': 50, 'lot_id': null},
            {
              'status': 'QUARANTINE',
              'name': '隔離',
              'quantity': 50,
              'lot_id': 3,
              'lot_code': 'A-2024/05',
              'expiry_date': '2027-03-31',
            },
          ],
        }
      ],
    };

void main() {
  group('StockPosition', () {
    test('keeps §5\'s four numbers apart', () {
      final p = StockPosition.fromJson(_positionPayload());

      expect(p.onHand, 100);
      expect(p.reserved, 30);
      expect(p.available, 20);
      expect(p.allocated, 30);
      // On hand but not shippable: the 50 quarantined. This is the number the
      // old single quantity hid.
      expect(p.unavailable, 50);
      expect(p.isOverPromised, isFalse);
    });

    test('flattens the parcels out of by_status', () {
      final p = StockPosition.fromJson(_positionPayload());

      expect(p.parcels, hasLength(2));
      final held = p.parcels.firstWhere((x) => x.status == 'QUARANTINE');
      expect(held.statusName, '隔離');
      expect(held.quantity, 50);
      expect(held.lotCode, 'A-2024/05');
      expect(held.expiryDate, DateTime.parse('2027-03-31'));
    });

    test('a negative available is kept, not clamped', () {
      // 0064 deliberately does not floor `available`: more promised than can be
      // shipped is a real state, and the fix is a purchase or a release.
      final p = StockPosition.fromJson(const {
        'product_id': 7,
        'on_hand': 20,
        'reserved': 40,
        'available': -20,
        'allocated': 40,
      });

      expect(p.available, -20);
      expect(p.isOverPromised, isTrue);
    });

    test('a product with no stock reads as zeroes, not as an error', () {
      final p = StockPosition.fromJson(const {'product_id': 7});
      expect(p.onHand, 0);
      expect(p.available, 0);
      expect(p.parcels, isEmpty);
      expect(p.isOverPromised, isFalse);
    });
  });

  group('StockRepositoryImpl.position', () {
    test('posts the product and warehouse to stock_position', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(_positionPayload(), 200);
      });

      final result =
          await StockRepositoryImpl(_dio(adapter)).position(7, warehouseId: 1);

      expect(captured.path, '/rpc/stock_position');
      final body = captured.data as Map;
      expect(body['p_product_id'], 7);
      expect(body['p_warehouse_id'], 1);
      result.when(
        success: (p) {
          expect(p.available, 20);
          expect(p.parcels, hasLength(2));
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('an empty body is a product with no stock', () async {
      final adapter = FakeHttpClientAdapter((_) => jsonResponseBody(null, 200));

      final result =
          await StockRepositoryImpl(_dio(adapter)).position(7, warehouseId: 1);

      result.when(
        success: (p) {
          expect(p.productId, 7);
          expect(p.onHand, 0);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });
  });

  group('StockRepositoryImpl.list', () {
    test('asks for product_id so a row can reach the new model', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody([
          {
            'jan_code': '4901234567890',
            'product_name': 'ペン',
            'on_hand': 30,
            'product_id': 7,
          },
          {
            'jan_code': '4909999999999',
            'product_name': '未登録品',
            'on_hand': 7,
            'product_id': null,
          },
        ], 200);
      });

      final result =
          await StockRepositoryImpl(_dio(adapter)).list(warehouseId: 1);

      expect(captured.queryParameters['select'],
          contains('product_id'));
      result.when(
        success: (items) {
          expect(items.first.productId, 7);
          expect(items.first.isLinked, isTrue);
          // 0058's honest case: stock received against a JAN the product master
          // does not know yet. Not an error — the link fills itself in when the
          // product is registered.
          expect(items.last.productId, isNull);
          expect(items.last.isLinked, isFalse);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('a row with no product_id key at all still parses', () async {
      final adapter = FakeHttpClientAdapter((_) => jsonResponseBody([
            {'jan_code': '4901234567890', 'on_hand': 3}
          ], 200));

      final result = await StockRepositoryImpl(_dio(adapter)).list();

      result.when(
        success: (items) => expect(items.single,
            const StockItem(janCode: '4901234567890', onHand: 3)),
        failure: (f) => fail('expected success, got $f'),
      );
    });
  });
}
