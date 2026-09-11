import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../data/admin_repository.dart';
import '../domain/app_user_summary.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepositoryImpl(ref.watch(restDioProvider));
});

/// Every user who has signed in at least once, with their current roles.
/// `autoDispose` (not kept alive) — this screen is admin-only and rarely
/// open, no reason to hold it warm in the background.
final adminUsersProvider =
    FutureProvider.autoDispose<List<AppUserSummary>>((ref) async {
  final result = await ref.watch(adminRepositoryProvider).listUsers();
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// The full role catalog, for the "add role" picker.
final adminRoleCatalogProvider =
    FutureProvider.autoDispose<List<RoleOption>>((ref) async {
  final result = await ref.watch(adminRepositoryProvider).listRoles();
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});
