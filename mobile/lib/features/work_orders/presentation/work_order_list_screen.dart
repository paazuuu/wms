import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../../warehouse_context/domain/warehouse.dart';
import '../application/work_order_providers.dart';
import '../domain/work_order.dart';
import 'work_order_detail_screen.dart';
import 'work_order_status_ui.dart';

/// Work orders / kitting / assembly (spec §46 checklist item 9, 0036) —
/// consume a set of component JANs, produce one output JAN, inside one
/// warehouse. Unlike purchase/sales orders, completing one moves stock.
class WorkOrderListScreen extends ConsumerStatefulWidget {
  const WorkOrderListScreen({super.key});

  @override
  ConsumerState<WorkOrderListScreen> createState() => _WorkOrderListScreenState();
}

class _WorkOrderListScreenState extends ConsumerState<WorkOrderListScreen> {
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
      _snack(l10n.woNeedsWarehouse, danger: true);
      return;
    }
    if (!mounted) return;
    if (overview.warehouses.isEmpty) {
      _snack(l10n.woNeedsWarehouse, danger: true);
      return;
    }

    final draft = await showModalBottomSheet<_WorkOrderDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateWorkOrderSheet(
        warehouses: overview.warehouses,
        initialWarehouseId: ref.read(activeWarehouseIdProvider),
      ),
    );
    if (draft == null || !mounted) return;

    setState(() => _busy = true);
    final result = await ref.read(workOrderRepositoryProvider).create(
          warehouseId: draft.warehouseId,
          outputJanCode: draft.outputJanCode,
          outputQuantity: draft.outputQuantity,
          components: draft.components,
          outputProductName: draft.outputProductName,
          note: draft.note,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (id) {
        ref.invalidate(workOrderListProvider);
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => WorkOrderDetailScreen(workOrderId: id),
        ));
      },
      failure: (f) => _snack(f.message, danger: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(workOrderListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.woTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _create,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.precision_manufacturing_outlined),
        label: Text(_busy ? l10n.working : l10n.woNew),
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(workOrderListProvider),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return EmptyStateView(
              icon: Icons.precision_manufacturing_outlined,
              title: l10n.woEmpty,
              message: l10n.woEmptyBody,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(workOrderListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl * 2),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) => _WorkOrderCard(order: orders[i]),
            ),
          );
        },
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
    final l10n = AppLocalizations.of(context);
    final ui = WorkOrderStatusUi.of(l10n, order.status);
    final title = order.outputProductName.isNotEmpty
        ? order.outputProductName
        : order.outputJanCode;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => WorkOrderDetailScreen(workOrderId: order.id),
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
                      order.woNumber ?? '#${order.id}',
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$title × ${order.outputQuantity}',
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
                    l10n.woComponentCount(order.totalComponentCount),
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

class _WorkOrderDraft {
  const _WorkOrderDraft({
    required this.warehouseId,
    required this.outputJanCode,
    required this.outputQuantity,
    required this.components,
    this.outputProductName,
    this.note,
  });

  final int warehouseId;
  final String outputJanCode;
  final int outputQuantity;
  final List<WorkOrderComponentDraft> components;
  final String? outputProductName;
  final String? note;
}

class _CreateWorkOrderSheet extends StatefulWidget {
  const _CreateWorkOrderSheet({
    required this.warehouses,
    this.initialWarehouseId,
  });

  final List<Warehouse> warehouses;
  final int? initialWarehouseId;

  @override
  State<_CreateWorkOrderSheet> createState() => _CreateWorkOrderSheetState();
}

class _CreateWorkOrderSheetState extends State<_CreateWorkOrderSheet> {
  final _outputJan = TextEditingController();
  final _outputName = TextEditingController();
  final _outputQuantity = TextEditingController();
  final _note = TextEditingController();
  late int _warehouseId = widget.warehouses.any((w) => w.id == widget.initialWarehouseId)
      ? widget.initialWarehouseId!
      : widget.warehouses.first.id;
  final List<WorkOrderComponentDraft> _components = [];
  String? _error;

