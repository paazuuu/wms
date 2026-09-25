import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/inventory/data/inventory_repository.dart';

import '../../support/fake_http_adapter.dart';

Dio _dio(FakeHttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://x.test/rest/v1'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('InventoryRepositoryImpl.expiringLots', () {
    test('posts the horizon and keeps expired lots by default', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody([
          {
            'lot_id': 5,
            'lot_code': 'A-2024/05',
            'expiry_date': '2027-03-31',
            'days_to_expiry': 20,
            'is_expired': false,
            'product_id': 7,
            'product_name': 'ボールペン',
            'jan_code': '4901234567890',
            'serial_count': 0,
          },
          {
            'lot_id': 6,
            'lot_code': 'OLD-1',
            'expiry_date': '2026-01-31',
            'days_to_expiry': -40,
            'is_expired': true,
            'product_id': 7,
            'product_name': 'ボールペン',
          },
        ], 200);
      });

      final result =
          await InventoryRepositoryImpl(_dio(adapter)).expiringLots(days: 90);

      expect(captured.path, '/rpc/expiring_lots');
      final body = captured.data as Map;
      expect(body['p_days'], 90);
      // An expired lot is the most urgent row, not an archive to filter away.
      expect(body['p_include_expired'], isTrue);
      result.when(
        success: (lots) {
          expect(lots, hasLength(2));
          expect(lots.first.lotCode, 'A-2024/05');
          expect(lots.first.daysToExpiry, 20);
          expect(lots.last.isExpired, isTrue);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });
  });

  group('InventoryRepositoryImpl.reservations', () {
    test('posts the filters and reads the allocations nested in each row',
        () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody([
          {
            'id': 3,
            'product_id': 7,
            'product_name': 'ボールペン',
            'warehouse_id': 1,
            'quantity': 30,
            'fulfilled_quantity': 10,
            'allocated_quantity': 20,
            'reference_type': 'sales_order',
            'reference_id': 'SO-1',
            'status': 'ACTIVE',
            'expires_at': null,
            'is_expired': false,
            'allocations': [
              {
                'allocation_id': 9,
                'stock_unit_id': 11,
                'quantity': 20,
                'status': 'OK',
                'lot_id': 5,
                'lot_code': 'A-2024/05',
                'expiry_date': '2027-03-31',
                'bin_id': null,
              }
            ],
          }
        ], 200);
      });

      final result = await InventoryRepositoryImpl(_dio(adapter))
          .reservations(warehouseId: 1, status: 'ACTIVE');

      expect(captured.path, '/rpc/list_reservations');
      final body = captured.data as Map;
      expect(body['p_warehouse_id'], 1);
      expect(body['p_status'], 'ACTIVE');
      result.when(
        success: (rows) {
          final r = rows.single;
          expect(r.quantity, 30);
          expect(r.fulfilledQuantity, 10);
          expect(r.allocatedQuantity, 20);
          // 30 promised, 20 pinned to parcels: 10 has no shelf behind it yet.
          expect(r.unallocated, 10);
          // 30 promised, 10 shipped: 20 still owed.
          expect(r.outstanding, 20);
          expect(r.isHolding, isTrue);
          expect(r.allocations.single.lotCode, 'A-2024/05');
          expect(r.allocations.single.quantity, 20);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('a null status asks for every one, not for the default', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody([], 200);
      });

      await InventoryRepositoryImpl(_dio(adapter)).reservations(status: null);

      // The RPC defaults to ACTIVE when the parameter is absent, so "all" has to
      // be said explicitly — '' is how it is said.
      expect((captured.data as Map)['p_status'], '');
    });

    test('a lapsed reservation reads ACTIVE and holds nothing', () async {
      final adapter = FakeHttpClientAdapter((_) => jsonResponseBody([
            {
              'id': 4,
              'product_id': 7,
              'product_name': 'ペン',
              'warehouse_id': 1,
              'quantity': 10,
              'status': 'ACTIVE',
              'expires_at': '2026-01-01T00:00:00Z',
              'is_expired': true,
            }
          ], 200));

      final result = await InventoryRepositoryImpl(_dio(adapter)).reservations();

      result.when(
        success: (rows) {
          final r = rows.single;
          // The clock decides, not a cleanup job — so the two facts stay apart.
          expect(r.status, 'ACTIVE');
          expect(r.isActive, isTrue);
          expect(r.isExpired, isTrue);
          expect(r.isHolding, isFalse);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });
  });

  group('InventoryRepositoryImpl.overAllocated', () {
    test('reads the gap between a parcel and what was promised from it',
        () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody([
          {
            'stock_unit_id': 11,
            'warehouse_id': 1,
            'product_id': 7,
            'product_name': 'ボールペン',
            'status': 'OK',
            'quantity': 20,
            'allocated': 40,
            'over': 20,
          }
        ], 200);
      });

      final result =
          await InventoryRepositoryImpl(_dio(adapter)).overAllocated(warehouseId: 1);

      expect(captured.path, '/rpc/over_allocated_stock');
      result.when(
        success: (rows) {
          expect(rows.single.quantity, 20);
          expect(rows.single.allocated, 40);
          expect(rows.single.over, 20);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });
  });

  group('InventoryRepositoryImpl.releaseReservation', () {
    test('posts the id and treats the returned position as success', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(
            {'reservation_id': 3, 'status': 'RELEASED', 'available': 70}, 200);
      });

      final result =
          await InventoryRepositoryImpl(_dio(adapter)).releaseReservation(3);

      expect(captured.path, '/rpc/release_reservation');
      expect((captured.data as Map)['p_reservation_id'], 3);
      result.when(
        success: (ok) => expect(ok, isTrue),
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('a double release is a failure the screen can show', () async {
      final adapter = FakeHttpClientAdapter((_) => jsonResponseBody(
            {'message': 'reservation 3 is already RELEASED'},
            400,
          ));

      final result =
          await InventoryRepositoryImpl(_dio(adapter)).releaseReservation(3);

      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.message, contains('already RELEASED')),
      );
    });
  });

  group('InventoryRepositoryImpl.replenishment', () {
    test('reads the shortfall, the suggestion and why stock is blocked',
        () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody([
          {
            'warehouse_id': 1,
            'warehouse_name': 'メイン倉庫',
            'product_id': 7,
            'jan_code': '4901234567890',
            'product_name': 'ボールペン',
            'reorder_point': 50,
            'max_stock': 200,
            'on_hand': 100,
            'available': 10,
            'shortfall': 40,
            'suggested_quantity': 190,
            'preferred_supplier_name': '文具商事',
            'lead_time_days': 7,
            'base_uom': 'PCS',
          }
        ], 200);
      });

      final result = await InventoryRepositoryImpl(_dio(adapter))
          .replenishment(warehouseId: 1);

      expect(captured.path, '/rpc/replenishment_suggestions');
      expect((captured.data as Map)['p_warehouse_id'], 1);
      result.when(
        success: (rows) {
          final r = rows.single;
          expect(r.shortfall, 40);
          expect(r.suggestedQuantity, 190);
          // 100 on hand yet listed: 90 of it cannot cover an order. This is the
          // case comparing against on_hand would have got wrong.
          expect(r.blocked, 90);
          expect(r.leadTimeDays, 7);
          expect(r.baseUom, 'PCS');
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });
  });

  group('InventoryRepositoryImpl.fulfilReservation', () {
    test('posts the id and quantity, and treats the returned position as success',
        () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(
            {'reservation_id': 3, 'fulfilled_quantity': 20}, 200);
      });

      final result = await InventoryRepositoryImpl(_dio(adapter))
          .fulfilReservation(3, quantity: 20);

      expect(captured.path, '/rpc/fulfil_reservation');
      final body = captured.data as Map;
      expect(body['p_reservation_id'], 3);
      expect(body['p_quantity'], 20);
      result.when(
        success: (ok) => expect(ok, isTrue),
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('a null quantity is sent as null, meaning "all of it"', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody({'reservation_id': 3}, 200);
      });

      await InventoryRepositoryImpl(_dio(adapter)).fulfilReservation(3);

      expect((captured.data as Map)['p_quantity'], isNull);
    });

    test('fulfilling one already fulfilled is a failure the screen can show',
        () async {
      final adapter = FakeHttpClientAdapter((_) => jsonResponseBody(
            {'message': 'reservation 3 is FULFILLED'},
            400,
          ));

      final result = await InventoryRepositoryImpl(_dio(adapter))
          .fulfilReservation(3, quantity: 5);

      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.message, contains('FULFILLED')),
      );
    });
  });

  group('InventoryRepositoryImpl.stockReconciliation', () {
    test('reads a quantity drift and an unlinked JAN alike', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody([
          {
            'warehouse_id': 1,
            'jan_code': '4901234567890',
            'product_id': 7,
            'stock_levels_on_hand': 100,
            'stock_units_on_hand': 90,
            'reason': 'quantity drift',
          },
          {
            'warehouse_id': 1,
            'jan_code': '4900000000099',
            'product_id': null,
            'stock_levels_on_hand': 5,
            'stock_units_on_hand': 0,
            'reason': 'unlinked jan_code',
          },
        ], 200);
      });

      final result = await InventoryRepositoryImpl(_dio(adapter))
          .stockReconciliation(warehouseId: 1);

      expect(captured.path, '/rpc/stock_reconciliation');
      expect((captured.data as Map)['p_warehouse_id'], 1);
      result.when(
        success: (rows) {
          expect(rows, hasLength(2));
          final drift = rows[0];
          expect(drift.productId, 7);
          expect(drift.isUnlinked, isFalse);
          // The ledger claims 100, the units only back up 90.
          expect(drift.drift, 10);
          final unlinked = rows[1];
          expect(unlinked.productId, isNull);
          expect(unlinked.isUnlinked, isTrue);
          expect(unlinked.reason, 'unlinked jan_code');
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });
  });
}
