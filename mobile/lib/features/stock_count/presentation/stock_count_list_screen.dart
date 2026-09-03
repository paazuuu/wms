import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../application/stock_audit_providers.dart';
import '../domain/stock_audit.dart';
import 'stock_audit_status_ui.dart';
import 'stock_audit_view_screen.dart';

/// Browse stock counts (cycle counts / audits) across all statuses. Read-only:
/// tapping a count opens a view of its counted lines and discrepancies.
class StockCountListScreen extends ConsumerWidget {
  const StockCountListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(stockAuditListProvider(''));
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.featStockCount)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(stockAuditListProvider('')),
        child: results.when(
          data: (items) => items.isEmpty
              ? EmptyStateView(
                  icon: Icons.checklist_outlined,
                  title: l10n.emptyStockCounts,
                  message: l10n.stockCountsEmptyBody,
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) =>
                      _StockAuditCard(audit: items[index]),
                ),
          loading: () => LoadingView(message: l10n.loading),
          error: (error, _) => ErrorStateView(
            message: '$error',
            onRetry: () => ref.invalidate(stockAuditListProvider('')),
          ),
        ),
      ),
    );
  }
}

class _StockAuditCard extends StatelessWidget {
  const _StockAuditCard({required this.audit});

  final StockAudit audit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final status = StockAuditStatusUi.of(l10n, audit);
    final subtitle = audit.name?.trim().isNotEmpty == true
        ? audit.name!
        : (audit.locationName ?? l10n.allLocations);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StockAuditViewScreen(stockAuditId: audit.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              StatusAvatar(tone: status.tone, icon: status.icon),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      audit.auditNumber,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontFamily: 'FiraCode'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        StatusPill(
                          tone: status.tone,
                          label: status.label,
                          icon: status.icon,
                          dense: true,
                        ),
                        if (audit.itemsCount != null)
                          StatusPill(
                            tone: StatusTone.neutral,
                            label: l10n.lineCount(audit.itemsCount!),
                            icon: Icons.list_alt_outlined,
                            dense: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
