import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error_mapper.dart';
import '../../core/api/api_result.dart';
import '../delivery/application/delivery_providers.dart';

/// The rules the system administrator can relax (0212).
abstract final class Req {
  static const receiptPrice = 'receipt.unit_price';
  static const shipPrice = 'shipment.unit_price';
  static const shipRate = 'shipment.fx_rate';
  static const shipCard = 'shipment.destination_card';
}

class RequirementRule {
  const RequirementRule({required this.key, required this.required, this.isDefault = true, this.updatedAt, this.updatedByName});

  final String key;
  final bool required;
  final bool isDefault;
  final DateTime? updatedAt;
  final String? updatedByName;

  factory RequirementRule.fromJson(Map<String, dynamic> j) => RequirementRule(
        key: '${j['key']}',
        required: j['required'] != false,
        isDefault: j['is_default'] == true,
        updatedAt: j['updated_at'] == null ? null : DateTime.tryParse('${j['updated_at']}')?.toLocal(),
        updatedByName: j['updated_by_name'] as String?,
      );
}

class Requirements {
  const Requirements({this.rules = const [], this.canEdit = false});

  final List<RequirementRule> rules;
  final bool canEdit;

  /// On unless turned off (a rule not listed is on, as in the database).
  bool on(String key) => rules.where((r) => r.key == key).firstOrNull?.required ?? true;
}

abstract class RequirementsRepository {
  Future<ApiResult<Requirements>> list();
  Future<ApiResult<bool>> set(String key, bool required);
}

class RequirementsRepositoryImpl implements RequirementsRepository {
  RequirementsRepositoryImpl(this._rest);

  final Dio _rest;

  @override
  Future<ApiResult<Requirements>> list() async {
    try {
      final r = await _rest.post('/rpc/requirements_list', data: const <String, dynamic>{});
      final d = r.data is Map ? (r.data as Map).cast<String, dynamic>() : const <String, dynamic>{};
      return ApiSuccess(Requirements(
        canEdit: d['can_edit'] == true,
        rules: [
          for (final e in (d['rules'] as List? ?? const []).whereType<Map>())
            RequirementRule.fromJson(e.cast<String, dynamic>()),
        ],
      ));
    } on DioException catch (e) {
      return mapDioError<Requirements>(e);
    }
  }

  @override
  Future<ApiResult<bool>> set(String key, bool required) async {
    try {
      await _rest.post('/rpc/requirement_set', data: {'p_key': key, 'p_required': required});
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }
}

final requirementsRepositoryProvider =
    Provider<RequirementsRepository>((ref) => RequirementsRepositoryImpl(ref.watch(restDioProvider)));

/// The rules as they are now; every rule on while they load or cannot be
/// read, as the database holds them on by default.
final requirementsProvider = FutureProvider.autoDispose<Requirements>((ref) async {
  final r = await ref.watch(requirementsRepositoryProvider).list();
  return r.when(success: (d) => d, failure: (_) => const Requirements());
});

/// Whether [key] is required now (true until known).
final requirementOnProvider = Provider.autoDispose.family<bool, String>(
    (ref, key) => ref.watch(requirementsProvider).valueOrNull?.on(key) ?? true);
