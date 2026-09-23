import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../audit/presentation/entity_audit_timeline.dart';
import '../../shipment/presentation/shipment_detail_screen.dart';
import '../application/sales_order_providers.dart';
import '../domain/sales_order.dart';
import 'sales_order_status_ui.dart';

/// One sales order, driven through its state machine one step at a time:
/// draft → submit → approve/reject → (cancel) → complete. Completing is a
/// bookkeeping close only — no stock moves here; fulfillment still goes
/// through the existing shipment-plan/picking/packing flow.
class SalesOrderDetailScreen extends ConsumerWidget {
  const SalesOrderDetailScreen({super.key, required this.salesOrderId});

  final int salesOrderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(salesOrderDetailProvider(salesOrderId));

    return Scaffold(
      appBar: AppBar(
        title: Text(async.valueOrNull?.soNumber ?? l10n.soTitle),
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(salesOrderDetailProvider(salesOrderId)),
        ),
        data: (order) => _Body(order: order),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.order});

  final SalesOrder order;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _busy = false;

  SalesOrder get _order => widget.order;

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
    ref.invalidate(salesOrderDetailProvider(_order.id));
    ref.invalidate(salesOrderListProvider);
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
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final result = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) {
        _refresh();
        if (successMessage != null) _snack(successMessage);
      },
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    await _run(() => ref.read(salesOrderRepositoryProvider).submit(_order.id),
        successMessage: l10n.soSubmitted);
  }

  Future<void> _approve() async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(l10n.soApprove, l10n.soApproveQ, l10n.soApprove)) return;

    setState(() => _busy = true);
    final result = await ref.read(salesOrderRepositoryProvider).approve(_order.id);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (approval) {
        _refresh();
        if (!approval.hasSkipped) {
          _snack(l10n.soApprovedWithReservations(approval.reservedLines));
          return;
        }
        // A shortfall is worth stopping for, not just noting: the approver
        // sees it now rather than a picker discovering it later.
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(l10n.soApprovedWithSkips(
                approval.reservedLines, approval.skipped.length)),
            action: SnackBarAction(
              label: l10n.soApprovalSkipDetail,
              onPressed: () => _showSkipped(approval.skipped),
            ),
          ));
      },
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  void _showSkipped(List<SalesOrderApprovalSkip> skipped) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.soSkippedLinesTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: skipped.length,
            separatorBuilder: (_, __) => const Divider(height: AppSpacing.lg),
            itemBuilder: (context, i) {
              final s = skipped[i];
              final reason = s.reason == 'insufficient_available'
                  ? l10n.soSkipInsufficientAvailable(
                      s.available ?? 0, s.requested ?? 0)
                  : l10n.soSkipUnlinkedJan;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.janCode,
                      style: const TextStyle(fontFamily: AppFonts.mono)),
                  const SizedBox(height: 2),
                  Text(reason),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.actionCancel),
          ),
        ],
      ),
    );
  }

  Future<void> _createShipment() async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(
        l10n.soCreateShipment, l10n.soCreateShipmentQ, l10n.soCreateShipment)) {
      return;
    }
    setState(() => _busy = true);
    final result =
        await ref.read(salesOrderRepositoryProvider).createShipment(_order.id);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (created) {
        _refresh();
        _snack(l10n.soShipmentCreated(created.lines));
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              ShipmentDetailScreen(shipmentId: created.shipmentPlanId),
        ));
      },
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  void _openShipment() {
    final id = _order.shipmentPlanId;
    if (id == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ShipmentDetailScreen(shipmentId: id),
    ));
  }

  Future<void> _reject() async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(l10n.soReject, l10n.soRejectQ, l10n.soReject)) return;
    await _run(() => ref.read(salesOrderRepositoryProvider).reject(_order.id),
        successMessage: l10n.soRejected);
  }

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(l10n.soCancelAction, l10n.soCancelBody, l10n.soCancelAction)) return;
    await _run(() => ref.read(salesOrderRepositoryProvider).cancel(_order.id),
        successMessage: l10n.soCancelled);
  }

  Future<void> _complete() async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(l10n.soComplete, l10n.soCompleteQ, l10n.soComplete)) return;
    await _run(() => ref.read(salesOrderRepositoryProvider).complete(_order.id),
        successMessage: l10n.soCompleted);
  }

  Widget? _primaryAction(AppLocalizations l10n) {
    switch (_order.status) {
      case SalesOrderStatus.draft:
        return FilledButton.icon(
          onPressed: _busy ? null : _submit,
          icon: const Icon(Icons.send_outlined),
          label: Text(l10n.soSubmit),
        );
      case SalesOrderStatus.submitted:
        return FilledButton.icon(
          onPressed: _busy ? null : _approve,
          icon: const Icon(Icons.check_circle_outline),
          label: Text(l10n.soApprove),
        );
      case SalesOrderStatus.approved:
        // Approving only reserves stock (0073); turning that into something
        // the floor can pick is a separate, explicit step. Once it exists,
        // the primary action goes back to closing the order's own bookkeeping.
        if (!_order.hasShipment) {
          return FilledButton.icon(
            onPressed: _busy ? null : _createShipment,
            icon: const Icon(Icons.local_shipping_outlined),
            label: Text(l10n.soCreateShipment),
          );
        }
        return FilledButton.icon(
          onPressed: _busy ? null : _complete,
          icon: const Icon(Icons.task_alt),
          label: Text(l10n.soComplete),
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
    final ui = SalesOrderStatusUi.of(l10n, _order.status);
    final primary = _primaryAction(l10n);

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
                      _order.customerName,
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
          child: _order.lines.isEmpty
              ? EmptyStateView(icon: Icons.receipt_long_outlined, title: l10n.soEmpty)
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    if (_order.reservations.isNotEmpty) ...[
                      _ReservationsCard(
                        order: _order,
                        onOpenShipment: _openShipment,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    for (final line in _order.lines) ...[
                      _LineCard(line: line),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    EntityAuditTimeline(
                      entityType: 'sales_order',
                      entityId: '${_order.id}',
                    ),
                  ],
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
                    if (_order.status == SalesOrderStatus.submitted)
                      SizedBox(
                        height: AppSpacing.minTouch,
                        child: OutlinedButton(
                          onPressed: _busy ? null : _reject,
                          child: Text(l10n.soReject),
                        ),
                      )
                    else if (_order.canCancel)
                      SizedBox(
                        height: AppSpacing.minTouch,
                        child: OutlinedButton(
                          onPressed: _busy ? null : _cancel,
                          child: Text(l10n.soCancelAction),
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

/// §6's promise, made visible: which lines are backed by stock already set
/// aside, and whether that promise has been kept. Shown once a reservation
/// exists — before approval there is nothing here to show.
class _ReservationsCard extends StatelessWidget {
  const _ReservationsCard({required this.order, required this.onOpenShipment});

  final SalesOrder order;
  final VoidCallback onOpenShipment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

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
                  child: Text(l10n.soReservationsTitle,
                      style: theme.textTheme.titleSmall),
                ),
                if (order.hasShipment)
                  TextButton.icon(
                    onPressed: onOpenShipment,
                    icon: const Icon(Icons.local_shipping_outlined, size: 18),
                    label: Text(l10n.soOpenShipment),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final r in order.reservations)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(r.janCode,
                          style: const TextStyle(fontFamily: AppFonts.mono)),
                    ),
                    Text('${r.fulfilledQuantity} / ${r.quantity}',
                        style: theme.textTheme.bodySmall),
                    if (r.isFulfilled) ...[
                      const SizedBox(width: AppSpacing.sm),
                      StatusPill(
                        tone: StatusTone.success,
                        label: l10n.soReservationFulfilled,
                        dense: true,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({required this.line});

  final SalesOrderLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final title = line.productName.isNotEmpty ? line.productName : line.janCode;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(line.janCode,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontFamily: AppFonts.mono, color: scheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _Stat(label: l10n.soLineQuantity, value: '${line.quantity}'),
                ),
                Expanded(
                  child: _Stat(
                    label: l10n.soLineUnitPrice,
                    value: line.unitPrice == null ? '—' : '¥${line.unitPrice!.toStringAsFixed(0)}',
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: l10n.soTotalAmount,
                    value: '¥${line.amount.toStringAsFixed(0)}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontFamily: AppFonts.mono, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
