import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../delivery/application/delivery_providers.dart';

/// A product's size and weight as the AI found them on the web (0141).
/// Nothing is saved until a person takes them.
class SpecLookupResult extends Equatable {
  const SpecLookupResult({
    this.weightG,
    this.weightBasis,
    this.widthMm,
    this.depthMm,
    this.heightMm,
    this.sizeBasis,
    this.sourceUrl,
    this.sources = const [],
    this.confidence,
    this.note,
    this.errorKind,
    this.message,
    this.keyLabel,
    this.keyFallback = false,
  });

  final double? weightG;

  /// product (本体) or package (梱包込み).
  final String? weightBasis;
  final double? widthMm;
  final double? depthMm;
  final double? heightMm;
  final String? sizeBasis;

  /// The page the AI says the values came from.
  final String? sourceUrl;

  /// The pages its search drew on.
  final List<({String? title, String url})> sources;
  final double? confidence;
  final String? note;
  final String? errorKind;
  final String? message;

  /// The key it was looked up with; [keyFallback] when that was the reading
  /// key because none is chosen for the lookup.
  final String? keyLabel;
  final bool keyFallback;

  bool get hasWeight => weightG != null;
  bool get hasSize => widthMm != null || depthMm != null || heightMm != null;
  bool get found => hasWeight || hasSize;

  /// The page to keep with the values: the one named, else the first found.
  String? get bestUrl => sourceUrl ?? sources.firstOrNull?.url;

  static double? _d(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
  static String? _s(Object? v) {
    final t = v?.toString().trim();
    return t == null || t.isEmpty ? null : t;
  }

  factory SpecLookupResult.fromJson(Map<String, dynamic> j, {String? keyLabel, bool keyFallback = false}) =>
      SpecLookupResult(
        weightG: _d(j['weight_g']),
        weightBasis: _s(j['weight_basis']),
        widthMm: _d(j['width_mm']),
        depthMm: _d(j['depth_mm']),
        heightMm: _d(j['height_mm']),
        sizeBasis: _s(j['size_basis']),
        sourceUrl: _s(j['source_url']),
        sources: [
          for (final e in (j['sources'] as List? ?? const []).whereType<Map>())
            if (_s(e['url']) case final u?) (title: _s(e['title']), url: u),
        ],
        confidence: _d(j['confidence']),
        note: _s(j['note']),
        errorKind: _s(j['error_kind']),
        message: _s(j['message']),
        keyLabel: keyLabel,
        keyFallback: keyFallback,
      );

  @override
  List<Object?> get props =>
      [weightG, weightBasis, widthMm, depthMm, heightMm, sizeBasis, sourceUrl, sources, confidence, note, errorKind];
}

/// What the AI is told about a product to look it up.
class SpecLookupRequest {
  const SpecLookupRequest({required this.name, this.maker, this.code, this.jan, this.nameEn});

  final String name;
  final String? maker;
  final String? code;
  final String? jan;
  final String? nameEn;

  Map<String, dynamic> toJson(int index) => {
        'index': index,
        'name': name,
        if (maker != null) 'maker': maker,
        if (code != null) 'code': code,
        if (jan != null) 'jan': jan,
        if (nameEn != null) 'name_en': nameEn,
      };
}

abstract class SpecLookupRepository {
  /// サイズ・重量を調べる: one product looked up on the web.
  Future<ApiResult<SpecLookupResult>> lookup(SpecLookupRequest item);
}

class SpecLookupRepositoryImpl implements SpecLookupRepository {
  SpecLookupRepositoryImpl(this._functions);

  final Dio _functions;

  @override
  Future<ApiResult<SpecLookupResult>> lookup(SpecLookupRequest item) async {
    try {
      final r = await _functions.post(
        '/import-plan',
        data: {
          'mode': 'lookup_spec',
          'items': [item.toJson(0)],
        },
        options: Options(contentType: Headers.jsonContentType, receiveTimeout: const Duration(seconds: 120)),
      );
      final data = ((r.data as Map)['data'] as Map).cast<String, dynamic>();
      final key = (data['key'] as Map?)?.cast<String, dynamic>() ?? const {};
      final first = (data['results'] as List? ?? const []).whereType<Map>().firstOrNull;
      if (first == null) return const ApiFailure(message: 'nothing came back from the lookup');
      return ApiSuccess(SpecLookupResult.fromJson(first.cast<String, dynamic>(),
          keyLabel: key['label']?.toString(), keyFallback: key['fallback'] == true));
    } on DioException catch (e) {
      return mapDioError<SpecLookupResult>(e);
    }
  }
}

final specLookupRepositoryProvider =
    Provider<SpecLookupRepository>((ref) => SpecLookupRepositoryImpl(ref.watch(deliveryDioProvider)));
