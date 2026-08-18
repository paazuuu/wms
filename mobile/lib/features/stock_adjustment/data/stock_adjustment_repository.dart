import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/stock_adjustment.dart';

/// Data access for booking stock adjustments against a product, backed by the
/// `/stock-adjustments` API. `quantity` is a signed delta: positive adds stock,
/// negative removes it (the backend rejects removals that would go negative).
abstract class StockAdjustmentRepository {
  Future<ApiResult<StockAdjustment>> create({
    required int productId,
    required int quantity,
    required String type,
    String? reason,
    String? notes,
  });
}

class StockAdjustmentRepositoryImpl implements StockAdjustmentRepository {
  StockAdjustmentRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<StockAdjustment>> create({
    required int productId,
    required int quantity,
    required String type,
    String? reason,
    String? notes,
  }) async {
    try {
      final response = await _dio.post('/stock-adjustments', data: {
        'product_id': productId,
        'quantity': quantity,
        'type': type,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      });
      return ApiSuccess(
          StockAdjustment.fromJson(response.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return mapDioError<StockAdjustment>(e);
    }
  }
}
