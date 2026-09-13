import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../../warehouse_context/domain/warehouse.dart';
import '../application/purchase_order_providers.dart';
import '../domain/purchase_order.dart';
import 'purchase_order_detail_screen.dart';
import 'purchase_order_status_ui.dart';

/// Purchase orders (spec §46 checklist item 6, 0033) — what was ordered from
/// a supplier, before it ships. Distinct from delivery plans (already-shipped
/// deliveries used for QC reconciliation); this module never moves stock.
class PurchaseOrderListScreen extends ConsumerStatefulWidget {
  const PurchaseOrderListScreen({super.key});

  @override
  ConsumerState<PurchaseOrderListScreen> createState() =>
      _PurchaseOrderListScreenState();
}

class _PurchaseOrderListScreenState extends ConsumerState<PurchaseOrderListScreen> {
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
      _snack(l10n.poNeedsWarehouse, danger: true);
      return;
    }
    if (!mounted) return;
    if (overview.warehouses.isEmpty) {
      _snack(l10n.poNeedsWarehouse, danger: true);
      return;
    }

    final draft = await showModalBottomSheet<_PurchaseOrderDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreatePurchaseOrderSheet(
        warehouses: overview.warehouses,
        initialWarehouseId: ref.read(activeWarehouseIdProvider),
      ),
    );
    if (draft == null || !mounted) return;

    setState(() => _busy = true);
    final result = await ref.read(purchaseOrderRepositoryProvider).create(
          supplierName: draft.supplierName,
          warehouseId: draft.warehouseId,
          lines: draft.lines,
          expectedDate: draft.expectedDate,
          note: draft.note,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (id) {
        ref.invalidate(purchaseOrderListProvider);
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PurchaseOrderDetailScreen(purchaseOrderId: id),
        ));
      },
      failure: (f) => _snack(f.message, danger: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(purchaseOrderListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.poTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _create,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.add_shopping_cart_outlined),
        label: Text(_busy ? l10n.working : l10n.poNew),
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(purchaseOrderListProvider),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return EmptyStateView(
              icon: Icons.shopping_cart_outlined,
              title: l10n.poEmpty,
              message: l10n.poEmptyBody,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(purchaseOrderListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl * 2),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) => _PurchaseOrderCard(order: orders[i]),
            ),
          );
        },
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
    final l10n = AppLocalizations.of(context);
    final ui = PurchaseOrderStatusUi.of(l10n, order.status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PurchaseOrderDetailScreen(purchaseOrderId: order.id),
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
                      order.poNumber ?? '#${order.id}',
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.supplierName,
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

class _PurchaseOrderDraft {
  const _PurchaseOrderDraft({
    required this.supplierName,
    required this.warehouseId,
    required this.lines,
    this.expectedDate,
    this.note,
  });

  final String supplierName;
  final int warehouseId;
  final List<PurchaseOrderLineDraft> lines;
  final DateTime? expectedDate;
  final String? note;
}

class _CreatePurchaseOrderSheet extends StatefulWidget {
  const _CreatePurchaseOrderSheet({
    required this.warehouses,
    this.initialWarehouseId,
  });

  final List<Warehouse> warehouses;
  final int? initialWarehouseId;

  @override
  State<_CreatePurchaseOrderSheet> createState() =>
      _CreatePurchaseOrderSheetState();
}

class _CreatePurchaseOrderSheetState extends State<_CreatePurchaseOrderSheet> {
  final _supplierName = TextEditingController();
  final _note = TextEditingController();
  late int _warehouseId = widget.warehouses.any((w) => w.id == widget.initialWarehouseId)
      ? widget.initialWarehouseId!
      : widget.warehouses.first.id;
  DateTime? _expectedDate;
  final List<PurchaseOrderLineDraft> _lines = [];
  String? _error;

  @override
  void dispose() {
    _supplierName.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _addLine() async {
    final draft = await showDialog<PurchaseOrderLineDraft>(
      context: context,
      builder: (_) => const _AddLineDialog(),
    );
    if (draft == null) return;
    setState(() {
      _lines.add(draft);
      _error = null;
    });
  }

  Future<void> _pickExpectedDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _expectedDate = picked);
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    if (_supplierName.text.trim().isEmpty) {
      setState(() => _error = l10n.poSupplierRequired);
      return;
    }
    if (_lines.isEmpty) {
      setState(() => _error = l10n.poLineRequired);
      return;
    }
    Navigator.pop(
      context,
      _PurchaseOrderDraft(
        supplierName: _supplierName.text.trim(),
        warehouseId: _warehouseId,
        lines: _lines,
        expectedDate: _expectedDate,
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
            Text(l10n.poNew, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _supplierName,
              decoration: InputDecoration(labelText: l10n.poSupplierName),
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<int>(
              initialValue: _warehouseId,
              decoration: InputDecoration(labelText: l10n.poWarehouse),
              items: [
                for (final w in widget.warehouses)
                  DropdownMenuItem(value: w.id, child: Text(w.name)),
              ],
              onChanged: (v) => setState(() => _warehouseId = v ?? _warehouseId),
            ),
            const SizedBox(height: AppSpacing.lg),
            InkWell(
              onTap: _pickExpectedDate,
              child: InputDecorator(
                decoration: InputDecoration(labelText: l10n.poExpectedDate),
                child: Text(_expectedDate == null
                    ? '—'
                    : '${_expectedDate!.year}-${_expectedDate!.month.toString().padLeft(2, '0')}-${_expectedDate!.day.toString().padLeft(2, '0')}'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Text(l10n.poLinesTitle, style: theme.textTheme.labelLarge),
                ),
                TextButton.icon(
                  onPressed: _addLine,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.poAddLine),
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
              decoration: InputDecoration(labelText: l10n.poNote),
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
              child: FilledButton(onPressed: _submit, child: Text(l10n.poCreate)),
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
      PurchaseOrderLineDraft(
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
      title: Text(l10n.poAddLine),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _jan,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: l10n.poLineJan),
              style: const TextStyle(fontFamily: AppFonts.mono),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _productName,
              decoration: InputDecoration(labelText: l10n.poLineProductName),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _quantity,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: l10n.poLineQuantity),
              style: const TextStyle(fontFamily: AppFonts.mono),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _unitPrice,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(labelText: l10n.poLineUnitPrice),
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
        FilledButton(onPressed: _submit, child: Text(l10n.poAddLine)),
      ],
    );
  }
}
