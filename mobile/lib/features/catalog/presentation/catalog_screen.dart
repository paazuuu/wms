import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/product_name.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../product/application/product_providers.dart';
import '../../product/presentation/product_labels.dart';
import '../../product/presentation/product_lifecycle_ui.dart';
import '../../product_library/application/product_library_providers.dart';
import '../application/catalog_providers.dart';
import '../domain/catalog.dart';
import 'catalog_import_screen.dart';
import 'catalog_item_screen.dart';
import 'catalog_thumb.dart';
import 'master_import_screen.dart';

String _yen(double v) => '¥${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2)}';

/// 商品ライブラリー (0124/0125): every product a file, a person or the master
/// brought in, as a list or as pictures, with each supplier's current terms
/// and, when the product is in the master, its stock. Apart from the product
/// master: reading files again or deleting here never touches the master,
/// stock or anything booked, and removing a product from the master leaves
/// the item here. Items are taken into the master by choosing them and マス
/// タに登録; master products not here yet come in by マスタから取り込む.
class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  Set<int>? _selected;

  void _snack(String t) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(t)));

  Future<void> _toMaster() async {
    final l10n = AppLocalizations.of(context);
    final ids = (_selected ?? const <int>{}).toList()..sort();
    if (ids.isEmpty) return;
    final r = await ref.read(catalogRepositoryProvider).toProducts(ids);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        setState(() => _selected = null);
        ref.invalidate(catalogListProvider);
        ref.invalidate(productListProvider);
        _snack(l10n.clToMasterDone(data.created, data.linked, data.skipped));
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final ids = (_selected ?? const <int>{}).toList()..sort();
    if (ids.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.clDeleteQ(ids.length)),
        content: Text(l10n.clDeleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l10n.actionCancel)),
          FilledButton(
            key: const ValueKey('cl-delete-confirm'),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(d).colorScheme.error),
            onPressed: () => Navigator.pop(d, true),
            child: Text(l10n.productDeleteAction),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final r = await ref.read(catalogRepositoryProvider).delete(ids);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        setState(() => _selected = null);
        ref.invalidate(catalogListProvider);
        _snack(l10n.clDeleted(data));
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final canManage = ref.watch(productLibraryCanManageProvider);
    final async = ref.watch(filteredCatalogProvider);
    final all = ref.watch(catalogListProvider).valueOrNull ?? const <CatalogItem>[];
    final shown = async.valueOrNull ?? const <CatalogItem>[];
    final selected = _selected;
    final photos = ref.watch(catalogPhotoViewProvider);

    void open(CatalogItem item) async {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CatalogItemScreen(itemId: item.id)));
      ref.invalidate(catalogListProvider);
    }

    return Scaffold(
      appBar: AppBar(
        leading: selected == null
            ? null
            : IconButton(
                key: const ValueKey('cl-exit'),
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selected = null),
              ),
        title: Text(selected == null ? l10n.clTitle : l10n.lcSelected(selected.length)),
        actions: [
          if (selected == null) ...[
            // The same items as cards or as large pictures.
            SegmentedButton<bool>(
              key: const ValueKey('cl-view'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: false, icon: const Icon(Icons.view_list_outlined), tooltip: l10n.productsListView),
                ButtonSegment(value: true, icon: const Icon(Icons.photo_library_outlined), tooltip: l10n.productsPhotoView),
              ],
              selected: {photos},
              onSelectionChanged: (v) => ref.read(catalogPhotoViewProvider.notifier).state = v.first,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
      bottomNavigationBar: selected == null
          ? null
          : Material(
              key: const ValueKey('cl-bar'),
              elevation: 8,
              color: theme.colorScheme.surfaceContainerHigh,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(l10n.lcSelected(selected.length), style: theme.textTheme.titleSmall),
                      TextButton.icon(
                        key: const ValueKey('cl-select-all'),
                        onPressed: () => setState(() => _selected = {for (final i in shown) i.id}),
                        icon: const Icon(Icons.select_all, size: 18),
                        label: Text(l10n.lcSelectAll(shown.length)),
                      ),
                      TextButton.icon(
                        key: const ValueKey('cl-clear'),
                        onPressed: selected.isEmpty ? null : () => setState(() => _selected = {}),
                        icon: const Icon(Icons.deselect, size: 18),
                        label: Text(l10n.lcClear),
                      ),
                      FilledButton.tonalIcon(
                        key: const ValueKey('cl-to-master'),
                        onPressed: selected.isEmpty ? null : _toMaster,
                        icon: const Icon(Icons.inventory_2_outlined, size: 18),
                        label: Text(l10n.clToMaster),
                      ),
                      FilledButton.tonalIcon(
                        key: const ValueKey('cl-delete'),
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.errorContainer,
                          foregroundColor: theme.colorScheme.onErrorContainer,
                        ),
                        onPressed: selected.isEmpty ? null : _delete,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: Text(l10n.clDelete),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
            child: TextField(
              key: const ValueKey('cl-search'),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.clSearchHint,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
              ),
              onChanged: (v) => ref.read(catalogSearchProvider.notifier).state = v.trim(),
            ),
          ),
          _CatalogFilterBar(items: all),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xs),
            child: Wrap(spacing: 0, runSpacing: AppSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (canManage && selected == null) ...[
                FilledButton.tonalIcon(
                  key: const ValueKey('cl-import'),
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CatalogImportScreen()));
                    ref.invalidate(catalogListProvider);
                  },
                  icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                  label: Text(l10n.ciTitle),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Master products not in the library yet (0125).
                OutlinedButton.icon(
                  key: const ValueKey('cl-from-master'),
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MasterImportScreen()));
                    ref.invalidate(catalogListProvider);
                  },
                  icon: const Icon(Icons.move_down_outlined, size: 18),
                  label: Text(l10n.clFromMaster),
                ),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton.icon(
                  key: const ValueKey('cl-select'),
                  onPressed: () => setState(() => _selected = {}),
                  icon: const Icon(Icons.checklist_outlined, size: 18),
                  label: Text(l10n.lcSelect),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Text(
                  selected != null ? l10n.lcHint : l10n.pfShowing(shown.length, all.length),
                  key: const ValueKey('cl-showing'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ]),
          ),
          Expanded(
            child: async.when(
              loading: () => LoadingView(message: l10n.loading),
              error: (e, _) => ErrorStateView(
                message: humanizeApiErrorMessage(l10n, '$e'),
                onRetry: () => ref.invalidate(catalogListProvider),
              ),
              data: (items) => items.isEmpty
                  ? EmptyStateView(
                      icon: Icons.local_library_outlined,
                      title: all.isEmpty ? l10n.clEmpty : l10n.pfNoneMatchTitle,
                      message: all.isEmpty ? l10n.clEmptyBody : l10n.pfNoneMatch,
                    )
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(catalogListProvider),
                      child: Builder(builder: (context) {
                        void toggle(CatalogItem item) =>
                            setState(() => selected!.contains(item.id) ? selected.remove(item.id) : selected.add(item.id));
                        VoidCallback? press(CatalogItem item) =>
                            canManage && selected == null ? () => setState(() => _selected = {item.id}) : null;
                        if (photos) {
                          return GridView.builder(
                            key: const ValueKey('cl-grid'),
                            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 96),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 240,
                              mainAxisExtent: 320,
                              crossAxisSpacing: AppSpacing.md,
                              mainAxisSpacing: AppSpacing.md,
                            ),
                            itemCount: items.length,
                            itemBuilder: (_, n) {
                              final item = items[n];
                              return _CatalogPhotoCard(
                                item: item,
                                selected: selected?.contains(item.id),
                                onTap: selected != null ? () => toggle(item) : () => open(item),
                                onLongPress: press(item),
                              );
                            },
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 96),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (_, n) {
                            final item = items[n];
                            return _CatalogCard(
                              item: item,
                              selected: selected?.contains(item.id),
                              onTap: selected != null ? () => toggle(item) : () => open(item),
                              onLongPress: press(item),
                            );
                          },
                        );
                      }),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogFilterBar extends ConsumerWidget {
  const _CatalogFilterBar({required this.items});

  final List<CatalogItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final f = ref.watch(catalogFilterProvider);
    void set(CatalogFilter v) => ref.read(catalogFilterProvider.notifier).state = v;
    final makers = <String, int>{};
    final suppliers = <int, (String, int)>{};
    for (final i in items) {
      if (i.maker case final m? when m.isNotEmpty) makers[m] = (makers[m] ?? 0) + 1;
      for (final (id, name) in i.suppliers) {
        suppliers[id] = (name, (suppliers[id]?.$2 ?? 0) + 1);
      }
    }
    Future<void> pick<T>(String title, List<(T, String, int)> options, Set<T> chosen, void Function(Set<T>) apply) async {
      final next = {...chosen};
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => StatefulBuilder(
          builder: (context, setSheet) => SafeArea(
            child: ListView(shrinkWrap: true, children: [
              for (final (v, label, n) in options)
                CheckboxListTile(
                  key: ValueKey('cl-opt-$v'),
                  value: next.contains(v),
                  title: Text(widenKana(label)),
                  secondary: Text('$n'),
                  onChanged: (on) {
                    setSheet(() => on == true ? next.add(v) : next.remove(v));
                    apply(next);
                  },
                ),
            ]),
          ),
        ),
      );
    }

    String label(String name, Iterable<String> picked) {
      final l = picked.toList();
      if (l.isEmpty) return name;
      return l.length == 1 ? '$name: ${l.single}' : '$name: ${l.first} +${l.length - 1}';
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          ActionChip(
            key: const ValueKey('cl-f-maker'),
            label: Text(label(l10n.pfMaker, f.makers)),
            onPressed: makers.isEmpty
                ? null
                : () => pick<String>(l10n.pfMaker, [for (final e in makers.entries) (e.key, e.key, e.value)], f.makers,
                    (s) => set(ref.read(catalogFilterProvider).copyWith(makers: s))),
          ),
          const SizedBox(width: AppSpacing.sm),
          ActionChip(
            key: const ValueKey('cl-f-supplier'),
            label: Text(label(l10n.pfSupplier, [for (final id in f.supplierIds) suppliers[id]?.$1 ?? '#$id'])),
            onPressed: suppliers.isEmpty
                ? null
                : () => pick<int>(l10n.pfSupplier, [for (final e in suppliers.entries) (e.key, e.value.$1, e.value.$2)],
                    f.supplierIds, (s) => set(ref.read(catalogFilterProvider).copyWith(supplierIds: s))),
          ),
          const SizedBox(width: AppSpacing.sm),
          for (final (v, text) in [
            (CatalogMasterFilter.notInMaster, l10n.clNotInMaster),
            (CatalogMasterFilter.inMaster, l10n.clInMaster),
          ]) ...[
            FilterChip(
              key: ValueKey('cl-f-${v.name}'),
              label: Text(text),
              selected: f.master == v,
              onSelected: (on) => set(f.copyWith(master: on ? v : CatalogMasterFilter.all)),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          FilterChip(
            key: const ValueKey('cl-f-stock'),
            label: Text(l10n.pfStockIn),
            selected: f.stock == CatalogStockFilter.inStock,
            onSelected: (on) => set(f.copyWith(stock: on ? CatalogStockFilter.inStock : CatalogStockFilter.all)),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (f != const CatalogFilter())
            ActionChip(
              key: const ValueKey('cl-f-clear'),
              avatar: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: Text(l10n.pfClear),
              onPressed: () => set(const CatalogFilter()),
            ),
        ],
      ),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({required this.item, required this.onTap, this.onLongPress, this.selected});

  final CatalogItem item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final i = item;
    final terms = i.terms;
    return Card(
      key: ValueKey('cl-item-${i.id}'),
      color: selected == true ? theme.colorScheme.secondaryContainer : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (selected != null)
              Checkbox(key: ValueKey('cl-check-${i.id}'), value: selected, onChanged: (_) => onTap()),
            CatalogThumb(item: i, size: 56),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (i.maker != null) Text(widenKana(i.maker!), style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
                Text(widenKana(i.name), style: theme.textTheme.titleSmall),
                Text([
                  if (i.itemCode != null) '${l10n.pdCode} ${widenKana(i.itemCode!)}',
                  if (i.janCode != null) 'JAN ${i.janCode}',
                  if (i.spec != null) widenKana(i.spec!),
                ].join('　'), style: muted),
                if (_spec(i) case final spec?) Text(spec, key: ValueKey('cl-spec-${i.id}'), style: muted),
                if (terms.isNotEmpty)
                  Text(
                    _termsLine(l10n, i),
                    key: ValueKey('cl-terms-${i.id}'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: muted,
                  ),
                // Its stock, when it is in the master and has any.
                if (i.stock case final st? when !st.isEmpty) StockLine(key: ValueKey('cl-stock-${i.id}'), stock: st),
              ]),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (i.cheapest?.unitPrice case final p?)
                Text(_yen(p), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              StatusPill(
                tone: i.inMaster ? StatusTone.success : StatusTone.neutral,
                label: i.inMaster ? l10n.clInMaster : l10n.clNotInMaster,
                dense: true,
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

String? _spec(CatalogItem i) =>
    specShort(weightG: i.weightG, width: i.widthMm, depth: i.depthMm, height: i.heightMm, note: i.sizeNote);

/// Every supplier with its current price, cheapest first: "仕入先 2社: A
/// (大阪支店) ¥88 / B ¥92".
String _termsLine(AppLocalizations l10n, CatalogItem i) {
  final terms = i.terms;
  return '${l10n.supCount(i.suppliers.length)}: ${terms.take(3).map((t) => [
        t.partnerName,
        if (t.where != null) '(${t.where})',
        if (t.unitPrice != null) _yen(t.unitPrice!),
      ].join(' ')).join(' / ')}${terms.length > 3 ? ' ${l10n.supMore(terms.length - 3)}' : ''}';
}

/// One item as a large picture: its face, maker, name, the cheapest price
/// with how many suppliers, its stock and whether it is in the master — the
/// same item as its card in the list.
class _CatalogPhotoCard extends StatelessWidget {
  const _CatalogPhotoCard({required this.item, required this.onTap, this.onLongPress, this.selected});

  final CatalogItem item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final i = item;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return Card(
      key: ValueKey('cl-photo-${i.id}'),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      color: selected == true ? scheme.secondaryContainer : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Stack(children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (_, c) => Center(child: CatalogThumb(item: i, size: c.maxHeight < c.maxWidth ? c.maxHeight : c.maxWidth)),
                ),
              ),
              if (selected != null)
                Positioned(
                  left: 4,
                  top: 4,
                  child: Checkbox(key: ValueKey('cl-check-${i.id}'), value: selected, onChanged: (_) => onTap()),
                ),
              Positioned(
                right: 6,
                top: 6,
                child: StatusPill(
                  tone: i.inMaster ? StatusTone.success : StatusTone.neutral,
                  label: i.inMaster ? l10n.clInMaster : l10n.clNotInMaster,
                  dense: true,
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (i.maker != null)
                Text(widenKana(i.maker!), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary)),
              Text(widenKana(i.name), maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
              if (i.terms.isNotEmpty)
                Text(
                  [
                    if (i.cheapest?.unitPrice case final p?) _yen(p),
                    l10n.supCount(i.suppliers.length),
                  ].join(' · '),
                  key: ValueKey('cl-photo-terms-${i.id}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium,
                ),
              if (i.stock case final st? when !st.isEmpty) StockLine(key: ValueKey('cl-photo-stock-${i.id}'), stock: st),
              Text(i.imageCount == 0 ? l10n.plNoImages : l10n.plImageCount(i.imageCount),
                  style: muted?.copyWith(color: i.imageCount == 0 ? scheme.error : null)),
            ]),
          ),
        ]),
      ),
    );
  }
}
