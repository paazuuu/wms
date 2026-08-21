import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../application/location_providers.dart';
import '../domain/location.dart';
import 'location_status_ui.dart';

/// Read-only location detail: identity, active state, and structure (aisle /
/// shelf / bin) plus how many products are assigned.
class LocationDetailScreen extends ConsumerWidget {
  const LocationDetailScreen({super.key, required this.locationId});

  final int locationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(locationDetailProvider(locationId));

    return Scaffold(
      appBar: AppBar(title: const Text('Location')),
      body: location.when(
        data: (l) => _LocationBody(location: l),
        loading: () => const LoadingView(message: 'Loading location…'),
        error: (error, _) => ErrorStateView(
          message: '$error',
          onRetry: () => ref.invalidate(locationDetailProvider(locationId)),
        ),
      ),
    );
  }
}

class _LocationBody extends StatelessWidget {
  const _LocationBody({required this.location});

  final Location location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = LocationStatusUi.of(AppLocalizations.of(context), location);
    final count = location.productsCount;

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
                            location.name,
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            location.displayCode,
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
                    if (count != null)
                      StatusPill(
                        tone: StatusTone.info,
                        label: '$count ${count == 1 ? 'item' : 'items'}',
                        icon: Icons.inventory_2_outlined,
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
                _InfoRow(label: 'Code', value: location.code ?? '—', mono: true),
                _InfoRow(label: 'Aisle', value: location.aisle ?? '—'),
                _InfoRow(label: 'Shelf', value: location.shelf ?? '—'),
                _InfoRow(label: 'Bin', value: location.bin ?? '—'),
                _InfoRow(
                  label: 'Full location',
                  value: location.fullLocation ?? '—',
                  mono: true,
                ),
                _InfoRow(
                  label: 'Products',
                  value: count != null ? '$count' : '—',
                ),
                _InfoRow(
                  label: 'Status',
                  value: location.isActive ? 'Active' : 'Inactive',
                ),
              ],
            ),
          ),
        ),
        if (location.description != null &&
            location.description!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(location.description!, style: theme.textTheme.bodyMedium),
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
  const _InfoRow({required this.label, required this.value, this.mono = false});

  final String label;
  final String value;
  final bool mono;

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
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: mono ? 'FiraCode' : null,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
