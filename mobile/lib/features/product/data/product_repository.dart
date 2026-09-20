import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/product.dart';
import '../domain/product_lot.dart';
import '../domain/warehouse_product.dart';

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

  /// `product_lots` (0060), soonest expiry first.
  Future<ApiResult<List<ProductLot>>> lots(int productId);

  /// `product_serials` (0060), optionally one status only.
  Future<ApiResult<List<ProductSerial>>> serials(int productId, {String? status});

  /// `warehouse_product_settings` for one product (0063). Null when this
  /// warehouse has no special handling for it — which is the common case, and
  /// not an error.
  Future<ApiResult<WarehouseProduct?>> warehouseSettings({
    required int warehouseId,
    required int productId,
  });

  /// `set_warehouse_product` (0063). Every field is nullable and null means
  /// "leave it alone", so one setting can be changed without restating the rest.
  /// [defaultLocationCode] is a location *code* because that is what is printed
  /// on the rack, and an empty string clears it.
  Future<ApiResult<WarehouseProduct?>> setWarehouseProduct({
    required int warehouseId,
    required int productId,
    String? defaultLocationCode,
    int? minStock,
    int? maxStock,
    int? reorderPoint,
    int? pickPriority,
    String? putawayRule,
    int? preferredSupplierId,
    int? leadTimeDays,
    String? note,
  });

  /// `clear_warehouse_product` (0063) — back to no special handling. False when
  /// there was no row to remove.
  Future<ApiResult<bool>> clearWarehouseProduct({
    required int warehouseId,
    required int productId,
  });
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
      return ApiSuccess(_rows(response.data)
          .map((e) => Uom.fromJson(e))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<Uom>>(e);
    }
  }

  /// A jsonb-array-returning RPC comes back as the array itself; some PostgREST
  /// setups wrap it in a single-element list. Accepting both in one place keeps
  /// that ambiguity out of every call site.
  static List<Map<String, dynamic>> _rows(dynamic data) {
    final list = data is List
        ? (data.length == 1 && data.first is List ? data.first as List : data)
        : const [];
    return list
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList(growable: false);
  }

  static Map<String, dynamic>? _object(dynamic data) {
    final row = data is List ? (data.isEmpty ? null : data.first) : data;
    return row is Map ? row.cast<String, dynamic>() : null;
  }

  @override
  Future<ApiResult<List<ProductLot>>> lots(int productId) async {
    try {
      final response = await _dio.post('/rpc/product_lots', data: {
        'p_product_id': productId,
      });
      return ApiSuccess(
          _rows(response.data).map((e) => ProductLot.fromJson(e)).toList());
    } on DioException catch (e) {
      return mapDioError<List<ProductLot>>(e);
    }
  }

  @override
  Future<ApiResult<List<ProductSerial>>> serials(int productId,
      {String? status}) async {
    try {
      final response = await _dio.post('/rpc/product_serials', data: {
        'p_product_id': productId,
        'p_status': status,
      });
      return ApiSuccess(
          _rows(response.data).map((e) => ProductSerial.fromJson(e)).toList());
    } on DioException catch (e) {
      return mapDioError<List<ProductSerial>>(e);
    }
  }

  @override
  Future<ApiResult<WarehouseProduct?>> warehouseSettings({
    required int warehouseId,
    required int productId,
  }) async {
    try {
      final response = await _dio.post('/rpc/warehouse_product_settings', data: {
        'p_warehouse_id': warehouseId,
        'p_product_id': productId,
      });
      final row = _object(response.data);
      return ApiSuccess(row == null ? null : WarehouseProduct.fromJson(row));
    } on DioException catch (e) {
      return mapDioError<WarehouseProduct?>(e);
    }
  }

  @override
  Future<ApiResult<WarehouseProduct?>> setWarehouseProduct({
    required int warehouseId,
    required int productId,
    String? defaultLocationCode,
    int? minStock,
    int? maxStock,
    int? reorderPoint,
    int? pickPriority,
    String? putawayRule,
    int? preferredSupplierId,
    int? leadTimeDays,
    String? note,
  }) async {
    try {
      final response = await _dio.post('/rpc/set_warehouse_product', data: {
        'p_warehouse_id': warehouseId,
        'p_product_id': productId,
        'p_default_location_code': defaultLocationCode,
        'p_min_stock': minStock,
        'p_max_stock': maxStock,
        'p_reorder_point': reorderPoint,
        'p_pick_priority': pickPriority,
        'p_putaway_rule': putawayRule,
        'p_preferred_supplier_id': preferredSupplierId,
        'p_lead_time_days': leadTimeDays,
        'p_note': note,
      });
      final row = _object(response.data);
      return ApiSuccess(row == null ? null : WarehouseProduct.fromJson(row));
    } on DioException catch (e) {
      return mapDioError<WarehouseProduct?>(e);
    }
  }

  @override
  Future<ApiResult<bool>> clearWarehouseProduct({
    required int warehouseId,
    required int productId,
  }) async {
    try {
      final response = await _dio.post('/rpc/clear_warehouse_product', data: {
        'p_warehouse_id': warehouseId,
        'p_product_id': productId,
      });
      return ApiSuccess(response.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }
}
