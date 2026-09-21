import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/scan/barcode_resolver.dart';
import 'package:wms_mobile/core/scan/scan_context.dart';
import 'package:wms_mobile/core/scan/scan_resolution.dart';

import '../../support/fake_http_adapter.dart';

Dio _dio(FakeHttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://x.test/rest/v1'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('BarcodeResolverImpl', () {
    test('posts the raw code to resolve_barcode', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody({
          'kind': 'product',
          'barcode': '4901234567890',
          'product_id': 7,
          'name': 'ボールペン',
          'quantity_per_scan': 1,
        }, 200);
      });

      final result = await BarcodeResolverImpl(_dio(adapter)).resolve('４９０１２３４５６７８９０');

      expect(captured.path, '/rpc/resolve_barcode');
      // Sent as scanned: normalizing full-width digits, separators and a
      // 12-digit UPC-A is the server's job (`normalize_barcode`), so there is
      // one implementation of it rather than two that can disagree.
      expect((captured.data as Map)['p_barcode'], '４９０１２３４５６７８９０');
      result.when(
        success: (hit) {
          expect(hit.kind, ScanKind.product);
          expect(hit.productId, 7);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('accepts a single-element list wrapper', () async {
      final adapter = FakeHttpClientAdapter((_) => jsonResponseBody([
            {'kind': 'location', 'barcode': 'A-01', 'location_id': 3}
          ], 200));

      final result = await BarcodeResolverImpl(_dio(adapter)).resolve('A-01');

      result.when(
        success: (hit) {
          expect(hit.kind, ScanKind.location);
          expect(hit.locationId, 3);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('an empty body is an unknown code, not a failure', () async {
      final adapter = FakeHttpClientAdapter((_) => jsonResponseBody(null, 200));

      final result = await BarcodeResolverImpl(_dio(adapter)).resolve('NOPE');

      result.when(
        success: (hit) {
          expect(hit.kind, ScanKind.unknown);
          // The code comes back even though the server said nothing, so a
          // screen can still show what was scanned.
          expect(hit.barcode, 'NOPE');
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('a refused call is a failure the caller can show', () async {
      final adapter = FakeHttpClientAdapter((_) => jsonResponseBody(
            {'message': 'not permitted: product.view required'},
            403,
          ));

      final result = await BarcodeResolverImpl(_dio(adapter)).resolve('4901234567890');

      result.when(
        success: (_) => fail('expected failure'),
        failure: (f) {
          expect(f.statusCode, 403);
          expect(f.message, contains('not permitted'));
        },
      );
    });
  });

  group('BarcodeResolverImpl in a context', () {
    test('sends the step it is in, and narrows a lot by product', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody({
          'kind': 'lot',
          'barcode': 'L-A',
          'lot_id': 11,
          'lot_code': 'L-A',
          'product_id': 7,
          'context': 'QC',
          'expected': true,
          'expected_rank': 1,
        }, 200);
      });

      final result = await BarcodeResolverImpl(_dio(adapter)).resolve(
        'L-A',
        context: ScanContext.qc,
        productId: 7,
        warehouseId: 1,
      );

      final body = captured.data as Map;
      expect(body['p_barcode'], 'L-A');
      expect(body['p_context'], 'QC');
      // Without this, the same lot code on two products is ambiguous — so the
      // screen that knows which product it is inspecting has to say so.
      expect(body['p_product_id'], 7);
      expect(body['p_warehouse_id'], 1);
      result.when(
        success: (r) {
          expect(r.kind, ScanKind.lot);
          expect(r.context, ScanContext.qc);
          expect(r.expected, isTrue);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('with no context the parameters are sent as null, not omitted', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody({'kind': 'unknown', 'barcode': 'X'}, 200);
      });

      await BarcodeResolverImpl(_dio(adapter)).resolve('X');

      final body = captured.data as Map;
      // PostgREST fills a named argument's default only when the key is absent
      // or null, so sending null is the same as not asking — and keeping the
      // keys present means one request shape for every call site.
      expect(body.containsKey('p_context'), isTrue);
      expect(body['p_context'], isNull);
      expect(body['p_product_id'], isNull);
    });

    test('the same code in two contexts is two answers', () async {
      // The server decides, but the client must not collapse them: a cache
      // keyed on the code alone would serve the put-away answer to receiving.
      final adapter = FakeHttpClientAdapter((options) {
        final ctx = (options.data as Map)['p_context'];
        return jsonResponseBody(
          ctx == 'PUTAWAY'
              ? {
                  'kind': 'location',
                  'barcode': 'A-01',
                  'code': 'A-01',
                  'location_id': 5,
                  'context': 'PUTAWAY',
                  'expected': true,
                }
              : {
                  'kind': 'unknown',
                  'barcode': 'A-01',
                  'context': 'PACKING',
                  'expected': false,
                },
          200,
        );
      });
      final resolver = BarcodeResolverImpl(_dio(adapter));

      final asPutaway = await resolver.resolve('A-01', context: ScanContext.putaway);
      final asPacking = await resolver.resolve('A-01', context: ScanContext.packing);

      asPutaway.when(
        success: (r) => expect(r.kind, ScanKind.location),
        failure: (f) => fail('expected success, got $f'),
      );
      asPacking.when(
        success: (r) => expect(r.kind, ScanKind.unknown),
        failure: (f) => fail('expected success, got $f'),
      );
    });
  });
}
