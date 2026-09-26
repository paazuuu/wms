import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../purchasing/application/purchase_order_providers.dart';
import '../../purchasing/presentation/purchase_order_detail_screen.dart';
import '../../sales/application/sales_order_providers.dart';
import '../../sales/presentation/sales_order_detail_screen.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../application/demand_providers.dart';
import '../domain/open_demand.dart';

/// The purchasing worklist for an order-first warehouse (0084): every product
/// approved sales orders are still waiting for, how much free stock can cover
/// right now, what is already on its way, and what is left to buy.
///
/// Two actions close the loop: fill from stock (oldest order first, or one
/// order picked by hand), and select products to raise one purchase order
/// covering many sales orders at once.
class OpenDemandScreen extends ConsumerStatefulWidget {
  const OpenDemandScreen({super.key});

  @override
  ConsumerState<OpenDemandScreen> createState() => _OpenDemandScreenState();
}

class _OpenDemandScreenState extends ConsumerState<OpenDemandScreen> {
  final Set<int> _selected = {};
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

  void _refresh() {
    ref.invalidate(openDemandProvider);
    ref.invalidate(salesOrderListProvider);
  }

  Future<void> _fill({int? productId, int? lineId, int? quantity}) async {
    final l10n = AppLocalizations.of(context);
    final warehouseId = ref.read(activeWarehouseIdProvider);
    if (warehouseId == null) return;
    setState(() => _busy = true);
    final result = await ref.read(demandRepositoryProvider).fillBackorders(
          warehouseId: warehouseId,
          productId: productId,
          salesOrderLineId: lineId,
          quantity: quantity,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (fill) {
        _refresh();
        _snack(fill.reservedUnits == 0
            ? l10n.demandNothingToFill
            : l10n.demandFilled(fill.reservedUnits));
      },
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  Future<void> _fillAll() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.demandFillAll),
        content: Text(l10n.demandFillAllQ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.demandFillAll),
          ),
        ],
      ),
    );
    if (ok == true) await _fill();
  }

  Future<void> _fillLine(OpenDemandItem item, OpenDemandLine line) async {
    final max = line.backordered < item.available ? line.backordered : item.available;
    if (max <= 0) return;
    final quantity = await showDialog<int>(
      context: context,
      builder: (_) => _QuantityDialog(
        title: line.soNumber ?? '#${line.salesOrderId}',
        subtitle: line.customerName,
        initial: max,
        max: max,
      ),
    );
    if (quantity == null) return;
    await _fill(lineId: line.salesOrderLineId, quantity: quantity);
  }

  Future<void> _createPurchaseOrder(List<OpenDemandItem> items) async {
    final l10n = AppLocalizations.of(context);
    final warehouseId = ref.read(activeWarehouseIdProvider);
    if (warehouseId == null) return;
    final chosen = items.where((i) => _selected.contains(i.productId)).toList();
    if (chosen.isEmpty) return;

    final draft = await showDialog<_PurchaseDraft>(
      context: context,
      builder: (_) => _PurchaseFromDemandDialog(items: chosen),
    );
    if (draft == null || !mounted) return;

    setState(() => _busy = true);
    final result = await ref.read(demandRepositoryProvider).createPurchaseOrder(
          supplierName: draft.supplierName,
          supplierId: draft.supplierId,
          warehouseId: warehouseId,
          lines: draft.lines,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (created) {
        _selected.clear();
        _refresh();
        ref.invalidate(purchaseOrderListProvider);
        _snack(l10n.demandPoCreated(created.links));
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              PurchaseOrderDetailScreen(purchaseOrderId: created.purchaseOrderId),
        ));
      },
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final warehouseId = ref.watch(activeWarehouseIdProvider);

    if (warehouseId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.demandTitle)),
        body: EmptyStateView(
          icon: Icons.warehouse_outlined,
          title: l10n.replenishmentNoWarehouse,
          message: l10n.demandEmptyBody,
        ),
      );
    }

    final async = ref.watch(openDemandProvider);
    final items = async.valueOrNull ?? const <OpenDemandItem>[];
    final anyFillable = items.any((i) => i.canFillNow > 0);
    // A product that dropped off the list cannot stay selected.
    _selected.removeWhere((id) => !items.any((i) => i.productId == id));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.demandTitle),
        actions: [
          IconButton(
            tooltip: l10n.demandFillAll,
            onPressed: _busy || !anyFillable ? null : _fillAll,
            icon: const Icon(Icons.playlist_add_check),
          ),
        ],
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(openDemandProvider),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return EmptyStateView(
              icon: Icons.assignment_turned_in_outlined,
              title: l10n.demandEmpty,
              message: l10n.demandEmptyBody,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(openDemandProvider),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _Summary(items: rows),
                const SizedBox(height: AppSpacing.md),
                for (final item in rows) ...[
                  _DemandCard(
                    item: item,
                    selected: _selected.contains(item.productId),
                    busy: _busy,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _selected.add(item.productId);
                      } else {
                        _selected.remove(item.productId);
                      }
                    }),
                    onFill: () => _fill(productId: item.productId),
                    onFillLine: (line) => _fillLine(item, line),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _selected.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SizedBox(
                  height: AppSpacing.minTouch,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _createPurchaseOrder(items),
                    icon: const Icon(Icons.add_shopping_cart_outlined),
                    label: Text(l10n.demandCreatePo(_selected.length)),
                  ),
                ),
              ),
            ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.items});

  final List<OpenDemandItem> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nf = NumberFormat.decimalPattern();
    int sum(int Function(OpenDemandItem) f) => items.fold(0, (s, i) => s + f(i));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
                child: _Figure(
                    label: l10n.demandBackordered,
                    value: nf.format(sum((i) => i.backordered)))),
            Expanded(
                child: _Figure(
                    label: l10n.demandCanFillNow,
                    value: nf.format(sum((i) => i.canFillNow)))),
            Expanded(
                child: _Figure(
                    label: l10n.demandIncoming,
                    value: nf.format(sum((i) => i.incoming)))),
            Expanded(
                child: _Figure(
                    label: l10n.demandToPurchase,
                    value: nf.format(sum((i) => i.toPurchase)),
                    emphasize: sum((i) => i.toPurchase) > 0)),
          ],
        ),
      ),
    );
  }
}

