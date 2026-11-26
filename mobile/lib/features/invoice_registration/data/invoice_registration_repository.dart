import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../delivery/application/delivery_providers.dart';
import '../domain/invoice_registration.dart';

/// Whether the Web-API's アプリケーションID is set, when and by whom.
typedef NtaKeyStatus = ({bool set, DateTime? updatedAt, String? updatedBy});

abstract class InvoiceRegistrationRepository {
  /// [numbers] checked with 国税庁 (an answer kept a week is given from
  /// there; [refresh] asks again).
  Future<ApiResult<InvoiceCheck>> check(List<String> numbers, {bool refresh = false});

  Future<ApiResult<NtaKeyStatus>> keyStatus();

  /// The アプリケーションID set (empty: cleared). The system administrator's.
  Future<ApiResult<bool>> setKey(String value);
}

class InvoiceRegistrationRepositoryImpl implements InvoiceRegistrationRepository {
  InvoiceRegistrationRepositoryImpl(this._rest, this._functions);

  final Dio _rest;
  final Dio _functions;

  @override
  Future<ApiResult<InvoiceCheck>> check(List<String> numbers, {bool refresh = false}) async {
    try {
      final r = await _functions.post('/invoice-check', data: {'numbers': numbers, 'refresh': refresh});
      return ApiSuccess(InvoiceCheck.fromJson((r.data is Map ? r.data as Map : const {}).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<NtaKeyStatus>> keyStatus() async {
    try {
      final r = await _rest.post('/rpc/integration_keys_status', data: const {});
      final row = (r.data is List ? r.data as List : const []).whereType<Map>().where((m) => m['service'] == 'nta_invoice').firstOrNull;
      return ApiSuccess((
        set: row?['set'] == true,
        updatedAt: DateTime.tryParse('${row?['updated_at'] ?? ''}')?.toLocal(),
        updatedBy: row?['updated_by_name']?.toString(),
      ));
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<bool>> setKey(String value) async {
    try {
      final r = await _rest.post('/rpc/integration_key_set', data: {'p_service': 'nta_invoice', 'p_secret': value});
      return ApiSuccess(r.data == true);
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }
}

final invoiceRegistrationRepositoryProvider = Provider<InvoiceRegistrationRepository>(
    (ref) => InvoiceRegistrationRepositoryImpl(ref.watch(restDioProvider), ref.watch(deliveryDioProvider)));

/// One number's check (normalized), kept while shown.
final invoiceRegistrationProvider = FutureProvider.autoDispose.family<InvoiceCheck, String>((ref, number) async =>
    (await ref.watch(invoiceRegistrationRepositoryProvider).check([number]))
        .when(success: (d) => d, failure: (f) => throw Exception(f.message)));

final ntaKeyStatusProvider = FutureProvider.autoDispose<NtaKeyStatus>((ref) async =>
    (await ref.watch(invoiceRegistrationRepositoryProvider).keyStatus())
        .when(success: (d) => d, failure: (f) => throw Exception(f.message)));
