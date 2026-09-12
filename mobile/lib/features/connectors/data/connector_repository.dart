import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/connector.dart';

/// The connector/adapter registry (spec §34, 0028) — external systems
/// (Shopify, carriers, freee, InventorOS…) live here as configuration, never
/// embedded directly in a feature screen. `connector.manage`-gated, same
/// pattern as the admin user-management RPCs.
abstract class ConnectorRepository {
  Future<ApiResult<List<Connector>>> list();

  Future<ApiResult<bool>> setEnabled(String code, bool enabled);
}

class ConnectorRepositoryImpl implements ConnectorRepository {
  ConnectorRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<List<Connector>>> list() async {
    try {
      final response = await _dio.post('/rpc/list_connectors');
      final data = response.data;
      // A jsonb-array-returning RPC comes back as the array itself; some
      // PostgREST setups wrap it in a single-element list — accept both,
      // same ambiguity `global_search`/`list_app_users` already handle.
      final rows = data is List
          ? (data.length == 1 && data.first is List ? data.first as List : data)
          : const [];
      return ApiSuccess(rows
          .whereType<Map>()
          .map((e) => Connector.fromJson(e.cast<String, dynamic>()))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<Connector>>(e);
    }
  }

  @override
  Future<ApiResult<bool>> setEnabled(String code, bool enabled) async {
    try {
      final response = await _dio.post('/rpc/set_connector_enabled', data: {
        'p_code': code,
        'p_enabled': enabled,
      });
      return ApiSuccess(response.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }
}