class _DemandCard extends StatelessWidget {
  const _DemandCard({
    required this.item,
    required this.selected,
    required this.busy,
    required this.onSelected,
    required this.onFill,
    required this.onFillLine,
  });

  final OpenDemandItem item;
  final bool selected;
  final bool busy;
  final ValueChanged<bool> onSelected;
  final VoidCallback onFill;
  final ValueChanged<OpenDemandLine> onFillLine;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final nf = NumberFormat.decimalPattern();

    final (tone, pill) = item.toPurchase > 0
        ? (StatusTone.warning, l10n.demandNeedsPurchase(item.toPurchase))
        : item.canFillNow > 0
            ? (StatusTone.info, l10n.demandFillable(item.canFillNow))
            : (StatusTone.success, l10n.demandCovered);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs, AppSpacing.sm, AppSpacing.md, 0),
            child: Row(
              children: [
                Checkbox(
                  value: selected,
                  onChanged: busy ? null : (v) => onSelected(v ?? false),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.displayName,
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(item.janCode,
                          style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: AppFonts.mono,
                              color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                StatusPill(tone: tone, label: pill, dense: true),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                    child: _Figure(
                        label: l10n.demandBackordered,
                        value: nf.format(item.backordered))),
                Expanded(
                    child: _Figure(
                        label: l10n.demandAvailable,
                        value: nf.format(item.available))),
                Expanded(
                    child: _Figure(
                        label: l10n.demandIncoming,
                        value: nf.format(item.incoming))),
                Expanded(
                    child: _Figure(
                        label: l10n.demandToPurchase,
                        value: nf.format(item.toPurchase),
                        emphasize: item.toPurchase > 0)),
              ],
            ),
          ),
          if (item.preferredSupplierName != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0),
              child: Text(item.preferredSupplierName!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          if (item.canFillNow > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
              child: OutlinedButton.icon(
                onPressed: busy ? null : onFill,
                icon: const Icon(Icons.move_to_inbox_outlined, size: 18),
                label: Text(l10n.demandFillNow(item.canFillNow)),
              ),
            ),
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              title: Text(l10n.demandWaitingOrders(item.lines.length),
                  style: theme.textTheme.bodyMedium),
              children: [
                for (final line in item.lines)
                  ListTile(
                    dense: true,
                    title: Text(
                      [line.soNumber ?? '#${line.salesOrderId}', line.customerName]
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(l10n.demandLineStatus(
                        line.ordered, line.promised, line.backordered, line.onOrder)),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          SalesOrderDetailScreen(salesOrderId: line.salesOrderId),
                    )),
                    trailing: item.available > 0 && line.backordered > 0
                        ? IconButton(
                            tooltip: l10n.demandLineFill,
                            onPressed: busy ? null : () => onFillLine(line),
                            icon: const Icon(Icons.move_to_inbox_outlined),
                          )
                        : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.emphasize = false});

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
        Text(label,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: AppFonts.mono,
              fontWeight: FontWeight.w600,
              color: emphasize ? scheme.error : null,
            )),
      ],
    );
  }
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({
    required this.title,
    required this.subtitle,
    required this.initial,
    required this.max,
  });

  final String title;
  final String subtitle;
  final int initial;
  final int max;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late final TextEditingController _qty =
      TextEditingController(text: '${widget.initial}');

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  int? get _value {
    final v = int.tryParse(_qty.text.trim());
    return v == null || v <= 0 || v > widget.max ? null : v;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.subtitle.isNotEmpty) Text(widget.subtitle),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _qty,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l10n.demandLineFillQuantity,
              helperText: l10n.demandLineFillMax(widget.max),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _value == null ? null : () => Navigator.pop(context, _value),
          child: Text(l10n.demandLineFill),
        ),
      ],
    );
  }
}

