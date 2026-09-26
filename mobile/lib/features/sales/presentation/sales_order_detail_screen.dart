import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../audit/presentation/entity_audit_timeline.dart';
import '../../demand/application/demand_providers.dart';
import '../../purchasing/presentation/purchase_order_detail_screen.dart';
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
    ref.invalidate(openDemandProvider);
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
                  // Being short is normal in an order-first warehouse: what
                  // exists is reserved, the rest waits as backorder (0084).
                  if (s.backordered > 0)
                    Text(l10n.soSkipPartial(s.reserved, s.backordered),
                        style: Theme.of(context).textTheme.bodySmall),
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
    final label = _shipLabel(l10n);
    if (!await _confirm(
        label, l10n.soCreateShipmentReadyQ(_order.readyToShipUnits), label)) {
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

  String _shipLabel(AppLocalizations l10n) => _order.shipments.any((s) => s.isShipped)
      ? l10n.soShipRemaining
      : l10n.soCreateShipment;

  void _openShipment([int? id]) {
    final target = id ?? _order.openShipmentPlanId ?? _order.shipmentPlanId;
    if (target == null) return;
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => ShipmentDetailScreen(shipmentId: target),
        ))
        .then((_) => _refresh());
  }

  void _openPurchaseOrder(int id) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PurchaseOrderDetailScreen(purchaseOrderId: id),
    ));
  }

  bool get _canFill => _order.lines.any((l) => l.backordered > 0 && l.productId != null);

  /// Promises free stock to this order's waiting lines (0084). Each line is
  /// filled on its own so this order is served even when older orders for the
  /// same product are also waiting — the operator chose this customer.
  Future<void> _fill([SalesOrderLine? only]) async {
    final l10n = AppLocalizations.of(context);
    final warehouseId = _order.warehouseId;
    if (warehouseId == null) return;
    final lines = only != null
        ? [only]
        : _order.lines.where((l) => l.backordered > 0 && l.productId != null).toList();
    if (lines.isEmpty) return;

    setState(() => _busy = true);
    final repo = ref.read(demandRepositoryProvider);
    var units = 0;
    String? error;
    for (final line in lines) {
      final result = await repo.fillBackorders(
          warehouseId: warehouseId, salesOrderLineId: line.id);
      result.when(
        success: (fill) => units += fill.reservedUnits,
        failure: (f) => error ??= f.message,
      );
      if (error != null) break;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _refresh();
    if (error != null) {
      _snack(humanizeApiErrorMessage(l10n, error!), danger: true);
    } else {
      _snack(units == 0 ? l10n.demandNothingToFill : l10n.demandFilled(units));
    }
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
        // The next step for an order-first warehouse, in the order the work
        // happens: a shipment being worked, then what is reserved and waiting
        // to go out, then what is still waiting for stock, then closing.
        if (_order.hasOpenShipment) {
          return FilledButton.icon(
            onPressed: _busy ? null : () => _openShipment(),
            icon: const Icon(Icons.local_shipping_outlined),
            label: Text(l10n.soOpenShipment),
          );
        }
        if (_order.readyToShipUnits > 0) {
          return FilledButton.icon(
            onPressed: _busy ? null : _createShipment,
            icon: const Icon(Icons.local_shipping_outlined),
            label: Text(_shipLabel(l10n)),
          );
        }
        if (_canFill) {
          return FilledButton.icon(
            onPressed: _busy ? null : () => _fill(),
            icon: const Icon(Icons.move_to_inbox_outlined),
            label: Text(l10n.soFillFromStock),
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

  /// Stock is only promised from approval on; before that there is nothing
  /// to show but what was ordered.
  bool get _tracksStock => [
        SalesOrderStatus.approved,
        SalesOrderStatus.completed,
      ].contains(_order.status);

  /// Everything the primary button is not, for an approved order: closing it
  /// with backorder left (the rest is supplied elsewhere), or filling from
  /// stock while something else is the next step.
  List<PopupMenuEntry<String>> _menuItems(AppLocalizations l10n) {
    if (_order.status != SalesOrderStatus.approved) return const [];
    final primaryIsFill = !_order.hasOpenShipment && _order.readyToShipUnits == 0 && _canFill;
    final primaryIsComplete =
        !_order.hasOpenShipment && _order.readyToShipUnits == 0 && !_canFill;
    return [
      if (_canFill && !primaryIsFill)
        PopupMenuItem(value: 'fill', child: Text(l10n.soFillFromStock)),
      if (!primaryIsComplete)
        PopupMenuItem(value: 'complete', child: Text(l10n.soComplete)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ui = SalesOrderStatusUi.of(l10n, _order.status);
    final primary = _primaryAction(l10n);
    final menu = _menuItems(l10n);

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
                    if (_tracksStock) ...[
                      _ProgressCard(order: _order, onOpenShipment: _openShipment),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    for (final line in _order.lines) ...[
                      _LineCard(
                        line: line,
                        tracksStock: _tracksStock,
                        onFill: _order.status == SalesOrderStatus.approved &&
                                line.backordered > 0 &&
                                line.productId != null &&
                                !_busy
                            ? () => _fill(line)
                            : null,
                        onOpenPurchaseOrder: _openPurchaseOrder,
                      ),
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
                    if (menu.isNotEmpty)
                      PopupMenuButton<String>(
                        tooltip: l10n.soMoreActions,
                        enabled: !_busy,
                        onSelected: (v) => v == 'fill' ? _fill() : _complete(),
                        itemBuilder: (_) => menu,
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Where the order stands against stock as a whole, and every shipment it
/// has gone out on — an order may ship in several (0084).
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.order, required this.onOpenShipment});

  final SalesOrder order;
  final ValueChanged<int> onOpenShipment;

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
                    child: _Stat(label: l10n.demandOrdered, value: '${order.orderedUnits}')),
                Expanded(
                    child: _Stat(
                        label: l10n.soReadyToShip, value: '${order.readyToShipUnits}')),
                Expanded(
                    child: _Stat(label: l10n.demandShipped, value: '${order.shippedUnits}')),
                Expanded(
                    child: _Stat(
                        label: l10n.demandBackordered,
                        value: '${order.backorderedUnits}',
                        emphasize: order.backorderedUnits > 0)),
              ],
            ),
            if (order.shipments.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.soShipments, style: theme.textTheme.titleSmall),
              for (final s in order.shipments)
                InkWell(
                  onTap: () => onOpenShipment(s.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      children: [
                        const Icon(Icons.local_shipping_outlined, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(s.shipmentNumber ?? '#${s.id}',
                              style: const TextStyle(fontFamily: AppFonts.mono)),
                        ),
                        StatusPill(
                          tone: s.isShipped ? StatusTone.success : StatusTone.info,
                          label: s.isShipped ? l10n.soShipmentShipped : l10n.soShipmentOpen,
                          dense: true,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.line,
    required this.tracksStock,
    required this.onFill,
    required this.onOpenPurchaseOrder,
  });

  final SalesOrderLine line;
  final bool tracksStock;
  final VoidCallback? onFill;
  final ValueChanged<int> onOpenPurchaseOrder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final title = line.productName.isNotEmpty ? line.productName : line.janCode;
    final price = line.unitPrice == null ? '—' : '¥${line.unitPrice!.toStringAsFixed(0)}';

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
            if (!tracksStock)
              Row(
                children: [
                  Expanded(
                    child: _Stat(label: l10n.soLineQuantity, value: '${line.quantity}'),
                  ),
                  Expanded(child: _Stat(label: l10n.soLineUnitPrice, value: price)),
                  Expanded(
                    child: _Stat(
                      label: l10n.soTotalAmount,
                      value: '¥${line.amount.toStringAsFixed(0)}',
                    ),
                  ),
                ],
              )
            else ...[
              Row(
                children: [
                  Expanded(child: _Stat(label: l10n.demandOrdered, value: '${line.quantity}')),
                  Expanded(child: _Stat(label: l10n.demandPromised, value: '${line.promised}')),
                  Expanded(child: _Stat(label: l10n.demandShipped, value: '${line.shipped}')),
                  Expanded(
                    child: _Stat(
                      label: l10n.demandBackordered,
                      value: '${line.backordered}',
                      emphasize: line.backordered > 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('${l10n.soLineUnitPrice} $price · ${l10n.soTotalAmount} ¥${line.amount.toStringAsFixed(0)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              if (line.productId == null && line.backordered > 0) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(l10n.soLineUnlinked,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
              ],
              if (line.purchaseOrders.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(l10n.soLineOnOrder(line.onOrder), style: theme.textTheme.bodySmall),
                    for (final po in line.purchaseOrders)
                      ActionChip(
                        avatar: const Icon(Icons.add_shopping_cart_outlined, size: 16),
                        label: Text([
                          po.poNumber ?? '#${po.purchaseOrderId}',
                          if (po.supplierName.isNotEmpty) po.supplierName,
                          '×${po.quantity}',
                          if (po.filled > 0) l10n.poDemandFilled(po.filled),
                        ].join(' ')),
                        onPressed: () => onOpenPurchaseOrder(po.purchaseOrderId),
                      ),
                  ],
                ),
              ],
              if (onFill != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onFill,
                    icon: const Icon(Icons.move_to_inbox_outlined, size: 18),
                    label: Text(l10n.soFillLine),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;

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
            style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: AppFonts.mono,
                fontWeight: FontWeight.w600,
                color: emphasize ? scheme.error : null)),
      ],
    );
  }
}
