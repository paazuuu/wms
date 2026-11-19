import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/product_providers.dart';
import '../data/product_category_repository.dart';
import '../domain/product.dart';

/// 商品カテゴリー (0218): the tree products are sorted into — 文房具 > ペン >
/// ボールペン > 油性, as deep as it needs — with how many products sit under
/// each level; a level renamed; and the products with no category yet
/// placed by the AI, all at once.
class ProductCategoriesScreen extends ConsumerStatefulWidget {
  const ProductCategoriesScreen({super.key, this.canManage = false});

  final bool canManage;

  @override
  ConsumerState<ProductCategoriesScreen> createState() => _ProductCategoriesScreenState();
}

class _ProductCategoriesScreenState extends ConsumerState<ProductCategoriesScreen> {
  bool _running = false;
  int _done = 0, _total = 0;
  String? _note;

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Every product with no category, placed by the AI.
  Future<void> _classify() async {
    final l10n = AppLocalizations.of(context);
    final r = await ref.read(productRepositoryProvider).list(status: null);
    if (!mounted) return;
    final products = switch (r) {
      ApiSuccess(:final data) => data,
      ApiFailure(:final message) => () {
          _snack(humanizeApiErrorMessage(l10n, message));
          return const <Product>[];
        }(),
    };
    final asks = [
      for (final p in products)
        if ((p.category ?? '').trim().isEmpty && p.lifecycle != ProductLifecycle.archived)
          CategoryAsk(productId: p.id, jan: p.janCode, name: p.name, maker: p.maker, code: p.sku),
    ];
    if (asks.isEmpty) {
      setState(() => _note = l10n.pcNothingToDo);
      return;
    }
    setState(() {
      _running = true;
      _done = 0;
      _total = asks.length;
      _note = null;
    });
    final out = await classifyAndSave(ref.read(productCategoryRepositoryProvider), asks, onProgress: (d, _) {
      if (mounted) setState(() => _done = d);
    });
    if (!mounted) return;
    ref.invalidate(categoryTreeProvider);
    ref.invalidate(productListProvider);
    setState(() {
      _running = false;
      _note = [
        l10n.pcClassified(out.applied, out.asked),
        if (out.stoppedBy != null) humanizeApiErrorMessage(l10n, out.stoppedBy!),
      ].join('\n');
    });
  }

  Future<void> _rename(CategoryNode n) async {
    final l10n = AppLocalizations.of(context);
    final name = await showDialog<String>(context: context, builder: (_) => _RenameDialog(node: n));
    if (name == null || name.isEmpty || name == n.name || !mounted) return;
    final r = await ref.read(productCategoryRepositoryProvider).rename(n.id, name);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess():
        ref.invalidate(categoryTreeProvider);
        ref.invalidate(productListProvider);
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final tree = ref.watch(categoryTreeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pcTitle)),
      body: tree.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: humanizeApiErrorMessage(l10n, '$e'),
          onRetry: () => ref.invalidate(categoryTreeProvider),
        ),
        data: (nodes) {
          // Levels nothing sits under any more are left out.
          final shown = [for (final n in nodes) if (n.total > 0) n];
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(l10n.pcIntro, style: muted),
              const SizedBox(height: AppSpacing.md),
              if (widget.canManage)
                Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  FilledButton.tonalIcon(
                    key: const ValueKey('pc-classify'),
                    onPressed: _running ? null : _classify,
                    icon: _running
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome_outlined),
                    label: Text(_running ? l10n.pcClassifying(_done, _total) : l10n.pcClassify),
                  ),
                  if (_note != null) Text(_note!, key: const ValueKey('pc-note'), style: theme.textTheme.bodyMedium),
                ]),
              const SizedBox(height: AppSpacing.lg),
              if (shown.isEmpty)
                Text(l10n.pcEmpty, key: const ValueKey('pc-empty'), style: muted)
              else
                Card(
                  child: Column(children: [
                    for (final n in shown)
                      ListTile(
                        key: ValueKey('pc-node-${n.id}'),
                        dense: true,
                        contentPadding: EdgeInsets.only(left: AppSpacing.md + n.depth * 24.0, right: AppSpacing.sm),
                        leading: Icon(n.depth == 0 ? Icons.folder_outlined : Icons.subdirectory_arrow_right, size: 20),
                        title: Text(n.name, style: n.depth == 0 ? theme.textTheme.titleSmall : null),
                        subtitle: n.depth == 0 ? null : Text(n.label, style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(l10n.pcCount(n.total), style: theme.textTheme.labelLarge),
                          if (widget.canManage)
                            IconButton(
                              key: ValueKey('pc-rename-${n.id}'),
                              tooltip: l10n.pcRename,
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _rename(n),
                            ),
                        ]),
                      ),
                  ]),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// A level's new name, the controller kept for as long as the dialog is.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.node});

  final CategoryNode node;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _c = TextEditingController(text: widget.node.name);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.pcRename),
      content: TextField(
        key: const ValueKey('pc-rename-field'),
        controller: _c,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.pcNodeName, helperText: widget.node.label),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('pc-rename-ok'),
          onPressed: () => Navigator.pop(context, _c.text.trim()),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
