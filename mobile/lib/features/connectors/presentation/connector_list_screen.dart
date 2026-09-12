import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/connector_providers.dart';
import '../domain/connector.dart';

/// The connector/adapter registry (spec §34) — external systems registered
/// for future integration. Anyone can open this screen; the server is the
/// real gate (`connector.manage`), same as user management. Deliberately a
/// skeleton: registering and enabling a connector here records intent only —
/// no adapter runs yet, so this never claims a sync happened.
class ConnectorListScreen extends ConsumerWidget {
  const ConnectorListScreen({super.key});

  void _snackError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
  }

  Future<void> _toggle(
      BuildContext context, WidgetRef ref, Connector connector, bool value) async {
    final result = await ref
        .read(connectorRepositoryProvider)
        .setEnabled(connector.code, value);
    if (!context.mounted) return;
    result.when(
      success: (_) => ref.invalidate(connectorListProvider),
      failure: (f) => _snackError(context, f.message),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(connectorListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.connectorsTitle)),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(connectorListProvider),
        ),
        data: (connectors) {
          if (connectors.isEmpty) {
            return EmptyStateView(
              icon: Icons.hub_outlined,
              title: l10n.connectorsEmpty,
              message: l10n.connectorsEmptyBody,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(connectorListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: connectors.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) => _ConnectorCard(
                connector: connectors[i],
                onToggle: (value) => _toggle(context, ref, connectors[i], value),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ConnectorCard extends StatelessWidget {
  const _ConnectorCard({required this.connector, required this.onToggle});

  final Connector connector;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final lastRun = connector.lastRun;
    final fmt = DateFormat('yyyy-MM-dd HH:mm');

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
                  child: Icon(Icons.hub_outlined, size: 18, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(connector.name, style: theme.textTheme.titleSmall),
                      Text(
                        connector.kind,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Switch(value: connector.enabled, onChanged: onToggle),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              connector.enabled ? l10n.connectorEnabled : l10n.connectorDisabled,
              style: theme.textTheme.bodySmall?.copyWith(
                color: connector.enabled ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              lastRun == null
                  ? l10n.connectorNeverRun
                  : '${lastRun.status} · ${lastRun.startedAt != null ? fmt.format(lastRun.startedAt!) : ''}',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (connector.note != null && connector.note!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                connector.note!,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l10n.connectorNoAdapterYet,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
