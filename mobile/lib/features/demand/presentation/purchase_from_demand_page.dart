import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/open_demand.dart';

/// One purchase order to raise: every product going to one supplier.
class SupplierPurchaseDraft {
  const SupplierPurchaseDraft({
    required this.supplierName,
    required this.lines,
    this.supplierId,
  });

  final String supplierName;
  final int? supplierId;
  final List<DemandPurchaseLine> lines;
}

/// One supplier's share of one product, and which waiting orders it is for.
class _Row {
  _Row({required String supplier, required int quantity, required this.item})
      : supplier = TextEditingController(text: supplier),
        quantity = TextEditingController(text: quantity > 0 ? '$quantity' : '');

  final OpenDemandItem item;
  final TextEditingController supplier;
  final TextEditingController quantity;
  final Map<int, TextEditingController> links = {};

  int get qty => int.tryParse(quantity.text.trim()) ?? 0;

  int linkOf(int lineId) => int.tryParse(links[lineId]?.text.trim() ?? '') ?? 0;

  int get linked => item.lines.fold(0, (s, l) => s + linkOf(l.salesOrderLineId));

  void setLinks(List<DemandLink> value) {
    for (final l in item.lines) {
      final q = value
          .where((d) => d.salesOrderLineId == l.salesOrderLineId)
          .fold(0, (s, d) => s + d.quantity);
      (links[l.salesOrderLineId] ??= TextEditingController()).text = q > 0 ? '$q' : '';
    }
  }

  void dispose() {
    supplier.dispose();
    quantity.dispose();
    for (final c in links.values) {
      c.dispose();
    }
  }
}

/// Buying for waiting orders, the way it is actually done: a product may be
/// split across suppliers, and each supplier's share is linked by hand to the
/// orders it is for — starting from the oldest-first split, freely changed.
/// Whatever a share is not linked to is bought ahead (見込み): it still counts
/// as incoming, and once it lands it goes to whichever order comes next.
///
/// Pops a list of [SupplierPurchaseDraft], one per supplier.
class PurchaseFromDemandPage extends StatefulWidget {
  const PurchaseFromDemandPage({super.key, required this.items});

  final List<OpenDemandItem> items;

  @override
  State<PurchaseFromDemandPage> createState() => _PurchaseFromDemandPageState();
}

class _PurchaseFromDemandPageState extends State<PurchaseFromDemandPage> {
  late final Map<int, List<_Row>> _rows = {
    for (final item in widget.items) item.productId: [_firstRow(item)],
  };

  _Row _firstRow(OpenDemandItem item) {
    final quantity = item.toPurchase > 0 ? item.toPurchase : item.backordered;
    final row = _Row(
      supplier: item.preferredSupplierName ?? '',
      quantity: quantity,
      item: item,
    );
    row.setLinks(defaultDemandLinks(
        lines: item.lines, quantity: quantity, freeStock: item.available));
    return row;
  }

  @override
  void dispose() {
    for (final rows in _rows.values) {
      for (final r in rows) {
        r.dispose();
      }
    }
    super.dispose();
  }

  /// What the other rows of the same product already link to each order line.
  Map<int, int> _takenBy(OpenDemandItem item, _Row except) {
    final taken = <int, int>{};
    for (final r in _rows[item.productId]!) {
      if (identical(r, except)) continue;
      for (final l in item.lines) {
        taken[l.salesOrderLineId] = (taken[l.salesOrderLineId] ?? 0) + r.linkOf(l.salesOrderLineId);
      }
    }
    return taken;
  }

  void _autoLink(OpenDemandItem item, _Row row) {
    setState(() => row.setLinks(defaultDemandLinks(
          lines: item.lines,
          quantity: row.qty,
          freeStock: item.available,
          taken: _takenBy(item, row),
        )));
  }

  void _split(OpenDemandItem item) {
    setState(() {
      final row = _Row(supplier: '', quantity: 0, item: item);
      row.setLinks(const []);
      _rows[item.productId]!.add(row);
    });
  }

