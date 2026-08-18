import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../application/receiving_providers.dart';
import '../domain/purchase_order.dart';
import 'receiving_detail_screen.dart';
import 'receiving_status_ui.dart';

/// Lists purchase orders that still have stock to receive (status `sent` or
/// `partial`). Tapping one opens the receive screen.
class ReceivingListScreen extends ConsumerWidget {
  const ReceivingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(receivablePurchaseOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Receiving')),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(receivablePurchaseOrdersProvider),
        child: orders.when(
          data: (items) => items.isEmpty
              ? const EmptyStateView(
                  icon: Icons.inbox_outlined,
                  title: 'Nothing to receive.',
                  message: 'Purchase orders that are sent or partially '
                      'received will appear here.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) =>
                      _PurchaseOrderCard(order: items[index]),
                ),
          loading: () => const LoadingView(message: 'Loading purchase orders…'),
          error: (error, _) => ErrorStateView(
            message: '$error',
            onRetry: () => ref.invalidate(receivablePurchaseOrdersProvider),
          ),
        ),
      ),
    );
  }
}

class _PurchaseOrderCard extends StatelessWidget {
  const _PurchaseOrderCard({required this.order});

  final PurchaseOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = ReceivingStatusUi.of(order);
    final itemCount = order.itemsCount ?? order.items.length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReceivingDetailScreen(purchaseOrderId: order.id),
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
                      order.poNumber,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontFamily: 'FiraCode'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.supplierName ?? 'Unknown supplier',
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
                          label: '$itemCount ${itemCount == 1 ? 'line' : 'lines'}',
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
