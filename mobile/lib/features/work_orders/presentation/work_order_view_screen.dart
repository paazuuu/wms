import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../application/work_order_providers.dart';
import '../domain/work_order.dart';
import '../domain/work_order_item.dart';
import 'work_order_status_ui.dart';

/// Read-only work order view: status, target product, quantities, and the
/// bill-of-materials components with required vs. consumed amounts.
class WorkOrderViewScreen extends ConsumerWidget {
  const WorkOrderViewScreen({super.key, required this.workOrderId});

  final int workOrderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(workOrderDetailProvider(workOrderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Work Order')),
      body: order.when(
        data: (o) => _WorkOrderBody(order: o),
        loading: () => const LoadingView(message: 'Loading work order…'),
        error: (error, _) => ErrorStateView(
          message: '$error',
          onRetry: () => ref.invalidate(workOrderDetailProvider(workOrderId)),
        ),
      ),
    );
  }
}

class _WorkOrderBody extends StatelessWidget {
  const _WorkOrderBody({required this.order});

  final WorkOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = WorkOrderStatusUi.of(order);

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
                        order.workOrderNumber,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.productName.isNotEmpty
                      ? order.productName
                      : 'Assembly product',
                  style: theme.textTheme.titleMedium,
                ),
                if (order.sku.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    order.sku,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFamily: 'FiraCode',
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    _Stat(label: 'Target', value: '${order.quantity}'),
                    _Stat(
                        label: 'Produced',
                        value: order.quantityProduced != null
                            ? '${order.quantityProduced}'
                            : '—'),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(label: 'Started', value: order.startedAt ?? '—'),
                _InfoRow(label: 'Completed', value: order.completedAt ?? '—'),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Components',
          style: theme.textTheme.titleSmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (order.items.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text('No components.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          )
        else
          ...order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _ComponentCard(item: item),
              )),
        if (order.notes != null && order.notes!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notes',
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

class _ComponentCard extends StatelessWidget {
  const _ComponentCard({required this.item});

  final WorkOrderItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = item.quantityRemaining <= 0;

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
                        item.productName.isNotEmpty
                            ? item.productName
                            : 'Product #${item.productId}',
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
                      ? 'Consumed'
                      : '${formatQuantity(item.quantityRemaining)} left',
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
                _Stat(
                    label: 'Required',
                    value: formatQuantity(item.quantityRequired)),
                _Stat(
                    label: 'Consumed',
                    value: formatQuantity(item.quantityConsumed)),
                _Stat(
                    label: 'On hand',
                    value: item.stock != null ? '${item.stock}' : '—'),
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
