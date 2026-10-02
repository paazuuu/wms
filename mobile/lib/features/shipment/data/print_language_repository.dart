import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../product/domain/product.dart' show productNamesFromJson;
import '../domain/print_language.dart';

/// The print languages, the words labels use, and the product names a
/// document prints (0118).
abstract class PrintLanguageRepository {
  Future<ApiResult<PrintLanguage>> load();

  /// Which languages print, in order; the first is the main line.
  Future<ApiResult<PrintLanguage>> setLanguages(List<String> languages);

  /// One word in its three languages.
  Future<ApiResult<PrintLanguage>> setWord(String key, {required String ja, required String en, required String zh});

  /// JAN → {lang: name} for the products on a document.
  Future<ApiResult<Map<String, Map<String, String>>>> namesByJan(List<String> jans);
}

class PrintLanguageRepositoryImpl implements PrintLanguageRepository {
  PrintLanguageRepositoryImpl(this._dio);

  final Dio _dio;

  PrintLanguage _parse(dynamic data) {
    final json = data is List && data.isNotEmpty ? data.first : data;
    return json is Map ? PrintLanguage.fromJson(json.cast<String, dynamic>()) : const PrintLanguage();
  }

  @override
  Future<ApiResult<PrintLanguage>> load() async {
    try {
      final r = await _dio.post('/rpc/print_language', data: const {});
      return ApiSuccess(_parse(r.data));
    } on DioException catch (e) {
      return mapDioError<PrintLanguage>(e);
    }
  }

  @override
  Future<ApiResult<PrintLanguage>> setLanguages(List<String> languages) async {
    try {
      final r = await _dio.post('/rpc/set_print_languages', data: {'p_languages': languages});
      return ApiSuccess(_parse(r.data));
    } on DioException catch (e) {
      return mapDioError<PrintLanguage>(e);
    }
  }

  @override
  Future<ApiResult<PrintLanguage>> setWord(String key, {required String ja, required String en, required String zh}) async {
    try {
      final r = await _dio.post('/rpc/set_label_term', data: {'p_key': key, 'p_ja': ja, 'p_en': en, 'p_zh': zh});
      return ApiSuccess(_parse(r.data));
    } on DioException catch (e) {
      return mapDioError<PrintLanguage>(e);
    }
  }

  @override
  Future<ApiResult<Map<String, Map<String, String>>>> namesByJan(List<String> jans) async {
    if (jans.isEmpty) return const ApiSuccess({});
    try {
      final r = await _dio.post('/rpc/product_names_by_jan', data: {'p_jans': jans});
      final raw = r.data is List && (r.data as List).isNotEmpty ? (r.data as List).first : r.data;
      final out = <String, Map<String, String>>{};
      if (raw is Map) raw.forEach((k, v) => out['$k'] = productNamesFromJson(v));
      return ApiSuccess(out);
    } on DioException catch (e) {
      return mapDioError<Map<String, Map<String, String>>>(e);
    }
  }
}
