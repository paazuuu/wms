import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../auth/application/auth_controller.dart' show authDioProvider;
import '../../delivery/application/delivery_providers.dart';
import '../domain/user_tier.dart';

/// One person to add: an email, the kind of user, a name if known.
class NewUser {
  const NewUser({required this.email, required this.tier, this.name});

  final String email;
  final UserTier tier;
  final String? name;

  Map<String, dynamic> toJson() => {'email': email, 'tier': tier.wire, if (name != null) 'name': name};
}

/// What became of one: 'created' (with its temporary password), 'existing'
/// (the account was there: its roles added, its password kept) or 'error'.
class ProvisionResult {
  const ProvisionResult({required this.email, required this.tier, required this.status, this.password, this.error});

  final String email;
  final UserTier tier;
  final String status;
  final String? password;
  final String? error;

  bool get ok => status != 'error';

  factory ProvisionResult.fromJson(Map<String, dynamic> j) => ProvisionResult(
        email: '${j['email'] ?? ''}',
        tier: UserTier.values.firstWhere((t) => t.wire == j['tier'], orElse: () => UserTier.user),
        status: '${j['status'] ?? 'error'}',
        password: j['password'] as String?,
        error: j['error'] as String?,
      );
}

/// Kinds of user written in a sheet: 普通 / 通常 / 現場 → user, 管理 →
/// manager, ADMIN / システム → admin; null when the words do not say.
UserTier? tierFromWords(String s) {
  final t = s.trim().toLowerCase();
  if (t.isEmpty) return null;
  if (t.contains('admin') || t.contains('システム') || t.contains('系统')) return UserTier.admin;
  if (t.contains('管理') || t.contains('manager')) return UserTier.manager;
  if (t.contains('普通') || t.contains('通常') || t.contains('現場') || t.contains('user') || t.contains('一般')) return UserTier.user;
  return null;
}

/// People pasted from a sheet, a line each: an email, the kind of user
/// (普通 when not written) and, if there is more, a name. Headings and lines
/// without an email are passed over; an email twice counts once.
List<NewUser> parseNewUsers(String text) {
  final out = <NewUser>[];
  final seen = <String>{};
  final mail = RegExp(r'[^\s@,;、，]+@[^\s@,;、，]+\.[^\s@,;、，]+');
  for (final line in text.split(RegExp(r'\r?\n'))) {
    final m = mail.firstMatch(line);
    if (m == null) continue;
    final email = m.group(0)!.toLowerCase();
    if (!seen.add(email)) continue;
    final rest = line.replaceFirst(m.group(0)!, '').split(RegExp(r'[\t,;、，]|\s{2,}')).map((c) => c.trim()).where((c) => c.isNotEmpty);
    UserTier? tier;
    String? name;
    for (final c in rest) {
      final t = tierFromWords(c);
      if (t != null && tier == null) {
        tier = t;
      } else {
        name ??= c;
      }
    }
    out.add(NewUser(email: email, tier: tier ?? UserTier.user, name: name));
  }
  return out;
}

/// Accounts made and passwords given by an ADMIN (user-admin, 0194), and
/// one's own password changed.
abstract class UserProvisioningRepository {
  Future<ApiResult<List<ProvisionResult>>> create(List<NewUser> users);

  /// A new temporary password for [userId].
  Future<ApiResult<String>> resetPassword(String userId);

  /// The signed-in user's own password.
  Future<ApiResult<bool>> changeOwnPassword(String password);
}

class UserProvisioningRepositoryImpl implements UserProvisioningRepository {
  UserProvisioningRepositoryImpl(this._functions, this._auth);

  final Dio _functions;
  final Dio _auth;

  @override
  Future<ApiResult<List<ProvisionResult>>> create(List<NewUser> users) async {
    try {
      final r = await _functions.post('/user-admin', data: {'action': 'create', 'users': [for (final u in users) u.toJson()]});
      final d = (r.data as Map)['data'] as Map?;
      return ApiSuccess([
        for (final e in (d?['results'] as List? ?? const []).whereType<Map>()) ProvisionResult.fromJson(e.cast<String, dynamic>()),
      ]);
    } on DioException catch (e) {
      return mapDioError<List<ProvisionResult>>(e);
    }
  }

  @override
  Future<ApiResult<String>> resetPassword(String userId) async {
    try {
      final r = await _functions.post('/user-admin', data: {'action': 'reset_password', 'user_id': userId});
      return ApiSuccess('${((r.data as Map)['data'] as Map)['password']}');
    } on DioException catch (e) {
      return mapDioError<String>(e);
    }
  }

  @override
  Future<ApiResult<bool>> changeOwnPassword(String password) async {
    try {
      await _auth.put('/user', data: {'password': password});
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }
}

final userProvisioningRepositoryProvider = Provider<UserProvisioningRepository>(
    (ref) => UserProvisioningRepositoryImpl(ref.watch(deliveryDioProvider), ref.watch(authDioProvider)));
