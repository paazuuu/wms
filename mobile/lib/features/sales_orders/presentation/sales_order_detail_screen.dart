import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../application/sales_order_providers.dart';
import '../domain/sales_order.dart';
import '../domain/sales_order_item.dart';
import 'sales_order_status_ui.dart';

/// Read-only sales order detail: status, customer, line items, and totals.
class SalesOrderDetailScreen extends ConsumerWidget {
  const SalesOrderDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(salesOrderDetailProvider(orderId));
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.featSalesOrders)),
      body: order.when(
        data: (o) => _SalesOrderBody(order: o),
        loading: () => LoadingView(message: l10n.loading),
        error: (error, _) => ErrorStateView(
          message: '$error',
          onRetry: () => ref.invalidate(salesOrderDetailProvider(orderId)),
        ),
      ),
    );
  }
}

class _SalesOrderBody extends StatelessWidget {
  const _SalesOrderBody({required this.order});

  final SalesOrder order;

  String _money(String? amount) {
    final a = amount?.trim();
    if (a == null || a.isEmpty) return '—';
    final code = order.currency?.trim();
    return (code != null && code.isNotEmpty) ? '$code $a' : a;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final status = SalesOrderStatusUi.of(l10n, order);

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
                        order.orderNumber,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontFamily: 'FiraCode'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    StatusPill(
                      tone: status.tone,
                      label: status.label,
                      icon: status.icon,
                    ),
                    if (order.source != null && order.source!.isNotEmpty)
                      StatusPill(
                        tone: StatusTone.neutral,
                        label: order.source!,
                        icon: Icons.storefront_outlined,
                      ),
                  ],
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
                _InfoRow(label: l10n.fieldCustomer, value: order.customerName ?? '—'),
                _InfoRow(label: l10n.email, value: order.customerEmail ?? '—'),
                _InfoRow(
                    label: l10n.fieldAddress, value: order.customerAddress ?? '—'),
                _InfoRow(label: l10n.fieldOrderDate, value: order.orderDate ?? '—'),
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
                child: _LineCard(item: item, money: _money),
              )),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                _InfoRow(label: l10n.fieldSubtotal, value: _money(order.subtotal)),
                _InfoRow(label: l10n.fieldTax, value: _money(order.tax)),
                _InfoRow(label: l10n.fieldShipping, value: _money(order.shipping)),
                const Divider(height: AppSpacing.xl),
                _InfoRow(
                    label: l10n.fieldTotal,
                    value: _money(order.total),
                    bold: true),
              ],
            ),
          ),
        ),
        if (order.notes != null && order.notes!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
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
  const _LineCard({required this.item, required this.money});

  final SalesOrderItem item;
  final String Function(String?) money;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
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
                  if (item.sku != null && item.sku!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.sku!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFamily: 'FiraCode',
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${item.quantity} × ${money(item.unitPrice)}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              money(item.total),
              style:
                  theme.textTheme.titleSmall?.copyWith(fontFamily: 'FiraCode'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

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
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: bold ? FontWeight.w600 : null,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
