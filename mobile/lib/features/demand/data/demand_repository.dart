import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/open_demand.dart';

/// The order-first loop (0084): what approved sales orders are still waiting
/// for, filling them from stock, and buying the rest — one purchase order may
/// cover many sales orders, and need not cover all of them.
abstract class DemandRepository {
  Future<ApiResult<List<OpenDemandItem>>> openDemand({int? warehouseId});

  /// Promises free stock to waiting order lines, oldest approval first. Narrow
  /// it to one product, or to one line (optionally only [quantity] of it) to
  /// serve a particular customer first.
  Future<ApiResult<BackorderFillResult>> fillBackorders({
    required int warehouseId,
    int? productId,
    int? salesOrderLineId,
    int? quantity,
  });

  Future<ApiResult<PurchaseFromDemandResult>> createPurchaseOrder({
    required String supplierName,
    required int warehouseId,
    required List<DemandPurchaseLine> lines,
    int? supplierId,
    DateTime? expectedDate,
    String? note,
  });
}

class DemandRepositoryImpl implements DemandRepository {
  DemandRepositoryImpl(this._dio);

  final Dio _dio;

  static Map<String, dynamic> _object(dynamic data) {
    final json = data is List && data.isNotEmpty ? data.first : data;
    return (json as Map).cast<String, dynamic>();
  }

  @override
  Future<ApiResult<List<OpenDemandItem>>> openDemand({int? warehouseId}) async {
    try {
      final response = await _dio
          .post('/rpc/open_demand', data: {'p_warehouse_id': warehouseId});
      final data = response.data;
      final rows = data is List
          ? (data.length == 1 && data.first is List ? data.first as List : data)
          : const [];
      return ApiSuccess(rows
          .whereType<Map>()
          .map((e) => OpenDemandItem.fromJson(e.cast<String, dynamic>()))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<OpenDemandItem>>(e);
    }
  }

  @override
  Future<ApiResult<BackorderFillResult>> fillBackorders({
    required int warehouseId,
    int? productId,
    int? salesOrderLineId,
    int? quantity,
  }) async {
    try {
      final response = await _dio.post('/rpc/fill_backorders', data: {
        'p_warehouse_id': warehouseId,
        'p_product_id': productId,
        'p_sales_order_line_id': salesOrderLineId,
        'p_quantity': quantity,
      });
      return ApiSuccess(BackorderFillResult.fromJson(_object(response.data)));
    } on DioException catch (e) {
      return mapDioError<BackorderFillResult>(e);
    }
  }

  @override
  Future<ApiResult<PurchaseFromDemandResult>> createPurchaseOrder({
    required String supplierName,
    required int warehouseId,
    required List<DemandPurchaseLine> lines,
    int? supplierId,
    DateTime? expectedDate,
    String? note,
  }) async {
    try {
      final response =
          await _dio.post('/rpc/create_purchase_order_from_demand', data: {
        'p_supplier_name': supplierName,
        'p_warehouse_id': warehouseId,
        'p_lines': lines.map((l) => l.toJson()).toList(),
        'p_supplier_id': supplierId,
        'p_expected_date': expectedDate?.toIso8601String().substring(0, 10),
        'p_note': note,
      });
      return ApiSuccess(PurchaseFromDemandResult.fromJson(_object(response.data)));
    } on DioException catch (e) {
      return mapDioError<PurchaseFromDemandResult>(e);
    }
  }
}
