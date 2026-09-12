import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/ai_review_providers.dart';
import '../domain/ai_analysis_entry.dart';

/// Human review of recorded AI results (spec §31) — the missing half of
/// 0026's `ai_analysis` store. AI never commits data directly
/// (docs/ai_architecture.md §1): every result sits here PENDING_REVIEW until
/// a person confirms or rejects it. Confirming/rejecting only updates the
/// `ai_analysis` row itself — it does not retroactively touch whatever
/// screen originally used the extracted lines (e.g. a delivery-note import
/// already completed with them); this is a record of "was this AI call
/// trustworthy", not an undo for what was done with it.
class AiReviewListScreen extends ConsumerWidget {
  const AiReviewListScreen({super.key});

  void _snackError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref, AiAnalysisEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final result = await ref.read(aiReviewRepositoryProvider).confirm(entry.id);
    if (!context.mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(aiReviewPendingListProvider);
        _snack(context, l10n.aiReviewConfirmed);
      },
      failure: (f) => _snackError(context, f.message),
    );
  }

  Future<void> _reject(BuildContext context, WidgetRef ref, AiAnalysisEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.aiReviewRejectTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: l10n.aiReviewRejectHint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.aiReviewReject),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final reason = controller.text.trim();
    final result = await ref
        .read(aiReviewRepositoryProvider)
        .reject(entry.id, reason: reason.isEmpty ? null : reason);
    if (!context.mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(aiReviewPendingListProvider);
        _snack(context, l10n.aiReviewRejected);
      },
      failure: (f) => _snackError(context, f.message),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(aiReviewPendingListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aiReviewTitle)),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(aiReviewPendingListProvider),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return EmptyStateView(
              icon: Icons.fact_check_outlined,
              title: l10n.aiReviewEmpty,
              message: l10n.aiReviewEmptyBody,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(aiReviewPendingListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) => _AnalysisCard(
                entry: entries[i],
                onConfirm: () => _confirm(context, ref, entries[i]),
                onReject: () => _reject(context, ref, entries[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({
    required this.entry,
    required this.onConfirm,
    required this.onReject,
  });

  final AiAnalysisEntry entry;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final fmt = DateFormat('yyyy-MM-dd HH:mm');

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
                    entry.taskType,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontFamily: AppFonts.mono),
                  ),
                ),
                Text(
                  fmt.format(entry.createdAt),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${entry.provider}${entry.model != null ? ' · ${entry.model}' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.aiReviewLinesCount(entry.lines.length),
              style: theme.textTheme.bodySmall,
            ),
            if (entry.lines.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              ...entry.lines.take(5).map((line) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '${line.janCode}'
                      '${line.productName != null && line.productName!.isNotEmpty ? '  ${line.productName}' : ''}'
                      '${line.quantity != null ? '  ×${line.quantity}' : ''}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontFamily: AppFonts.mono),
                    ),
                  )),
              if (entry.lines.length > 5)
                Text(
                  '+${entry.lines.length - 5}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(onPressed: onReject, child: Text(l10n.aiReviewReject)),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(onPressed: onConfirm, child: Text(l10n.aiReviewConfirm)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
