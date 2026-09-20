import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/product.dart';

/// The product master (spec §19, 0032) — read via `list_products`, written
/// only through `create_product`/`update_product`/`set_product_status`
/// (`product.manage`-gated), never a direct table write.
///
/// 0057 split identity from the core fields: `sku` and `tracking_mode` are set
/// by their own RPC rather than by `update_product`, because changing what must
/// be recorded about a product is a different decision from correcting its name
/// — and the server refuses a tracking mode that contradicts lots or serials
/// already on file (§37-15).
abstract class ProductRepository {
  Future<ApiResult<List<Product>>> list({String? search, String? status = 'active'});

  Future<ApiResult<int>> create({
    required String janCode,
    required String name,
    String? category,
    double? price,
  });

  Future<ApiResult<bool>> update({
    required int id,
    required String name,
    String? category,
    double? price,
  });

  Future<ApiResult<bool>> setStatus(int id, String status);

  /// `set_product_identity` (0057). Either field may be null, which leaves it
  /// as it was — so this can set a SKU without restating the tracking mode.
  Future<ApiResult<bool>> setIdentity({
    required int id,
    String? sku,
    TrackingMode? trackingMode,
  });

  /// `add_product_barcode` (0057, extended in 0059). Naming a unit makes the
  /// product's own conversion authoritative for how much one scan means, so
  /// `quantityPerScan` is only read when [uomCode] is null.
  Future<ApiResult<int>> addBarcode({
    required int productId,
    required String barcode,
    String barcodeType = 'JAN',
    int quantityPerScan = 1,
    bool isPrimary = false,
    String? uomCode,
    String? note,
  });

  /// `remove_product_barcode` (0057), by barcode id — `list_products` returns
  /// the id on each code for exactly this. The primary code cannot be removed;
  /// the server refuses rather than leave a product unreachable by scan.
  Future<ApiResult<bool>> removeBarcode(int barcodeId);

  /// `set_product_uom` (0059) — defines or corrects one pack size.
  Future<ApiResult<bool>> setUom({
    required int productId,
    required String uomCode,
    required double conversionFactor,
  });

  /// `list_uoms` (0059) — the vocabulary a pack size can be chosen from.
  Future<ApiResult<List<Uom>>> listUoms();
}

class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<List<Product>>> list(
      {String? search, String? status = 'active'}) async {
    try {
      final response = await _dio.post('/rpc/list_products', data: {
        'p_search': search,
        'p_status': status,
      });
      final data = response.data;
      // A jsonb-array-returning RPC comes back as the array itself; some
      // PostgREST setups wrap it in a single-element list — accept both,
      // same ambiguity `list_connectors`/`list_ai_analysis` already handle.
      final rows = data is List
          ? (data.length == 1 && data.first is List ? data.first as List : data)
          : const [];
      return ApiSuccess(rows
          .whereType<Map>()
          .map((e) => Product.fromJson(e.cast<String, dynamic>()))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<Product>>(e);
    }
  }

  @override
  Future<ApiResult<int>> create({
    required String janCode,
    required String name,
    String? category,
    double? price,
  }) async {
    try {
      final response = await _dio.post('/rpc/create_product', data: {
        'p_jan_code': janCode,
        'p_name': name,
        'p_category': category,
        'p_price': price,
      });
      final id = response.data is int
          ? response.data as int
          : int.tryParse('${response.data}') ?? 0;
      return ApiSuccess(id);
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
  }

  @override
  Future<ApiResult<bool>> update({
    required int id,
    required String name,
    String? category,
    double? price,
  }) async {
    try {
      final response = await _dio.post('/rpc/update_product', data: {
        'p_id': id,
        'p_name': name,
        'p_category': category,
        'p_price': price,
      });
      return ApiSuccess(response.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<bool>> setStatus(int id, String status) async {
    try {
      final response = await _dio.post('/rpc/set_product_status', data: {
        'p_id': id,
        'p_status': status,
      });
      return ApiSuccess(response.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<bool>> setIdentity({
    required int id,
    String? sku,
    TrackingMode? trackingMode,
  }) async {
    try {
      final response = await _dio.post('/rpc/set_product_identity', data: {
        'p_id': id,
        'p_sku': sku,
        'p_tracking_mode': trackingMode?.code,
      });
      return ApiSuccess(response.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<int>> addBarcode({
    required int productId,
    required String barcode,
    String barcodeType = 'JAN',
    int quantityPerScan = 1,
    bool isPrimary = false,
    String? uomCode,
    String? note,
  }) async {
    try {
      final response = await _dio.post('/rpc/add_product_barcode', data: {
        'p_product_id': productId,
        'p_barcode': barcode,
        'p_barcode_type': barcodeType,
        'p_quantity_per_scan': quantityPerScan,
        'p_is_primary': isPrimary,
        'p_note': note,
        'p_uom_code': uomCode,
      });
      final id = response.data is int
          ? response.data as int
          : int.tryParse('${response.data}') ?? 0;
      return ApiSuccess(id);
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
  }

  @override
  Future<ApiResult<bool>> removeBarcode(int barcodeId) async {
    try {
      final response = await _dio.post('/rpc/remove_product_barcode', data: {
        'p_barcode_id': barcodeId,
      });
      return ApiSuccess(response.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<bool>> setUom({
    required int productId,
    required String uomCode,
    required double conversionFactor,
  }) async {
    try {
      final response = await _dio.post('/rpc/set_product_uom', data: {
        'p_product_id': productId,
        'p_uom_code': uomCode,
        'p_conversion_factor': conversionFactor,
      });
      return ApiSuccess(response.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<List<Uom>>> listUoms() async {
    try {
      final response = await _dio.post('/rpc/list_uoms', data: const {});
      final data = response.data;
      final rows = data is List
          ? (data.length == 1 && data.first is List ? data.first as List : data)
          : const [];
      return ApiSuccess(rows
          .whereType<Map>()
          .map((e) => Uom.fromJson(e.cast<String, dynamic>()))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<Uom>>(e);
    }
  }
}
