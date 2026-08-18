import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../sales_orders/application/sales_order_providers.dart';
import '../../sales_orders/domain/sales_order.dart';
import '../../sales_orders/domain/sales_order_item.dart';

/// Executes a pick list for one open sales order. Line items are checked off
/// locally as they are picked — progress is tracked on-device only, since the
/// backend has no picking endpoint.
class PickListScreen extends ConsumerStatefulWidget {
  const PickListScreen({super.key, required this.orderId});

  final int orderId;

  @override
  ConsumerState<PickListScreen> createState() => _PickListScreenState();
}

class _PickListScreenState extends ConsumerState<PickListScreen> {
  final Set<int> _picked = {};

  void _toggle(int itemId, bool picked) {
    setState(() {
      if (picked) {
        _picked.add(itemId);
      } else {
        _picked.remove(itemId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(salesOrderDetailProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Pick List')),
      body: result.when(
        data: (order) => _PickListBody(
          order: order,
          picked: _picked,
          onToggle: _toggle,
        ),
        loading: () => const LoadingView(message: 'Loading pick list…'),
        error: (error, _) => ErrorStateView(
          message: '$error',
          onRetry: () =>
              ref.invalidate(salesOrderDetailProvider(widget.orderId)),
        ),
      ),
    );
  }
}

class _PickListBody extends StatelessWidget {
  const _PickListBody({
    required this.order,
    required this.picked,
    required this.onToggle,
  });

  final SalesOrder order;
  final Set<int> picked;
  final void Function(int itemId, bool picked) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = order.items;
    final pickedCount = items.where((i) => picked.contains(i.id)).length;
    final allPicked = items.isNotEmpty && pickedCount == items.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.orderNumber,
                style:
                    theme.textTheme.titleLarge?.copyWith(fontFamily: 'FiraCode'),
              ),
              const SizedBox(height: 2),
              Text(
                order.customerName?.trim().isNotEmpty == true
                    ? order.customerName!
                    : 'No customer',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.sm),
              StatusPill(
                tone: allPicked ? StatusTone.success : StatusTone.info,
                label: '$pickedCount / ${items.length} picked',
                icon: allPicked
                    ? Icons.check_circle_outline
                    : Icons.checklist_outlined,
                dense: true,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: items.isEmpty
              ? const EmptyStateView(
                  icon: Icons.inventory_2_outlined,
                  title: 'No lines to pick.',
                  message: 'This order has no line items.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _PickLineTile(
                      item: item,
                      picked: picked.contains(item.id),
                      onChanged: (value) => onToggle(item.id, value ?? false),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _PickLineTile extends StatelessWidget {
  const _PickLineTile({
    required this.item,
    required this.picked,
    required this.onChanged,
  });

  final SalesOrderItem item;
  final bool picked;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onChanged(!picked),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Checkbox(value: picked, onChanged: onChanged),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName.isNotEmpty
                          ? item.productName
                          : 'Unnamed product',
                      style: theme.textTheme.titleSmall?.copyWith(
                        decoration:
                            picked ? TextDecoration.lineThrough : null,
                        color: picked ? scheme.onSurfaceVariant : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.sku?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.sku!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'FiraCode',
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusPill(
                tone: StatusTone.neutral,
                label: 'Qty ${item.quantity}',
                icon: Icons.numbers_outlined,
                dense: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
