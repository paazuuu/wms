import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/auth_user.dart';

/// Data access for authentication. Talks to `/login`, `/logout`, `/user` and
/// persists the returned Sanctum token via [TokenStorage].
abstract class AuthRepository {
  Future<ApiResult<AuthUser>> login(String email, String password);
  Future<ApiResult<AuthUser>> currentUser();
  Future<void> logout();
}

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._dio, this._tokenStorage);

  final Dio _dio;
  final TokenStorage _tokenStorage;

  @override
  Future<ApiResult<AuthUser>> login(String email, String password) async {
    try {
      final response = await _dio.post('/login', data: {
        'email': email,
        'password': password,
        'device_name': 'wms_mobile',
      });

      final body = response.data as Map<String, dynamic>;
      final token = body['token'] as String?;
      if (token != null) {
        await _tokenStorage.write(token);
      }

      final userJson = (body['user'] ?? body['data']) as Map<String, dynamic>;
      return ApiSuccess(AuthUser.fromJson(userJson));
    } on DioException catch (e) {
      return mapDioError<AuthUser>(e);
    }
  }

  @override
  Future<ApiResult<AuthUser>> currentUser() async {
    try {
      final response = await _dio.get('/user');
      final body = response.data as Map<String, dynamic>;
      final userJson = (body['data'] ?? body) as Map<String, dynamic>;
      return ApiSuccess(AuthUser.fromJson(userJson));
    } on DioException catch (e) {
      return mapDioError<AuthUser>(e);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _dio.post('/logout');
    } on DioException catch (_) {
      // Ignore network errors on logout; we clear the token regardless.
    } finally {
      await _tokenStorage.clear();
    }
  }
}
