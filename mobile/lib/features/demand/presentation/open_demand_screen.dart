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
import 'purchase_from_demand_page.dart';

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

    final drafts = await Navigator.of(context).push<List<SupplierPurchaseDraft>>(
      MaterialPageRoute(builder: (_) => PurchaseFromDemandPage(items: chosen)),
    );
    if (drafts == null || drafts.isEmpty || !mounted) return;

    setState(() => _busy = true);
    final repo = ref.read(demandRepositoryProvider);
    final created = <int>[];
    String? error;
    // One purchase order per supplier; a failure stops the rest so nothing is
    // half-created silently.
    for (final draft in drafts) {
      final result = await repo.createPurchaseOrder(
        supplierName: draft.supplierName,
        supplierId: draft.supplierId,
        warehouseId: warehouseId,
        lines: draft.lines,
      );
      result.when(
        success: (r) => created.add(r.purchaseOrderId),
        failure: (f) => error = f.message,
      );
      if (error != null) break;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (created.isNotEmpty) {
      _selected.clear();
      _refresh();
      ref.invalidate(purchaseOrderListProvider);
    }
    if (error != null) {
      _snack(humanizeApiErrorMessage(l10n, error!), danger: true);
      return;
    }
    _snack(l10n.demandPosCreated(created.length));
    if (created.length == 1) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PurchaseOrderDetailScreen(purchaseOrderId: created.single),
      ));
    }
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
                    label: l10n.demandIncomingAhead,
                    value: nf.format(sum((i) => i.incomingUnlinked)))),
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

    final (tone, pill) = item.isAheadOnly
        ? (StatusTone.neutral, l10n.demandAheadOnly)
        : item.toPurchase > 0
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
          if (item.incomingOrders.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.incomingUnlinked > 0
                        ? l10n.demandIncomingBreakdownAhead(item.incoming, item.incomingUnlinked)
                        : l10n.demandIncomingBreakdown(item.incoming),
                    style: theme.textTheme.labelMedium,
                  ),
                  for (final po in item.incomingOrders)
                    Text(
                      [
                        po.poNumber ?? '#${po.purchaseOrderId}',
                        if (po.supplierName.isNotEmpty) po.supplierName,
                        po.unlinked > 0
                            ? l10n.demandIncomingPoAhead(po.outstanding, po.unlinked)
                            : l10n.demandIncomingPo(po.outstanding),
                      ].join(' · '),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
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
          if (item.lines.isEmpty)
            const SizedBox(height: AppSpacing.md)
          else
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
