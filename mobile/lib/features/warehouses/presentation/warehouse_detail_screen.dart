import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../application/warehouse_providers.dart';
import '../domain/warehouse.dart';
import 'warehouse_status_ui.dart';

/// Read-only warehouse detail: identity, address, contact, and capacity counts.
class WarehouseDetailScreen extends ConsumerWidget {
  const WarehouseDetailScreen({super.key, required this.warehouseId});

  final int warehouseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warehouse = ref.watch(warehouseDetailProvider(warehouseId));
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.featWarehouses)),
      body: warehouse.when(
        data: (w) => _WarehouseBody(warehouse: w),
        loading: () => LoadingView(message: l10n.loading),
        error: (error, _) => ErrorStateView(
          message: '$error',
          onRetry: () => ref.invalidate(warehouseDetailProvider(warehouseId)),
        ),
      ),
    );
  }
}

class _WarehouseBody extends StatelessWidget {
  const _WarehouseBody({required this.warehouse});

  final Warehouse warehouse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final status = WarehouseStatusUi.of(l10n, warehouse);
    final locations = warehouse.locationsCount;
    final users = warehouse.usersCount;
    final address = warehouse.fullAddress;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusAvatar(tone: status.tone, icon: status.icon),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            warehouse.name,
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            warehouse.displayCode,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontFamily: 'FiraCode',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    StatusPill(
                      tone: status.tone,
                      label: status.label,
                      icon: status.icon,
                    ),
                    if (warehouse.isDefault)
                      StatusPill(
                        tone: StatusTone.info,
                        label: l10n.warehouseDefault,
                        icon: Icons.star_outline,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                _InfoRow(
                  label: l10n.fieldAddress,
                  value: address.isEmpty ? '—' : address,
                ),
                _InfoRow(label: l10n.fieldPhone, value: warehouse.phone ?? '—'),
                _InfoRow(label: l10n.email, value: warehouse.email ?? '—'),
                _InfoRow(
                    label: l10n.fieldManager, value: warehouse.managerName ?? '—'),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                _InfoRow(
                  label: l10n.fieldLocations,
                  value: locations != null ? '$locations' : '—',
                ),
                _InfoRow(
                  label: l10n.fieldUsers,
                  value: users != null ? '$users' : '—',
                ),
                _InfoRow(label: l10n.fieldTimezone, value: warehouse.timezone ?? '—'),
                _InfoRow(label: l10n.fieldCurrency, value: warehouse.currency ?? '—'),
                _InfoRow(label: l10n.fieldPriority, value: '${warehouse.priority}'),
                _InfoRow(
                  label: l10n.fieldStatus,
                  value: warehouse.isActive
                      ? l10n.statusActive
                      : l10n.statusInactive,
                ),
              ],
            ),
          ),
        ),
        if (warehouse.description != null &&
            warehouse.description!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.fieldDescription,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(warehouse.description!,
                      style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
