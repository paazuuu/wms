import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/data_quality.dart';
import '../domain/product.dart';
import '../domain/supplier_product_name.dart';
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

  /// What suppliers call products (0087), for one product or one supplier.
  Future<ApiResult<List<SupplierProductName>>> supplierNames(
      {int? productId, int? supplierId});

  /// Sets (or replaces) one supplier's name and code for one product.
  Future<ApiResult<int>> setSupplierName({
    required int supplierId,
    required int productId,
    required String supplierName,
    String? supplierCode,
    String? note,
    String? supplierJanCode,
    String? supplierMaker,
  });

  Future<ApiResult<bool>> removeSupplierName(int id);

  /// A product must name its maker (0105).
  Future<ApiResult<int>> create({
    required String janCode,
    required String name,
    required String maker,
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

  /// Removes one product for good (0126). One that stock, an order or a
  /// document names is refused ("product is in use"); it is archived or
  /// deactivated instead.
  Future<ApiResult<bool>> delete(int id);

  /// `products_import` (0130): lines read from a file of our own straight
  /// into the library. A line whose JAN or 品番 is already there (or whose
  /// JAN came earlier in the file) becomes an alert instead.
  Future<ApiResult<LibraryImported>> importLines(List<Map<String, dynamic>> lines, {String? sourceFile});

  /// `products_add_one` (0130): one product by hand, every field optional.
  /// A JAN or 品番 already in the library is refused as
  /// `jan_exists:<id>:<name>` / `sku_exists:<id>:<name>`.
  Future<ApiResult<int>> addOne(Map<String, dynamic> fields);

  /// The alerts kept back from imports, newest first (0130).
  Future<ApiResult<List<ProductAlert>>> alerts();

  /// Removes alerts for good: the ones given, or every one when [ids] is null.
  Future<ApiResult<int>> deleteAlerts(List<int>? ids);

  /// Removes products for good (0126): those nothing booked points at go,
  /// with their names, codes and picture rows; the rest are left and
  /// returned in `inUse`. 価格台帳 keeps its items.
  Future<ApiResult<({List<int> removed, List<int> inUse})>> deleteMany(List<int> ids);

  /// `reactivate_products` (0123) — the products a file lists, made active
  /// again. Dormant ones need product.manage; archived or discontinued ones
  /// need product.lifecycle and are otherwise left as they are, returned in
  /// `skipped`.
  Future<ApiResult<({int changed, List<int> skipped})>> reactivate(List<int> ids);

  /// `set_products_lifecycle` (0120) — many products at once into one
  /// lifecycle, with why; resolves to how many changed.
  Future<ApiResult<int>> setLifecycle(List<int> ids, ProductLifecycle lifecycle, {String? reason});

  /// `set_product_identity` (0057). Either field may be null, which leaves it
  /// as it was — so this can set a SKU without restating the tracking mode.
  Future<ApiResult<bool>> setIdentity({
    required int id,
    String? sku,
    TrackingMode? trackingMode,
    String? maker,
  });

  /// `set_picking_rule` (0074, §16). Sets the product's own default —
  /// [warehouseId] is left for a later per-warehouse override, the same shape
  /// [setWarehouseProduct]'s `putawayRule` already has for put-away.
  Future<ApiResult<bool>> setPickingRule({
    required int productId,
    required String rule,
  });

  /// `set_inspection_requirement` (0068, §13). Sets the product's own
  /// default, same shape as [setPickingRule] — a warehouse override is a
  /// later addition, not a gap this call needs to close today.
  Future<ApiResult<bool>> setInspectionRequirement({
    required int productId,
    required bool requiresInspection,
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

  /// `set_product_pack` (0115) — a pack size with its weights: the empty
  /// packaging and, when someone weighed a whole one, the gross weight.
  Future<ApiResult<bool>> setPack({
    required int productId,
    required String uomCode,
    required double conversionFactor,
    double? packageWeightG,
    double? grossWeightG,
  });

  /// `set_product_weight` (0115) — one base unit's weight in grams, or null
  /// to clear it. [source] is `manual`, `web` or `measured`.
  Future<ApiResult<bool>> setWeight({
    required int productId,
    double? unitWeightG,
    String source = 'manual',
    String? url,
    String? note,
  });

  /// `set_product_size` (0125) — 幅・奥行・高さ in mm and any other
  /// notation; all null clears it.
  Future<ApiResult<bool>> setSize({
    required int productId,
    double? widthMm,
    double? depthMm,
    double? heightMm,
    String? note,
    String source = 'manual',
  });

  /// `set_product_name_en` (0117) — the English name, or null to clear it.
  Future<ApiResult<bool>> setNameEn(int productId, String? nameEn);

  /// `set_product_name` (0118) — the name in [lang] (`en`, `zh`, …), or null
  /// to clear it. Japanese is the product name itself and is not set here.
  Future<ApiResult<Map<String, String>>> setName(int productId, String lang, String? name);

  /// `list_uoms` (0059) — the vocabulary a pack size can be chosen from.
  Future<ApiResult<List<Uom>>> listUoms();

  /// `remove_product_uom` (0059) — takes a pack size back off, refused while
  /// the base unit or a barcode still names it.
  Future<ApiResult<bool>> removeUom({
    required int productId,
    required String uomCode,
  });

  /// `product_lots` (0060), soonest expiry first.
  Future<ApiResult<List<ProductLot>>> lots(int productId);

  /// `product_serials` (0060), optionally one status only.
  Future<ApiResult<List<ProductSerial>>> serials(int productId, {String? status});

  /// `set_serial_status` (0060) — the exception path a serial's normal
  /// IN_STOCK/SHIPPED lifecycle does not cover on its own: recording a
  /// return, a scrap, or a hold.
  Future<ApiResult<bool>> setSerialStatus({
    required int serialId,
    required String status,
    String? note,
  });

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

  /// `unlinked_jan_codes` (0058) — codes in use across the system that no
  /// product accounts for, worst (most rows) first. The worklist for
  /// registering master data: once a product exists for a code, the history
  /// already using it links itself.
  Future<ApiResult<List<UnlinkedJan>>> unlinkedJanCodes({int limit = 200});

  /// `product_id_coverage` (0058) — how complete `product_id` is next to
  /// `jan_code`, system-wide. [UnlinkedJan]'s own summary line.
  Future<ApiResult<ProductIdCoverage>> productIdCoverage();
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
    required String maker,
    String? category,
    double? price,
  }) async {
    try {
      final response = await _dio.post('/rpc/create_product', data: {
        'p_jan_code': janCode,
        'p_name': name,
        'p_maker': maker,
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
  Future<ApiResult<({int changed, List<int> skipped})>> reactivate(List<int> ids) async {
    try {
      final r = await _dio.post('/rpc/reactivate_products', data: {'p_ids': ids});
      final json = r.data is List && (r.data as List).isNotEmpty ? (r.data as List).first : r.data;
      final m = json is Map ? json : const {};
      return ApiSuccess((
        changed: (m['changed'] as num?)?.toInt() ?? 0,
        skipped: [for (final v in (m['skipped'] as List? ?? const [])) (v as num).toInt()],
      ));
    } on DioException catch (e) {
      return mapDioError<({int changed, List<int> skipped})>(e);
    }
  }

  @override
  Future<ApiResult<int>> setLifecycle(List<int> ids, ProductLifecycle lifecycle, {String? reason}) async {
    try {
      final r = await _dio.post('/rpc/set_products_lifecycle',
          data: {'p_ids': ids, 'p_lifecycle': lifecycle.wire, 'p_reason': reason});
      final json = r.data is List && (r.data as List).isNotEmpty ? (r.data as List).first : r.data;
      return ApiSuccess(json is Map ? (json['changed'] as num?)?.toInt() ?? 0 : 0);
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
  }

  @override
  Future<ApiResult<bool>> delete(int id) async {
    final r = await deleteMany([id]);
    return switch (r) {
      ApiSuccess(:final data) when data.removed.contains(id) => const ApiSuccess(true),
      ApiSuccess(:final data) when data.inUse.contains(id) =>
        const ApiFailure(message: 'product is in use; deactivate it instead'),
      ApiSuccess() => const ApiFailure(message: 'not permitted: product.delete required'),
      ApiFailure(:final message, :final statusCode) => ApiFailure(message: message, statusCode: statusCode),
    };
  }

  @override
  Future<ApiResult<LibraryImported>> importLines(List<Map<String, dynamic>> lines, {String? sourceFile}) async {
    try {
      final r = await _dio.post('/rpc/products_import', data: {'p_lines': lines, 'p_source_file': sourceFile});
      final j = r.data is List && (r.data as List).isNotEmpty ? (r.data as List).first : r.data;
      return ApiSuccess(LibraryImported.fromJson((j as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<LibraryImported>(e);
    }
  }

  @override
  Future<ApiResult<int>> addOne(Map<String, dynamic> fields) async {
    try {
      final r = await _dio.post('/rpc/products_add_one', data: {'p': fields});
      final id = r.data is int ? r.data as int : int.tryParse('${r.data}') ?? 0;
      return ApiSuccess(id);
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
  }

  @override
  Future<ApiResult<List<ProductAlert>>> alerts() async {
    try {
      final r = await _dio.get('/product_import_alerts', queryParameters: {'select': '*', 'order': 'created_at.desc,id.desc'});
      return ApiSuccess([
        for (final e in (r.data is List ? r.data as List : const []).whereType<Map>())
          ProductAlert.fromJson(e.cast<String, dynamic>()),
      ]);
    } on DioException catch (e) {
      return mapDioError<List<ProductAlert>>(e);
    }
  }

  @override
  Future<ApiResult<int>> deleteAlerts(List<int>? ids) async {
    if (ids != null && ids.isEmpty) return const ApiSuccess(0);
    try {
      // Row removals under the alerts' policy (product.manage).
      final r = await _dio.delete(
        '/product_import_alerts',
        queryParameters: {'id': ids == null ? 'gt.0' : 'in.(${ids.join(',')})', 'select': 'id'},
        options: Options(headers: {'Prefer': 'return=representation'}),
      );
      return ApiSuccess(r.data is List ? (r.data as List).length : 0);
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
  }

  static bool _refusedAsInUse(DioException e) {
    final d = e.response?.data;
    return e.response?.statusCode == 409 || (d is Map && d['code'] == '23503');
  }

  /// Row removals under 0126's policies: the picture rows first (their key
  /// would refuse), then the products; the ids actually removed come back.
  Future<List<int>> _remove(List<int> ids) async {
    final inList = 'in.(${ids.join(',')})';
    await _dio.delete('/product_images', queryParameters: {'product_id': inList});
    final r = await _dio.delete(
      '/products',
      queryParameters: {'id': inList, 'select': 'id'},
      options: Options(headers: {'Prefer': 'return=representation'}),
    );
    return [
      for (final e in (r.data is List ? r.data as List : const []).whereType<Map>())
        if (e['id'] case final num id) id.toInt(),
    ];
  }

  @override
  Future<ApiResult<({List<int> removed, List<int> inUse})>> deleteMany(List<int> ids) async {
    if (ids.isEmpty) return const ApiSuccess((removed: <int>[], inUse: <int>[]));
    try {
      // What anything booked still names stays — pictures included.
      final u = await _dio.post('/rpc/products_in_use', data: {'p_ids': ids});
      final raw = u.data is List && u.data.length == 1 && u.data.first is List ? u.data.first : u.data;
      final inUse = {for (final x in (raw as List? ?? const [])) (x as num).toInt()};
      final free = [for (final id in ids) if (!inUse.contains(id)) id];
      final removed = <int>[];
      if (free.isNotEmpty) {
        try {
          removed.addAll(await _remove(free));
        } on DioException catch (e) {
          // Booked against in the meantime: one at a time, keeping the rest.
          if (!_refusedAsInUse(e)) rethrow;
          for (final id in free) {
            try {
              removed.addAll(await _remove([id]));
            } on DioException catch (e2) {
              if (!_refusedAsInUse(e2)) rethrow;
              inUse.add(id);
            }
          }
        }
      }
      return ApiSuccess((removed: removed, inUse: [for (final id in ids) if (inUse.contains(id)) id]));
    } on DioException catch (e) {
      return mapDioError<({List<int> removed, List<int> inUse})>(e);
    }
  }

  @override
  Future<ApiResult<bool>> setIdentity({
    required int id,
    String? sku,
    TrackingMode? trackingMode,
    String? maker,
  }) async {
    try {
      final response = await _dio.post('/rpc/set_product_identity', data: {
        'p_id': id,
        'p_sku': sku,
        'p_tracking_mode': trackingMode?.code,
        // '' clears it, null leaves it (0103).
        'p_maker': maker,
      });
      return ApiSuccess(response.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<bool>> setPickingRule({
    required int productId,
    required String rule,
  }) async {
    try {
      await _dio.post('/rpc/set_picking_rule', data: {
        'p_product_id': productId,
        'p_warehouse_id': null,
        'p_rule': rule,
      });
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<bool>> setInspectionRequirement({
    required int productId,
    required bool requiresInspection,
  }) async {
    try {
      await _dio.post('/rpc/set_inspection_requirement', data: {
        'p_product_id': productId,
        'p_requires_inspection': requiresInspection,
        'p_warehouse_id': null,
      });
      return const ApiSuccess(true);
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
  Future<ApiResult<bool>> setPack({
    required int productId,
    required String uomCode,
    required double conversionFactor,
    double? packageWeightG,
    double? grossWeightG,
  }) async {
    try {
      await _dio.post('/rpc/set_product_pack', data: {
        'p_product_id': productId,
        'p_uom_code': uomCode,
        'p_conversion_factor': conversionFactor,
        'p_package_weight_g': packageWeightG,
        'p_gross_weight_g': grossWeightG,
      });
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<bool>> setWeight({
    required int productId,
    double? unitWeightG,
    String source = 'manual',
    String? url,
    String? note,
  }) async {
    try {
      await _dio.post('/rpc/set_product_weight', data: {
        'p_product_id': productId,
        'p_unit_weight_g': unitWeightG,
        'p_source': source,
        'p_url': url,
        'p_note': note,
      });
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<bool>> setSize({
    required int productId,
    double? widthMm,
    double? depthMm,
    double? heightMm,
    String? note,
    String source = 'manual',
  }) async {
    try {
      await _dio.post('/rpc/set_product_size', data: {
        'p_product_id': productId,
        'p_width_mm': widthMm,
        'p_depth_mm': depthMm,
        'p_height_mm': heightMm,
        'p_note': note,
        'p_source': source,
      });
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<bool>> setNameEn(int productId, String? nameEn) async {
    try {
      await _dio.post('/rpc/set_product_name_en', data: {'p_product_id': productId, 'p_name_en': nameEn});
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<Map<String, String>>> setName(int productId, String lang, String? name) async {
    try {
      final r = await _dio.post('/rpc/set_product_name',
          data: {'p_product_id': productId, 'p_lang': lang, 'p_name': name, 'p_source': 'manual'});
      return ApiSuccess(productNamesFromJson(r.data));
    } on DioException catch (e) {
      return mapDioError<Map<String, String>>(e);
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

  @override
  Future<ApiResult<bool>> removeUom({
    required int productId,
    required String uomCode,
  }) async {
    try {
      final response = await _dio.post('/rpc/remove_product_uom', data: {
        'p_product_id': productId,
        'p_uom_code': uomCode,
      });
      return ApiSuccess(response.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
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
  Future<ApiResult<bool>> setSerialStatus({
    required int serialId,
    required String status,
    String? note,
  }) async {
    try {
      final response = await _dio.post('/rpc/set_serial_status', data: {
        'p_serial_id': serialId,
        'p_status': status,
        'p_note': note,
      });
      return ApiSuccess(response.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
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

  @override
  Future<ApiResult<List<UnlinkedJan>>> unlinkedJanCodes({
    int limit = 200,
  }) async {
    try {
      final response = await _dio.post('/rpc/unlinked_jan_codes', data: {
        'p_limit': limit,
      });
      return ApiSuccess(
          _rows(response.data).map((e) => UnlinkedJan.fromJson(e)).toList());
    } on DioException catch (e) {
      return mapDioError<List<UnlinkedJan>>(e);
    }
  }

  @override
  Future<ApiResult<ProductIdCoverage>> productIdCoverage() async {
    try {
      final response = await _dio.post('/rpc/product_id_coverage');
      final row = _object(response.data);
      return ApiSuccess(
          row == null ? const ProductIdCoverage() : ProductIdCoverage.fromJson(row));
    } on DioException catch (e) {
      return mapDioError<ProductIdCoverage>(e);
    }
  }

  @override
  Future<ApiResult<List<SupplierProductName>>> supplierNames(
      {int? productId, int? supplierId}) async {
    try {
      final response = await _dio.post('/rpc/list_supplier_product_names', data: {
        'p_product_id': productId,
        'p_supplier_id': supplierId,
      });
      return ApiSuccess(
          _rows(response.data).map((e) => SupplierProductName.fromJson(e)).toList());
    } on DioException catch (e) {
      return mapDioError<List<SupplierProductName>>(e);
    }
  }

  @override
  Future<ApiResult<int>> setSupplierName({
    required int supplierId,
    required int productId,
    required String supplierName,
    String? supplierCode,
    String? note,
    String? supplierJanCode,
    String? supplierMaker,
  }) async {
    try {
      final response = await _dio.post('/rpc/set_supplier_product_name', data: {
        'p_supplier_id': supplierId,
        'p_product_id': productId,
        'p_supplier_name': supplierName,
        'p_supplier_code': supplierCode,
        'p_note': note,
        'p_supplier_jan_code': supplierJanCode,
        'p_supplier_maker': supplierMaker,
      });
      final id = response.data;
      return ApiSuccess(id is int ? id : int.tryParse('$id') ?? 0);
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
  }

  @override
  Future<ApiResult<bool>> removeSupplierName(int id) async {
    try {
      final response =
          await _dio.post('/rpc/remove_supplier_product_name', data: {'p_id': id});
      return ApiSuccess(response.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }
}
