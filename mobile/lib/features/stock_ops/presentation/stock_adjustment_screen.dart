import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/scan/barcode_scan_screen.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../product/application/product_providers.dart';
import '../../product/domain/product.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../application/stock_ops_providers.dart';
import '../domain/stock_ops.dart';
import 'stock_ops_ui.dart';
import '../../home/presentation/feature_link.dart';

/// The products an adjustment can be made to: the whole library (any
/// status), each with its stock, filtered on the screen.
final adjustProductsProvider =
    FutureProvider.autoDispose<List<Product>>((ref) async {
  final result = await ref
      .watch(productRepositoryProvider)
      .list(search: null, status: null);
  return result.when(
      success: (d) => d, failure: (f) => throw Exception(f.message));
});

/// Full-width letters, digits and spaces as their half-width selves, lower
/// case — so 「ＡＢＣ１２３」 finds "abc123".
String adjustSearchKey(String s) {
  final b = StringBuffer();
  for (final c in s.runes) {
    if (c >= 0xFF01 && c <= 0xFF5E) {
      b.writeCharCode(c - 0xFEE0);
    } else if (c == 0x3000) {
      b.write(' ');
    } else {
      b.writeCharCode(c);
    }
  }
  return b.toString().toLowerCase();
}

/// Whether [p] matches every word of [query] — in its name (any language),
/// maker, JAN or 品番 — and is [maker]'s (null: any maker).
bool adjustProductMatches(Product p, String query,
    {String? maker, bool inStockOnly = false, int? warehouseId}) {
  if (maker != null && (p.maker ?? '').trim() != maker) return false;
  if (inStockOnly && adjustOnHand(p, warehouseId) <= 0) return false;
  final words =
      adjustSearchKey(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return true;
  final hay = adjustSearchKey([
    p.name,
    p.nameEn ?? '',
    ...p.names.values,
    p.maker ?? '',
    p.janCode,
    p.sku ?? '',
  ].join('\n'));
  return words.every(hay.contains);
}

/// What [p] has on hand in [warehouseId] (null: in every warehouse).
int adjustOnHand(Product p, int? warehouseId) {
  final stock = p.stock;
  if (stock == null) return 0;
  if (warehouseId == null) return stock.onHand;
  for (final w in stock.warehouses) {
    if (w.warehouseId == warehouseId) return w.onHand;
  }
  return 0;
}

/// Reason-coded stock corrections.
///
/// Every entry posts through the ledger server-side, so the history below is
/// the audit trail rather than a convenience log: nothing here edits a quantity
/// in place (spec §17).
///
/// A product is picked from the library (found by its name, maker, JAN or
/// 品番, narrowed to one maker) and adjusted from there; a history entry
/// opens the same product again. The JAN can still be keyed or scanned.
class StockAdjustmentScreen extends ConsumerStatefulWidget {
  const StockAdjustmentScreen({super.key});

  @override
  ConsumerState<StockAdjustmentScreen> createState() =>
      _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends ConsumerState<StockAdjustmentScreen> {
  final _search = TextEditingController();
  bool _busy = false;
  String _query = '';
  String? _maker;
  bool _inStockOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _snack(String message, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: danger ? Theme.of(context).colorScheme.error : null,
      ));
  }

  /// [product] picked from the list (or found for a history entry), or
  /// [janCode] alone when the library has no such product; neither: keyed.
  Future<void> _newAdjustment({Product? product, String? janCode}) async {
    final l10n = AppLocalizations.of(context);
    final warehouseId = ref.read(writeWarehouseIdProvider);
    if (warehouseId == null) {
      // Two or more warehouses and no active one: a movement must not be
      // guessed into a building.
      _snack(l10n.adjNeedsWarehouse, danger: true);
      return;
    }

    final draft = await showModalBottomSheet<_AdjustDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AdjustSheet(
        product: product,
        janCode: janCode,
        onHand: product == null ? null : adjustOnHand(product, warehouseId),
      ),
    );
    if (draft == null || !mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.adjConfirmQ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product != null) ...[
              Text(product.name, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
            ],
            Text('${draft.janCode}　${signed(draft.delta)}',
                style: const TextStyle(fontFamily: AppFonts.mono)),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.adjConfirmIrreversible),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.adjConfirmAction),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    final result = await ref.read(stockOpsRepositoryProvider).adjust(
          warehouseId: warehouseId,
          janCode: draft.janCode,
          delta: draft.delta,
          reason: draft.reason,
          note: draft.note,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (adjustment) {
        ref.invalidate(adjustmentListProvider);
        ref.invalidate(adjustProductsProvider);
        ref.invalidate(productListProvider);
        _snack(l10n.adjDone(signed(adjustment.quantityDelta)));
      },
      failure: (f) =>
          _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _query = '';
      _maker = null;
      _inStockOnly = false;
    });
  }

  bool get _filtered =>
      _query.trim().isNotEmpty || _maker != null || _inStockOnly;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final products =
        ref.watch(adjustProductsProvider).valueOrNull ?? const <Product>[];
    final makers = {
      for (final p in products)
        if ((p.maker ?? '').trim().isNotEmpty) p.maker!.trim(),
    }.toList()
      ..sort();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.adjTitle),
          // Where the stock levels disagree is what an adjustment fixes.
          actions: const [FeatureLinkButton('stock_reconciliation')],
          bottom: TabBar(tabs: [
            Tab(key: const Key('adj-tab-products'), text: l10n.adjTabProducts),
            Tab(key: const Key('adj-tab-history'), text: l10n.adjTabHistory),
          ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _busy ? null : () => _newAdjustment(),
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.tune),
          label: Text(_busy ? l10n.working : l10n.adjNew),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FilterBar(
              controller: _search,
              makers: makers,
              maker: makers.contains(_maker) ? _maker : null,
              inStockOnly: _inStockOnly,
              filtered: _filtered,
              onQuery: (v) => setState(() => _query = v),
              onMaker: (v) => setState(() => _maker = v),
              onInStockOnly: (v) => setState(() => _inStockOnly = v),
              onClear: _clearFilters,
            ),
            Expanded(
              child: TabBarView(children: [
                _productsTab(l10n),
                _historyTab(l10n, products),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productsTab(AppLocalizations l10n) {
    final warehouseId = ref.watch(writeWarehouseIdProvider);
    return ref.watch(adjustProductsProvider).when(
          loading: () => LoadingView(message: l10n.loading),
          error: (e, _) => ErrorStateView(
            message: '$e',
            onRetry: () => ref.invalidate(adjustProductsProvider),
          ),
          data: (all) {
            if (all.isEmpty) {
              return EmptyStateView(
                  icon: Icons.inventory_2_outlined, title: l10n.adjNoProducts);
            }
            final shown = [
              for (final p in all)
                if (adjustProductMatches(p, _query,
                    maker: _maker,
                    inStockOnly: _inStockOnly,
                    warehouseId: warehouseId))
                  p,
            ];
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(adjustProductsProvider),
              child: ListView.separated(
                key: const Key('adj-product-list'),
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm,
                    AppSpacing.lg, AppSpacing.xxl * 2),
                itemCount: shown.length + 1,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return _ListHead(
                      count: l10n.adjShownCount(shown.length, all.length),
                      hint: shown.isEmpty ? l10n.adjNoMatch : l10n.adjTapHint,
                    );
                  }
                  final p = shown[i - 1];
                  return _ProductCard(
                    product: p,
                    onHand: adjustOnHand(p, warehouseId),
                    onTap: _busy ? null : () => _newAdjustment(product: p),
                  );
                },
              ),
            );
          },
        );
  }

  Widget _historyTab(AppLocalizations l10n, List<Product> products) {
    final byJan = {for (final p in products) p.janCode: p};
    return ref.watch(adjustmentListProvider).when(
          loading: () => LoadingView(message: l10n.loading),
          error: (e, _) => ErrorStateView(
            message: '$e',
            onRetry: () => ref.invalidate(adjustmentListProvider),
          ),
          data: (list) {
            if (list.isEmpty) {
              return EmptyStateView(
                icon: Icons.tune_outlined,
                title: l10n.adjEmpty,
                message: l10n.adjEmptyBody,
              );
            }
            // The same words find an entry by its product (its maker too)
            // or by what was noted with it.
            bool matches(StockAdjustment a) {
              final p = byJan[a.janCode];
              if (_maker != null && (p?.maker ?? '').trim() != _maker) {
                return false;
              }
              final words = adjustSearchKey(_query)
                  .split(RegExp(r'\s+'))
                  .where((w) => w.isNotEmpty);
              if (words.isEmpty) return true;
              final hay = adjustSearchKey([
                a.productName,
                a.janCode,
                a.note ?? '',
                if (p != null) ...[
                  p.name,
                  p.maker ?? '',
                  p.sku ?? '',
                  ...p.names.values
                ],
              ].join('\n'));
              return words.every(hay.contains);
            }

            final shown = [
              for (final a in list)
                if (matches(a)) a
            ];
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(adjustmentListProvider),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm,
                    AppSpacing.lg, AppSpacing.xxl * 2),
                itemCount: shown.length + 1,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return _ListHead(
                      count: l10n.adjShownCount(shown.length, list.length),
                      hint: shown.isEmpty
                          ? l10n.adjNoMatch
                          : l10n.adjHistoryTapHint,
                    );
                  }
                  final a = shown[i - 1];
                  return _AdjustmentCard(
                    adjustment: a,
                    onTap: _busy
                        ? null
                        : () => _newAdjustment(
                            product: byJan[a.janCode], janCode: a.janCode),
                  );
                },
              ),
            );
          },
        );
  }
}

