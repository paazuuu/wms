import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../application/report_providers.dart';
import '../domain/report_result.dart';

/// Executes a saved report and renders its rows as a horizontally-scrollable
/// table. Read-only.
class ReportResultScreen extends ConsumerWidget {
  const ReportResultScreen({super.key, required this.reportId});

  final int reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final result = ref.watch(reportResultProvider(reportId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.report)),
      body: result.when(
        data: (r) => _ReportBody(result: r),
        loading: () => LoadingView(message: l10n.runningReport),
        error: (error, _) => ErrorStateView(
          message: '$error',
          onRetry: () => ref.invalidate(reportResultProvider(reportId)),
        ),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.result});

  final ReportResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.name, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                l10n.rowCount(result.total),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: result.columns.isEmpty || result.rows.isEmpty
              ? EmptyStateView(
                  icon: Icons.table_chart_outlined,
                  title: l10n.noData,
                  message: l10n.reportNoRows,
                )
              : _ReportTable(result: result),
        ),
      ],
    );
  }
}

class _ReportTable extends StatelessWidget {
  const _ReportTable({required this.result});

  final ReportResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: DataTable(
          columns: [
            for (final column in result.columns)
              DataColumn(
                label: Text(
                  result.labelFor(column),
                  style: theme.textTheme.labelLarge,
                ),
              ),
          ],
          rows: [
            for (final row in result.rows)
              DataRow(
                cells: [
                  for (final column in result.columns)
                    DataCell(Text(result.cell(row, column))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
