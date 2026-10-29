import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/open_window.dart';
import '../../../l10n/app_localizations.dart';
import '../application/product_providers.dart';
import '../data/market_names.dart';
import '../domain/product.dart';

/// 商品名（言語別） (0166): the 商品名 — the name shops show — in Japanese,
/// English and Chinese, each changeable by hand. The Japanese one can be
/// looked up on the web again; a blank one means 未登録. The 表示名 is built
/// from the Japanese 商品名 by the product's format.
///
/// Pops true once something was saved.
class ProductNamesDialog extends ConsumerStatefulWidget {
  const ProductNamesDialog({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<ProductNamesDialog> createState() => _ProductNamesDialogState();
}

class _ProductNamesDialogState extends ConsumerState<ProductNamesDialog> {
  late final _ja = TextEditingController(text: marketNameOf(widget.product) ?? '');
  late final _en = TextEditingController(text: widget.product.names['en'] ?? widget.product.nameEn ?? '');
  late final _zh = TextEditingController(text: widget.product.names['zh'] ?? '');
  bool _busy = false;
  bool _searching = false;
  String? _searchNote;
  String? _foundUrl;

  @override
  void dispose() {
    _ja.dispose();
    _en.dispose();
    _zh.dispose();
    super.dispose();
  }

  /// The 商品名 looked up on the web now, put in the field to check.
  Future<void> _search() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _searching = true;
      _searchNote = null;
    });
    final r = await ref.read(marketNameRepositoryProvider).lookup([nameAskFor(widget.product)]);
    if (!mounted) return;
    setState(() {
      _searching = false;
      switch (r) {
        case ApiSuccess(:final data):
          final f = data.results.firstOrNull;
          if (f != null && f.usable) {
            _ja.text = f.name!.trim();
            _foundUrl = f.sourceUrl;
            _searchNote = l10n.pnmFound;
          } else {
            _searchNote = data.searchUnavailable || (f?.errorKind != null) ? l10n.plFindNamesStopped : l10n.pnmNotFound;
          }
        case ApiFailure(:final message):
          _searchNote = humanizeApiErrorMessage(l10n, message);
      }
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final p = widget.product;
    setState(() => _busy = true);
    String? failed;
    var saved = false;
    final ja = _ja.text.trim();
    if (ja != (marketNameOf(p) ?? '')) {
      final r = await ref.read(marketNameRepositoryProvider).setMarketName(p.id, ja.isEmpty ? null : ja);
      if (r case ApiFailure(:final message)) failed = message;
      saved = true;
    }
    final repo = ref.read(productRepositoryProvider);
    for (final (lang, c, was) in [
      ('en', _en, p.names['en'] ?? p.nameEn ?? ''),
      ('zh', _zh, p.names['zh'] ?? ''),
    ]) {
      if (failed != null || c.text.trim() == was.trim()) continue;
      final r = await repo.setName(p.id, lang, c.text.trim().isEmpty ? null : c.text.trim());
      if (r case ApiFailure(:final message)) failed = message;
      saved = true;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (failed != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, failed))));
      return;
    }
    Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final p = widget.product;
    return AlertDialog(
      title: Text(l10n.productNamesTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.pnmIntro, style: muted),
            const SizedBox(height: AppSpacing.md),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('product-name-ja'),
                  controller: _ja,
                  decoration: InputDecoration(
                    labelText: l10n.productNamesJa,
                    hintText: l10n.plNameMissing,
                    helperText: p.nameByAi && _foundUrl == null ? l10n.plNameByAi : null,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: OutlinedButton.icon(
                  key: const ValueKey('product-name-search'),
                  onPressed: _searching || _busy ? null : _search,
                  icon: _searching
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.travel_explore, size: 18),
                  label: Text(l10n.pnmSearch),
                ),
              ),
            ]),
            if (_searchNote case final n?)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(n, key: const ValueKey('product-name-search-note'), style: muted),
              ),
            if (_foundUrl ?? (p.nameByAi ? p.baseNameSourceUrl : null) case final u?)
              TextButton.icon(
                key: const ValueKey('product-name-source'),
                onPressed: () => openExternalUrl(u),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(u, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('product-name-en'),
              controller: _en,
              decoration: InputDecoration(labelText: l10n.productNamesEn),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('product-name-zh'),
              controller: _zh,
              decoration: InputDecoration(labelText: l10n.productNamesZh),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('product-name-en-save'),
          onPressed: _busy ? null : _save,
          child: Text(l10n.productSave),
        ),
      ],
    );
  }
}
