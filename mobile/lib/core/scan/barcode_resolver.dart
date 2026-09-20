import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/delivery/application/delivery_providers.dart';
import '../api/api_error_mapper.dart';
import '../api/api_result.dart';
import 'scan_resolution.dart';

/// Turns a scanned code into what it actually is (§26, `resolve_barcode`).
///
/// One resolver for every kind of label in the building: a product barcode, a
/// case code, an internal SKU alias, a serial number, a shelf label. The gun is
/// the same gun, so the operator should not have to pick the right screen before
/// scanning — and a screen that only handles one kind can say so from the [kind]
/// rather than by failing to find anything.
abstract class BarcodeResolver {
  Future<ApiResult<ScanResolution>> resolve(String barcode);
}

class BarcodeResolverImpl implements BarcodeResolver {
  BarcodeResolverImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<ScanResolution>> resolve(String barcode) async {
    try {
      final response = await _dio.post('/rpc/resolve_barcode', data: {
        'p_barcode': barcode,
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

/// One scan, resolved. `autoDispose` with the code as the family key, so the
/// same code scanned twice on one screen does not hit the server twice while
/// the first answer is still on screen.
final scanResolutionProvider =
    FutureProvider.autoDispose.family<ScanResolution, String>((ref, code) async {
  final result = await ref.watch(barcodeResolverProvider).resolve(code);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});
