import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/scan/scan_field.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../application/sales_order_providers.dart';
import '../domain/sales_order.dart';
import 'sales_order_detail_screen.dart';
import 'sales_order_status_ui.dart';

/// Browse and search sales (customer) orders. Read-only: tapping an order opens
/// its detail with line items.
class SalesOrderListScreen extends ConsumerStatefulWidget {
  const SalesOrderListScreen({super.key});

  @override
  ConsumerState<SalesOrderListScreen> createState() =>
      _SalesOrderListScreenState();
}

class _SalesOrderListScreenState extends ConsumerState<SalesOrderListScreen> {
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
      ref.invalidate(salesOrderSearchProvider(_query));
    } else {
      setState(() => _query = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(salesOrderSearchProvider(_query));
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.featSalesOrders)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ScanField(
              controller: _controller,
              autofocusOnWide: true,
              clearOnSubmit: false,
              hintText: l10n.hintSalesOrders,
              onSubmitted: (_) => _submit(),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(salesOrderSearchProvider(_query)),
              child: results.when(
                data: (items) => items.isEmpty
                    ? EmptyStateView(
                        icon: Icons.list_alt_outlined,
                        title: _query.isEmpty
                            ? l10n.emptySalesOrders
                            : l10n.noMatchesFor(_query),
                        message: l10n.tryDifferentOrder,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) =>
                            _SalesOrderCard(order: items[index]),
                      ),
                loading: () => LoadingView(message: l10n.loading),
                error: (error, _) => ErrorStateView(
                  message: '$error',
                  onRetry: () =>
                      ref.invalidate(salesOrderSearchProvider(_query)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesOrderCard extends StatelessWidget {
  const _SalesOrderCard({required this.order});

  final SalesOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final status = SalesOrderStatusUi.of(order);
    final customer = order.customerName?.trim().isNotEmpty == true
        ? order.customerName!
        : l10n.noCustomer;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SalesOrderDetailScreen(orderId: order.id),
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
                            label: l10n.lineCount(order.itemsCount!),
                            icon: Icons.list_alt_outlined,
                            dense: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    order.displayTotal,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontFamily: 'FiraCode'),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
