import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../application/receiving_providers.dart';
import '../data/receiving_repository.dart';
import '../domain/purchase_order.dart';
import '../domain/purchase_order_item.dart';
import 'receiving_status_ui.dart';

/// Receive stock against a purchase order. Each outstanding line gets a
/// quantity field (defaulting to what's still remaining); submitting posts to
/// `/purchase-orders/{id}/receive`, which auto-creates a receiving inspection.
class ReceivingDetailScreen extends ConsumerWidget {
  const ReceivingDetailScreen({super.key, required this.purchaseOrderId});

  final int purchaseOrderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(purchaseOrderDetailProvider(purchaseOrderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Receive')),
      body: order.when(
        data: (po) => _ReceiveForm(order: po),
        loading: () => const LoadingView(message: 'Loading purchase order…'),
        error: (error, _) => ErrorStateView(
          message: '$error',
          onRetry: () =>
              ref.invalidate(purchaseOrderDetailProvider(purchaseOrderId)),
        ),
      ),
    );
  }
}

class _ReceiveForm extends ConsumerStatefulWidget {
  const _ReceiveForm({required this.order});

  final PurchaseOrder order;

  @override
  ConsumerState<_ReceiveForm> createState() => _ReceiveFormState();
}

class _ReceiveFormState extends ConsumerState<_ReceiveForm> {
  /// One controller per receivable line, keyed by line id, seeded with the
  /// remaining quantity so the common "receive everything" path is one tap.
  late final Map<int, TextEditingController> _controllers;
  bool _submitting = false;

  List<PurchaseOrderItem> get _lines => widget.order.receivableItems;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final line in _lines)
        line.id: TextEditingController(text: '${line.remainingQuantity}'),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Collects valid receive lines, or returns null after showing a message when
  /// a quantity is invalid (non-numeric or exceeds what's remaining).
  List<ReceiveLine>? _collectLines() {
    final lines = <ReceiveLine>[];
    for (final item in _lines) {
      final raw = _controllers[item.id]!.text.trim();
      if (raw.isEmpty) continue;
      final qty = int.tryParse(raw);
      if (qty == null || qty < 0) {
        _notify('Enter a valid quantity for ${item.productName}.');
        return null;
      }
      if (qty > item.remainingQuantity) {
        _notify('${item.productName}: cannot receive more than '
            '${item.remainingQuantity} remaining.');
        return null;
      }
      if (qty > 0) {
        lines.add(ReceiveLine(itemId: item.id, quantityToReceive: qty));
      }
    }
    return lines;
  }

  Future<void> _submit() async {
    final lines = _collectLines();
    if (lines == null) return;
    if (lines.isEmpty) {
      _notify('Enter a quantity on at least one line to receive.');
      return;
    }

    setState(() => _submitting = true);
    final repository = ref.read(receivingRepositoryProvider);
    final result = await repository.receive(widget.order.id, lines);
    if (!mounted) return;
    setState(() => _submitting = false);

    switch (result) {
      case ApiSuccess():
        ref.invalidate(receivablePurchaseOrdersProvider);
        ref.invalidate(purchaseOrderDetailProvider(widget.order.id));
        _notify('Stock received. An inspection was started automatically.');
        Navigator.of(context).pop();
      case ApiFailure(:final message):
        _notify(message);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final status = ReceivingStatusUi.of(order);
    final lines = _lines;

    if (lines.isEmpty) {
      return const EmptyStateView(
        icon: Icons.inventory_2_outlined,
        title: 'Nothing left to receive.',
        message: 'Every line on this purchase order is fully received.',
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _HeaderCard(order: order, status: status),
              const SizedBox(height: AppSpacing.lg),
              for (final line in lines) ...[
                _LineCard(item: line, controller: _controllers[line.id]!),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_submitting ? 'Receiving…' : 'Receive stock'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.order, required this.status});

  final PurchaseOrder order;
  final ReceivingStatusUi status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.poNumber,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontFamily: 'FiraCode'),
                      ),
                      Text(
                        order.supplierName ?? 'Unknown supplier',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            StatusPill(tone: status.tone, label: status.label, icon: status.icon),
          ],
        ),
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({required this.item, required this.controller});

  final PurchaseOrderItem item;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.productName,
              style: theme.textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              item.sku,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontFamily: 'FiraCode',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _QtyStat(
                    label: 'Ordered',
                    value: '${item.quantityOrdered}',
                  ),
                ),
                Expanded(
                  child: _QtyStat(
                    label: 'Received',
                    value: '${item.quantityReceived}',
                  ),
                ),
                Expanded(
                  child: _QtyStat(
                    label: 'Remaining',
                    value: '${item.remainingQuantity}',
                    emphasize: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Quantity to receive',
                prefixIcon: Icon(Icons.add_box_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyStat extends StatelessWidget {
  const _QtyStat({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

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
        Text(
          label,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontFamily: 'FiraCode',
            fontWeight: FontWeight.w600,
            color: emphasize ? scheme.primary : null,
          ),
        ),
      ],
    );
  }
}
