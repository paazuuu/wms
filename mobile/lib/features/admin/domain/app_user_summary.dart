import 'package:equatable/equatable.dart';

/// A role held by a user, as returned by `list_app_users`/`my_roles` — just
/// enough to show a chip ("Warehouse Manager") without a separate lookup.
class UserRoleTag extends Equatable {
  const UserRoleTag({required this.code, required this.name});

  final String code;
  final String name;

  factory UserRoleTag.fromJson(Map<String, dynamic> json) => UserRoleTag(
        code: (json['code'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
      );

  @override
  List<Object?> get props => [code];
}

/// One row of `list_app_users` (0025/0029) — a person who has signed in at
/// least once, with the roles and warehouse scope currently assigned to
/// them.
class AppUserSummary extends Equatable {
  const AppUserSummary({
    required this.id,
    required this.name,
    required this.email,
    required this.status,
    required this.createdAt,
    this.roles = const [],
    this.warehouseIds = const [],
  });

  /// The real Supabase Auth `auth.uid()` — what every role/warehouse
  /// assignment keys off.
  final String id;
  final String name;
  final String email;
  final String status;
  final DateTime createdAt;
  final List<UserRoleTag> roles;

  /// Warehouses this user is restricted to (`user_warehouses`, 0029) —
  /// `can_access_warehouse` ignores this for system_admin/company_admin
  /// (who always pass), so an empty list here means "no restriction" only
  /// for an admin; for anyone else it means no warehouse access at all.
  final List<int> warehouseIds;

  factory AppUserSummary.fromJson(Map<String, dynamic> json) => AppUserSummary(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        email: (json['email'] ?? '').toString(),
        status: (json['status'] ?? 'active').toString(),
        createdAt:
            DateTime.tryParse((json['created_at'] ?? '').toString()) ??
                DateTime.fromMillisecondsSinceEpoch(0),
        roles: ((json['roles'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => UserRoleTag.fromJson(e.cast<String, dynamic>()))
            .toList(),
        warehouseIds: ((json['warehouse_ids'] as List?) ?? const [])
            .map((e) => e is int ? e : int.tryParse('$e'))
            .whereType<int>()
            .toList(),
      );

  @override
  List<Object?> get props => [id, name, email, status, roles, warehouseIds];
}

/// One row of the `roles` catalog — the full set of assignable roles, for
/// the "add role" picker.
class RoleOption extends Equatable {
  const RoleOption({required this.code, required this.name});

  final String code;
  final String name;

  factory RoleOption.fromJson(Map<String, dynamic> json) => RoleOption(
        code: (json['code'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
      );

  @override
  List<Object?> get props => [code];
}
