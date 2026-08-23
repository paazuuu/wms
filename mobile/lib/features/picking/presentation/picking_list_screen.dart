import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../sales_orders/domain/sales_order.dart';
import '../../sales_orders/presentation/sales_order_status_ui.dart';
import '../application/picking_providers.dart';
import 'pick_list_screen.dart';

/// Browse open sales orders that still need picking. Tapping one opens its
/// pick list where line items can be checked off.
class PickingListScreen extends ConsumerWidget {
  const PickingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(pickListsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Picking')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(pickListsProvider),
        child: results.when(
          data: (items) => items.isEmpty
              ? const EmptyStateView(
                  icon: Icons.shopping_cart_checkout_outlined,
                  title: 'Nothing to pick.',
                  message: 'Open sales orders awaiting fulfilment appear here.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) =>
                      _PickListCard(order: items[index]),
                ),
          loading: () => const LoadingView(message: 'Loading pick lists…'),
          error: (error, _) => ErrorStateView(
            message: '$error',
            onRetry: () => ref.invalidate(pickListsProvider),
          ),
        ),
      ),
    );
  }
}

class _PickListCard extends StatelessWidget {
  const _PickListCard({required this.order});

  final SalesOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = SalesOrderStatusUi.of(AppLocalizations.of(context), order);
    final customer = order.customerName?.trim().isNotEmpty == true
        ? order.customerName!
        : 'No customer';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PickListScreen(orderId: order.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              const StatusAvatar(
                tone: StatusTone.info,
                icon: Icons.shopping_cart_checkout_outlined,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderNumber,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontFamily: 'FiraCode'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customer,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
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
                        if (order.itemsCount != null)
                          StatusPill(
                            tone: StatusTone.neutral,
                            label:
                                '${order.itemsCount} ${order.itemsCount == 1 ? 'line' : 'lines'}',
                            icon: Icons.list_alt_outlined,
                            dense: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
