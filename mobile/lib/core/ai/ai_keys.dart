import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/delivery/application/delivery_providers.dart';
import '../api/api_error_mapper.dart';
import '../api/api_result.dart';
import 'ai_health.dart';

/// Free or paid Gemini usage, as the person who registered the key says.
enum AiKeyTier {
  free('free'),
  paid('paid'),
  unknown('unknown');

  const AiKeyTier(this.wire);
  final String wire;

  static AiKeyTier fromWire(String? v) =>
      AiKeyTier.values.firstWhere((t) => t.wire == v, orElse: () => AiKeyTier.unknown);
}

/// What a key is used for (0141): reading documents, or looking a
/// product's size and weight up on the web.
enum AiKeyPurpose {
  general('general'),
  specLookup('spec_lookup');

  const AiKeyPurpose(this.wire);
  final String wire;

  static AiKeyPurpose fromWire(String? v) =>
      AiKeyPurpose.values.firstWhere((p) => p.wire == v, orElse: () => AiKeyPurpose.general);
}

/// One Gemini API key registered on the screen (0137). The key itself stays
/// in Supabase Vault; only its last four characters come back.
class AiApiKey extends Equatable {
  const AiApiKey({
    required this.id,
    required this.label,
    this.keyHint,
    this.tier = AiKeyTier.unknown,
    this.model,
    this.isActive = false,
    this.note,
    this.lastUsedAt,
    this.lastOk,
    this.lastErrorKind,
    this.calls24h = 0,
    this.failed24h = 0,
    this.purpose = AiKeyPurpose.general,
    this.specActive = false,
    this.lookups24h = 0,
  });

  final int id;
  final String label;
  final String? keyHint;
  final AiKeyTier tier;

  /// The model to call with this key; null is the server's default.
  final String? model;
  final bool isActive;
  final String? note;
  final DateTime? lastUsedAt;
  final bool? lastOk;
  final String? lastErrorKind;
  final int calls24h;
  final int failed24h;

  /// What it was registered for (0141).
  final AiKeyPurpose purpose;

  /// In use for サイズ・重量を調べる (0141); [isActive] is reading.
  final bool specActive;
  final int lookups24h;

  factory AiApiKey.fromJson(Map<String, dynamic> j) {
    String? s(Object? v) {
      final t = v?.toString().trim();
      return t == null || t.isEmpty ? null : t;
    }

    int n(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
    return AiApiKey(
      id: n(j['id']),
      label: s(j['label']) ?? '',
      keyHint: s(j['key_hint']),
      tier: AiKeyTier.fromWire(s(j['tier'])),
      model: s(j['model']),
      isActive: j['is_active'] == true,
      note: s(j['note']),
      lastUsedAt: DateTime.tryParse('${j['last_used_at'] ?? ''}')?.toLocal(),
      lastOk: j['last_ok'] is bool ? j['last_ok'] as bool : null,
      lastErrorKind: s(j['last_error_kind']),
      calls24h: n(j['calls_24h']),
      failed24h: n(j['failed_24h']),
      purpose: AiKeyPurpose.fromWire(s(j['purpose'])),
      specActive: j['spec_active'] == true,
      lookups24h: n(j['lookups_24h']),
    );
  }

  @override
  List<Object?> get props =>
      [id, label, keyHint, tier, model, isActive, lastOk, lastErrorKind, calls24h, failed24h, purpose, specActive, lookups24h];
}

/// The registered keys, and whether the server's own GEMINI_API_KEY is the
/// one in use because none is chosen.
class AiKeys extends Equatable {
  const AiKeys({this.keys = const [], this.usingServerKey = true, this.specUsesGeneral = true});

  final List<AiApiKey> keys;
  final bool usingServerKey;

  /// No key is chosen for the lookup: it uses the reading key (0141).
  final bool specUsesGeneral;

  factory AiKeys.fromJson(Map<String, dynamic> j) => AiKeys(
        keys: [
          for (final e in (j['keys'] as List? ?? const []))
            if (e is Map) AiApiKey.fromJson(e.cast<String, dynamic>()),
        ],
        usingServerKey: j['using_server_key'] != false,
        specUsesGeneral: j['spec_uses_general'] != false,
      );