  void _removeRow(OpenDemandItem item, _Row row) {
    setState(() {
      _rows[item.productId]!.remove(row);
      row.dispose();
    });
  }

  /// A problem with one row, or null when it is fine.
  String? _rowError(AppLocalizations l10n, OpenDemandItem item, _Row row) {
    if (row.qty > 0 && row.supplier.text.trim().isEmpty) return l10n.demandPoNeedSupplier;
    if (row.linked > row.qty) return l10n.demandPoOverLinked(row.linked, row.qty);
    return null;
  }

  /// An order line linked for more than it is waiting for, across all rows.
  String? _lineError(AppLocalizations l10n, OpenDemandItem item, OpenDemandLine line) {
    final total = _rows[item.productId]!
        .fold(0, (s, r) => s + r.linkOf(line.salesOrderLineId));
    return total > line.backordered ? l10n.demandPoLineOverLinked(line.backordered) : null;
  }

  bool get _valid {
    final l10n = AppLocalizations.of(context);
    var any = false;
    for (final item in widget.items) {
      for (final row in _rows[item.productId]!) {
        if (_rowError(l10n, item, row) != null) return false;
        if (row.qty > 0) any = true;
      }
      for (final line in item.lines) {
        if (_lineError(l10n, item, line) != null) return false;
      }
    }
    return any;
  }

  void _submit() {
    final bySupplier = <String, Map<String, DemandPurchaseLine>>{};
    final ids = <String, int?>{};
    for (final item in widget.items) {
      for (final row in _rows[item.productId]!) {
        if (row.qty <= 0) continue;
        final name = row.supplier.text.trim();
        // The partner record only when the name is the one it prefilled.
        final id = name == item.preferredSupplierName ? item.preferredSupplierId : null;
        ids[name] = ids.containsKey(name) ? (ids[name] == id ? id : null) : id;
        final demands = [
          for (final l in item.lines)
            if (row.linkOf(l.salesOrderLineId) > 0)
              DemandLink(salesOrderLineId: l.salesOrderLineId, quantity: row.linkOf(l.salesOrderLineId)),
        ];
        final lines = bySupplier.putIfAbsent(name, () => {});
        final existing = lines[item.janCode];
        // One product twice for one supplier is one line on that order.
        lines[item.janCode] = existing == null
            ? DemandPurchaseLine(
                janCode: item.janCode,
                productName: item.productName,
                quantity: row.qty,
                demands: demands,
              )
            : DemandPurchaseLine(
                janCode: item.janCode,
                productName: item.productName,
                quantity: existing.quantity + row.qty,
                demands: _merge(existing.demands ?? const [], demands),
              );
      }
    }
    Navigator.pop(context, [
      for (final e in bySupplier.entries)
        SupplierPurchaseDraft(
            supplierName: e.key, supplierId: ids[e.key], lines: e.value.values.toList()),
    ]);
  }

