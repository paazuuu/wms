import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/product_providers.dart';
import '../domain/data_quality.dart';

/// The worklist for registering master data (`unlinked_jan_codes` +
/// `product_id_coverage`, 0058): every JAN code in use somewhere in the
/// system that no product accounts for, worst (most rows) first. Once a
/// product is registered for a code, the history already using it links
/// itself — this screen exists to say which code to register next.
class UnlinkedJanScreen extends ConsumerWidget {
  const UnlinkedJanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(unlinkedJanCodesProvider);
    final coverage = ref.watch(productIdCoverageProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.unlinkedJanTitle)),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(unlinkedJanCodesProvider),
        ),
        data: (rows) => rows.isEmpty
            ? EmptyStateView(
                icon: Icons.link_outlined,
                title: l10n.unlinkedJanEmpty,
                message: l10n.unlinkedJanEmptyBody,
              )
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(unlinkedJanCodesProvider);
                  ref.invalidate(productIdCoverageProvider);
                },
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    if (coverage != null) ...[
                      _CoverageBar(coverage: coverage),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    for (final row in rows) ...[
                      _UnlinkedJanCard(row: row),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _CoverageBar extends StatelessWidget {
  const _CoverageBar({required this.coverage});

  final ProductIdCoverage coverage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      color:
          coverage.readyToSwitch ? null : scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(
              coverage.readyToSwitch
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
              color: coverage.readyToSwitch ? scheme.primary : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                coverage.readyToSwitch
                    ? l10n.unlinkedJanReady
                    : l10n.unlinkedJanCoverage(coverage.linked, coverage.rows),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnlinkedJanCard extends StatelessWidget {
  const _UnlinkedJanCard({required this.row});

  final UnlinkedJan row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(row.janCode,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontFamily: AppFonts.mono)),
                ),
                Text(l10n.unlinkedJanRows(row.totalRows),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              row.seenAs ?? l10n.unlinkedJanSeenAsUnknown,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontStyle: row.seenAs == null ? FontStyle.italic : null,
              ),
            ),
            if (row.sources.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: 2,
                children: [
                  for (final entry in row.sources.entries)
                    Text('${entry.key}: ${entry.value}',
                        style: theme.textTheme.labelSmall?.copyWith(
                            fontFamily: AppFonts.mono,
                            color: scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
