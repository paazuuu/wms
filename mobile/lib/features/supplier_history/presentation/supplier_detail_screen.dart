import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/copy_text.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../product/presentation/product_detail_screen.dart';
import '../../purchase_request/data/purchase_request_repository.dart';
import '../../purchase_request/domain/purchase_request.dart';
import '../../purchase_request/presentation/purchase_request_screen.dart';
import '../../stock_import/presentation/import_view_screen.dart' show openReadingTable;
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/supplier_history_repository.dart';
import '../domain/supplier_history.dart';

final _day = DateFormat('y/MM/dd');
final _num = NumberFormat('#,##0');
final _yen = NumberFormat('#,##0.##');

String _pct(double rate) => NumberFormat('0.#').format(rate * 100);

/// 仕入先から (0143): one supplier — who they are, what we buy from them
/// most, how often and when last, and every purchase. The products bought
/// before come ticked with their last quantity, so the next order is a
/// matter of looking down the list and pressing one button: it becomes an
/// 入荷希望リスト for this supplier, ready to adjust and send as Excel.
class SupplierDetailScreen extends ConsumerStatefulWidget {
  const SupplierDetailScreen({super.key, required this.supplierId, this.today});

  final int supplierId;

  /// For tests: the day "next due" is measured against.
  final DateTime? today;

