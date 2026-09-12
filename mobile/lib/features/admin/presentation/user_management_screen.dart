import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../../warehouse_context/domain/warehouse.dart';
import '../application/admin_providers.dart';
import '../domain/app_user_summary.dart';

/// Assigning roles to teammates (spec §21/§22) — the UI half of 0024/0025's
/// admin RPCs. Anyone can open this screen; the server is the real gate
/// (`user.manage`), so a non-admin just sees the RPC's own permission error
/// here rather than the screen hiding itself and leaving no explanation.
class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  void _snackError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
  }

  Future<void> _addRole(
      BuildContext context, WidgetRef ref, AppUserSummary user) async {
    final l10n = AppLocalizations.of(context);
    final List<RoleOption> catalog;
    try {
      catalog = await ref.read(adminRoleCatalogProvider.future);
    } catch (e) {
      if (context.mounted) _snackError(context, '$e');
      return;
    }
    if (!context.mounted) return;

    final held = user.roles.map((r) => r.code).toSet();
    final options = catalog.where((r) => !held.contains(r.code)).toList();
    if (options.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.userMgmtAllRolesHeld)));
      return;
    }

    final picked = await showModalBottomSheet<RoleOption>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final role in options)
              ListTile(
                title: Text(role.name),
                onTap: () => Navigator.of(sheetContext).pop(role),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !context.mounted) return;

    final result =
        await ref.read(adminRepositoryProvider).assignRole(user.id, picked.code);
    if (!context.mounted) return;
    result.when(
      success: (_) => ref.invalidate(adminUsersProvider),
      failure: (f) => _snackError(context, f.message),
    );
  }

  Future<void> _addWarehouse(
      BuildContext context, WidgetRef ref, AppUserSummary user) async {
    final l10n = AppLocalizations.of(context);
    final List<Warehouse> catalog;
    try {
      final overview = await ref.read(warehouseOverviewProvider.future);
      catalog = overview.warehouses;
    } catch (e) {
      if (context.mounted) _snackError(context, '$e');
      return;
    }
    if (!context.mounted) return;

    final held = user.warehouseIds.toSet();
    final options = catalog.where((w) => !held.contains(w.id)).toList();
    if (options.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.userMgmtAllWarehousesHeld)));
      return;
    }

    final picked = await showModalBottomSheet<Warehouse>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final warehouse in options)
              ListTile(
                title: Text(warehouse.name),
                subtitle: Text(warehouse.code),
                onTap: () => Navigator.of(sheetContext).pop(warehouse),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !context.mounted) return;

    final result = await ref
        .read(adminRepositoryProvider)
        .assignWarehouse(user.id, picked.id);
    if (!context.mounted) return;
    result.when(
      success: (_) => ref.invalidate(adminUsersProvider),
      failure: (f) => _snackError(context, f.message),
    );
  }

  Future<void> _removeWarehouse(BuildContext context, WidgetRef ref,
      AppUserSummary user, Warehouse warehouse) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.userMgmtRemoveWarehouseTitle),
        content: Text(l10n.userMgmtRemoveWarehouseBody(warehouse.name, user.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.userMgmtRemoveWarehouseAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await ref
        .read(adminRepositoryProvider)
        .revokeWarehouse(user.id, warehouse.id);
    if (!context.mounted) return;
    result.when(
      success: (_) => ref.invalidate(adminUsersProvider),
      failure: (f) => _snackError(context, f.message),
    );
  }

  Future<void> _removeRole(BuildContext context, WidgetRef ref,
      AppUserSummary user, UserRoleTag role) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.userMgmtRemoveRoleTitle),
        content: Text(l10n.userMgmtRemoveRoleBody(role.name, user.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.userMgmtRemoveRoleAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result =
        await ref.read(adminRepositoryProvider).revokeRole(user.id, role.code);
    if (!context.mounted) return;
    result.when(
      success: (_) => ref.invalidate(adminUsersProvider),
      failure: (f) => _snackError(context, f.message),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(adminUsersProvider);
    final warehouses =
        ref.watch(warehouseOverviewProvider).valueOrNull?.warehouses ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.userMgmtTitle)),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(adminUsersProvider),
        ),
        data: (users) {
          if (users.isEmpty) {
            return EmptyStateView(
              icon: Icons.people_outline,
              title: l10n.userMgmtEmpty,
              message: l10n.userMgmtEmptyBody,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminUsersProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: users.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) => _UserCard(
                user: users[i],
                warehouses: warehouses,
                onAddRole: () => _addRole(context, ref, users[i]),
                onRemoveRole: (role) => _removeRole(context, ref, users[i], role),
                onAddWarehouse: () => _addWarehouse(context, ref, users[i]),
                onRemoveWarehouse: (w) => _removeWarehouse(context, ref, users[i], w),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.warehouses,
    required this.onAddRole,
    required this.onRemoveRole,
    required this.onAddWarehouse,
    required this.onRemoveWarehouse,
  });

  final AppUserSummary user;
  final List<Warehouse> warehouses;
  final VoidCallback onAddRole;
  final ValueChanged<UserRoleTag> onRemoveRole;
  final VoidCallback onAddWarehouse;
  final ValueChanged<Warehouse> onRemoveWarehouse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: scheme.surfaceContainerHigh,
                  child: Icon(Icons.person_outline,
                      size: 18, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name.isEmpty ? user.email : user.name,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (user.email.isNotEmpty)
                        Text(
                          user.email,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.userMgmtAddRole,
                  icon: const Icon(Icons.add_moderator_outlined),
                  onPressed: onAddRole,
                ),
                IconButton(
                  tooltip: l10n.userMgmtAddWarehouse,
                  icon: const Icon(Icons.add_business_outlined),
                  onPressed: onAddWarehouse,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (user.roles.isEmpty)
              Text(
                l10n.userMgmtNoRoles,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              )
            else
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final role in user.roles)
                    InputChip(
                      label: Text(role.name),
                      onDeleted: () => onRemoveRole(role),
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.userMgmtWarehousesLabel,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (user.warehouseIds.isEmpty)
              Text(
                l10n.userMgmtNoWarehouses,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              )
            else
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final id in user.warehouseIds)
                    _warehouseChip(id, onRemoveWarehouse),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _warehouseChip(int id, ValueChanged<Warehouse> onRemove) {
    final match = warehouses.where((w) => w.id == id);
    if (match.isEmpty) {
      // The warehouse itself was deleted after the assignment was made —
      // still shown (with its raw id) rather than silently dropped, since
      // the underlying user_warehouses row is real and worth surfacing.
      return Chip(label: Text('#$id'));
    }
    final warehouse = match.first;
    return InputChip(
      label: Text(warehouse.name),
      onDeleted: () => onRemove(warehouse),
    );
  }
}
