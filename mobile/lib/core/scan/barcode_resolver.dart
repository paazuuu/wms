import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/delivery/application/delivery_providers.dart';
import '../api/api_error_mapper.dart';
import '../api/api_result.dart';
import 'scan_context.dart';
import 'scan_resolution.dart';

/// Turns a scanned code into what it actually is (§26, `resolve_barcode`).
///
/// One resolver for every kind of label in the building: a product barcode, a
/// case code, an internal SKU alias, a serial number, a lot, a shelf label, a
/// delivery note, a shipment, a printed task. The gun is the same gun, so the
/// operator should not have to pick the right screen before scanning.
///
/// The [context] is what makes one resolver enough. A screen says which step it
/// is (`ScanContext.putaway`), and the server tries the kinds that step expects
/// first — so the same string is a location during put-away and a product during
/// receiving. It also comes back saying whether what it found is something the
/// step wanted at all, which is the difference between a screen that can say
/// "that is a product, I am waiting for a shelf" and one that silently does the
/// wrong thing.
///
/// [productId] narrows a lot scan. A lot code identifies a lot only within its
/// product, so a QC screen that already knows which product it is inspecting
/// passes it and gets an exact answer instead of a list of candidates.
abstract class BarcodeResolver {
  Future<ApiResult<ScanResolution>> resolve(
    String barcode, {
    ScanContext? context,
    int? productId,
    int? warehouseId,
  });
}

class BarcodeResolverImpl implements BarcodeResolver {
  BarcodeResolverImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<ScanResolution>> resolve(
    String barcode, {
    ScanContext? context,
    int? productId,
    int? warehouseId,
  }) async {
    try {
      final response = await _dio.post('/rpc/resolve_barcode', data: {
        'p_barcode': barcode,
        'p_context': context?.code,
        'p_product_id': productId,
        'p_warehouse_id': warehouseId,
      });
      final data = response.data;
      // The RPC returns a single jsonb object; some PostgREST setups wrap it in
      // a one-element list, the same ambiguity the jsonb-array reads handle.
      final row = data is List
          ? (data.isEmpty ? null : data.first)
          : data;
      if (row is! Map) {
        // Not an error: an empty body means nothing was recognised, which is
        // exactly what an unknown code is.
        return ApiSuccess(ScanResolution(
          kind: ScanKind.unknown,
          barcode: barcode,
        ));
      }
      return ApiSuccess(
          ScanResolution.fromJson(row.cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<ScanResolution>(e);
    }
  }
}

final barcodeResolverProvider = Provider<BarcodeResolver>((ref) {
  return BarcodeResolverImpl(ref.watch(restDioProvider));
});

/// What to resolve, and in aid of what. A record rather than a bare string so
/// the same code scanned in two contexts is two different cache keys — which it
/// has to be, since it can resolve to two different things.
typedef ScanRequest = ({
  String code,
  ScanContext? context,
  int? productId,
  int? warehouseId,
});

/// One scan, resolved. `autoDispose` with the request as the family key, so the
/// same code scanned twice on one screen does not hit the server twice while the
/// first answer is still on screen.
final scanResolutionProvider = FutureProvider.autoDispose
    .family<ScanResolution, ScanRequest>((ref, request) async {
  final result = await ref.watch(barcodeResolverProvider).resolve(
        request.code,
        context: request.context,
        productId: request.productId,
        warehouseId: request.warehouseId,
      );
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});
