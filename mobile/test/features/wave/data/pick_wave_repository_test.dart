import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/wave/data/pick_wave_repository.dart';

import '../../../support/fake_http_adapter.dart';

Dio _dio(FakeHttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://x.test/rest/v1'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('PickWaveRepositoryImpl', () {
    test('create() posts the warehouse and shipment ids to create_pick_wave',
        () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody({
          'wave_id': 5,
          'code': 'WV-000005',
          'pick_list_ids': [10, 11],
          'skipped': [
            {'shipment_plan_id': 99, 'reason': 'not_found'}
          ],
        }, 200);
      });
      final repo = PickWaveRepositoryImpl(_dio(adapter));

      final result = await repo.create(
          warehouseId: 1, shipmentPlanIds: [10, 11, 99], note: '午前便');

      expect(captured.path, '/rpc/create_pick_wave');
      final body = captured.data as Map;
      expect(body['p_warehouse_id'], 1);
      expect(body['p_shipment_plan_ids'], [10, 11, 99]);
      expect(body['p_note'], '午前便');
      result.when(
        success: (created) {
          expect(created.waveId, 5);
          expect(created.code, 'WV-000005');
          expect(created.pickListIds, [10, 11]);
          expect(created.skipped.single.reason, 'not_found');
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('plan() reads the aggregated sheet from wave_pick_plan', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody({
          'wave_id': 5,
          'warehouse_id': 1,
          'total_units': 30,
          'stops': [
            {
              'bin_id': 3,
              'bin_code': 'R-01-A',
              'product_id': 7,
              'jan_code': '4900000000001',
              'product_name': 'ペン',
              'lot_id': 2,
              'lot_code': 'L-B',
              'expiry_date': '2027-01-01',
              'stock_unit_id': 40,
              'quantity': 30,
              'lines': [
                {'task_id': 1, 'pick_list_id': 10, 'shipment_plan_id': 100, 'quantity': 10},
                {'task_id': 2, 'pick_list_id': 11, 'shipment_plan_id': 101, 'quantity': 10},
                {'task_id': 3, 'pick_list_id': 12, 'shipment_plan_id': 102, 'quantity': 10},
              ],
            }
          ],
          'short': [],
        }, 200);
      });
      final repo = PickWaveRepositoryImpl(_dio(adapter));

      final result = await repo.plan(5);

      expect(captured.path, '/rpc/wave_pick_plan');
      expect((captured.data as Map)['p_wave_id'], 5);
      result.when(
        success: (plan) {
          expect(plan.totalUnits, 30);
          expect(plan.stops, hasLength(1));
          final stop = plan.stops.single;
          expect(stop.binCode, 'R-01-A');
          expect(stop.lotCode, 'L-B');
          expect(stop.quantity, 30);
          // The economics of a wave: three orders, one stop.
          expect(stop.lines, hasLength(3));
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('assign() posts the wave id and user id to assign_pick_wave', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody({
          'id': 5,
          'status': 'PICKING',
          'assigned_to': 'user-1',
          'assigned_to_name': 'ピッカー',
        }, 200);
      });
      final repo = PickWaveRepositoryImpl(_dio(adapter));

      final result = await repo.assign(5, userId: 'user-1');

      expect(captured.path, '/rpc/assign_pick_wave');
      expect((captured.data as Map)['p_wave_id'], 5);
      expect((captured.data as Map)['p_user_id'], 'user-1');
      result.when(
        success: (wave) => expect(wave.assignedToName, 'ピッカー'),
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('complete() and cancel() report what changed', () async {
      final completeAdapter = FakeHttpClientAdapter(
          (_) => jsonResponseBody({'wave_id': 5, 'status': 'DONE', 'lists_closed': 3}, 200));
      final completeRepo = PickWaveRepositoryImpl(_dio(completeAdapter));
      final completed = await completeRepo.complete(5);
      completed.when(
        success: (o) {
          expect(o.status, 'DONE');
          expect(o.count, 3);
        },
        failure: (f) => fail('expected success, got $f'),
      );

      final cancelAdapter = FakeHttpClientAdapter((_) =>
          jsonResponseBody({'wave_id': 5, 'status': 'CANCELLED', 'lists_released': 1}, 200));
      final cancelRepo = PickWaveRepositoryImpl(_dio(cancelAdapter));
      final cancelled = await cancelRepo.cancel(5);
      cancelled.when(
        success: (o) {
          expect(o.status, 'CANCELLED');
          expect(o.count, 1);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });
  });
}
