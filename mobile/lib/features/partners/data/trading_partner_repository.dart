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

  /// `set_trading_partner_country` (0102).
  Future<ApiResult<bool>> setCountry(int id, String countryCode);

  // Our codes for companies (0112).

  /// Our code for the company (empty keeps the one it has) and its code for us.
  Future<ApiResult<bool>> setCodes(int id, {String? code, String? theirCodeForUs});
  Future<ApiResult<List<PartnerCodeFormat>>> codeFormats();
  Future<ApiResult<List<PartnerCodeFormat>>> saveCodeFormat(PartnerKind kind, {required String prefix, required int digits, int? nextNumber});

  /// Gives every company without a code one; returns how many.
  Future<ApiResult<int>> issueMissingCodes();
  Future<ApiResult<List<PartnerVendorCode>>> vendorCodes(int partnerId);

  /// The company's 書式メモ (0114); empty clears it.
  Future<ApiResult<String?>> setReadingNotes(int id, String notes);
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

  @override
  Future<ApiResult<bool>> setCountry(int id, String countryCode) async {
    try {
      await _dio.post('/rpc/set_trading_partner_country', data: {
        'p_id': id,
        'p_country_code': countryCode,
      });
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  List<Map<String, dynamic>> _rows(dynamic d) {
    final raw = d is List && d.length == 1 && d.first is List ? d.first : d;
    return [for (final e in (raw as List? ?? const []).whereType<Map>()) e.cast<String, dynamic>()];
  }

  @override
  Future<ApiResult<bool>> setCodes(int id, {String? code, String? theirCodeForUs}) async {
    try {
      await _dio.post('/rpc/set_partner_codes', data: {
        'p_id': id,
        'p_code': code,
        'p_their_code_for_us': theirCodeForUs,
      });
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<List<PartnerCodeFormat>>> codeFormats() async {
    try {
      final r = await _dio.post('/rpc/list_partner_code_formats', data: {});
      return ApiSuccess([for (final m in _rows(r.data)) PartnerCodeFormat.fromJson(m)]);
    } on DioException catch (e) {
      return mapDioError<List<PartnerCodeFormat>>(e);
    }
  }

  @override
  Future<ApiResult<List<PartnerCodeFormat>>> saveCodeFormat(PartnerKind kind,
      {required String prefix, required int digits, int? nextNumber}) async {
    try {
      final r = await _dio.post('/rpc/save_partner_code_format', data: {
        'p_kind': kind.wire,
        'p_prefix': prefix,
        'p_digits': digits,
        'p_next_number': nextNumber,
      });
      return ApiSuccess([for (final m in _rows(r.data)) PartnerCodeFormat.fromJson(m)]);
    } on DioException catch (e) {
      return mapDioError<List<PartnerCodeFormat>>(e);
    }
  }

  @override
  Future<ApiResult<int>> issueMissingCodes() async {
    try {
      final r = await _dio.post('/rpc/issue_missing_partner_codes', data: {});
      final d = r.data;
      return ApiSuccess(d is num ? d.toInt() : int.tryParse('$d') ?? 0);
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
  }

  @override
  Future<ApiResult<List<PartnerVendorCode>>> vendorCodes(int partnerId) async {
    try {
      final r = await _dio.post('/rpc/list_partner_vendor_codes', data: {'p_partner_id': partnerId});
      return ApiSuccess([for (final m in _rows(r.data)) PartnerVendorCode.fromJson(m)]);
    } on DioException catch (e) {
      return mapDioError<List<PartnerVendorCode>>(e);
    }
  }

  @override
  Future<ApiResult<String?>> setReadingNotes(int id, String notes) async {
    try {
      final r = await _dio.post('/rpc/set_partner_reading_notes', data: {'p_id': id, 'p_notes': notes});
      final d = r.data;
      return ApiSuccess(d is String && d.isNotEmpty ? d : null);
    } on DioException catch (e) {
      return mapDioError<String?>(e);
    }
  }
}
