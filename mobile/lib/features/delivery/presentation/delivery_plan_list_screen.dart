import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/scan/scan_field.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../application/delivery_providers.dart';
import '../domain/delivery_plan.dart';
import '../domain/delivery_plan_status.dart';
import 'delivery_status_ui.dart';
import 'plan_import_screen.dart';
import 'reconciliation_screen.dart';
import 'stock_list_screen.dart';

/// Lists delivery plans imported from suppliers' Excel that still need a
/// physical check. A scan/search box at the top filters by voucher number or
/// supplier so a handheld can jump straight to the right plan.
class DeliveryPlanListScreen extends ConsumerStatefulWidget {
  const DeliveryPlanListScreen({super.key});

  @override
  ConsumerState<DeliveryPlanListScreen> createState() =>
      _DeliveryPlanListScreenState();
}

class _DeliveryPlanListScreenState
    extends ConsumerState<DeliveryPlanListScreen> {
  String _query = '';

  /// null = all statuses; otherwise only this status.
  DeliveryPlanStatus? _statusFilter;

  /// Show only plans that still need a manual company check.
  bool _reviewOnly = false;

  bool _matchesSearch(DeliveryPlan plan) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return plan.deliveryNumber.toLowerCase().contains(q) ||
        (plan.supplierName?.toLowerCase().contains(q) ?? false) ||
        (plan.supplierCode?.toLowerCase().contains(q) ?? false);
  }

  bool _matches(DeliveryPlan plan) {
    if (!_matchesSearch(plan)) return false;
    if (_reviewOnly && !plan.needsReview) return false;
    if (_statusFilter != null && plan.status != _statusFilter) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plans = ref.watch(deliveryPlansProvider);
    final showCompleted = ref.watch(showCompletedPlansProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.deliveryPlansTitle),
        actions: [
          IconButton(
            tooltip:
                showCompleted ? l10n.hideCompletedPlans : l10n.showCompletedPlans,
            isSelected: showCompleted,
            icon: const Icon(Icons.history_toggle_off),
            selectedIcon: const Icon(Icons.manage_history),
            onPressed: () => ref
                .read(showCompletedPlansProvider.notifier)
                .update((v) => !v),
          ),
          IconButton(
            tooltip: l10n.totalStockTitle,
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StockListScreen()),
            ),
          ),
          IconButton(
            tooltip: l10n.planImportTitle,
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PlanImportScreen()),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            child: ScanField(
              autofocusOnWide: true,
              clearOnSubmit: false,
              hintText: l10n.deliveryPlansHint,
              onSubmitted: (value) => setState(() => _query = value),
            ),
          ),
          if ((plans.valueOrNull?.length ?? 0) > 0)
            _FilterBar(
              items: plans.value!,
              statusFilter: _statusFilter,
              reviewOnly: _reviewOnly,
              onStatus: (s) => setState(() {
                _statusFilter = s;
                _reviewOnly = false;
              }),
              onReview: () => setState(() {
                _reviewOnly = !_reviewOnly;
                _statusFilter = null;
              }),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(deliveryPlansProvider),
              child: plans.when(
                data: (items) {
                  final filtered = items.where(_matches).toList();
                  if (items.isEmpty) {
                    return _ScrollableEmpty(
                      icon: Icons.inventory_2_outlined,
                      title: l10n.deliveryPlansEmpty,
                      message: l10n.deliveryPlansEmptyBody,
                    );
                  }
                  if (filtered.isEmpty) {
                    return _ScrollableEmpty(
                      icon: Icons.search_off,
                      title: l10n.deliveryNoMatches,
                      message: l10n.deliverySearchTip,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) =>
                        _DeliveryPlanCard(plan: filtered[index]),
                  );
                },
                loading: () => LoadingView(message: l10n.loading),
                error: (error, _) => ErrorStateView(
                  message: '$error',
                  onRetry: () => ref.invalidate(deliveryPlansProvider),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal status filter for the plan list. Only shows chips for statuses
/// actually present in [items], plus a "needs check" chip when any plan is
/// flagged, so it stays uncluttered.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.items,
    required this.statusFilter,
    required this.reviewOnly,
    required this.onStatus,
    required this.onReview,
  });

  final List<DeliveryPlan> items;
  final DeliveryPlanStatus? statusFilter;
  final bool reviewOnly;
  final ValueChanged<DeliveryPlanStatus?> onStatus;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Preserve a sensible order and only show statuses that occur.
    const order = [
      DeliveryPlanStatus.open,
      DeliveryPlanStatus.reconciling,
      DeliveryPlanStatus.partial,
      DeliveryPlanStatus.completed,
    ];
    final present = order.where((s) => items.any((p) => p.status == s)).toList();
    final hasReview = items.any((p) => p.needsReview);

    String label(DeliveryPlanStatus s) => switch (s) {
          DeliveryPlanStatus.open => l10n.deliveryStatusOpen,
          DeliveryPlanStatus.reconciling => l10n.deliveryStatusReconciling,
          DeliveryPlanStatus.partial => l10n.deliveryStatusPartial,
          DeliveryPlanStatus.completed => l10n.deliveryStatusCompleted,
        };

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          ChoiceChip(
            label: Text(l10n.filterAll),
            selected: statusFilter == null && !reviewOnly,
            onSelected: (_) => onStatus(null),
          ),
          for (final s in present) ...[
            const SizedBox(width: AppSpacing.sm),
            ChoiceChip(
              label: Text(label(s)),
              selected: statusFilter == s && !reviewOnly,
              onSelected: (_) => onStatus(s),
            ),
          ],
          if (hasReview) ...[
            const SizedBox(width: AppSpacing.sm),
            FilterChip(
              avatar: Icon(Icons.help_outline,
                  size: 16, color: Theme.of(context).colorScheme.error),
              label: Text(l10n.planNeedsReviewBadge),
              selected: reviewOnly,
              onSelected: (_) => onReview(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Empty/no-match state that still scrolls, so pull-to-refresh keeps working.
class _ScrollableEmpty extends StatelessWidget {
  const _ScrollableEmpty({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: EmptyStateView(icon: icon, title: title, message: message),
        ),
      ],
    );
  }
}

class _DeliveryPlanCard extends StatelessWidget {
  const _DeliveryPlanCard({required this.plan});

  final DeliveryPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final status = DeliveryPlanStatusUi.of(l10n, plan.status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReconciliationScreen(planId: plan.id),
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
                      plan.deliveryNumber,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontFamily: 'FiraCode'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plan.supplierName ?? l10n.unknownSupplier,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (plan.referenceNo != null &&
                        plan.referenceNo!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${l10n.referenceNoLabel}: ${plan.referenceNo}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'FiraCode', color: scheme.primary),
                      ),
                    ],
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
                        StatusPill(
                          tone: StatusTone.neutral,
                          label: l10n.plannedLines(plan.lineCount),
                          icon: Icons.list_alt_outlined,
                          dense: true,
                        ),
                        if (plan.needsReview)
                          StatusPill(
                            tone: StatusTone.warning,
                            label: l10n.planNeedsReviewBadge,
                            icon: Icons.help_outline,
                            dense: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
