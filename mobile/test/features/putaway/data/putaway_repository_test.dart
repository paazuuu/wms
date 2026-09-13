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
            'product_name': 'テスト商品',
            'pending_quantity': 30,
            'warehouse_on_hand': 48,
            'binned_quantity': 18,
            'suggested_bin_id': 7,
            'suggested_bin_code': 'PA-TEST-A',
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
          expect(task.binnedQuantity, 18);
          expect(task.suggestedBinCode, 'PA-TEST-A');
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
}