class _PurchaseDraft {
  const _PurchaseDraft({
    required this.supplierName,
    required this.lines,
    this.supplierId,
  });

  final String supplierName;
  final int? supplierId;
  final List<DemandPurchaseLine> lines;
}

/// One purchase order for several products, each defaulting to what is still
/// to buy. Ordering less is allowed on purpose: the rest may be supplied from
/// somewhere else, and the orders it does not cover simply stay waiting.
class _PurchaseFromDemandDialog extends StatefulWidget {
  const _PurchaseFromDemandDialog({required this.items});

  final List<OpenDemandItem> items;

  @override
  State<_PurchaseFromDemandDialog> createState() =>
      _PurchaseFromDemandDialogState();
}

class _PurchaseFromDemandDialogState extends State<_PurchaseFromDemandDialog> {
  late final String? _preferredName;
  late final int? _preferredId;
  late final TextEditingController _supplier;
  late final List<TextEditingController> _qty;

  @override
  void initState() {
    super.initState();
    final ids = widget.items.map((i) => i.preferredSupplierId).toSet();
    // Prefill only when every chosen product comes from the same supplier.
    _preferredId = ids.length == 1 ? ids.first : null;
    _preferredName = _preferredId == null
        ? null
        : widget.items.first.preferredSupplierName;
    _supplier = TextEditingController(text: _preferredName ?? '');
    _qty = [
      for (final i in widget.items)
        TextEditingController(
            text: '${i.toPurchase > 0 ? i.toPurchase : i.backordered}'),
    ];
  }

  @override
  void dispose() {
    _supplier.dispose();
    for (final c in _qty) {
      c.dispose();
    }
    super.dispose();
  }

  List<DemandPurchaseLine>? get _lines {
    final lines = <DemandPurchaseLine>[];
    for (var i = 0; i < widget.items.length; i++) {
      final q = int.tryParse(_qty[i].text.trim()) ?? 0;
      if (q < 0) return null;
      if (q == 0) continue;
      final item = widget.items[i];
      lines.add(DemandPurchaseLine(
          janCode: item.janCode, productName: item.productName, quantity: q));
    }
    return lines.isEmpty ? null : lines;
  }

  bool get _valid => _supplier.text.trim().isNotEmpty && _lines != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.demandPoTitle),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _supplier,
                decoration: InputDecoration(labelText: l10n.poSupplierName),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.demandPoHint,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.md),
              for (var i = 0; i < widget.items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.items[i].displayName,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(
                              l10n.demandPoLineHint(widget.items[i].backordered,
                                  widget.items[i].toPurchase),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      SizedBox(
                        width: 96,
                        child: TextField(
                          key: ValueKey('demand-po-qty-${widget.items[i].productId}'),
                          controller: _qty[i],
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(labelText: l10n.demandQuantity),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: !_valid
              ? null
              : () {
                  final name = _supplier.text.trim();
                  Navigator.pop(
                    context,
                    _PurchaseDraft(
                      supplierName: name,
                      // The partner record only when the name was left as it.
                      supplierId: name == _preferredName ? _preferredId : null,
                      lines: _lines!,
                    ),
                  );
                },
          child: Text(l10n.poCreate),
        ),
      ],
    );
  }
}
