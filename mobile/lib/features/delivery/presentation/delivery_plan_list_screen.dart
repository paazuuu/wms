import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/scan/scan_field.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../application/delivery_providers.dart';
import '../domain/delivery_plan.dart';
import 'delivery_status_ui.dart';
import 'reconciliation_screen.dart';

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

  bool _matches(DeliveryPlan plan) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return plan.deliveryNumber.toLowerCase().contains(q) ||
        (plan.supplierName?.toLowerCase().contains(q) ?? false) ||
        (plan.supplierCode?.toLowerCase().contains(q) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plans = ref.watch(deliveryPlansProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.deliveryPlansTitle)),
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
