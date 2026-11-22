import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../delivery/application/delivery_providers.dart';

/// What erasing a supplier / partner card would do (0228): the work records
/// still naming it (it cannot go while they do), those that keep themselves
/// without it, and what goes with it — each as table → rows.
class PartnerEraseCheck {
  const PartnerEraseCheck({
    required this.id,
    required this.name,
    this.placeholder = false,
    this.blockers = const {},
    this.detached = const {},
    this.erased = const {},
  });

  final int id;
  final String name;

  /// 未確認（要手動確認）: the system's own, never erased.
  final bool placeholder;
  final Map<String, int> blockers;
  final Map<String, int> detached;
  final Map<String, int> erased;

  bool get canErase => !placeholder && blockers.isEmpty;

  static Map<String, int> _counts(Object? v) => {
        for (final e in (v is Map ? v : const {}).entries)
          if (e.value is num) '${e.key}': (e.value as num).toInt(),
      };

  factory PartnerEraseCheck.fromJson(Map<String, dynamic> j) => PartnerEraseCheck(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: '${j['name'] ?? ''}',
        placeholder: j['placeholder'] == true,
        blockers: _counts(j['blockers']),
        detached: _counts(j['detached']),
        erased: _counts(j['erased']),
      );
}

/// What erasing an 国外の仮想在庫 card would take with it.
class OverseasEraseCheck {
  const OverseasEraseCheck({
    required this.id,
    required this.name,
    this.isDefault = false,
    this.imports = 0,
    this.shipments = 0,
    this.notes = 0,
  });

  final int id;
  final String name;
  final bool isDefault;
  final int imports;
  final int shipments;
  final int notes;

  factory OverseasEraseCheck.fromJson(Map<String, dynamic> j) {
    int n(Object? v) => v is List ? v.length : 0;
    return OverseasEraseCheck(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: '${j['name'] ?? ''}',
      isDefault: j['is_default'] == true,
      imports: n(j['import_ids']),
      shipments: n(j['shipment_ids']),
      notes: n(j['note_ids']),
    );
  }
}

/// Cards erased for good, through the card-erase function (0228).
abstract class CardEraseRepository {
  Future<ApiResult<PartnerEraseCheck>> partnerCheck(int id);
  Future<ApiResult<OverseasEraseCheck>> overseasCheck(int id);

  /// [kind]: partner or overseas_site. True when it went.
  Future<ApiResult<bool>> erase(String kind, int id);
}

class CardEraseRepositoryImpl implements CardEraseRepository {
  CardEraseRepositoryImpl(this._rest, this._functions);

  final Dio _rest;
  final Dio _functions;

  Future<ApiResult<T>> _rpc<T>(String name, int id, T Function(Map<String, dynamic>) read) async {
    try {
      final r = await _rest.post('/rpc/$name', data: {'p_id': id});
      return ApiSuccess(read((r.data is Map ? r.data as Map : const {}).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<T>(e);
    }
  }

  @override
  Future<ApiResult<PartnerEraseCheck>> partnerCheck(int id) =>
      _rpc('partner_erase_check', id, PartnerEraseCheck.fromJson);

  @override
  Future<ApiResult<OverseasEraseCheck>> overseasCheck(int id) =>
      _rpc('overseas_site_erase_check', id, OverseasEraseCheck.fromJson);

  @override
  Future<ApiResult<bool>> erase(String kind, int id) async {
    try {
      final r = await _functions.post('/card-erase', data: {'kind': kind, 'id': id});
      return ApiSuccess(r.data is Map && (r.data as Map)['erased'] == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }
}

final cardEraseRepositoryProvider = Provider<CardEraseRepository>(
    (ref) => CardEraseRepositoryImpl(ref.watch(restDioProvider), ref.watch(deliveryDioProvider)));
