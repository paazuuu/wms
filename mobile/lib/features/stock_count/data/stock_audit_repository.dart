import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/stock_audit.dart';

/// Data access for stock counts, backed by the read-only `/stock-audits` API.
abstract class StockAuditRepository {
  Future<ApiResult<List<StockAudit>>> list({String? status});
  Future<ApiResult<StockAudit>> show(int id);
}

class StockAuditRepositoryImpl implements StockAuditRepository {
  StockAuditRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<List<StockAudit>>> list({String? status}) async {
    try {
      final response = await _dio.get('/stock-audits', queryParameters: {
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
        'per_page': 50,
      });
      final data = (response.data['data'] as List<dynamic>)
          .map((e) => StockAudit.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiSuccess(data);
    } on DioException catch (e) {
      return mapDioError<List<StockAudit>>(e);
    }
  }

  @override
  Future<ApiResult<StockAudit>> show(int id) async {
    try {
      final response = await _dio.get('/stock-audits/$id');
      return ApiSuccess(
          StockAudit.fromJson(response.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return mapDioError<StockAudit>(e);
    }
  }
}