/// The words, the maker and 在庫ありのみ — over both tabs.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.controller,
    required this.makers,
    required this.maker,
    required this.inStockOnly,
    required this.filtered,
    required this.onQuery,
    required this.onMaker,
    required this.onInStockOnly,
    required this.onClear,
  });

  final TextEditingController controller;
  final List<String> makers;
  final String? maker;
  final bool inStockOnly;
  final bool filtered;
  final ValueChanged<String> onQuery;
  final ValueChanged<String?> onMaker;
  final ValueChanged<bool> onInStockOnly;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('adj-search'),
            controller: controller,
            onChanged: onQuery,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.adjSearchHint,
              border: const OutlineInputBorder(),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: l10n.adjClearFilters,
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        controller.clear();
                        onQuery('');
                      },
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: InputDecorator(
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: l10n.adjMakerLabel,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      key: const Key('adj-maker'),
                      value: maker,
                      isExpanded: true,
                      isDense: true,
                      items: [
                        DropdownMenuItem<String?>(
                            value: null, child: Text(l10n.adjAllMakers)),
                        for (final m in makers)
                          DropdownMenuItem<String?>(
                              value: m,
                              child: Text(m, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: onMaker,
                    ),
                  ),
                ),
              ),
              FilterChip(
                key: const Key('adj-in-stock'),
                label: Text(l10n.adjInStockOnly),
                selected: inStockOnly,
                onSelected: onInStockOnly,
              ),
              if (filtered)
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                  label: Text(l10n.adjClearFilters),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ListHead extends StatelessWidget {
  const _ListHead({required this.count, required this.hint});

  final String count;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Row(
      children: [
        Expanded(child: Text(hint, style: style)),
        const SizedBox(width: AppSpacing.sm),
        Text(count, style: style),
      ],
    );
  }
}

