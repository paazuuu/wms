import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../application/inspection_providers.dart';
import '../domain/inspection.dart';
import 'bulk_inspection_screen.dart';
import 'inspection_detail_screen.dart';
import 'qc_result_ui.dart';
import '../../../core/offline/pending_sync_banner.dart';
import '../data/offline_inspection_repository.dart';
import '../../home/presentation/feature_link.dart';
import '../../stock_import/data/stock_import_repository.dart' show awaitingImportsProvider;
import '../../stock_import/presentation/stock_inspection_screen.dart';
import '../../warehouse_context/application/warehouse_providers.dart';

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
      appBar: AppBar(
        title: Text(l10n.qcTitle),
        actions: [
          IconButton(
            key: const ValueKey('qc-open-bulk'),
            tooltip: l10n.bulkQcTitle,
            icon: const Icon(Icons.done_all),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BulkInspectionScreen()),
            ),
          ),
          const FeatureLinkButton('held_stock'),
        ],
      ),
      body: Column(
        children: [
          // A weak connection: what waits on the device, and a way to send it.
          PendingSyncBanner(onSync: () async {
          final repo = ref.read(inspectionRepositoryProvider);
          final sent = repo is OfflineInspectionRepository ? await repo.flush() : 0;
          ref.invalidate(inspectionListProvider);
          return sent;
        }),
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
          // Stock read in from files waits here too (0148), not only in 取込の検品.
          if (active == null || active == 'PENDING') const StockFileWaiting(),
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

/// Stock files waiting for inspection, for the warehouse in view: the first
/// few, each opening its lines to count, and a way to all of them.
class StockFileWaiting extends ConsumerWidget {
  const StockFileWaiting({super.key});

  static const shown = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final warehouseId = ref.watch(activeWarehouseIdProvider);
    final all = ref.watch(awaitingImportsProvider).valueOrNull ?? const [];
    final items = [for (final a in all) if (warehouseId == null || a.warehouseId == warehouseId) a];
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('qc-file-waiting'),
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.pending_actions_outlined, size: 18, color: scheme.tertiary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(l10n.qcFileWaiting(items.length), style: theme.textTheme.titleSmall)),
          if (items.length > shown)
            TextButton(
              key: const ValueKey('qc-file-waiting-all'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StockInspectionScreen())),
              child: Text(l10n.qcFileWaitingAll(items.length)),
            ),
        ]),
        Text(l10n.qcFileWaitingHint, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.xs),
        for (final a in items.take(shown))
          Card(
            key: ValueKey('qc-file-${a.id}'),
            margin: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: ListTile(
              dense: true,
              leading: const StatusAvatar(tone: StatusTone.warning, icon: Icons.pending_actions_outlined),
              title: Text(l10n.siFile(a.id, a.fileName ?? ''), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text([
                if (a.warehouseName case final w?) w,
                l10n.siLeft(a.left, a.lines, a.quantityLeft),
              ].join(' · ')),
              trailing: StatusPill(tone: StatusTone.warning, label: l10n.qcFileBadge, dense: true),
              onTap: () async {
                await Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => StockInspectionDetailScreen(importId: a.id)));
                ref.invalidate(awaitingImportsProvider);
              },
            ),
          ),
      ]),
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
