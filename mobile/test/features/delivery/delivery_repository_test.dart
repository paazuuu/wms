import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/delivery/data/delivery_repository.dart';

import '../../support/fake_http_adapter.dart';

Dio _dio(FakeHttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://x.test/rest/v1'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('DeliveryRepositoryImpl.recordReceiptItem', () {
    test('posts a parcel by hand, straight to the guarded RPC', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody({'receipt_item_id': 91}, 200);
      });

      final result =
          await DeliveryRepositoryImpl(_dio(adapter)).recordReceiptItem(
        reconciliationId: 12,
        janCode: '4901234567890',
        quantity: 3,
        lineId: 30,
        lotCode: 'L-A',
        expiry: DateTime(2027, 3, 31),
        locationCode: 'RECV-01',
      );

      // Straight to PostgREST, not the receiving edge function: this is the
      // hand-added parcel path, gated by receiving.confirm in the database.
      expect(captured.path, '/rpc/record_receipt_item');
      final body = captured.data as Map;
      expect(body['p_reconciliation_id'], 12);
      expect(body['p_jan_code'], '4901234567890');
      expect(body['p_quantity'], 3);
      expect(body['p_line_id'], 30);
      expect(body['p_lot_code'], 'L-A');
      expect(body['p_expiry'], '2027-03-31');
      expect(body['p_location_code'], 'RECV-01');
      result.when(
        success: (ok) => expect(ok, isTrue),
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('a permission-denied add surfaces as a failure', () async {
      final adapter = FakeHttpClientAdapter((_) => jsonResponseBody(
            {'message': 'not permitted: receiving.confirm required'},
            403,
          ));

      final result =
          await DeliveryRepositoryImpl(_dio(adapter)).recordReceiptItem(
        reconciliationId: 12,
        janCode: '4901234567890',
        quantity: 1,
      );

      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) => expect(f.message, contains('receiving.confirm')),
      );
    });
  });
}