/// One product in the list: its name, maker, JAN and 品番, and what it has
/// on hand here; pressing it opens the adjustment for it.
class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onHand, this.onTap});

  final Product product;
  final int onHand;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final sub = [
      if ((product.maker ?? '').trim().isNotEmpty) product.maker!.trim(),
      product.janCode,
      if ((product.sku ?? '').trim().isNotEmpty) product.sku!.trim(),
    ].join('  ·  ');
    return Card(
      key: ValueKey('adj-product-${product.janCode}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name.isEmpty ? product.janCode : product.name,
                        style: theme.textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(sub,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontFamily: AppFonts.mono),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n.adjOnHand(onHand),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontFamily: AppFonts.mono,
                  fontWeight: FontWeight.w600,
                  color:
                      onHand > 0 ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdjustmentCard extends StatelessWidget {
  const _AdjustmentCard({required this.adjustment, this.onTap});

  final StockAdjustment adjustment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final ui = AdjustReasonUi.of(l10n, adjustment.reason);
    final title = adjustment.productName.isNotEmpty
        ? adjustment.productName
        : adjustment.janCode;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                    Text(title,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      adjustment.note?.isNotEmpty == true
                          ? adjustment.note!
                          : adjustment.janCode,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFamily: adjustment.note?.isNotEmpty == true
                              ? null
                              : AppFonts.mono),
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
                  Text(
                    signed(adjustment.quantityDelta),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: AppFonts.mono,
                      fontWeight: FontWeight.w600,
                      color: adjustment.quantityDelta < 0
                          ? scheme.error
                          : scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  StatusPill(tone: ui.tone, label: ui.label, dense: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdjustDraft {
  const _AdjustDraft(this.janCode, this.delta, this.reason, this.note);
  final String janCode;
  final int delta;
  final AdjustReason reason;
  final String? note;
}

/// The entry form. Direction and magnitude are separate controls: a single
/// signed field invites a missing minus, and a missing minus doubles stock.
///
/// With a [product] (picked from the list) its JAN is fixed and what it has
/// on hand here is shown, with what it will have after; with a [janCode]
/// alone (a history entry not in the library) the JAN is filled in.
class _AdjustSheet extends StatefulWidget {
  const _AdjustSheet({this.product, this.janCode, this.onHand});

  final Product? product;
  final String? janCode;
  final int? onHand;

  @override
  State<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends State<_AdjustSheet> {
  late final _jan = TextEditingController(
      text: widget.product?.janCode ?? widget.janCode ?? '');
  final _quantity = TextEditingController();
  final _note = TextEditingController();
  bool _adding = false;
  AdjustReason _reason = AdjustReason.damage;
  String? _error;

  // Barcode input before manual keying (§35): the operator is standing next
  // to the item being corrected, not reading a JAN off a screen elsewhere.
  Future<void> _scanJan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
    );
    if (!mounted || code == null || code.isEmpty) return;
    setState(() => _jan.text = code);
  }

  @override
  void dispose() {
    _jan.dispose();
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final jan = _jan.text.trim();
    final magnitude = int.tryParse(_quantity.text.trim()) ?? 0;
    if (jan.isEmpty) {
      setState(() => _error = l10n.adjJanRequired);
      return;
    }
    if (magnitude <= 0) {
      setState(() => _error = l10n.adjDeltaRequired);
      return;
    }
    Navigator.pop(
      context,
      _AdjustDraft(
        jan,
        _adding ? magnitude : -magnitude,
        _reason,
        _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final product = widget.product;
    final magnitude = int.tryParse(_quantity.text.trim()) ?? 0;
    final after = widget.onHand == null
        ? null
        : widget.onHand! + (_adding ? magnitude : -magnitude);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.adjNew, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.lg),
            if (product != null)
              _SheetProduct(
                  product: product, onHand: widget.onHand ?? 0, after: after)
            else
              TextField(
                key: const Key('adj-jan'),
                controller: _jan,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.adjJan,
                  suffixIcon: IconButton(
                    tooltip: l10n.scanBarcode,
                    icon: const Icon(Icons.qr_code_scanner_outlined),
                    onPressed: _scanJan,
                  ),
                ),
                style: const TextStyle(fontFamily: AppFonts.mono),
              ),
            const SizedBox(height: AppSpacing.lg),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.remove),
                  label: Text(l10n.adjustRemove),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.adjustAdd),
                ),
              ],
              selected: {_adding},
              onSelectionChanged: (s) => setState(() => _adding = s.first),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: const Key('adj-quantity'),
              controller: _quantity,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: l10n.adjQuantity),
              style: const TextStyle(fontFamily: AppFonts.mono),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.adjReason, style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final r in AdjustReason.values)
                  ChoiceChip(
                    selected: _reason == r,
                    label: Text(AdjustReasonUi.of(l10n, r).label),
                    onSelected: (_) => setState(() => _reason = r),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: const Key('adj-note'),
              controller: _note,
              decoration: InputDecoration(labelText: l10n.adjNote),
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
              child: FilledButton(
                onPressed: _submit,
                child: Text(l10n.adjApply),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The product being adjusted, at the top of the form: what it is, what it
/// has on hand here and what it will have.
class _SheetProduct extends StatelessWidget {
  const _SheetProduct(
      {required this.product, required this.onHand, this.after});

  final Product product;
  final int onHand;
  final int? after;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final mono = theme.textTheme.bodySmall
        ?.copyWith(color: scheme.onSurfaceVariant, fontFamily: AppFonts.mono);
    final stock = theme.textTheme.titleMedium
        ?.copyWith(fontFamily: AppFonts.mono, fontWeight: FontWeight.w600);
    return Container(
      key: const Key('adj-sheet-product'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(product.name.isEmpty ? product.janCode : product.name,
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 2),
          if ((product.maker ?? '').trim().isNotEmpty)
            Text(product.maker!.trim(), style: theme.textTheme.bodySmall),
          Text(
            [
              product.janCode,
              if ((product.sku ?? '').trim().isNotEmpty) product.sku!.trim()
            ].join('  ·  '),
            style: mono,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text('${l10n.adjCurrentStock} ',
                  style: theme.textTheme.bodySmall),
              Text('$onHand', key: const Key('adj-on-hand'), style: stock),
              if (after != null && after != onHand) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.arrow_forward,
                    size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Text('${l10n.adjAfterStock} ',
                    style: theme.textTheme.bodySmall),
                Text('$after',
                    key: const Key('adj-after'),
                    style: stock?.copyWith(
                        color: after! < 0 ? scheme.error : scheme.primary)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
