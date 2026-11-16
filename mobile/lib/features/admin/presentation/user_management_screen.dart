import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../../warehouse_context/domain/warehouse.dart';
import '../application/admin_providers.dart';
import '../domain/user_tier.dart';
import 'add_users_dialog.dart';
import 'menu_visibility_screen.dart' show userTierLabel;
import '../domain/app_user_summary.dart';
import '../../../core/ui/popconfirm.dart';
import '../../auth/application/auth_controller.dart';

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

  /// 区分 (0217): 通常 ⇄ 管理者 (and ADMIN), after a confirm; the roles follow.
  Future<void> _setTier(BuildContext context, WidgetRef ref, AppUserSummary user, UserTier? from, UserTier to) async {
    final l10n = AppLocalizations.of(context);
    final name = user.name.isEmpty ? user.email : user.name;
    final confirmed = await showPopconfirm(
      context,
      title: l10n.umTierConfirm,
      message: l10n.umTierConfirmBody(name, from == null ? l10n.umTierNone : userTierLabel(l10n, from), userTierLabel(l10n, to)),
      okLabel: l10n.umTierChange,
      okKey: ValueKey('um-tier-ok-${user.id}'),
      danger: to == UserTier.admin || from == UserTier.admin,
    );
    if (confirmed != true || !context.mounted) return;
    final result = await ref.read(adminRepositoryProvider).setTier(user.id, to.wire);
    if (!context.mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(adminUsersProvider);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.umTierChanged(name, userTierLabel(l10n, to)))));
      },
      failure: (f) => _snackError(context, humanizeApiErrorMessage(l10n, f.message)),
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
      failure: (f) => _snackError(context, humanizeApiErrorMessage(l10n, f.message)),
    );
  }

  Future<void> _removeWarehouse(BuildContext context, WidgetRef ref,
      AppUserSummary user, Warehouse warehouse) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showPopconfirm(
      context,
      title: l10n.userMgmtRemoveWarehouseTitle,
      message: l10n.userMgmtRemoveWarehouseBody(warehouse.name, user.name),
      okLabel: l10n.userMgmtRemoveWarehouseAction,
      danger: true,
    );
    if (confirmed != true || !context.mounted) return;

    final result = await ref
        .read(adminRepositoryProvider)
        .revokeWarehouse(user.id, warehouse.id);
    if (!context.mounted) return;
    result.when(
      success: (_) => ref.invalidate(adminUsersProvider),
      failure: (f) => _snackError(context, humanizeApiErrorMessage(l10n, f.message)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(adminUsersProvider);
    final warehouses =
        ref.watch(warehouseOverviewProvider).valueOrNull?.warehouses ?? const [];
    final meId = ref.exists(authControllerProvider) ? ref.watch(authControllerProvider).user?.id : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.userMgmtTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: FilledButton.icon(
              key: const ValueKey('um-add'),
              onPressed: () => addUsers(context, ref),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: Text(l10n.umAdd),
            ),
          ),
        ],
      ),
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
                isMe: users[i].id == meId,
                onTier: (from, to) => _setTier(context, ref, users[i], from, to),
                onAddWarehouse: () => _addWarehouse(context, ref, users[i]),
                onRemoveWarehouse: (w) => _removeWarehouse(context, ref, users[i], w),
                onResetPassword: () => resetUserPassword(context, ref, userId: users[i].id, email: users[i].email),
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
    required this.onTier,
    this.isMe = false,
    required this.onAddWarehouse,
    required this.onRemoveWarehouse,
    this.onResetPassword,
  });

  final AppUserSummary user;
  final List<Warehouse> warehouses;
  /// The 区分 picked: (what it was, what it becomes).
  final void Function(UserTier? from, UserTier to) onTier;

  /// The signed-in user: their own 区分 is not changed here.
  final bool isMe;
  final VoidCallback onAddWarehouse;
  final ValueChanged<Warehouse> onRemoveWarehouse;
  final VoidCallback? onResetPassword;

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
                  tooltip: l10n.userMgmtAddWarehouse,
                  icon: const Icon(Icons.add_business_outlined),
                  onPressed: onAddWarehouse,
                ),
                if (onResetPassword != null)
                  IconButton(
                    key: ValueKey('um-reset-${user.id}'),
                    tooltip: l10n.umReset,
                    icon: const Icon(Icons.key_outlined),
                    onPressed: onResetPassword,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // 区分: one of three, each one role — changed here, not by roles.
            Builder(builder: (context) {
              final tier = UserTier.of(user.roles.map((r) => r.code));
              final help = switch (tier) {
                UserTier.admin => l10n.umTierHelpAdmin,
                UserTier.manager => l10n.umTierHelpManager,
                UserTier.user => l10n.umTierHelpUser,
                null => l10n.userMgmtNoRoles,
              };
              return Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Tooltip(
                  message: isMe ? l10n.umTierSelf : '',
                  child: PopupMenuButton<UserTier>(
                    key: ValueKey('um-tier-${user.id}'),
                    enabled: !isMe,
                    tooltip: '',
                    onSelected: (t) {
                      if (t != tier) onTier(tier, t);
                    },
                    itemBuilder: (_) => [
                      for (final t in UserTier.values)
                        CheckedPopupMenuItem(
                          key: ValueKey('um-tier-${user.id}-${t.wire}'),
                          value: t,
                          checked: t == tier,
                          child: Text(userTierLabel(l10n, t)),
                        ),
                    ],
                    // Always what is saved: a cancelled change leaves it as it was.
                    child: SizedBox(
                      width: 200,
                      child: InputDecorator(
                        decoration: InputDecoration(labelText: l10n.umTierPick, isDense: true, enabled: !isMe),
                        child: Row(children: [
                          Expanded(
                            child: Text(tier == null ? l10n.umTierNone : userTierLabel(l10n, tier),
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                          ),
                          Icon(isMe ? Icons.lock_outline : Icons.arrow_drop_down, size: 20),
                        ]),
                      ),
                    ),
                  ),
                ),
                Text(help, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ]);
            }),
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
