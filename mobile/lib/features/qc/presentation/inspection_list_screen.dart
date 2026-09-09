import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../application/inspection_providers.dart';
import '../domain/inspection.dart';
import 'inspection_detail_screen.dart';
import 'qc_result_ui.dart';

/// Inbound inspections for the active warehouse, newest first, filterable by
/// outcome so an operator can jump straight to what still needs checking.
class QcInspectionListScreen extends ConsumerWidget {
  const QcInspectionListScreen({super.key});

  static const _filters = <String?>[
    null,
    'PENDING',
    'PARTIAL',
    'FAIL',
    'HOLD',
    'PASS',
  ];

  String _filterLabel(AppLocalizations l10n, String? status) => switch (status) {
        null => l10n.filterAll,
        'PENDING' => l10n.qcResultPending,
        'PASS' => l10n.qcResultPass,
        'FAIL' => l10n.qcResultFail,
        'PARTIAL' => l10n.qcResultPartial,
        'HOLD' => l10n.qcResultHold,
        _ => status,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(inspectionListProvider);
    final active = ref.watch(inspectionStatusFilterProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.qcTitle)),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                for (final f in _filters) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: Center(
                      child: FilterChip(
                        selected: active == f,
                        label: Text(_filterLabel(l10n, f)),
                        onSelected: (_) => ref
                            .read(inspectionStatusFilterProvider.notifier)
                            .state = f,
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
                onRetry: () => ref.invalidate(inspectionListProvider),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.fact_check_outlined,
                    title: l10n.qcListEmpty,
                    message: l10n.qcListEmptyBody,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(inspectionListProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: list.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) =>
                        _InspectionCard(inspection: list[i]),
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

class _InspectionCard extends StatelessWidget {
  const _InspectionCard({required this.inspection});

  final Inspection inspection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final ui = QcResultUi.of(l10n, inspection.status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              InspectionDetailScreen(inspectionId: inspection.id),
        )),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              StatusAvatar(tone: ui.tone, icon: ui.icon),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inspection.deliveryNumber ?? '#${inspection.id}',
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      inspection.supplierName ?? '',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusPill(tone: ui.tone, label: ui.label, dense: true),
                  const SizedBox(height: 4),
                  Text(
                    l10n.lineCount(inspection.lineCount),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
