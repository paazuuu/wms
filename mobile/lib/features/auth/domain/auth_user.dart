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
    this.permissions = const [],
    this.warehouseIds = const [],
  });

  final String id;
  final String email;
  final String name;

  /// Role codes this user holds (e.g. `system_admin`, `picker`) — from
  /// `my_access()`. Empty means "signed in but not yet assigned a role",
  /// which `has_permission()` will treat as no access to anything gated.
  final List<String> roles;

  /// Permission codes this user holds through those roles (e.g.
  /// `pick.confirm`, `report.view`) — the same set every server-side
  /// `has_permission()` check consults. An admin role is granted every
  /// permission explicitly at the database, so this list is already complete
  /// for them; there is no separate "is admin" bypass to apply client-side.
  ///
  /// Used only to decide what the UI *offers* (UI spec §37) — hiding a
  /// screen someone cannot act in avoids a menu entry that opens onto an
  /// empty, RLS-filtered view with no explanation. It is not itself a
  /// security boundary: every RPC and RLS policy re-checks permission
  /// server-side regardless of what this list says.
  final List<String> permissions;

  /// Warehouse ids this user is scoped to (`user_warehouses`, via
  /// `my_access()`). Empty means one of two very different things, which
  /// [isWarehouseUnrestricted] separates: an admin is unrestricted and
  /// simply has no rows here, while a non-admin with no rows can act in no
  /// warehouse at all.
  ///
  /// Same standing as [permissions]: used to explain the UI, never to decide
  /// access. Migration 0044's `accessible_warehouse_ids()` is what actually
  /// enforces this, inside every warehouse-scoped RPC.
  final List<int> warehouseIds;

  /// True when warehouse scope does not apply to this user — mirrors the
  /// server's own rule in `accessible_warehouse_ids()`, where these two
  /// roles resolve to "every warehouse" regardless of `user_warehouses`.
  bool get isWarehouseUnrestricted =>
      roles.contains('system_admin') || roles.contains('company_admin');

  /// True when this user has been given a role but no warehouse to use it
  /// in — the state that would otherwise show up only as silently empty
  /// screens and a refused write, so the UI says so instead.
  bool get hasNoAssignedWarehouse =>
      !isWarehouseUnrestricted && warehouseIds.isEmpty;

  bool hasPermission(String code) => permissions.contains(code);

  /// True if this user holds at least one of [codes]. An empty [codes] means
  /// "not gated" and is always true — the convention [FeatureEntry] uses for
  /// a screen with no permission requirement of its own.
  bool hasAnyPermission(Iterable<String> codes) =>
      codes.isEmpty || codes.any(permissions.contains);

  factory AuthUser.fromGoTrue(
    Map<String, dynamic> json, {
    List<String> roles = const [],
    List<String> permissions = const [],
    List<int> warehouseIds = const [],
  }) {
    final email = json['email'] as String? ?? '';
    final metadata = json['user_metadata'] as Map<String, dynamic>?;
    final name = metadata?['name'] as String? ??
        (email.contains('@') ? email.split('@').first : email);
    return AuthUser(
      id: (json['id'] ?? '').toString(),
      email: email,
      name: name,
      roles: roles,
      permissions: permissions,
      warehouseIds: warehouseIds,
    );
  }

  AuthUser copyWith({
    List<String>? roles,
    List<String>? permissions,
    List<int>? warehouseIds,
  }) =>
      AuthUser(
        id: id,
        email: email,
        name: name,
        roles: roles ?? this.roles,
        permissions: permissions ?? this.permissions,
        warehouseIds: warehouseIds ?? this.warehouseIds,
      );

  @override
  List<Object?> get props => [id, email, roles, permissions, warehouseIds];
}
