import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../application/report_providers.dart';
import '../domain/saved_report.dart';
import 'report_result_screen.dart';

/// Browse saved reports (own + shared). Tapping a report executes it and shows
/// the resulting rows.
class ReportListScreen extends ConsumerWidget {
  const ReportListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(reportListProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.featReports)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(reportListProvider),
        child: results.when(
          data: (items) => items.isEmpty
              ? EmptyStateView(
                  icon: Icons.assessment_outlined,
                  title: l10n.emptyReports,
                  message: l10n.reportsEmptyBody,
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) =>
                      _ReportCard(report: items[index]),
                ),
          loading: () => LoadingView(message: l10n.loading),
          error: (error, _) => ErrorStateView(
            message: '$error',
            onRetry: () => ref.invalidate(reportListProvider),
          ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final SavedReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final subtitle = report.description?.trim().isNotEmpty == true
        ? report.description!
        : (report.dataSource ?? l10n.customReport);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReportResultScreen(reportId: report.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              const StatusAvatar(
                  tone: StatusTone.info, icon: Icons.assessment_outlined),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.name,
                      style: theme.textTheme.titleMedium,
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
                          tone: StatusTone.neutral,
                          label: l10n.columnCount(report.columnsCount),
                          icon: Icons.view_column_outlined,
                          dense: true,
                        ),
                        if (report.isShared)
                          StatusPill(
                            tone: StatusTone.info,
                            label: l10n.reportShared,
                            icon: Icons.groups_outlined,
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
