import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../audit/presentation/entity_audit_timeline.dart';
import '../../delivery/presentation/reconciliation_screen.dart';
import '../../sales/presentation/sales_order_detail_screen.dart';
import '../application/purchase_order_providers.dart';
import '../domain/purchase_order.dart';
import '../../product/application/product_providers.dart';
import '../../product/domain/supplier_product_name.dart';
import 'purchase_link_editor_page.dart';
import 'purchase_order_status_ui.dart';

/// One purchase order, driven through its state machine one step at a time:
/// draft → submit → approve/reject → (cancel) → complete. Completing is a
/// bookkeeping close only — no stock moves here; receiving still goes
/// through the existing delivery-plan/reconciliation flow.
class PurchaseOrderDetailScreen extends ConsumerWidget {
  const PurchaseOrderDetailScreen({super.key, required this.purchaseOrderId});

  final int purchaseOrderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(purchaseOrderDetailProvider(purchaseOrderId));

    final deliveryPlanId = async.valueOrNull?.deliveryPlanId;

    return Scaffold(
      appBar: AppBar(
        title: Text(async.valueOrNull?.poNumber ?? l10n.poTitle),
        actions: [
          if (deliveryPlanId != null)
            IconButton(
              tooltip: l10n.poOpenDeliveryPlan,
              icon: const Icon(Icons.move_to_inbox_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ReconciliationScreen(planId: deliveryPlanId),
              )),
            ),
        ],
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(purchaseOrderDetailProvider(purchaseOrderId)),
        ),
        data: (order) => _Body(order: order),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.order});

  final PurchaseOrder order;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _busy = false;

  PurchaseOrder get _order => widget.order;

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
    ref.invalidate(purchaseOrderDetailProvider(_order.id));
    ref.invalidate(purchaseOrderListProvider);
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
    await _run(() => ref.read(purchaseOrderRepositoryProvider).submit(_order.id),
        successMessage: l10n.poSubmitted);
  }

  Future<void> _approve() async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(l10n.poApprove, l10n.poApproveQ, l10n.poApprove)) return;
    await _run(() => ref.read(purchaseOrderRepositoryProvider).approve(_order.id),
        successMessage: l10n.poApproved);
  }

  Future<void> _reject() async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(l10n.poReject, l10n.poRejectQ, l10n.poReject)) return;
    await _run(() => ref.read(purchaseOrderRepositoryProvider).reject(_order.id),
        successMessage: l10n.poRejected);
  }

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(l10n.poCancelAction, l10n.poCancelBody, l10n.poCancelAction)) return;
    await _run(() => ref.read(purchaseOrderRepositoryProvider).cancel(_order.id),
        successMessage: l10n.poCancelled);
  }

  Future<void> _complete() async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(l10n.poComplete, l10n.poCompleteQ, l10n.poComplete)) return;
    await _run(() => ref.read(purchaseOrderRepositoryProvider).complete(_order.id),
        successMessage: l10n.poCompleted);
  }

  String _planLabel(AppLocalizations l10n) => _order.hasDeliveryPlan
      ? l10n.poCreateRemainingDeliveryPlan
      : l10n.poCreateDeliveryPlan;

  void _openPlan(int id) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ReconciliationScreen(planId: id)))
        .then((_) => _refresh());
  }

  /// What this order's supplier calls each product, by JAN (0087).
  Map<String, SupplierProductName> get _supplierNames {
    final id = _order.supplierId;
    if (id == null) return const {};
    return ref.watch(supplierNamesBySupplierProvider(id)).valueOrNull ?? const {};
  }

  bool get _canEditLinks => ![
        PurchaseOrderStatus.rejected,
        PurchaseOrderStatus.cancelled,
      ].contains(_order.status);

  Future<void> _editLinks(PurchaseOrderLine line) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => PurchaseLinkEditorPage(line: line),
    ));
    if (saved == true) _refresh();
  }

  void _openSalesOrder(int id) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SalesOrderDetailScreen(salesOrderId: id),
    ));
  }

  Future<void> _createDeliveryPlan() async {
    final l10n = AppLocalizations.of(context);
    final label = _planLabel(l10n);
    if (!await _confirm(label, l10n.poCreateDeliveryPlanQ, label)) {
      return;
    }
    setState(() => _busy = true);
    final result = await ref
        .read(purchaseOrderRepositoryProvider)
        .createDeliveryPlan(_order.id);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (created) {
        _refresh();
        _snack(l10n.poDeliveryPlanCreated(created.lines));
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              ReconciliationScreen(planId: created.deliveryPlanId),
        ));
      },
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  Widget? _primaryAction(AppLocalizations l10n) {
    switch (_order.status) {
      case PurchaseOrderStatus.draft:
        return FilledButton.icon(
          onPressed: _busy ? null : _submit,
          icon: const Icon(Icons.send_outlined),
          label: Text(l10n.poSubmit),
        );
      case PurchaseOrderStatus.submitted:
        return FilledButton.icon(
          onPressed: _busy ? null : _approve,
          icon: const Icon(Icons.check_circle_outline),
          label: Text(l10n.poApprove),
        );
      case PurchaseOrderStatus.approved:
        // Approving is a bookkeeping step only; turning that into something
        // receiving can reconcile against is a separate, explicit action
        // (0083). Once a delivery plan exists, the primary action goes back
        // to closing the order's own bookkeeping.
        // A supplier may deliver in parts: while anything ordered is on no
        // plan yet, the next plan is still the next step (0084).
        if (_order.hasUnplannedQuantity) {
          return FilledButton.icon(
            onPressed: _busy ? null : _createDeliveryPlan,
            icon: const Icon(Icons.move_to_inbox_outlined),
            label: Text(_planLabel(l10n)),
          );
        }
        return FilledButton.icon(
          onPressed: _busy ? null : _complete,
          icon: const Icon(Icons.task_alt),
          label: Text(l10n.poComplete),
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
    final ui = PurchaseOrderStatusUi.of(l10n, _order.status);
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
                      _order.supplierName,
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
              ? EmptyStateView(icon: Icons.shopping_cart_outlined, title: l10n.poEmpty)
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    if (_order.deliveryPlans.isNotEmpty) ...[
                      _DeliveryPlansCard(plans: _order.deliveryPlans, onOpen: _openPlan),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    for (final line in _order.lines) ...[
                      _LineCard(
                        line: line,
                        tracksReceipt: [
                          PurchaseOrderStatus.approved,
                          PurchaseOrderStatus.completed,
                        ].contains(_order.status),
                        onOpenSalesOrder: _openSalesOrder,
                        onEditLinks: _canEditLinks && !_busy ? () => _editLinks(line) : null,
                        supplierName: _supplierNames[line.janCode],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    EntityAuditTimeline(
                      entityType: 'purchase_order',
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
                    if (_order.status == PurchaseOrderStatus.submitted)
                      SizedBox(
                        height: AppSpacing.minTouch,
                        child: OutlinedButton(
                          onPressed: _busy ? null : _reject,
                          child: Text(l10n.poReject),
                        ),
                      )
                    else if (_order.canCancel)
                      SizedBox(
                        height: AppSpacing.minTouch,
                        child: OutlinedButton(
                          onPressed: _busy ? null : _cancel,
                          child: Text(l10n.poCancelAction),
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

class _DeliveryPlansCard extends StatelessWidget {
  const _DeliveryPlansCard({required this.plans, required this.onOpen});

  final List<PurchaseOrderDeliveryPlan> plans;
  final ValueChanged<int> onOpen;

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
            Text(l10n.poDeliveryPlans, style: theme.textTheme.titleSmall),
            for (final p in plans)
              InkWell(
                onTap: () => onOpen(p.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      const Icon(Icons.move_to_inbox_outlined, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(p.deliveryNumber ?? '#${p.id}',
                            style: const TextStyle(fontFamily: AppFonts.mono)),
                      ),
                      StatusPill(
                        tone: p.isCompleted ? StatusTone.success : StatusTone.info,
                        label: p.isCompleted ? l10n.poPlanReceived : l10n.poPlanOpen,
                        dense: true,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.line,
    required this.tracksReceipt,
    required this.onOpenSalesOrder,
    required this.onEditLinks,
    this.supplierName,
  });

  /// What the supplier calls this product, shown beside our own name.
  final SupplierProductName? supplierName;

  final PurchaseOrderLine line;
  final bool tracksReceipt;
  final ValueChanged<int> onOpenSalesOrder;
  final VoidCallback? onEditLinks;

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
            if (supplierName != null)
              Text(
                l10n.poLineSupplierName(supplierName!.supplierName) +
                    (supplierName!.supplierCode == null ? '' : ' (${supplierName!.supplierCode})'),
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.tertiary),
              ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _Stat(label: l10n.poLineQuantity, value: '${line.quantity}'),
                ),
                Expanded(
                  child: _Stat(
                    label: l10n.poLineUnitPrice,
                    value: line.unitPrice == null ? '—' : '¥${line.unitPrice!.toStringAsFixed(0)}',
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: l10n.poTotalAmount,
                    value: '¥${line.amount.toStringAsFixed(0)}',
                  ),
                ),
              ],
            ),
            if (tracksReceipt) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(child: _Stat(label: l10n.poLinePlanned, value: '${line.planned}')),
                  Expanded(child: _Stat(label: l10n.poLineReceived, value: '${line.received}')),
                  Expanded(
                    child: _Stat(
                      label: l10n.poLineOutstanding,
                      value: '${line.quantity > line.received ? line.quantity - line.received : 0}',
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    line.unlinked > 0
                        ? l10n.poLineLinkedAhead(line.linked, line.unlinked)
                        : l10n.poLineForOrders,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                if (onEditLinks != null)
                  TextButton.icon(
                    onPressed: onEditLinks,
                    icon: const Icon(Icons.link, size: 18),
                    label: Text(l10n.poLinkEdit),
                  ),
              ],
            ),
            if (line.demands.isNotEmpty)
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final d in line.demands)
                    ActionChip(
                      avatar: const Icon(Icons.point_of_sale_outlined, size: 16),
                      label: Text([
                        d.soNumber ?? '#${d.salesOrderId}',
                        if (d.customerName.isNotEmpty) d.customerName,
                        '×${d.quantity}',
                        if (d.filled > 0) l10n.poDemandFilled(d.filled),
                      ].join(' ')),
                      onPressed: () => onOpenSalesOrder(d.salesOrderId),
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
