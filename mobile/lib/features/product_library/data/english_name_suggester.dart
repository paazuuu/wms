import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../delivery/application/delivery_providers.dart';

/// One product we do not have yet, as the supplier wrote it.
class NameRequest {
  const NameRequest({required this.index, required this.supplierName, this.maker, this.code, this.spec, this.supplier});

  final int index;
  final String supplierName;
  final String? maker;
  final String? code;
  final String? spec;

  /// The supplier, so its name never ends up in ours.
  final String? supplier;

  Map<String, dynamic> toJson() => {
        'index': index,
        'supplier_name': supplierName,
        if (maker != null) 'maker': maker,
        if (code != null) 'code': code,
        if (spec != null) 'spec': spec,
        if (supplier != null) 'supplier': supplier,
      };
}

/// English standard names for new products (§43), proposed by the AI through
/// `import-plan` (`mode: suggest_names`). Nothing is saved here: a person
/// accepts or changes each one.
abstract class EnglishNameSuggester {
  /// index → proposed English name; indexes the AI could not name are left out.
  Future<ApiResult<Map<int, String>>> suggest(List<NameRequest> items);
}

class EnglishNameSuggesterImpl implements EnglishNameSuggester {
  EnglishNameSuggesterImpl(this._dio);

  final Dio _dio;

  @override
  Future<ApiResult<Map<int, String>>> suggest(List<NameRequest> items) async {
    try {
      final r = await _dio.post(
        '/import-plan',
        data: {'mode': 'suggest_names', 'items': [for (final i in items) i.toJson()]},
        options: Options(contentType: Headers.jsonContentType, receiveTimeout: const Duration(seconds: 90)),
      );
      final out = <int, String>{};
      for (final e in (r.data['data'] as List? ?? const [])) {
        if (e is! Map) continue;
        final index = (e['index'] as num?)?.toInt();
        final name = '${e['name_en'] ?? ''}'.trim();
        if (index != null && name.isNotEmpty) out[index] = name;
      }
      return ApiSuccess(out);
    } on DioException catch (e) {
      return mapDioError<Map<int, String>>(e);
    }
  }
}

final englishNameSuggesterProvider = Provider<EnglishNameSuggester>((ref) {
  return EnglishNameSuggesterImpl(ref.watch(deliveryDioProvider));
});
