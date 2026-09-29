import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../partners/application/trading_partner_providers.dart';
import '../../partners/domain/trading_partner.dart';
import '../application/product_library_providers.dart';
import '../data/product_image_repository.dart';
import '../domain/product_image.dart';

// The product page's other two tabs (0110): our attributes, and how each
// supplier calls the product — its name, 品番, JAN and maker for it, every
// spelling seen, and its attributes in its own words. Pre-training, imports
// and inspection fill the second one by themselves; a manager can correct it.

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

String _fieldLabel(AppLocalizations l10n, String field) => switch (field) {
      'jan' => l10n.ntFieldJan,
      'maker' => l10n.ntFieldMaker,
      'name' => l10n.ntFieldName,
      'code' => l10n.ntFieldCode,
      _ => field,
    };

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

// ---------------------------------------------------------------------------
// 仕入先の呼び名
// ---------------------------------------------------------------------------

final _partnersProvider = FutureProvider.autoDispose<List<TradingPartner>>((ref) async =>
    (await ref.watch(tradingPartnerRepositoryProvider).list()).when(success: (d) => d, failure: (f) => throw Exception(f.message)));

class ProductSuppliersTab extends ConsumerWidget {
  const ProductSuppliersTab({super.key, required this.productId});

  final int productId;

  Future<void> _edit(BuildContext context, WidgetRef ref, ProductProfile p, SupplierProfile? s) async {
    final l10n = AppLocalizations.of(context);
    final attrs = await ref.read(productAttributesProvider.future).catchError((_) => const <ProductAttributeDef>[]);
    if (!context.mounted) return;
    final draft = await showDialog<SupplierProfileDraft>(
      context: context,
      builder: (_) => _SupplierProfileDialog(productId: productId, profile: s, attributes: [for (final a in attrs) if (a.active) a]),
    );
    if (draft == null || !context.mounted) return;
    await _save(context, ref, productId, () => ref.read(productImageRepositoryProvider).saveSupplierProfile(draft),
        done: l10n.plSupplierSaved);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, SupplierProfile s) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        content: Text(l10n.plRemoveSupplierConfirm(s.supplierName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l10n.actionCancel)),
          FilledButton(key: const ValueKey('pl-supplier-remove-ok'), onPressed: () => Navigator.pop(d, true), child: Text(l10n.plWithdraw)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _save(context, ref, productId, () => ref.read(productImageRepositoryProvider).removeSupplierProfile(productId, s.supplierId));
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
          data: (p) {
            final ours = {for (final a in p.attributes) a.attribute.id: a.value};
            return ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
              children: [
                // Ours, for comparison.
                Text(
                  [p.name, if (p.sku != null) p.sku!, if (p.janCode != null) p.janCode!, if (p.maker != null) p.maker!].join(' · '),
                  style: theme.textTheme.titleSmall,
                ),
                Text(l10n.plSuppliersHint, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.sm),
                if (p.suppliers.isEmpty)
                  Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text(l10n.plNoSuppliers)),
                for (final s in p.suppliers)
                  _SupplierCard(
                    supplier: s,
                    ours: ours,
                    canManage: canManage,
                    onEdit: () => _edit(context, ref, p, s),
                    onRemove: () => _remove(context, ref, s),
                    onAdopt: (a) => _save(context, ref, productId,
                        () => ref.read(productImageRepositoryProvider).setAttributeValues(productId, {a.attributeId: a.rawValue})),
                  ),
                if (canManage)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const ValueKey('pl-supplier-add'),
                      onPressed: () => _edit(context, ref, p, null),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.plSupplierAdd),
                    ),
                  ),
              ],
            );
          },
        );
  }
}

class _SupplierCard extends StatelessWidget {
  const _SupplierCard({
    required this.supplier,
    required this.ours,
    required this.canManage,
    required this.onEdit,
    required this.onRemove,
    required this.onAdopt,
  });