  @override
  List<Object?> get props => [keys, usingServerKey, specUsesGeneral];
}

abstract class AiKeyRepository {
  Future<ApiResult<AiKeys>> list();
  Future<ApiResult<int>> add({
    required String label,
    required String key,
    AiKeyTier tier = AiKeyTier.unknown,
    String? model,
    bool activate = false,
    String? note,
    AiKeyPurpose purpose = AiKeyPurpose.general,
  });

  /// Null puts the server's GEMINI_API_KEY back in use.
  Future<ApiResult<bool>> activate(int? id);

  /// The key for [purpose] (0141); null goes back to the fallback — for the
  /// lookup, the reading key.
  Future<ApiResult<bool>> use(AiKeyPurpose purpose, int? id);
  Future<ApiResult<bool>> update(int id, {String? label, AiKeyTier? tier, String? model, String? note, String? newKey});
  Future<ApiResult<bool>> retire(int id);

  /// One small call with this key (or with the one in use when null).
  Future<ApiResult<AiPingResult>> test(int? id);
}

class AiKeyRepositoryImpl implements AiKeyRepository {
  AiKeyRepositoryImpl({required Dio rest, required Dio functions})
      : _rest = rest,
        _functions = functions;

  final Dio _rest;
  final Dio _functions;

  Future<ApiResult<T>> _rpc<T>(String name, Map<String, dynamic> body, T Function(Object? data) read) async {
    try {
      final r = await _rest.post('/rpc/$name', data: body);
      return ApiSuccess(read(r.data));
    } on DioException catch (e) {
      return mapDioError<T>(e);
    }
  }

  @override
  Future<ApiResult<AiKeys>> list() => _rpc('ai_keys_list', const {}, (d) {
        final m = d is List && d.isNotEmpty ? d.first : d;
        return AiKeys.fromJson((m as Map).cast<String, dynamic>());
      });

  @override
  Future<ApiResult<int>> add({
    required String label,
    required String key,
    AiKeyTier tier = AiKeyTier.unknown,
    String? model,
    bool activate = false,
    String? note,
    AiKeyPurpose purpose = AiKeyPurpose.general,
  }) =>
      _rpc('ai_key_add_for', {
        'p_purpose': purpose.wire,
        'p_label': label,
        'p_key': key,
        'p_tier': tier.wire,
        'p_model': model,
        'p_activate': activate,
        'p_note': note,
      }, (d) => d is num ? d.toInt() : int.tryParse('$d') ?? 0);

  @override
  Future<ApiResult<bool>> activate(int? id) => use(AiKeyPurpose.general, id);

  @override
  Future<ApiResult<bool>> use(AiKeyPurpose purpose, int? id) =>
      _rpc('ai_key_use', {'p_purpose': purpose.wire, 'p_id': id}, (_) => true);

  @override
  Future<ApiResult<bool>> update(int id, {String? label, AiKeyTier? tier, String? model, String? note, String? newKey}) =>
      _rpc('ai_key_update', {
        'p_id': id,
        'p_label': label,
        'p_tier': tier?.wire,
        'p_model': model,
        'p_note': note,
        'p_new_key': newKey,
      }, (_) => true);

  @override
  Future<ApiResult<bool>> retire(int id) => _rpc('ai_key_retire', {'p_id': id}, (_) => true);

  @override
  Future<ApiResult<AiPingResult>> test(int? id) async {
    try {
      final r = await _functions.post(
        '/import-plan',
        data: {'mode': 'ai_ping', if (id != null) 'key_id': id},
        options: Options(contentType: Headers.jsonContentType, receiveTimeout: const Duration(seconds: 60)),
      );
      return ApiSuccess(AiPingResult.fromJson(((r.data as Map)['data'] as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<AiPingResult>(e);
    }
  }
}

final aiKeyRepositoryProvider = Provider<AiKeyRepository>((ref) => AiKeyRepositoryImpl(
      rest: ref.watch(restDioProvider),
      functions: ref.watch(deliveryDioProvider),
    ));

final aiKeysProvider = FutureProvider.autoDispose<AiKeys>((ref) async {
  final r = await ref.watch(aiKeyRepositoryProvider).list();
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});
