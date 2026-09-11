import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/app_user_summary.dart';

/// Managing who has which role (spec §21/§22) — the read/write pair that
/// completes 0024's auth bootstrap: `list_app_users`/`assign_user_role`/
/// `revoke_user_role` are all `user.manage`-gated SECURITY DEFINER RPCs, so
/// the server refuses a non-admin regardless of what this screen shows.
abstract class AdminRepository {
  /// Every user who has signed in at least once, with their current roles.
  Future<ApiResult<List<AppUserSummary>>> listUsers();

  /// The full role catalog, for the "add role" picker.
  Future<ApiResult<List<RoleOption>>> listRoles();

  Future<ApiResult<bool>> assignRole(String userId, String roleCode);

  Future<ApiResult<bool>> revokeRole(String userId, String roleCode);
}

class AdminRepositoryImpl implements AdminRepository {
  AdminRepositoryImpl(this._dio);

  /// PostgREST, same Dio the rest of the app's Supabase reads use — carries
  /// the signed-in user's real access token via `SupabaseAuthInterceptor`,
  /// which is what lets `auth.uid()` resolve inside these RPCs at all.
  final Dio _dio;

  @override
  Future<ApiResult<List<AppUserSummary>>> listUsers() async {
    try {
      final response = await _dio.post('/rpc/list_app_users');
      final data = response.data;
      // A jsonb-array-returning RPC comes back as the array itself; some
      // PostgREST setups wrap it in a single-element list — accept both,
      // same ambiguity `global_search` already handles.
      final rows = data is List
          ? (data.length == 1 && data.first is List ? data.first as List : data)
          : const [];
      return ApiSuccess(rows
          .whereType<Map>()
          .map((e) => AppUserSummary.fromJson(e.cast<String, dynamic>()))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<AppUserSummary>>(e);
    }
  }

  @override
  Future<ApiResult<List<RoleOption>>> listRoles() async {
    try {
      final response = await _dio.get('/roles', queryParameters: {
        'select': 'code,name',
        'order': 'id.asc',
      });
      final rows = (response.data as List);
      return ApiSuccess(rows
          .whereType<Map>()
          .map((e) => RoleOption.fromJson(e.cast<String, dynamic>()))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<RoleOption>>(e);
    }
  }

  @override
  Future<ApiResult<bool>> assignRole(String userId, String roleCode) async {
    try {
      final response = await _dio.post('/rpc/assign_user_role', data: {
        'p_user_id': userId,
        'p_role_code': roleCode,
      });
      return ApiSuccess(response.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<bool>> revokeRole(String userId, String roleCode) async {
    try {
      final response = await _dio.post('/rpc/revoke_user_role', data: {
        'p_user_id': userId,
        'p_role_code': roleCode,
      });
      return ApiSuccess(response.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }
}
