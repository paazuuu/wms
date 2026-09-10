import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../application/audit_providers.dart';

/// A compact "what happened to this record" timeline (spec §40) for a
/// document's own detail screen — the same events the Audit Log screen shows
/// company-wide, scoped down to one entity. Renders nothing while loading or
/// on a load error rather than displacing the screen's primary content; the
/// full Audit Log screen is always the fallback for a deeper look.
class EntityAuditTimeline extends ConsumerWidget {
  const EntityAuditTimeline({
    super.key,
    required this.entityType,
    required this.entityId,
  });

  final String entityType;
  final String entityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(entityAuditProvider((entityType, entityId)));
    final entries = async.valueOrNull;
    if (entries == null || entries.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final fmt = DateFormat('M/d HH:mm');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Text(l10n.auditTitle, style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < entries.length; i++)
              Padding(
                padding: EdgeInsets.only(
                    bottom: i == entries.length - 1 ? 0 : AppSpacing.md),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == 0
                                  ? scheme.primary
                                  : scheme.outlineVariant,
                            ),
                          ),
                          if (i != entries.length - 1)
                            Expanded(
                              child: Container(
                                width: 1,
                                margin: const EdgeInsets.only(top: 4),
                                color: scheme.outlineVariant,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entries[i].eventType,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontFamily: AppFonts.mono),
                            ),
                            if (entries[i].createdAt != null)
                              Text(
                                fmt.format(entries[i].createdAt!),
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
