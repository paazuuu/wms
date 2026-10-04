import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/product_library_providers.dart';
import '../domain/product_image.dart';

// The product page's attributes tab (0110). How each supplier calls the
// product and on what terms is shown by 価格台帳 (0124/0125), not
// the master.

Future<void> _save(
  BuildContext context,
  WidgetRef ref,
  int productId,
  Future<ApiResult<ProductProfile>> Function() call, {
  String? done,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final r = await call();
  r.when(
    success: (_) {
      ref.invalidate(productProfileProvider(productId));
      if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
    },
    failure: (f) => messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, f.message)))),
  );
}

// ---------------------------------------------------------------------------
// 属性
// ---------------------------------------------------------------------------

class ProductAttributesTab extends ConsumerWidget {
  const ProductAttributesTab({super.key, required this.productId});

  final int productId;

  Future<void> _edit(BuildContext context, WidgetRef ref, ProductAttributeValue a) async {
    final l10n = AppLocalizations.of(context);
    final c = TextEditingController(text: a.value ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(a.attribute.name),
        content: TextField(
          key: const ValueKey('pl-attr-value'),
          controller: c,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.plAttrValue, suffixText: a.attribute.unit),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(l10n.actionCancel)),
          FilledButton(key: const ValueKey('pl-attr-save'), onPressed: () => Navigator.pop(d, c.text.trim()), child: Text(l10n.actionSave)),
        ],
      ),
    );
    if (value == null || !context.mounted) return;
    await _save(context, ref, productId,
        () => ref.read(productImageRepositoryProvider).setAttributeValues(productId, {a.attribute.id: value}));
  }

  Future<void> _newAttribute(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final name = TextEditingController();
    final unit = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.plAttrNew),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(key: const ValueKey('pl-attr-new-name'), controller: name, decoration: InputDecoration(labelText: l10n.plAttrName)),
          TextField(controller: unit, decoration: InputDecoration(labelText: l10n.plAttrUnit)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l10n.actionCancel)),
          FilledButton(key: const ValueKey('pl-attr-new-save'), onPressed: () => Navigator.pop(d, true), child: Text(l10n.actionSave)),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final r = await ref
        .read(productImageRepositoryProvider)
        .saveAttribute(name: name.text.trim(), unit: unit.text.trim().isEmpty ? null : unit.text.trim());
    r.when(
      success: (_) {
        ref.invalidate(productAttributesProvider);
        ref.invalidate(productProfileProvider(productId));
      },
      failure: (f) => messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, f.message)))),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final canManage = ref.watch(productLibraryCanManageProvider);
    return ref.watch(productProfileProvider(productId)).when(
          loading: () => LoadingView(message: l10n.loading),
          error: (e, _) => ErrorStateView(
              message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => ref.invalidate(productProfileProvider(productId))),
          data: (p) => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(l10n.plAttributesHint, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.sm),
              for (final a in p.attributes)
                Card(
                  key: ValueKey('pl-attr-${a.attribute.key}'),
                  child: ListTile(
                    title: Text(a.attribute.name),
                    trailing: Text(
                      a.value == null ? '—' : '${a.value}${a.attribute.unit == null ? '' : ' ${a.attribute.unit}'}',
                      style: theme.textTheme.titleSmall,
                    ),
                    onTap: canManage ? () => _edit(context, ref, a) : null,
                  ),
                ),
              if (canManage)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('pl-attr-new'),
                    onPressed: () => _newAttribute(context, ref),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.plAttrNew),
                  ),
                ),
            ],
          ),
        );
  }
}
