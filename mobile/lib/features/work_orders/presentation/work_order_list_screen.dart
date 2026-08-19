import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/scan/scan_field.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../application/work_order_providers.dart';
import '../domain/work_order.dart';
import 'work_order_status_ui.dart';
import 'work_order_view_screen.dart';

/// Browse and search assembly/kitting work orders. Read-only: tapping a work
/// order opens a view of its components. (State transitions live on the back
/// office.)
class WorkOrderListScreen extends ConsumerStatefulWidget {
  const WorkOrderListScreen({super.key});

  @override
  ConsumerState<WorkOrderListScreen> createState() =>
      _WorkOrderListScreenState();
}

class _WorkOrderListScreenState extends ConsumerState<WorkOrderListScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final next = _controller.text.trim();
    if (next == _query) {
      ref.invalidate(workOrderSearchProvider(_query));
    } else {
      setState(() => _query = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(workOrderSearchProvider(_query));

    return Scaffold(
      appBar: AppBar(title: const Text('Work Orders')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ScanField(
              controller: _controller,
              clearOnSubmit: false,
              hintText: 'Scan or search by WO number, product, or SKU',
              onSubmitted: (_) => _submit(),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(workOrderSearchProvider(_query)),
              child: results.when(
                data: (items) => items.isEmpty
                    ? EmptyStateView(
                        icon: Icons.precision_manufacturing_outlined,
                        title: _query.isEmpty
                            ? 'No work orders yet.'
                            : 'No matches for "$_query".',
                        message: 'Try a different WO number, product, or SKU.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) =>
                            _WorkOrderCard(order: items[index]),
                      ),
                loading: () =>
                    const LoadingView(message: 'Loading work orders…'),
                error: (error, _) => ErrorStateView(
                  message: '$error',
                  onRetry: () =>
                      ref.invalidate(workOrderSearchProvider(_query)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkOrderCard extends StatelessWidget {
  const _WorkOrderCard({required this.order});

  final WorkOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = WorkOrderStatusUi.of(order);
    final product = order.productName.trim().isNotEmpty
        ? order.productName
        : 'No product';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WorkOrderViewScreen(workOrderId: order.id),
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
                      order.workOrderNumber,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontFamily: 'FiraCode'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product,
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
                        StatusPill(
                          tone: StatusTone.neutral,
                          label: 'Qty ${order.quantity}',
                          icon: Icons.numbers_outlined,
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
