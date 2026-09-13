import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../audit/presentation/entity_audit_timeline.dart';
import '../application/work_order_providers.dart';
import '../domain/work_order.dart';
import 'work_order_status_ui.dart';

/// One work order, driven through its state machine one step at a time:
/// draft → start → complete (or cancel before anything moved). Completing
/// is the only step that moves stock — every component's required quantity
/// leaves, the output quantity arrives, both on the existing ledger.
class WorkOrderDetailScreen extends ConsumerWidget {
  const WorkOrderDetailScreen({super.key, required this.workOrderId});

  final int workOrderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(workOrderDetailProvider(workOrderId));

    return Scaffold(
      appBar: AppBar(
        title: Text(async.valueOrNull?.woNumber ?? l10n.woTitle),
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(workOrderDetailProvider(workOrderId)),
        ),
        data: (order) => _Body(order: order),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.order});

  final WorkOrder order;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _busy = false;

  WorkOrder get _order => widget.order;

  void _snack(String message, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: danger ? Theme.of(context).colorScheme.error : null,
      ));
  }

  void _refresh() {
    ref.invalidate(workOrderDetailProvider(_order.id));
    ref.invalidate(workOrderListProvider);
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _run(Future<ApiResult<bool>> Function() action,
      {String? successMessage}) async {
    setState(() => _busy = true);
    final result = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) {
        _refresh();
        if (successMessage != null) _snack(successMessage);
      },
      failure: (f) => _snack(f.message, danger: true),
    );
  }

  Future<void> _start() async {
    final l10n = AppLocalizations.of(context);
    await _run(() => ref.read(workOrderRepositoryProvider).start(_order.id),
        successMessage: l10n.woStarted);
  }

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(l10n.woCancelAction, l10n.woCancelBody, l10n.woCancelAction)) return;
    await _run(() => ref.read(workOrderRepositoryProvider).cancel(_order.id),
        successMessage: l10n.woCancelled);
  }

  Future<void> _complete() async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(l10n.woComplete, l10n.woCompleteQ, l10n.woComplete)) return;
    await _run(() => ref.read(workOrderRepositoryProvider).complete(_order.id),
        successMessage: l10n.woCompleted);
  }

  Widget? _primaryAction(AppLocalizations l10n) {
    switch (_order.status) {
      case WorkOrderStatus.draft:
        return FilledButton.icon(
          onPressed: _busy ? null : _start,
          icon: const Icon(Icons.play_arrow_outlined),
          label: Text(l10n.woStart),
        );
      case WorkOrderStatus.inProgress:
        return FilledButton.icon(
          onPressed: _busy ? null : _complete,
          icon: const Icon(Icons.task_alt),
          label: Text(l10n.woComplete),
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ui = WorkOrderStatusUi.of(l10n, _order.status);
    final primary = _primaryAction(l10n);
    final outputTitle = _order.outputProductName.isNotEmpty
        ? _order.outputProductName
        : _order.outputJanCode;

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: theme.colorScheme.surfaceContainerLow,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusPill(tone: ui.tone, label: ui.label, icon: ui.icon),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '$outputTitle × ${_order.outputQuantity}',
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _order.warehouseName ?? '#${_order.warehouseId}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Expanded(
          child: _order.components.isEmpty
              ? EmptyStateView(
                  icon: Icons.precision_manufacturing_outlined, title: l10n.woEmpty)
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  // One extra row at the end for the activity timeline.
                  itemCount: _order.components.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    if (i == _order.components.length) {
                      return EntityAuditTimeline(
                        entityType: 'work_order',
                        entityId: '${_order.id}',
                      );
                    }
                    return _ComponentCard(component: _order.components[i]);
                  },
                ),
        ),
        if (primary != null || _order.canCancel)
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border:
                  Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    if (_order.canCancel)
                      SizedBox(
                        height: AppSpacing.minTouch,
                        child: OutlinedButton(
                          onPressed: _busy ? null : _cancel,
                          child: Text(l10n.woCancelAction),
                        ),
                      ),
                    if (primary != null) ...[
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: SizedBox(height: AppSpacing.minTouch, child: primary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ComponentCard extends StatelessWidget {
  const _ComponentCard({required this.component});

  final WorkOrderComponent component;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final title = component.productName.isNotEmpty ? component.productName : component.janCode;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(component.janCode,
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: AppFonts.mono, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(l10n.woComponentQuantity,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                Text('${component.quantityRequired}',
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: AppFonts.mono, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
