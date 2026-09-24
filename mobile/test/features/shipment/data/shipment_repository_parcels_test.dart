import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/shipment/data/shipment_repository.dart';

import '../../../support/fake_http_adapter.dart';

Dio _dio(FakeHttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://x.test/rest/v1'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('ShipmentRepositoryImpl.parcels', () {
    test(
        'reads the bare jsonb array shipment_parcels returns — not a row-wrapped one',
        () async {
      late RequestOptions captured;
      // shipment_parcels `returns jsonb` where the value itself is a
      // jsonb_agg() array, so PostgREST's body *is* that array directly —
      // unlike a function returning a jsonb object, there is no extra
      // single-row wrapper to unwrap first.
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody([
          {
            'movement_id': 501,
            'created_at': '2026-09-20T10:00:00Z',
            'movement_type': 'SHIP',
            'jan_code': '4900000000001',
            'product_id': 7,
            'product_name': 'ペン',
            'quantity': 30,
            'lot_id': 2,
            'lot_code': 'L-B',
            'expiry_date': '2027-01-01',
            'serial_id': null,
            'serial_number': null,
            'bin_id': 3,
            'bin_code': 'R-01-A',
          },
          {
            'movement_id': 502,
            'created_at': '2026-09-20T10:05:00Z',
            'movement_type': 'SHIP_CANCEL',
            'jan_code': '4900000000001',
            'product_id': 7,
            'product_name': 'ペン',
            'quantity': -30,
            'lot_id': 2,
            'lot_code': 'L-B',
            'expiry_date': '2027-01-01',
            'bin_id': 3,
            'bin_code': 'R-01-A',
          },
        ], 200);
      });
      final repo = ShipmentRepositoryImpl(_dio(adapter), _dio(adapter));

      final result = await repo.parcels(9);

      expect(captured.path, '/rpc/shipment_parcels');
      expect((captured.data as Map)['p_plan_id'], 9);
      result.when(
        success: (parcels) {
          expect(parcels, hasLength(2));
          expect(parcels[0].quantity, 30);
          expect(parcels[0].lotCode, 'L-B');
          expect(parcels[0].isReversal, isFalse);
          expect(parcels[1].quantity, -30);
          expect(parcels[1].isReversal, isTrue);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('an empty shipment (nothing shipped yet) reads as an empty list',
        () async {
      final adapter =
          FakeHttpClientAdapter((_) => jsonResponseBody([], 200));
      final repo = ShipmentRepositoryImpl(_dio(adapter), _dio(adapter));

      final result = await repo.parcels(9);

      result.when(
        success: (parcels) => expect(parcels, isEmpty),
        failure: (f) => fail('expected success, got $f'),
      );
    });
  });
}