  static List<DemandLink> _merge(List<DemandLink> a, List<DemandLink> b) {
    final sum = <int, int>{};
    for (final d in [...a, ...b]) {
      sum[d.salesOrderLineId] = (sum[d.salesOrderLineId] ?? 0) + d.quantity;
    }
    return [for (final e in sum.entries) DemandLink(salesOrderLineId: e.key, quantity: e.value)];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final suppliers = {
      for (final rows in _rows.values)
        for (final r in rows)
          if (r.qty > 0 && r.supplier.text.trim().isNotEmpty) r.supplier.text.trim(),
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.demandPoTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(l10n.demandPoHint, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          for (final item in widget.items) ...[
            _ProductCard(
              item: item,
              rows: _rows[item.productId]!,
              rowError: (row) => _rowError(l10n, item, row),
              lineError: (line) => _lineError(l10n, item, line),
              onChanged: () => setState(() {}),
              onAutoLink: (row) => _autoLink(item, row),
              onSplit: () => _split(item),
              onRemove: (row) => _removeRow(item, row),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            height: AppSpacing.minTouch,
            child: FilledButton.icon(
              onPressed: _valid ? _submit : null,
              icon: const Icon(Icons.add_shopping_cart_outlined),
              label: Text(l10n.demandPoCreateN(suppliers.isEmpty ? 1 : suppliers.length)),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.item,
    required this.rows,
    required this.rowError,
    required this.lineError,
    required this.onChanged,
    required this.onAutoLink,
    required this.onSplit,
    required this.onRemove,
  });

  final OpenDemandItem item;
  final List<_Row> rows;
  final String? Function(_Row) rowError;
  final String? Function(OpenDemandLine) lineError;
  final VoidCallback onChanged;
  final ValueChanged<_Row> onAutoLink;
  final VoidCallback onSplit;
  final ValueChanged<_Row> onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = rows.fold(0, (s, r) => s + r.qty);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.displayName, style: theme.textTheme.titleSmall),
            Text(
              l10n.demandPoProductHint(item.backordered, item.toPurchase, item.incoming),
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            for (var i = 0; i < rows.length; i++) ...[
              const Divider(height: AppSpacing.lg),
              _RowEditor(
                item: item,
                row: rows[i],
                index: i,
                error: rowError(rows[i]),
                lineError: lineError,
                onChanged: onChanged,
                onAutoLink: () => onAutoLink(rows[i]),
                onRemove: rows.length > 1 ? () => onRemove(rows[i]) : null,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(l10n.demandPoProductTotal(total),
                      style: theme.textTheme.bodySmall),
                ),
                TextButton.icon(
                  onPressed: onSplit,
                  icon: const Icon(Icons.call_split, size: 18),
                  label: Text(l10n.demandPoSplitSupplier),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RowEditor extends StatelessWidget {
  const _RowEditor({
    required this.item,
    required this.row,
    required this.index,
    required this.error,
    required this.lineError,
    required this.onChanged,
    required this.onAutoLink,
    required this.onRemove,
  });

  final OpenDemandItem item;
  final _Row row;
  final int index;
  final String? error;
  final String? Function(OpenDemandLine) lineError;
  final VoidCallback onChanged;
  final VoidCallback onAutoLink;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ahead = row.qty - row.linked;
    final key = '${item.productId}-$index';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                key: ValueKey('po-supplier-$key'),
                controller: row.supplier,
                decoration: InputDecoration(labelText: l10n.poSupplierName),
                onChanged: (_) => onChanged(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 96,
              child: TextField(
                key: ValueKey('po-qty-$key'),
                controller: row.quantity,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: l10n.demandQuantity),
                onChanged: (_) => onChanged(),
              ),
            ),
            if (onRemove != null)
              IconButton(
                tooltip: l10n.demandPoRemoveRow,
                onPressed: onRemove,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Text(l10n.demandPoLinksTitle, style: theme.textTheme.labelMedium),
            ),
            TextButton(
              onPressed: onAutoLink,
              child: Text(l10n.demandPoAutoLink),
            ),
          ],
        ),
        if (item.lines.isEmpty)
          Text(l10n.demandPoNoWaiting,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        for (final line in item.lines)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [line.soNumber ?? '#${line.salesOrderId}', line.customerName]
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        lineError(line) ??
                            l10n.demandPoLineWaiting(line.backordered, line.onOrder),
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: lineError(line) != null ? scheme.error : null),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: TextField(
                    key: ValueKey('po-link-$key-${line.salesOrderLineId}'),
                    controller: row.links[line.salesOrderLineId],
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.end,
                    decoration: const InputDecoration(isDense: true, hintText: '0'),
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ],
            ),
          ),
        Text(
          error ?? l10n.demandPoRowSummary(row.linked, ahead > 0 ? ahead : 0),
          style: theme.textTheme.bodySmall?.copyWith(color: error != null ? scheme.error : null),
        ),
      ],
    );
  }
}
