import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../application/putaway_providers.dart';
import '../domain/putaway_task.dart';
import 'putaway_confirm_sheet.dart';

/// 棚入れ (put-away) — the dedicated queue UI spec §13 calls the current
/// critical gap. Receiving raises the warehouse balance; this is where an
/// operator says *which shelf* each item actually went to, so stock becomes
/// findable rather than just "somewhere in the building".
///
/// Deliberately its own screen, not a step buried in receiving: §13's whole
/// point is that put-away is separate work, often done later and by someone
/// else, and it needs its own queue to pick up.
class PutawayQueueScreen extends ConsumerWidget {
  const PutawayQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(putawayQueueProvider);
    final warehouseId = ref.watch(writeWarehouseIdProvider);
    // Resolved from the write scope, not activeWarehouseProvider: with a single
    // warehouse the active id stays null while the write scope still resolves,
    // and we need that warehouse's uses_locations flag to explain an empty
    // queue correctly.
    final warehouse = warehouseId == null
        ? null
        : ref.watch(warehouseOverviewProvider).valueOrNull?.byId(warehouseId);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.putawayTitle)),
      body: warehouseId == null
          ? EmptyStateView(
              icon: Icons.warehouse_outlined,
              title: l10n.putawayNeedsWarehouse,
              message: l10n.putawayNeedsWarehouseBody,
            )
          : async.when(
              loading: () => LoadingView(message: l10n.loading),
              error: (e, _) => ErrorStateView(
                message: '$e',
                onRetry: () => ref.invalidate(putawayQueueProvider),
              ),
              data: (tasks) {
                if (tasks.isEmpty) {
                  // Two very different "nothing here" cases, and conflating
                  // them is what §33 warns about: locations switched off means
                  // put-away can never have work, which is a setup fact, not
                  // an empty day.
                  final locationsOff = warehouse != null && !warehouse.usesLocations;
                  return EmptyStateView(
                    icon: locationsOff
                        ? Icons.grid_off_outlined
                        : Icons.inventory_2_outlined,
                    title: locationsOff
                        ? l10n.putawayLocationsOff
                        : l10n.putawayEmpty,
                    message: locationsOff
                        ? l10n.putawayLocationsOffBody
                        : l10n.putawayEmptyBody,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(putawayQueueProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: tasks.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      if (i == 0) return _QueueHeader(count: tasks.length);
                      final task = tasks[i - 1];
                      return _PutawayTaskCard(
                        task: task,
                        onTap: () => _startPutaway(context, ref, task, warehouseId),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  Future<void> _startPutaway(
    BuildContext context,
    WidgetRef ref,
    PutawayTask task,
    int warehouseId,
  ) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PutawayConfirmSheet(task: task, warehouseId: warehouseId),
    );
    if (done == true) {
      ref.invalidate(putawayQueueProvider);
    }
  }
}

class _QueueHeader extends StatelessWidget {
  const _QueueHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          StatusPill(
            tone: StatusTone.warning,
            label: l10n.putawayPendingCount(count),
            icon: Icons.move_to_inbox_outlined,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n.putawayQueueHint,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _PutawayTaskCard extends StatelessWidget {
  const _PutawayTaskCard({required this.task, required this.onTap});

  final PutawayTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(task.title,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(task.janCode,
                            style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: AppFonts.mono,
                                color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // The number the operator is about to shelve, big and
                  // monospaced — §39's "quantities in a monospace font".
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${task.pendingQuantity}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                              fontFamily: AppFonts.mono,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary)),
                      Text(l10n.putawayPendingLabel,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(Icons.place_outlined, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    task.suggestedBinCode == null
                        ? l10n.putawayNoSuggestion
                        : l10n.putawaySuggested(task.suggestedBinCode!),
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: task.suggestedBinCode == null
                            ? null
                            : AppFonts.mono,
                        color: scheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                ],
              ),
              if (task.binnedQuantity > 0) ...[
                const SizedBox(height: 2),
                Text(
                  l10n.putawayAlreadyBinned(task.binnedQuantity, task.warehouseOnHand),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