  final SupplierProfile supplier;
  final Map<int, String?> ours;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final ValueChanged<SupplierAttribute> onAdopt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final s = supplier;
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 72, child: Text(label, style: muted)),
            Expanded(child: Text(value)),
          ]),
        );
    return Card(
      key: ValueKey('pl-supplier-${s.supplierId}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.storefront_outlined, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text(s.supplierName, style: theme.textTheme.titleSmall)),
              if (canManage) ...[
                IconButton(
                  key: ValueKey('pl-supplier-edit-${s.supplierId}'),
                  tooltip: l10n.actionEdit,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEdit,
                ),
                IconButton(
                  key: ValueKey('pl-supplier-remove-${s.supplierId}'),
                  tooltip: l10n.plWithdraw,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: onRemove,
                ),
              ],
            ]),
            if (s.name != null) row(l10n.ntFieldName, s.name!),
            if (s.code != null) row(l10n.ntFieldCode, s.code!),
            if (s.janCode != null) row(l10n.ntFieldJan, s.janCode!),
            if (s.maker != null) row(l10n.ntFieldMaker, s.maker!),
            for (final a in s.attributes)
              Padding(
                key: ValueKey('pl-supplier-attr-${s.supplierId}-${a.key}'),
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(children: [
                  SizedBox(width: 72, child: Text(a.name, style: muted)),
                  Expanded(
                    child: Text([
                      '${a.rawName ?? a.name}: ${a.rawValue}',
                      if (a.translated) '→ ${a.ourValue}',
                    ].join('  ')),
                  ),
                  if (canManage && (ours[a.attributeId] == null))
                    TextButton(
                      key: ValueKey('pl-adopt-${s.supplierId}-${a.key}'),
                      onPressed: () => onAdopt(a),
                      child: Text(l10n.plAdopt),
                    ),
                ]),
              ),
            if (s.writings.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.plWritings, style: muted),
              Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [
                for (final w in s.writings)
                  for (final v in w.values)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('${_fieldLabel(l10n, w.field)}: $v', style: theme.textTheme.bodySmall),
                    ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _SupplierProfileDialog extends ConsumerStatefulWidget {
  const _SupplierProfileDialog({required this.productId, this.profile, required this.attributes});

  final int productId;
  final SupplierProfile? profile;
  final List<ProductAttributeDef> attributes;

  @override
  ConsumerState<_SupplierProfileDialog> createState() => _SupplierProfileDialogState();
}

class _SupplierProfileDialogState extends ConsumerState<_SupplierProfileDialog> {
  late int? _supplierId = widget.profile?.supplierId;
  late final _name = TextEditingController(text: widget.profile?.name ?? '');
  late final _code = TextEditingController(text: widget.profile?.code ?? '');
  late final _jan = TextEditingController(text: widget.profile?.janCode ?? '');
  late final _maker = TextEditingController(text: widget.profile?.maker ?? '');
  late final Map<int, TextEditingController> _values = {
    for (final a in widget.attributes)
      a.id: TextEditingController(text: _existing(a.id)?.rawValue ?? ''),
  };
  late final Map<int, TextEditingController> _headings = {
    for (final a in widget.attributes)
      a.id: TextEditingController(text: _existing(a.id)?.rawName ?? ''),
  };

  SupplierAttribute? _existing(int id) {
    for (final a in widget.profile?.attributes ?? const <SupplierAttribute>[]) {
      if (a.attributeId == id) return a;
    }
    return null;
  }

  @override
  void dispose() {
    for (final c in [_name, _code, _jan, _maker, ..._values.values, ..._headings.values]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final partners = ref.watch(_partnersProvider).valueOrNull ?? const <TradingPartner>[];
    return AlertDialog(
      title: Text(widget.profile?.supplierName ?? l10n.plSupplierAdd),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (widget.profile == null)
              DropdownButtonFormField<int>(
                key: const ValueKey('pl-supplier-pick'),
                initialValue: _supplierId,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.plSupplier),
                items: [for (final p in partners) DropdownMenuItem(value: p.id, child: Text(p.name))],
                onChanged: (v) => setState(() => _supplierId = v),
              ),
            TextField(key: const ValueKey('pl-sup-name'), controller: _name, decoration: InputDecoration(labelText: l10n.ntFieldName)),
            TextField(key: const ValueKey('pl-sup-code'), controller: _code, decoration: InputDecoration(labelText: l10n.ntFieldCode)),
            TextField(key: const ValueKey('pl-sup-jan'), controller: _jan, decoration: InputDecoration(labelText: l10n.ntFieldJan)),
            TextField(key: const ValueKey('pl-sup-maker'), controller: _maker, decoration: InputDecoration(labelText: l10n.ntFieldMaker)),
            if (widget.attributes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(l10n.plTabAttributes, style: theme.textTheme.labelLarge),
              for (final a in widget.attributes)
                Row(children: [
                  SizedBox(width: 64, child: Text(a.name)),
                  Expanded(
                    child: TextField(
                      key: ValueKey('pl-sup-attr-heading-${a.key}'),
                      controller: _headings[a.id],
                      decoration: InputDecoration(hintText: l10n.plAttrHeading, isDense: true),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      key: ValueKey('pl-sup-attr-${a.key}'),
                      controller: _values[a.id],
                      decoration: InputDecoration(hintText: l10n.plAttrValue, isDense: true),
                    ),
                  ),
                ]),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('pl-sup-save'),
          onPressed: _supplierId == null
              ? null
              : () => Navigator.pop(
                    context,
                    SupplierProfileDraft(
                      productId: widget.productId,
                      supplierId: _supplierId!,
                      name: _t(_name),
                      code: _t(_code),
                      janCode: _t(_jan),
                      maker: _t(_maker),
                      attributes: [
                        for (final a in widget.attributes)
                          // Unchanged-and-empty stays out; cleared removes it.
                          if (_t(_values[a.id]!) != null || _existing(a.id) != null)
                            (attributeId: a.id, rawName: _t(_headings[a.id]!), rawValue: _t(_values[a.id]!)),
                      ],
                    ),
                  ),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
