import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/export/csv_export.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/audit_providers.dart';
import '../domain/audit_entry.dart';

/// The audit trail (spec §33): every approval, rejection, cancellation and
/// completion any mutating RPC has logged, newest first. Filterable by event
/// type and exportable as CSV.
class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final entries = ref.read(auditListProvider).valueOrNull ?? const [];
    final fmt = DateFormat('yyyy-MM-dd HH:mm:ss');
    try {
      final path = await exportCsv(
        fileName: 'audit_log.csv',
        headers: const [
          'id',
          'created_at',
          'event_type',
          'entity_type',
          'entity_id',
          'warehouse_name',
          'actor_user_id',
          'details',
        ],
        rows: [
          for (final e in entries)
            [
              e.id,
              e.createdAt == null ? '' : fmt.format(e.createdAt!),
              e.eventType,
              e.entityType ?? '',
              e.entityId ?? '',
              e.warehouseName ?? '',
              e.actorUserId ?? '',
              e.details.isEmpty ? '' : e.details.toString(),
            ],
        ],
      );
      if (!context.mounted) return;
      if (path != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.auditExported)));
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(l10n.auditExportFailed),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(auditListProvider);
    final types = ref.watch(auditEventTypesProvider).valueOrNull ?? const [];
    final active = ref.watch(auditEventTypeFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.auditTitle),
        actions: [
          IconButton(
            tooltip: l10n.auditExport,
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => _export(context, ref),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Column(
        children: [
          if (types.isNotEmpty)
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                children: [
                  for (final t in [null, ...types]) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: Center(
                        child: FilterChip(
                          selected: active == t,
                          label: Text(t ?? l10n.filterAll),
                          onSelected: (_) => ref
                              .read(auditEventTypeFilterProvider.notifier)
                              .state = t,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Expanded(
            child: async.when(
              loading: () => LoadingView(message: l10n.loading),
              error: (e, _) => ErrorStateView(
                message: '$e',
                onRetry: () => ref.invalidate(auditListProvider),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.history_outlined,
                    title: l10n.auditEmpty,
                    message: l10n.auditEmptyBody,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(auditListProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: list.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) => _AuditCard(entry: list[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditCard extends StatelessWidget {
  const _AuditCard({required this.entry});

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final fmt = DateFormat('M/d HH:mm');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.eventType,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontFamily: AppFonts.mono),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (entry.createdAt != null)
                  Text(
                    fmt.format(entry.createdAt!),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
            if (entry.entityType != null) ...[
              const SizedBox(height: 4),
              Text(
                '${l10n.auditEntity}: ${entry.entityType}'
                '${entry.entityId != null ? ' #${entry.entityId}' : ''}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              '${l10n.auditActor}: ${entry.actorUserId ?? l10n.auditActorSystem}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
