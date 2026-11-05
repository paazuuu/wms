import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../auth/application/auth_controller.dart';
import '../../delivery/application/delivery_providers.dart';
import '../../home/domain/feature_catalog.dart';
import '../domain/user_tier.dart';

/// 表示設定 (0193): what a manager and a user see, as set by an ADMIN.
abstract class MenuVisibilityRepository {
  /// Every setting made: 'feature|tier' → shown.
  Future<ApiResult<Map<String, bool>>> list();

  /// Written over what was there; ADMIN only (the server refuses others).
  Future<ApiResult<int>> save(Map<String, bool> settings);
}

String visibilityKey(String featureId, UserTier tier) => '$featureId|${tier.wire}';

class MenuVisibilityRepositoryImpl implements MenuVisibilityRepository {
  MenuVisibilityRepositoryImpl(this._rest);

  final Dio _rest;

  @override
  Future<ApiResult<Map<String, bool>>> list() async {
    try {
      final r = await _rest.post('/rpc/menu_visibility_list', data: const {});
      final d = r.data is List && (r.data as List).length == 1 && (r.data as List).first is List ? (r.data as List).first : r.data;
      return ApiSuccess({
        for (final e in (d as List? ?? const []).whereType<Map>()) '${e['feature_id']}|${e['tier']}': e['visible'] == true,
      });
    } on DioException catch (e) {
      return mapDioError<Map<String, bool>>(e);
    }
  }

  @override
  Future<ApiResult<int>> save(Map<String, bool> settings) async {
    try {
      final rows = [
        for (final e in settings.entries)
          if (e.key.contains('|'))
            {'feature_id': e.key.split('|').first, 'tier': e.key.split('|').last, 'visible': e.value},
      ];
      final r = await _rest.post('/rpc/menu_visibility_save', data: {'p_rows': rows});
      return ApiSuccess(r.data is num ? (r.data as num).toInt() : rows.length);
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
  }
}

final menuVisibilityRepositoryProvider =
    Provider<MenuVisibilityRepository>((ref) => MenuVisibilityRepositoryImpl(ref.watch(restDioProvider)));

/// What has been set ('feature|tier' → shown); empty until read, or when it
/// cannot be — the defaults then apply.
final menuVisibilitySettingsProvider = FutureProvider<Map<String, bool>>((ref) async {
  final r = await ref.watch(menuVisibilityRepositoryProvider).list();
  return switch (r) {
    ApiSuccess(:final data) => data,
    ApiFailure() => const <String, bool>{},
  };
});

/// Whether [tier] sees [featureId] (in [groupId]): as set, else the default.
bool tierSees(Map<String, bool> settings, String featureId, String groupId, UserTier tier) =>
    tier == UserTier.admin || (settings[visibilityKey(featureId, tier)] ?? defaultVisible(featureId, groupId, tier));

/// The signed-in user's tier; null when signed out or without a role.
final currentUserTierProvider = Provider<UserTier?>((ref) {
  // Signed in, the app built the auth controller long before any screen; a
  // screen shown on its own (a test, a preview) is not made to start one.
  if (!ref.exists(authControllerProvider)) return null;
  final user = ref.watch(authControllerProvider).user;
  return user == null ? null : UserTier.of(user.roles);
});

/// The menu entries (and content) hidden from the signed-in user by their
/// tier. Only what is offered: permissions still decide what is allowed.
final hiddenFeaturesProvider = Provider<Set<String>>((ref) {
  final tier = ref.watch(currentUserTierProvider);
  if (tier == null || tier == UserTier.admin) return const {};
  final settings = ref.watch(menuVisibilitySettingsProvider).valueOrNull ?? const <String, bool>{};
  return {
    for (final g in buildFeatureCatalog())
      for (final e in g.entries)
        if (!tierSees(settings, e.id, g.id, tier)) e.id,
    if (!tierSees(settings, contentPrices, 'content', tier)) contentPrices,
  };
});

/// Prices and amounts are shown to the signed-in user.
final showPricesProvider = Provider<bool>((ref) => !ref.watch(hiddenFeaturesProvider).contains(contentPrices));
