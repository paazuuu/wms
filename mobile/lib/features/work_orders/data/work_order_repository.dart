import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/work_order.dart';

/// Data access for work orders, backed by the `/work-orders` API. Read-only on
/// mobile: the state transitions (start/complete/cancel) live on the back office.
abstract class WorkOrderRepository {
  Future<ApiResult<List<WorkOrder>>> list({String? search, String? status});
  Future<ApiResult<WorkOrder>> show(int id);
}

class WorkOrderRepositoryImpl implements WorkOrderRepository {
  WorkOrderRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<List<WorkOrder>>> list({
    String? search,
    String? status,
  }) async {
    try {
      final response = await _dio.get('/work-orders', queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
        'per_page': 50,
      });
      final data = (response.data['data'] as List<dynamic>)
          .map((e) => WorkOrder.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiSuccess(data);
    } on DioException catch (e) {
      return mapDioError<List<WorkOrder>>(e);
    }
  }

  @override
  Future<ApiResult<WorkOrder>> show(int id) async {
    try {
      final response = await _dio.get('/work-orders/$id');
      return ApiSuccess(
          WorkOrder.fromJson(response.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return mapDioError<WorkOrder>(e);
    }
  }
}
