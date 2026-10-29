import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../product/application/product_providers.dart';
import '../../product/data/market_names.dart';
import '../../product/domain/product.dart';
import '../../product/presentation/product_marks_ui.dart';
import '../data/shelf_notes_repository.dart';

/// 棚メモ (0167): where something was put, written freely — until shelves
/// have numbers, a note per product ("・A棚の上段の奥", "・割れ物なので下段")
/// to find again. Searched by place, note, 商品名, 品番, JAN or maker.
class ShelfNotesScreen extends ConsumerStatefulWidget {
  const ShelfNotesScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<ShelfNotesScreen> createState() => _ShelfNotesScreenState();
}

class _ShelfNotesScreenState extends ConsumerState<ShelfNotesScreen> {
  late final _query = TextEditingController(text: widget.initialQuery);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final async = ref.watch(shelfNotesProvider);
    final products = {for (final p in ref.watch(productListProvider).valueOrNull ?? const <Product>[]) p.id: p};
    final canWrite = ref.watch(canWriteShelfNotesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.snTitle)),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              key: const ValueKey('sn-add'),
              onPressed: () => editShelfNote(context, ref),
              icon: const Icon(Icons.add),
              label: Text(l10n.snAdd),
            )
          : null,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.snIntro, style: muted),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('sn-search'),
              controller: _query,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: l10n.snSearch,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ]),
        ),
        Expanded(
          child: async.when(
            loading: () => const LoadingView(),
            error: (e, _) =>
                ErrorStateView(message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => ref.invalidate(shelfNotesProvider)),
            data: (notes) {
              final shown = [
                for (final n in notes)
                  if (n.matches(_query.text, productTexts: _texts(products[n.productId]))) n,
              ];
              if (shown.isEmpty) {
                return Center(child: Text(notes.isEmpty ? l10n.snEmpty : l10n.snNoneMatch, key: const ValueKey('sn-none')));
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 96),
                itemCount: shown.length,
                itemBuilder: (context, i) => _NoteCard(note: shown[i], product: products[shown[i].productId], canWrite: canWrite),
              );
            },
          ),
        ),
      ]),
    );
  }

  static List<String> _texts(Product? p) =>
      p == null ? const [] : [p.name, p.baseName ?? '', p.sku ?? '', p.maker ?? '', p.janCode];
}

class _NoteCard extends ConsumerWidget {
  const _NoteCard({required this.note, required this.product, required this.canWrite});

  final ShelfNote note;
  final Product? product;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final p = product;
    final when = note.updatedAt ?? note.createdAt;
    return Card(
      key: ValueKey('sn-note-${note.id}'),
      child: InkWell(
        onTap: canWrite ? () => editShelfNote(context, ref, note: note, product: p) : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if ((note.location ?? '').isNotEmpty) ...[
                const Icon(Icons.place_outlined, size: 18),
                const SizedBox(width: 4),
                Text(note.location!, style: theme.textTheme.titleSmall),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Text(
                  p == null
                      ? (note.janCode ?? l10n.snNoProduct)
                      : [if ((p.maker ?? '').isNotEmpty) p.maker!, marketNameOf(p) ?? p.name, if (p.sku != null) p.sku!]
                          .join('  '),
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (p != null) ProductMarks(product: p, size: 18),
            ]),
            if (p != null) ProductWarningNote(product: p),
            const SizedBox(height: AppSpacing.xs),
            Text(note.body, key: ValueKey('sn-body-${note.id}')),
            const SizedBox(height: AppSpacing.xs),
            Text(
              [
                if (when != null) DateFormat('y/MM/dd HH:mm').format(when),
                note.updatedByName ?? note.createdByName ?? '',
              ].where((t) => t.isNotEmpty).join(' · '),
              style: muted,
            ),
          ]),
        ),
      ),
    );
  }
}

/// A note written or changed (or taken off), about [product] when given.
Future<void> editShelfNote(BuildContext context, WidgetRef ref, {ShelfNote? note, Product? product}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _NoteDialog(note: note, product: product),
  );
  if (saved == true) ref.invalidate(shelfNotesProvider);
}

class _NoteDialog extends ConsumerStatefulWidget {
  const _NoteDialog({this.note, this.product});

  final ShelfNote? note;
  final Product? product;

  @override
  ConsumerState<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends ConsumerState<_NoteDialog> {
  late final _location = TextEditingController(text: widget.note?.location ?? '');
  late final _body = TextEditingController(text: widget.note?.body ?? '・');
  late int? _productId = widget.product?.id ?? widget.note?.productId;
  bool _busy = false;

  @override
  void dispose() {
    _location.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final body = _body.text.trim();
    if (body.isEmpty || body == '・') return;
    setState(() => _busy = true);
    final r = await ref
        .read(shelfNotesRepositoryProvider)
        .save(id: widget.note?.id, productId: _productId, location: _location.text.trim(), body: body);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess():
        Navigator.pop(context, true);
      case ApiFailure(:final message):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
  }

  Future<void> _remove() async {
    final id = widget.note?.id;
    if (id == null) return;
    setState(() => _busy = true);
    final r = await ref.read(shelfNotesRepositoryProvider).remove(id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r is ApiSuccess) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final products = ref.watch(productListProvider).valueOrNull ?? const <Product>[];
    String label(Product p) =>
        [if ((p.maker ?? '').isNotEmpty) p.maker!, marketNameOf(p) ?? p.name, if (p.sku != null) p.sku!].join('  ');
    return AlertDialog(
      title: Text(widget.note == null ? l10n.snAdd : l10n.snEdit),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (widget.product == null)
              Autocomplete<Product>(
                key: const ValueKey('sn-product'),
                initialValue: TextEditingValue(
                    text: products.where((p) => p.id == _productId).map(label).firstOrNull ?? ''),
                displayStringForOption: label,
                optionsBuilder: (v) {
                  final q = v.text.trim().toLowerCase();
                  if (q.isEmpty) return const Iterable<Product>.empty();
                  return products
                      .where((p) => [label(p), p.janCode].any((t) => t.toLowerCase().contains(q)))
                      .take(20);
                },
                onSelected: (p) => setState(() => _productId = p.id),
                fieldViewBuilder: (context, c, focus, onSubmit) => TextField(
                  controller: c,
                  focusNode: focus,
                  decoration: InputDecoration(labelText: l10n.snProduct, helperText: l10n.snProductHint),
                  onChanged: (t) {
                    if (t.trim().isEmpty) setState(() => _productId = null);
                  },
                ),
              )
            else
              ListTile(contentPadding: EdgeInsets.zero, title: Text(label(widget.product!))),
            TextField(
              key: const ValueKey('sn-location'),
              controller: _location,
              decoration: InputDecoration(labelText: l10n.snLocation, hintText: l10n.snLocationHint),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('sn-body'),
              controller: _body,
              minLines: 3,
              maxLines: 8,
              decoration: InputDecoration(labelText: l10n.snBody, hintText: l10n.snBodyHint, border: const OutlineInputBorder()),
            ),
          ]),
        ),
      ),
      actions: [
        if (widget.note != null)
          TextButton(key: const ValueKey('sn-remove'), onPressed: _busy ? null : _remove, child: Text(l10n.snRemove)),
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: Text(l10n.actionCancel)),
        FilledButton(key: const ValueKey('sn-save'), onPressed: _busy ? null : _save, child: Text(l10n.actionSave)),
      ],
    );
  }
}
