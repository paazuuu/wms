import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/trading_partner.dart';

/// The supplier/customer directory (spec §46 checklist item 8, 0035) — read
/// via `list_trading_partners`, written only through `create_trading_partner`/
/// `update_trading_partner`/`set_trading_partner_status` (`partner.manage`-
/// gated), never a direct table write.
abstract class TradingPartnerRepository {
  Future<ApiResult<List<TradingPartner>>> list({
    PartnerKind? kind,
    String? search,
    String? status = 'active',
  });

  Future<ApiResult<int>> create({
    required String name,
    PartnerKind kind = PartnerKind.supplier,
    String? code,
    String? contactName,
    String? phone,
    String? email,
    String? address,
    String? paymentTerms,
    String? notes,
  });

  Future<ApiResult<bool>> update({
    required int id,
    required String name,
    PartnerKind kind = PartnerKind.supplier,
    String? contactName,
    String? phone,
    String? email,
    String? address,
    String? paymentTerms,
    String? notes,
  });

  Future<ApiResult<bool>> setStatus(int id, String status);
}

class TradingPartnerRepositoryImpl implements TradingPartnerRepository {
  TradingPartnerRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<List<TradingPartner>>> list({
    PartnerKind? kind,
    String? search,
    String? status = 'active',
  }) async {
    try {
      final response = await _dio.post('/rpc/list_trading_partners', data: {
        'p_kind': kind?.wire,
        'p_search': search,
        'p_status': status,
      });
      final data = response.data;
      // A jsonb-array-returning RPC comes back as the array itself; some
      // PostgREST setups wrap it in a single-element list — accept both,
      // same ambiguity every other jsonb-returning RPC here already handles.
      final rows = data is List
          ? (data.length == 1 && data.first is List ? data.first as List : data)
          : const [];
      return ApiSuccess(rows
          .whereType<Map>()
          .map((e) => TradingPartner.fromJson(e.cast<String, dynamic>()))
          .toList());
    } on DioException catch (e) {
      return mapDioError<List<TradingPartner>>(e);
    }
  }

  @override
  Future<ApiResult<int>> create({
    required String name,
    PartnerKind kind = PartnerKind.supplier,
    String? code,
    String? contactName,
    String? phone,
    String? email,
    String? address,
    String? paymentTerms,
    String? notes,
  }) async {
    try {
      final response = await _dio.post('/rpc/create_trading_partner', data: {
        'p_name': name,
        'p_kind': kind.wire,
        'p_code': code,
        'p_contact_name': contactName,
        'p_phone': phone,
        'p_email': email,
        'p_address': address,
        'p_payment_terms': paymentTerms,
        'p_notes': notes,
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
    PartnerKind kind = PartnerKind.supplier,
    String? contactName,
    String? phone,
    String? email,
    String? address,
    String? paymentTerms,
    String? notes,
  }) async {
    try {
      final response = await _dio.post('/rpc/update_trading_partner', data: {
        'p_id': id,
        'p_name': name,
        'p_kind': kind.wire,
        'p_contact_name': contactName,
        'p_phone': phone,
        'p_email': email,
        'p_address': address,
        'p_payment_terms': paymentTerms,
        'p_notes': notes,
      });
      return ApiSuccess(response.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<bool>> setStatus(int id, String status) async {
    try {
      final response = await _dio.post('/rpc/set_trading_partner_status', data: {
        'p_id': id,
        'p_status': status,
      });
      return ApiSuccess(response.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }
}
