import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/report_result.dart';
import '../domain/saved_report.dart';

/// Data access for saved reports, backed by the read-only `/reports` API.
abstract class ReportRepository {
  Future<ApiResult<List<SavedReport>>> list();
  Future<ApiResult<ReportResult>> run(int id);
}

class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<List<SavedReport>>> list() async {
    try {
      final response = await _dio.get('/reports');
      final data = (response.data['data'] as List<dynamic>)
          .map((e) => SavedReport.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiSuccess(data);
    } on DioException catch (e) {
      return mapDioError<List<SavedReport>>(e);
    }
  }

  @override
  Future<ApiResult<ReportResult>> run(int id) async {
    try {
      final response = await _dio.get('/reports/$id');
      return ApiSuccess(
          ReportResult.fromJson(response.data['data'] as Map<String, dynamic>));
    } on DioException catch (e) {
      return mapDioError<ReportResult>(e);
    }
  }
}
