import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/putaway/data/putaway_repository.dart';

import '../../../support/fake_http_adapter.dart';

Dio _dio(FakeHttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://x.test/rest/v1'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('PutawayRepositoryImpl', () {
    test('queue() posts the warehouse and parses the derived rows', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody([
          {
            'jan_code': '4988601001053',
            'product_id': 5,
            'product_name': 'テスト商品',
            'pending_quantity': 30,
            'warehouse_on_hand': 48,
            'status_code': 'OK',
            'counts_available': true,
            'suggestions': [
              {
                'bin_id': 7,
                'bin_code': 'PA-TEST-A',
                'bin_type': 'PICKABLE',
                'on_hand': 18,
                'score': 100,
                'reason': '同一商品あり',
              },
            ],
          },
        ], 200);
      });

      final result = await PutawayRepositoryImpl(_dio(adapter)).queue(1);

      expect(captured.path, '/rpc/putaway_queue');
      expect((captured.data as Map)['p_warehouse_id'], 1);
      result.when(
        success: (tasks) {
          expect(tasks, hasLength(1));
          final task = tasks.single;
          expect(task.janCode, '4988601001053');
          expect(task.title, 'テスト商品');
          expect(task.pendingQuantity, 30);
          expect(task.warehouseOnHand, 48);
          expect(task.bestSuggestion?.binCode, 'PA-TEST-A');
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('queue() unwraps a single-element list wrapping the jsonb array',
        () async {
      final adapter = FakeHttpClientAdapter((_) => jsonResponseBody([
            [
              {'jan_code': '4901234567890', 'pending_quantity': 5},
            ],
          ], 200));

      final result = await PutawayRepositoryImpl(_dio(adapter)).queue(1);

      result.when(
        success: (tasks) {
          expect(tasks, hasLength(1));
          expect(tasks.single.janCode, '4901234567890');
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('binByCode() returns the bin with what it currently holds', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody({
          'bin_id': 7,
          'bin_code': 'PA-TEST-A',
          'bin_type': 'PICKABLE',
          'is_active': true,
          'lines': [
            {'jan_code': '4988601001053', 'product_name': 'テスト商品', 'on_hand': 18},
            {'jan_code': '4901234567890', 'on_hand': 4},
          ],
        }, 200);
      });

      final result =
          await PutawayRepositoryImpl(_dio(adapter)).binByCode(1, ' pa-test-a ');

      expect(captured.path, '/rpc/bin_by_code');
      final body = captured.data as Map;
      expect(body['p_warehouse_id'], 1);
      // Sent as typed; the server normalises case/whitespace.
      expect(body['p_code'], ' pa-test-a ');
      result.when(
        success: (bin) {
          expect(bin, isNotNull);
          expect(bin!.binCode, 'PA-TEST-A');
          expect(bin.isActive, isTrue);
          expect(bin.lines, hasLength(2));
          expect(bin.onHandOf('4988601001053'), 18);
          expect(bin.onHandOf('9999999999999'), 0);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('binByCode() maps an unknown code to success with null', () async {
      final adapter = FakeHttpClientAdapter((_) => jsonResponseBody(null, 200));

      final result = await PutawayRepositoryImpl(_dio(adapter)).binByCode(1, 'NOPE');

      result.when(
        success: (bin) => expect(bin, isNull),
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('confirm() posts the idempotency key and parses the result', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody({
          'jan_code': '4988601001053',
          'quantity': 18,
          'bin_code': 'PA-TEST-A',
          'bin_on_hand': 18,
          'pending_after': 12,
          'replayed': false,
        }, 200);
      });

      final result = await PutawayRepositoryImpl(_dio(adapter)).confirm(
        warehouseId: 1,
        janCode: '4988601001053',
        binId: 7,
        quantity: 18,
        idempotencyKey: 'pa-1-4988601001053-7-123',
        note: 'メモ',
      );

      expect(captured.path, '/rpc/confirm_putaway');
      final body = captured.data as Map;
      expect(body['p_warehouse_id'], 1);
      expect(body['p_jan_code'], '4988601001053');
      expect(body['p_bin_id'], 7);
      expect(body['p_quantity'], 18);
      expect(body['p_idempotency_key'], 'pa-1-4988601001053-7-123');
      expect(body['p_note'], 'メモ');
      result.when(
        success: (res) {
          expect(res.quantity, 18);
          expect(res.binCode, 'PA-TEST-A');
          expect(res.binOnHand, 18);
          expect(res.pendingAfter, 12);
          expect(res.replayed, isFalse);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('confirm() surfaces a replayed key', () async {
      final adapter = FakeHttpClientAdapter((_) => jsonResponseBody({
            'jan_code': '4988601001053',
            'quantity': 18,
            'bin_code': 'PA-TEST-A',
            'pending_after': 12,
            'replayed': true,
          }, 200));

      final result = await PutawayRepositoryImpl(_dio(adapter)).confirm(
        warehouseId: 1,
        janCode: '4988601001053',
        binId: 7,
        quantity: 18,
        idempotencyKey: 'pa-1-4988601001053-7-123',
      );

      result.when(
        success: (res) => expect(res.replayed, isTrue),
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('confirm() maps a server refusal to a failure', () async {
      final adapter = FakeHttpClientAdapter((_) => jsonResponseBody(
          {'message': 'Only 12 of 4988601001053 awaits put-away'}, 400));

      final result = await PutawayRepositoryImpl(_dio(adapter)).confirm(
        warehouseId: 1,
        janCode: '4988601001053',
        binId: 7,
        quantity: 99,
        idempotencyKey: 'pa-1-4988601001053-7-456',
      );

      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.message, contains('awaits put-away')),
      );
    });
  });

  group('PutawayRepositoryImpl parcels and suggestions (0069)', () {
    test('reads a held parcel with its lot, status and ranked bins', () async {
      final adapter = FakeHttpClientAdapter((_) => jsonResponseBody([
            {
              'product_id': 34,
              'jan_code': '4988601001053',
              'product_name': 'テスト商品',
              'lot_id': 27,
              'lot_code': 'QC-L1',
              'expiry': '2026-11-19',
              'status_code': 'QC_PENDING',
              'status_name': '検品待ち',
              'counts_available': false,
              'pending_quantity': 40,
              'warehouse_on_hand': 40,
              'suggestions': [
                {
                  'bin_id': 9,
                  'bin_code': 'QC-01',
                  'bin_type': 'QC_HOLD',
                  'zone_id': 2,
                  'on_hand': 0,
                  'same_lot': false,
                  'capacity': null,
                  'free_capacity': null,
                  'score': 0,
                  'reason': null,
                },
              ],
            },
          ], 200));

      final result = await PutawayRepositoryImpl(_dio(adapter)).queue(1);

      result.when(
        success: (tasks) {
          final t = tasks.single;
          expect(t.lotCode, 'QC-L1');
          expect(t.expiry, DateTime(2026, 11, 19));
          expect(t.statusName, '検品待ち');
          // The flag that decides where it may go, and whether the screen warns.
          expect(t.countsAvailable, isFalse);
          expect(t.isHeld, isTrue);
          expect(t.bestSuggestion?.binType, 'QC_HOLD');
          expect(t.hasNowhereToGo, isFalse);
          // No capacity recorded is not zero capacity — that distinction is why
          // capacity is a preference and not a hard rule (§14).
          expect(t.bestSuggestion?.hasCapacityRecorded, isFalse);
          expect(t.bestSuggestion?.freeCapacity, isNull);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('keeps the server ranking, and the reason behind the top bin', () async {
      final adapter = FakeHttpClientAdapter((_) => jsonResponseBody([
            {
              'jan_code': '4988601001053',
              'pending_quantity': 10,
              'status_code': 'OK',
              'counts_available': true,
              'suggestions': [
                {
                  'bin_id': 7,
                  'bin_code': 'PA-B',
                  'bin_type': 'PICKABLE',
                  'on_hand': 4,
                  'same_lot': true,
                  'capacity': 50,
                  'free_capacity': 46,
                  'score': 140,
                  'reason': '同一商品あり / 同一ロット / 空き46',
                },
                {
                  'bin_id': 8,
                  'bin_code': 'PA-A',
                  'bin_type': 'PICKABLE',
                  'on_hand': 0,
                  'score': 0,
                  'reason': '',
                },
              ],
            },
          ], 200));

      final result = await PutawayRepositoryImpl(_dio(adapter)).queue(1);

      result.when(
        success: (tasks) {
          final t = tasks.single;
          // Ranked by the server, not re-sorted here: PA-B outranks PA-A even
          // though PA-A sorts first alphabetically.
          expect(t.suggestions.map((s) => s.binCode), ['PA-B', 'PA-A']);
          expect(t.bestSuggestion?.sameLot, isTrue);
          expect(t.bestSuggestion?.freeCapacity, 46);
          expect(t.bestSuggestion?.reason, contains('同一ロット'));
          // An empty reason string is no reason, not an empty label to render.
          expect(t.suggestions.last.reason, isNull);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('a parcel the server can offer no bin for says so', () async {
      final adapter = FakeHttpClientAdapter((_) => jsonResponseBody([
            {
              'jan_code': 'X',
              'pending_quantity': 5,
              'status_code': 'DAMAGED',
              'counts_available': false,
              'suggestions': [],
            },
          ], 200));

      final result = await PutawayRepositoryImpl(_dio(adapter)).queue(1);

      result.when(
        success: (tasks) {
          expect(tasks.single.hasNowhereToGo, isTrue);
          expect(tasks.single.bestSuggestion, isNull);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('confirm names the parcel, and reports how much actually moved',
        () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody({
          'jan_code': '4988601001053',
          'product_id': 34,
          'bin_code': 'QC-01',
          'quantity': 40,
          'moved': 40,
          'pending_after': 0,
          'replayed': false,
        }, 200);
      });

      final result = await PutawayRepositoryImpl(_dio(adapter)).confirm(
        warehouseId: 1,
        janCode: '4988601001053',
        binId: 9,
        quantity: 40,
        idempotencyKey: 'k1',
        lotCode: 'QC-L1',
        statusCode: 'QC_PENDING',
      );

      final body = captured.data as Map;
      expect(body['p_lot_code'], 'QC-L1');
      expect(body['p_status_code'], 'QC_PENDING');
      result.when(
        success: (r) {
          expect(r.moved, 40);
          expect(r.pendingAfter, 0);
          expect(r.productId, 34);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('the server refusing a pickable bin for held stock is a failure',
        () async {
      final adapter = FakeHttpClientAdapter((_) => jsonResponseBody({
            'message':
                'bin T69-PICK-A is a PICKABLE bin and cannot hold this stock (it is held or failed)',
          }, 400));

      final result = await PutawayRepositoryImpl(_dio(adapter)).confirm(
        warehouseId: 1,
        janCode: 'X',
        binId: 1,
        quantity: 1,
        idempotencyKey: 'k2',
        statusCode: 'QC_PENDING',
      );

      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.message, contains('cannot hold this stock')),
      );
    });
  });
}
