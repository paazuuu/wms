import 'package:equatable/equatable.dart';

/// The signed-in operator. [id] is the Supabase Auth user id (uuid) — the
/// same value `auth.uid()` resolves to server-side, so it's what every
/// RBAC/self-approval check in the database keys off.
class AuthUser extends Equatable {
  const AuthUser({
    required this.id,
    required this.email,
    this.name = '',
    this.roles = const [],
  });

  final String id;
  final String email;
  final String name;

  /// Role codes this user holds (e.g. `system_admin`, `picker`) — from
  /// `my_roles()`. Empty means "signed in but not yet assigned a role",
  /// which `has_permission()` will treat as no access to anything gated.
  final List<String> roles;

  factory AuthUser.fromGoTrue(Map<String, dynamic> json, {List<String> roles = const []}) {
    final email = json['email'] as String? ?? '';
    final metadata = json['user_metadata'] as Map<String, dynamic>?;
    final name = metadata?['name'] as String? ??
        (email.contains('@') ? email.split('@').first : email);
    return AuthUser(
      id: (json['id'] ?? '').toString(),
      email: email,
      name: name,
      roles: roles,
    );
  }

  AuthUser copyWith({List<String>? roles}) => AuthUser(
        id: id,
        email: email,
        name: name,
        roles: roles ?? this.roles,
      );

  @override
  List<Object?> get props => [id, email, roles];
}