  @override
  void dispose() {
    _outputJan.dispose();
    _outputName.dispose();
    _outputQuantity.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _addComponent() async {
    final draft = await showDialog<WorkOrderComponentDraft>(
      context: context,
      builder: (_) => const _AddComponentDialog(),
    );
    if (draft == null) return;
    setState(() {
      _components.add(draft);
      _error = null;
    });
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final outputJan = _outputJan.text.trim();
    final outputQty = int.tryParse(_outputQuantity.text.trim()) ?? 0;
    if (outputJan.isEmpty || outputQty <= 0) {
      setState(() => _error = l10n.woOutputRequired);
      return;
    }
    if (_components.isEmpty) {
      setState(() => _error = l10n.woComponentRequired);
      return;
    }
    Navigator.pop(
      context,
      _WorkOrderDraft(
        warehouseId: _warehouseId,
        outputJanCode: outputJan,
        outputQuantity: outputQty,
        outputProductName: _outputName.text.trim(),
        components: _components,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(l10n.woNew, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<int>(
              initialValue: _warehouseId,
              decoration: InputDecoration(labelText: l10n.woWarehouse),
              items: [
                for (final w in widget.warehouses)
                  DropdownMenuItem(value: w.id, child: Text(w.name)),
              ],
              onChanged: (v) => setState(() => _warehouseId = v ?? _warehouseId),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.woOutputTitle, style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _outputJan,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: l10n.woLineJan),
              style: const TextStyle(fontFamily: AppFonts.mono),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _outputName,
              decoration: InputDecoration(labelText: l10n.woLineProductName),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _outputQuantity,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: l10n.woOutputQuantity),
              style: const TextStyle(fontFamily: AppFonts.mono),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child:
                      Text(l10n.woComponentsTitle, style: theme.textTheme.labelLarge),
                ),
                TextButton.icon(
                  onPressed: _addComponent,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.woAddComponent),
                ),
              ],
            ),
            for (final component in _components)
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  dense: true,
                  title: Text(component.productName.isNotEmpty
                      ? component.productName
                      : component.janCode),
                  subtitle: Text(component.janCode,
                      style: const TextStyle(fontFamily: AppFonts.mono)),
                  trailing: Text('${component.quantityRequired}',
                      style: const TextStyle(
                          fontFamily: AppFonts.mono, fontWeight: FontWeight.w600)),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _note,
              decoration: InputDecoration(labelText: l10n.woNote),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              height: AppSpacing.minTouch,
              child: FilledButton(onPressed: _submit, child: Text(l10n.woCreate)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddComponentDialog extends StatefulWidget {
  const _AddComponentDialog();

  @override
  State<_AddComponentDialog> createState() => _AddComponentDialogState();
}

class _AddComponentDialogState extends State<_AddComponentDialog> {
  final _jan = TextEditingController();
  final _productName = TextEditingController();
  final _quantity = TextEditingController();

  @override
  void dispose() {
    _jan.dispose();
    _productName.dispose();
    _quantity.dispose();
    super.dispose();
  }

  void _submit() {
    final jan = _jan.text.trim();
    final qty = int.tryParse(_quantity.text.trim()) ?? 0;
    if (jan.isEmpty || qty <= 0) return;
    Navigator.pop(
      context,
      WorkOrderComponentDraft(
        janCode: jan,
        quantityRequired: qty,
        productName: _productName.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.woAddComponent),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _jan,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: l10n.woLineJan),
            style: const TextStyle(fontFamily: AppFonts.mono),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _productName,
            decoration: InputDecoration(labelText: l10n.woLineProductName),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _quantity,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: l10n.woComponentQuantity),
            style: const TextStyle(fontFamily: AppFonts.mono),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.woAddComponent)),
      ],
    );
  }
}
