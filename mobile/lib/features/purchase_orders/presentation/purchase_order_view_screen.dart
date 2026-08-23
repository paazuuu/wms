import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../receiving/application/receiving_providers.dart';
import '../../receiving/domain/purchase_order.dart';
import '../../receiving/domain/purchase_order_item.dart';
import '../../receiving/presentation/receiving_status_ui.dart';

/// Read-only purchase order view: status, supplier, dates, and ordered vs.
/// received quantities per line. Unlike the Receiving screen, this never books
/// stock — it is a browse detail for any PO status.
class PurchaseOrderViewScreen extends ConsumerWidget {
  const PurchaseOrderViewScreen({super.key, required this.purchaseOrderId});

  final int purchaseOrderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(purchaseOrderDetailProvider(purchaseOrderId));
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.featPurchaseOrders)),
      body: order.when(
        data: (o) => _PurchaseOrderBody(order: o),
        loading: () => LoadingView(message: l10n.loading),
        error: (error, _) => ErrorStateView(
          message: '$error',
          onRetry: () =>
              ref.invalidate(purchaseOrderDetailProvider(purchaseOrderId)),
        ),
      ),
    );
  }
}

class _PurchaseOrderBody extends StatelessWidget {
  const _PurchaseOrderBody({required this.order});

  final PurchaseOrder order;

  String get _displayTotal {
    final amount = order.total?.trim();
    if (amount == null || amount.isEmpty) return '—';
    final code = order.currency?.trim();
    return (code != null && code.isNotEmpty) ? '$code $amount' : amount;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final status = ReceivingStatusUi.of(l10n, order);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusAvatar(tone: status.tone, icon: status.icon),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Text(
                        order.poNumber,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontFamily: 'FiraCode'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                StatusPill(
                  tone: status.tone,
                  label: status.label,
                  icon: status.icon,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                _InfoRow(label: l10n.fieldSupplier, value: order.supplierName ?? '—'),
                _InfoRow(label: l10n.fieldOrderDate, value: order.orderDate ?? '—'),
                _InfoRow(label: l10n.fieldExpected, value: order.expectedDate ?? '—'),
                _InfoRow(label: l10n.fieldReceived, value: order.receivedDate ?? '—'),
                _InfoRow(label: l10n.fieldTotal, value: _displayTotal),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.lineItems,
          style: theme.textTheme.titleSmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (order.items.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(l10n.noLineItems,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          )
        else
          ...order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _LineCard(item: item),
              )),
        if (order.notes != null && order.notes!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.fieldNotes,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(order.notes!, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({required this.item});

  final PurchaseOrderItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final done = item.remainingQuantity <= 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: theme.textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.sku.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.sku,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontFamily: 'FiraCode',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                StatusPill(
                  tone: done ? StatusTone.success : StatusTone.warning,
                  label: done
                      ? l10n.actionComplete
                      : l10n.remainingLeft(item.remainingQuantity),
                  icon: done
                      ? Icons.check_circle_outline
                      : Icons.hourglass_bottom,
                  dense: true,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _Stat(label: l10n.fieldOrdered, value: '${item.quantityOrdered}'),
                _Stat(label: l10n.fieldReceived, value: '${item.quantityReceived}'),
                _Stat(
                    label: l10n.fieldRemaining,
                    value: '${item.remainingQuantity}'),
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
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontFamily: 'FiraCode'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
