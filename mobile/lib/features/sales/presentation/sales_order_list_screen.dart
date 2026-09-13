import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../../warehouse_context/domain/warehouse.dart';
import '../application/sales_order_providers.dart';
import '../domain/sales_order.dart';
import 'sales_order_detail_screen.dart';
import 'sales_order_status_ui.dart';

/// Sales orders (spec §46 checklist item 7, 0034) — what a customer ordered,
/// before fulfillment starts. Distinct from shipment plans (an already-
/// committed shipment feeding picking/packing/shipping); this module never
/// moves stock.
class SalesOrderListScreen extends ConsumerStatefulWidget {
  const SalesOrderListScreen({super.key});

  @override
  ConsumerState<SalesOrderListScreen> createState() => _SalesOrderListScreenState();
}

class _SalesOrderListScreenState extends ConsumerState<SalesOrderListScreen> {
  bool _busy = false;

  void _snack(String message, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: danger ? Theme.of(context).colorScheme.error : null,
      ));
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final WarehouseOverview overview;
    try {
      overview = await ref.read(warehouseOverviewProvider.future);
    } catch (_) {
      _snack(l10n.soNeedsWarehouse, danger: true);
      return;
    }
    if (!mounted) return;
    if (overview.warehouses.isEmpty) {
      _snack(l10n.soNeedsWarehouse, danger: true);
      return;
    }

    final draft = await showModalBottomSheet<_SalesOrderDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateSalesOrderSheet(
        warehouses: overview.warehouses,
        initialWarehouseId: ref.read(activeWarehouseIdProvider),
      ),
    );
    if (draft == null || !mounted) return;

    setState(() => _busy = true);
    final result = await ref.read(salesOrderRepositoryProvider).create(
          customerName: draft.customerName,
          warehouseId: draft.warehouseId,
          lines: draft.lines,
          requestedShipDate: draft.requestedShipDate,
          note: draft.note,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (id) {
        ref.invalidate(salesOrderListProvider);
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SalesOrderDetailScreen(salesOrderId: id),
        ));
      },
      failure: (f) => _snack(f.message, danger: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(salesOrderListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.soTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _create,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.point_of_sale_outlined),
        label: Text(_busy ? l10n.working : l10n.soNew),
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(salesOrderListProvider),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return EmptyStateView(
              icon: Icons.receipt_long_outlined,
              title: l10n.soEmpty,
              message: l10n.soEmptyBody,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(salesOrderListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl * 2),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) => _SalesOrderCard(order: orders[i]),
            ),
          );
        },
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
    final ui = SalesOrderStatusUi.of(l10n, order.status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SalesOrderDetailScreen(salesOrderId: order.id),
        )),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              StatusAvatar(tone: ui.tone, icon: ui.icon),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.soNumber ?? '#${order.id}',
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.customerName,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusPill(tone: ui.tone, label: ui.label, dense: true),
                  const SizedBox(height: 4),
                  Text(
                    l10n.lineCount(order.totalLineCount),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SalesOrderDraft {
  const _SalesOrderDraft({
    required this.customerName,
    required this.warehouseId,
    required this.lines,
    this.requestedShipDate,
    this.note,
  });

  final String customerName;
  final int warehouseId;
  final List<SalesOrderLineDraft> lines;
  final DateTime? requestedShipDate;
  final String? note;
}

class _CreateSalesOrderSheet extends StatefulWidget {
  const _CreateSalesOrderSheet({
    required this.warehouses,
    this.initialWarehouseId,
  });

  final List<Warehouse> warehouses;
  final int? initialWarehouseId;

  @override
  State<_CreateSalesOrderSheet> createState() => _CreateSalesOrderSheetState();
}

class _CreateSalesOrderSheetState extends State<_CreateSalesOrderSheet> {
  final _customerName = TextEditingController();
  final _note = TextEditingController();
  late int _warehouseId = widget.warehouses.any((w) => w.id == widget.initialWarehouseId)
      ? widget.initialWarehouseId!
      : widget.warehouses.first.id;
  DateTime? _requestedShipDate;
  final List<SalesOrderLineDraft> _lines = [];
  String? _error;

  @override
  void dispose() {
    _customerName.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _addLine() async {
    final draft = await showDialog<SalesOrderLineDraft>(
      context: context,
      builder: (_) => const _AddLineDialog(),
    );
    if (draft == null) return;
    setState(() {
      _lines.add(draft);
      _error = null;
    });
  }

  Future<void> _pickShipDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _requestedShipDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _requestedShipDate = picked);
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    if (_customerName.text.trim().isEmpty) {
      setState(() => _error = l10n.soCustomerRequired);
      return;
    }
    if (_lines.isEmpty) {
      setState(() => _error = l10n.soLineRequired);
      return;
    }
    Navigator.pop(
      context,
      _SalesOrderDraft(
        customerName: _customerName.text.trim(),
        warehouseId: _warehouseId,
        lines: _lines,
        requestedShipDate: _requestedShipDate,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(l10n.soNew, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _customerName,
              decoration: InputDecoration(labelText: l10n.soCustomerName),
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<int>(
              initialValue: _warehouseId,
              decoration: InputDecoration(labelText: l10n.soWarehouse),
              items: [
                for (final w in widget.warehouses)
                  DropdownMenuItem(value: w.id, child: Text(w.name)),
              ],
              onChanged: (v) => setState(() => _warehouseId = v ?? _warehouseId),
            ),
            const SizedBox(height: AppSpacing.lg),
            InkWell(
              onTap: _pickShipDate,
              child: InputDecorator(
                decoration: InputDecoration(labelText: l10n.soRequestedShipDate),
                child: Text(_requestedShipDate == null
                    ? '—'
                    : '${_requestedShipDate!.year}-${_requestedShipDate!.month.toString().padLeft(2, '0')}-${_requestedShipDate!.day.toString().padLeft(2, '0')}'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Text(l10n.soLinesTitle, style: theme.textTheme.labelLarge),
                ),
                TextButton.icon(
                  onPressed: _addLine,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.soAddLine),
                ),
              ],
            ),
            for (final line in _lines)
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  dense: true,
                  title: Text(line.productName.isNotEmpty ? line.productName : line.janCode),
                  subtitle: Text(line.janCode,
                      style: const TextStyle(fontFamily: AppFonts.mono)),
                  trailing: Text('${line.quantity}',
                      style: const TextStyle(
                          fontFamily: AppFonts.mono, fontWeight: FontWeight.w600)),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _note,
              decoration: InputDecoration(labelText: l10n.soNote),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              height: AppSpacing.minTouch,
              child: FilledButton(onPressed: _submit, child: Text(l10n.soCreate)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddLineDialog extends StatefulWidget {
  const _AddLineDialog();

  @override
  State<_AddLineDialog> createState() => _AddLineDialogState();
}

class _AddLineDialogState extends State<_AddLineDialog> {
  final _jan = TextEditingController();
  final _productName = TextEditingController();
  final _quantity = TextEditingController();
  final _unitPrice = TextEditingController();

  @override
  void dispose() {
    _jan.dispose();
    _productName.dispose();
    _quantity.dispose();
    _unitPrice.dispose();
    super.dispose();
  }

  void _submit() {
    final jan = _jan.text.trim();
    final qty = int.tryParse(_quantity.text.trim()) ?? 0;
    if (jan.isEmpty || qty <= 0) return;
    Navigator.pop(
      context,
      SalesOrderLineDraft(
        janCode: jan,
        quantity: qty,
        productName: _productName.text.trim(),
        unitPrice: double.tryParse(_unitPrice.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.soAddLine),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _jan,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: l10n.soLineJan),
              style: const TextStyle(fontFamily: AppFonts.mono),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _productName,
              decoration: InputDecoration(labelText: l10n.soLineProductName),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _quantity,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: l10n.soLineQuantity),
              style: const TextStyle(fontFamily: AppFonts.mono),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _unitPrice,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(labelText: l10n.soLineUnitPrice),
              style: const TextStyle(fontFamily: AppFonts.mono),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.soAddLine)),
      ],
    );
  }
}