  @override
  ConsumerState<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends ConsumerState<SupplierDetailScreen> {
  final Set<String> _chosen = {};

  /// Products whose every purchase is shown under them.
  final Set<String> _open = {};
  final Map<String, TextEditingController> _qty = {};
  NextOrderQty _how = NextOrderQty.last;
  bool _seeded = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in _qty.values) {
      c.dispose();
    }
    super.dispose();
  }

  DateTime get _today => widget.today ?? DateTime.now();

  TextEditingController _c(SupplierProduct p) =>
      _qty.putIfAbsent(p.key, () => TextEditingController(text: _qtyText(nextOrderQuantity(p, _how))));

  static String _qtyText(int q) => q > 0 ? '$q' : '';

  int _q(SupplierProduct p) => int.tryParse(_c(p).text.replaceAll(',', '').trim()) ?? 0;

  /// The first time the history arrives: everything bought before is ticked.
  void _seed(SupplierHistory h) {
    if (_seeded) return;
    _seeded = true;
    _chosen.addAll([for (final p in h.products) if (p.times > 0) p.key]);
  }

  void _fill(List<SupplierProduct> products, NextOrderQty how) => setState(() {
        _how = how;
        for (final p in products) {
          _c(p).text = _qtyText(nextOrderQuantity(p, how));
        }
      });

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _makeRequest(SupplierHistory h) async {
    final l10n = AppLocalizations.of(context);
    final rows = <RequestRow>[];
    var manual = 0;
    for (final p in h.products) {
      if (!_chosen.contains(p.key)) continue;
      final q = _q(p);
      if (q <= 0) continue;
      rows.add(RequestRow(
        key: p.productId != null ? 'p${p.productId}' : 'm${++manual}',
        name: p.name,
        productId: p.productId,
        janCode: p.janCode,
        nameEn: p.nameEn,
        maker: p.maker,
        sku: p.sku,
        unit: p.unit,
        onHand: p.onHand,
        supplierCode: p.theirCode,
        supplierProductName: p.theirName,
        fromSupplier: true,
        inList: true,
        quantity: q,
        manual: p.productId == null,
      ));
    }
    if (rows.isEmpty) return _snack(l10n.supNothingChosen);
    setState(() => _busy = true);
    final r = await ref.read(purchaseRequestRepositoryProvider).save(
          supplierId: h.supplierId,
          warehouseId: ref.read(activeWarehouseIdProvider),
          title: l10n.supRequestTitle(h.name, _day.format(_today)),
          lines: rows,
          settings: const {'from': 'supplier_history'},
        );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess(:final data):
        _snack(l10n.supRequestMade(data.number, data.lines, data.units));
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PurchaseRequestScreen(requestId: data.id)));
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(supplierHistoryProvider(widget.supplierId));
    final h = async.valueOrNull;
    if (h != null) _seed(h);
    final chosen = h == null ? const <SupplierProduct>[] : [for (final p in h.products) if (_chosen.contains(p.key)) p];
    final units = chosen.fold<int>(0, (s, p) => s + _q(p));
    final count = chosen.where((p) => _q(p) > 0).length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(h?.name ?? ''),
          bottom: TabBar(tabs: [
            Tab(key: const ValueKey('sup-tab-products'), text: l10n.supTabProducts(h?.products.length ?? 0)),
            Tab(key: const ValueKey('sup-tab-history'), text: l10n.supTabHistory(h?.events.length ?? 0)),
          ]),
        ),
        bottomNavigationBar: h == null || h.products.isEmpty
            ? null
            : Material(
                elevation: 8,
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.sm,
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(l10n.supChosen(count, units), key: const ValueKey('sup-chosen')),
                        FilledButton.icon(
                          key: const ValueKey('sup-make-request'),
                          onPressed: _busy || count == 0 ? null : () => _makeRequest(h),
                          icon: const Icon(Icons.playlist_add_outlined, size: 18),
                          label: Text(l10n.supMakeRequest),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        body: async.when(
          loading: () => LoadingView(message: l10n.loading),
          error: (e, _) => ErrorStateView(
            message: humanizeApiErrorMessage(l10n, '$e'),
            onRetry: () => ref.invalidate(supplierHistoryProvider(widget.supplierId)),
          ),
          data: (h) => TabBarView(children: [
            _products(context, h),
            _events(context, h),
          ]),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, SupplierHistory h) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
            CopyableText(h.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            if (h.code != null) CopyableText(h.code!, style: muted?.copyWith(fontFamily: AppFonts.mono)),
          ]),
          Wrap(spacing: AppSpacing.md, children: [
            if (h.contactName != null) CopyableText(h.contactName!, style: muted),
            if (h.phone != null) CopyableText(h.phone!, style: muted),
            if (h.email != null) CopyableText(h.email!, style: muted),
            if (h.address != null) CopyableText(h.address!, style: muted),
          ]),
          const SizedBox(height: AppSpacing.xs),
          Text(
            h.purchases == 0
                ? l10n.supNoPurchases
                : [
                    l10n.supTotals(h.purchases, _num.format(h.units)),
                    if (h.lastAt != null) l10n.supLastAt(_day.format(h.lastAt!)),
                    if (h.amount > 0) '¥${_num.format(h.amount)}',
                  ].join(' · '),
            key: const ValueKey('sup-totals'),
            style: theme.textTheme.bodyMedium,
          ),
        ]),
      ),
    );
  }

  Widget _products(BuildContext context, SupplierHistory h) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final whName = ref.watch(activeWarehouseProvider)?.name ?? l10n.plAllWarehouses;
    if (h.products.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: _header(context, h)),
        Expanded(
          child: EmptyStateView(icon: Icons.inventory_2_outlined, title: l10n.supNoProducts, message: l10n.supNoProductsBody),
        ),
      ]);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
      children: [
        _header(context, h),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.supNextOrderHint, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xs),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
          DropdownButton<NextOrderQty>(
            key: const ValueKey('sup-qty-mode'),
            value: _how,
            items: [
              DropdownMenuItem(value: NextOrderQty.last, child: Text(l10n.supQtyLast)),
              DropdownMenuItem(value: NextOrderQty.average, child: Text(l10n.supQtyAverage)),
              DropdownMenuItem(value: NextOrderQty.none, child: Text(l10n.supQtyNone)),
            ],
            onChanged: (v) => _fill(h.products, v ?? _how),
          ),
          TextButton(
            key: const ValueKey('sup-select-all'),
            onPressed: () => setState(() => _chosen.addAll([for (final p in h.products) p.key])),
            child: Text(l10n.supSelectAll),
          ),
          TextButton(
            key: const ValueKey('sup-select-due'),
            onPressed: () => setState(() {
              _chosen
                ..clear()
                ..addAll([for (final p in h.products) if (p.dueBy(_today)) p.key]);
            }),
            child: Text(l10n.supSelectDue),
          ),
          TextButton(
            key: const ValueKey('sup-clear'),
            onPressed: () => setState(_chosen.clear),
            child: Text(l10n.supClear),
          ),
          Text(l10n.supStockIn(whName), style: theme.textTheme.bodySmall),
        ]),
        const SizedBox(height: AppSpacing.xs),
        for (final p in h.products) _row(context, p),
      ],
    );
  }

  Widget _row(BuildContext context, SupplierProduct p) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final on = _chosen.contains(p.key);
    final due = p.dueBy(_today);
    return Card(
      key: ValueKey('sup-row-${p.key}'),
      color: on ? scheme.secondaryContainer.withValues(alpha: 0.5) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: Row(children: [
          Checkbox(
            key: ValueKey('sup-check-${p.key}'),
            value: on,
            onChanged: (v) => setState(() => v == true ? _chosen.add(p.key) : _chosen.remove(p.key)),
          ),
          Expanded(
            child: InkWell(
              onTap: p.productId == null
                  ? null
                  : () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: p.productId!))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: theme.textTheme.titleSmall),
                Wrap(spacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  if (p.theirName != null && p.theirName != p.name) Text('「${p.theirName}」', style: muted),
                  if (p.theirCode ?? p.sku case final code?) CopyableText(code, style: muted?.copyWith(fontFamily: AppFonts.mono)),
                  if (p.janCode != null) CopyableText(p.janCode!, style: muted?.copyWith(fontFamily: AppFonts.mono)),
                ]),
                Text(
                  p.times == 0
                      ? l10n.supNeverBought
                      : [
                          l10n.supBought(p.times, _num.format(p.total)),
                          if (p.lastQty != null && p.lastAt != null) l10n.supLast(_num.format(p.lastQty), _day.format(p.lastAt!)),
                          if (p.avgQty != null && p.times > 1) l10n.supAverage(_num.format(p.avgQty)),
                        ].join(' · '),
                  key: ValueKey('sup-stats-${p.key}'),
                  style: theme.textTheme.bodySmall,
                ),
                // What was paid: the last 単価, its 定価 and rate (掛率), and
                // the range when it changed.
                if (p.lastPrice != null)
                  Text(
                    [
                      l10n.supLastPrice(_yen.format(p.lastPrice)),
                      if (p.lastListPrice != null) l10n.supListPrice(_yen.format(p.lastListPrice)),
                      if (p.lastRate != null) l10n.supRate(_pct(p.lastRate!)),
                      if (p.minPrice != null && p.maxPrice != null && p.minPrice != p.maxPrice)
                        l10n.supPriceRange(_yen.format(p.minPrice), _yen.format(p.maxPrice)),
                    ].join(' · '),
                    key: ValueKey('sup-price-${p.key}'),
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                if (p.intervalDays != null && p.nextDue != null)
                  Text(
                    l10n.supEvery(p.intervalDays!, _day.format(p.nextDue!)) + (due ? ' · ${l10n.supDue}' : ''),
                    key: ValueKey('sup-due-${p.key}'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: due ? scheme.error : scheme.onSurfaceVariant,
                      fontWeight: due ? FontWeight.w700 : null,
                    ),
                  ),
                Text(l10n.supOnHand(_num.format(p.onHand)), key: ValueKey('sup-onhand-${p.key}'), style: muted),
                if (p.buys.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: ValueKey('sup-buys-${p.key}'),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                      onPressed: () => setState(() => _open.contains(p.key) ? _open.remove(p.key) : _open.add(p.key)),
                      icon: Icon(_open.contains(p.key) ? Icons.expand_less : Icons.expand_more, size: 18),
                      label: Text(l10n.supBuysToggle(p.buys.length)),
                    ),
                  ),
                if (_open.contains(p.key)) _buys(context, p),
              ]),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 100,
            child: TextField(
              key: ValueKey('sup-qty-${p.key}'),
              controller: _c(p),
              enabled: on,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.end,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: l10n.supQty, isDense: true, suffixText: p.unit),
            ),
          ),
        ]),
      ),
    );
  }

  /// Every time [p] was bought: the day, how many, the 単価, 定価 and 掛率,
  /// and where — a file opens its reading.
  Widget _buys(BuildContext context, SupplierProduct p) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Container(
      key: ValueKey('sup-buylist-${p.key}'),
      margin: const EdgeInsets.only(top: 2, bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final (i, b) in p.buys.indexed)
          InkWell(
            key: ValueKey('sup-buy-${p.key}-$i'),
            onTap: b.source == PurchaseSource.import ? () => openReadingTable(context, ref, b.refId) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 84, child: Text(b.at == null ? '—' : _day.format(b.at!), style: theme.textTheme.bodySmall)),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      [
                        '${_num.format(b.quantity)}${p.unit ?? l10n.supUnits}',
                        if (b.unitPrice != null) l10n.supLastPrice(_yen.format(b.unitPrice)),
                        if (b.listPrice != null) l10n.supListPrice(_yen.format(b.listPrice)),
                        if (b.rate != null) l10n.supRate(_pct(b.rate!)),
                        if (b.amount != null) l10n.supAmount(_num.format(b.amount!.round())),
                      ].join(' · '),
                      key: ValueKey('sup-buy-text-${p.key}-$i'),
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      [_sourceText(l10n, b.source), if (b.refNo != null) b.refNo!].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: muted,
                    ),
                  ]),
                ),
                if (b.source == PurchaseSource.import) Icon(Icons.open_in_new, size: 14, color: muted?.color),
              ]),
            ),
          ),
      ]),
    );
  }

  static String _sourceText(AppLocalizations l10n, PurchaseSource s) => switch (s) {
        PurchaseSource.po => l10n.supSourcePo,
        PurchaseSource.delivery => l10n.supSourceDelivery,
        PurchaseSource.import => l10n.supSourceImport,
      };

  Widget _events(BuildContext context, SupplierHistory h) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (h.events.isEmpty) {
      return EmptyStateView(icon: Icons.history, title: l10n.supNoPurchases);
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        for (final e in h.events)
          Card(
            key: ValueKey('sup-event-${e.source.name}-${e.refId}'),
            child: ListTile(
              // A file opens as read: every line with its price.
              onTap: e.source == PurchaseSource.import ? () => openReadingTable(context, ref, e.refId) : null,
              trailing: e.source == PurchaseSource.import ? const Icon(Icons.open_in_new, size: 18) : null,
              leading: Icon(switch (e.source) {
                PurchaseSource.po => Icons.shopping_cart_outlined,
                PurchaseSource.delivery => Icons.local_shipping_outlined,
                PurchaseSource.import => Icons.upload_file_outlined,
              }),
              title: Text(e.refNo ?? '—', maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text([
                _sourceText(l10n, e.source),
                if (e.at != null) _day.format(e.at!),
                l10n.supEventLines(e.lines, _num.format(e.units)),
                if ((e.amount ?? 0) > 0) '¥${_num.format(e.amount)}',
              ].join(' · '), style: theme.textTheme.bodySmall),
            ),
          ),
      ],
    );
  }
}
