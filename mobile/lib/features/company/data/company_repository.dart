import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/company_profile.dart';

/// Our own company (0131) and the names our documents were addressed to
/// (0132). Reading is open to anyone signed in; `set_company_profile`
/// needs user.manage, checked by the server.
abstract class CompanyRepository {
  Future<ApiResult<CompanyProfile>> profile();
  Future<ApiResult<CompanyProfile>> save(CompanyProfile profile);
  Future<ApiResult<List<OwnNameSuggestion>>> suggestions();
}

class CompanyRepositoryImpl implements CompanyRepository {
  CompanyRepositoryImpl(this._dio);

  final Dio _dio;

  Map<String, dynamic> _one(dynamic data) {
    final v = data is List && data.isNotEmpty ? data.first : data;
    return v is Map ? v.cast<String, dynamic>() : const {};
  }

  @override
  Future<ApiResult<CompanyProfile>> profile() async {
    try {
      final r = await _dio.post('/rpc/company_profile');
      return ApiSuccess(CompanyProfile.fromJson(_one(r.data)));
    } on DioException catch (e) {
      return mapDioError<CompanyProfile>(e);
    }
  }

  @override
  Future<ApiResult<CompanyProfile>> save(CompanyProfile profile) async {
    try {
      final r = await _dio.post('/rpc/set_company_profile', data: {'p': profile.toJson()});
      return ApiSuccess(CompanyProfile.fromJson(_one(r.data)));
    } on DioException catch (e) {
      return mapDioError<CompanyProfile>(e);
    }
  }

  @override
  Future<ApiResult<List<OwnNameSuggestion>>> suggestions() async {
    try {
      final r = await _dio.post('/rpc/own_company_suggestions');
      final rows = r.data is List ? r.data as List : const [];
      return ApiSuccess([
        for (final e in rows.whereType<Map>()) OwnNameSuggestion.fromJson(e.cast<String, dynamic>()),
      ]);
    } on DioException catch (e) {
      return mapDioError<List<OwnNameSuggestion>>(e);
    }
  }
}
