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

/// One row of `list_app_users` (0025) — a person who has signed in at least
/// once, with the roles currently assigned to them.
class AppUserSummary extends Equatable {
  const AppUserSummary({
    required this.id,
    required this.name,
    required this.email,
    required this.status,
    required this.createdAt,
    this.roles = const [],
  });

  /// The real Supabase Auth `auth.uid()` — what every role assignment keys
  /// off.
  final String id;
  final String name;
  final String email;
  final String status;
  final DateTime createdAt;
  final List<UserRoleTag> roles;

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
      );

  @override
  List<Object?> get props => [id, name, email, status, roles];
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
