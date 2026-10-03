import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/supplier_quote.dart';

/// Any document listing products — a quotation (見積書), an invoice, a
/// delivery note, our own catalogue — read by the same reader as a delivery
/// note (import-plan, dry run: Excel by its columns, a PDF or photo by the
/// AI, checked twice), and its prices kept (0119).
abstract class QuoteRepository {
  /// Reads [file]. [partnerId] is optional: when given, that company's way of
  /// writing is used to read it; when not, the reader looks for the company
  /// on the document itself (its name or 登録番号).
  Future<ApiResult<QuoteRead>> read({int? partnerId, required MultipartFile file});

  Future<ApiResult<QuoteSaved>> save({
    required int partnerId,
    required List<Map<String, dynamic>> lines,
    String? note,
  });
}

class QuoteRepositoryImpl implements QuoteRepository {
  QuoteRepositoryImpl({required Dio functions, required Dio rest})
      : _functions = functions,
        _rest = rest;

  final Dio _functions;
  final Dio _rest;

  @override
  Future<ApiResult<QuoteRead>> read({int? partnerId, required MultipartFile file}) async {
    try {
      final form = FormData();
      form.files.add(MapEntry('file', file));
      form.fields
        ..add(const MapEntry('dry_run', '1'))
        ..addAll([if (partnerId != null) MapEntry('partner_id', '$partnerId')]);
      final r = await _functions.post(
        '/import-plan',
        data: form,
        options: Options(receiveTimeout: const Duration(seconds: 180)),
      );
      return ApiSuccess(QuoteRead.fromJson(((r.data as Map)['data'] as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<QuoteRead>(e);
    }
  }

  @override
  Future<ApiResult<QuoteSaved>> save({
    required int partnerId,
    required List<Map<String, dynamic>> lines,
    String? note,
  }) async {
    try {
      final r = await _rest.post('/rpc/save_supplier_quote', data: {
        'p_partner_id': partnerId,
        'p_lines': [for (final l in lines) QuoteLine.toSaveJson(l)],
        'p_note': note,
      });
      final json = r.data is List && (r.data as List).isNotEmpty ? (r.data as List).first : r.data;
      return ApiSuccess(QuoteSaved.fromJson((json as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<QuoteSaved>(e);
    }
  }
}
