import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/product_library_providers.dart';
import '../application/product_naming_providers.dart';
import '../domain/product_image.dart';
import '../domain/product_naming.dart';

// 商品様式 (0111): the company's own product format. A product's name is
// built from its parts by a template; change the template, a maker's name
// or what a colour is called here, and every affected product follows.

void _snack(BuildContext context, String m) =>
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(m)));

class NameFormatsScreen extends StatelessWidget {
  const NameFormatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.nfTitle),
          bottom: TabBar(tabs: [
            Tab(key: const ValueKey('nf-tab-formats'), text: l10n.nfTabFormats),
            Tab(key: const ValueKey('nf-tab-makers'), text: l10n.nfTabMakers),
            Tab(key: const ValueKey('nf-tab-values'), text: l10n.nfTabValues),
          ]),
        ),
        body: const TabBarView(children: [_FormatsTab(), _MakersTab(), _ValuesTab()]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 様式
// ---------------------------------------------------------------------------

class _FormatsTab extends ConsumerWidget {
  const _FormatsTab();

  Future<void> _edit(BuildContext context, WidgetRef ref, NameFormat? f) async {
    final l10n = AppLocalizations.of(context);
    final saved = await showDialog<NameFormatSaved>(
      context: context,
      builder: (_) => NameFormatEditor(format: f),
    );
    if (saved == null || !context.mounted) return;
    ref.invalidate(nameFormatsProvider);
    _snack(context, l10n.nfSaved(saved.renamed));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('nf-new'),
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add),
        label: Text(l10n.nfNew),
      ),
      body: ref.watch(nameFormatsProvider).when(
            loading: () => LoadingView(message: l10n.loading),
            error: (e, _) => ErrorStateView(
                message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => ref.invalidate(nameFormatsProvider)),
            data: (formats) => ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
              children: [
                Text(l10n.nfIntro, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.md),
                for (final f in formats)
                  Card(
                    key: ValueKey('nf-format-${f.id}'),
                    child: ListTile(
                      title: Row(children: [
                        Flexible(child: Text(f.name, overflow: TextOverflow.ellipsis)),
                        if (f.isDefault) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(l10n.nfDefault),
                          ),
                        ],
                      ]),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(f.template, style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
                        Text(
                          renderProductName(f.template, base: l10n.nfSampleBase, maker: l10n.nfSampleMaker, code: 'BP-05',
                              jan: '4900000000000', unit: l10n.nfSampleUnit, attributes: {'size': '0.5mm', 'color': l10n.nfSampleColor}),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ]),
                      trailing: Text(l10n.nfProducts(f.products), style: theme.textTheme.bodySmall),
                      onTap: () => _edit(context, ref, f),
                    ),
                  ),
              ],
            ),
          ),
    );
  }
}

/// Writing a template: its placeholders to tap in, a sample, and what the
/// real products using it would be called.
class NameFormatEditor extends ConsumerStatefulWidget {
  const NameFormatEditor({super.key, this.format});

  final NameFormat? format;

  @override
  ConsumerState<NameFormatEditor> createState() => _NameFormatEditorState();
}

class _NameFormatEditorState extends ConsumerState<NameFormatEditor> {
  late final _name = TextEditingController(text: widget.format?.name ?? '');
  late final _template = TextEditingController(text: widget.format?.template ?? '{base} {attr:size} {attr:color}');
  late bool _default = widget.format?.isDefault ?? false;
  bool _busy = false;
  List<NamePreview>? _preview;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPreview());
  }

  @override
  void dispose() {
    _name.dispose();
    _template.dispose();
    super.dispose();
  }

  void _insert(String token) {
    final t = _template.text;
    final sel = _template.selection;
    final at = sel.isValid ? sel.start : t.length;
    final end = sel.isValid ? sel.end : t.length;
    final before = t.substring(0, at);
    final pad = before.isEmpty || before.endsWith(' ') ? '' : ' ';
    final next = '$before$pad$token${t.substring(end)}';
    _template.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: before.length + pad.length + token.length),
    );
    setState(() {});
  }

  Future<void> _loadPreview() async {
    final r = await ref
        .read(productNamingRepositoryProvider)
        .preview(_template.text, formatId: widget.format?.id, limit: 20);
    if (!mounted) return;
    setState(() => _preview = r.when(success: (d) => d, failure: (_) => const []));
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (!_template.text.contains('{base}')) {
      _snack(context, l10n.nfNeedsBase);
      return;
    }
    if (_name.text.trim().isEmpty) {
      _snack(context, l10n.nfNeedsName);
      return;
    }
    setState(() => _busy = true);
    final r = await ref.read(productNamingRepositoryProvider).saveFormat(
          id: widget.format?.id,
          name: _name.text.trim(),
          template: _template.text.trim(),
          isDefault: _default,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    r.when(
      success: (saved) => Navigator.pop(context, saved),
      failure: (f) => _snack(context, humanizeApiErrorMessage(l10n, f.message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final attrs = ref.watch(productAttributesProvider).valueOrNull ?? const <ProductAttributeDef>[];
    final sample = renderProductName(_template.text,
        base: l10n.nfSampleBase, maker: l10n.nfSampleMaker, code: 'BP-05', jan: '4900000000000',
        unit: l10n.nfSampleUnit, attributes: {'size': '0.5mm', 'color': l10n.nfSampleColor});
    final parts = [
      ('{base}', l10n.nfPartBase),
      ('{maker}', l10n.nfPartMaker),
      ('{code}', l10n.nfPartCode),
      ('{jan}', l10n.nfPartJan),
      ('{unit}', l10n.nfPartUnit),
      for (final a in attrs)
        if (a.active) ('{attr:${a.key}}', a.name),
    ];
    return AlertDialog(
      title: Text(widget.format == null ? l10n.nfNew : l10n.nfEdit),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const ValueKey('nf-name'),
                controller: _name,
                decoration: InputDecoration(labelText: l10n.nfName),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const ValueKey('nf-template'),
                controller: _template,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontFamily: 'monospace'),
                decoration: InputDecoration(labelText: l10n.nfTemplate, helperText: l10n.nfTemplateHint),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.nfInsert, style: theme.textTheme.labelMedium),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final (token, label) in parts)
                    ActionChip(
                      key: ValueKey('nf-insert-$token'),
                      label: Text(label),
                      onPressed: () => _insert(token),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.nfSample, style: theme.textTheme.labelMedium),
              Text(sample, key: const ValueKey('nf-sample'), style: theme.textTheme.titleMedium),
              SwitchListTile(
                key: const ValueKey('nf-default'),
                contentPadding: EdgeInsets.zero,
                value: _default,
                onChanged: widget.format?.isDefault == true ? null : (v) => setState(() => _default = v),
                title: Text(l10n.nfMakeDefault),
              ),
              Row(children: [
                Expanded(child: Text(l10n.nfPreview, style: theme.textTheme.labelMedium)),
                TextButton.icon(
                  key: const ValueKey('nf-preview'),
                  onPressed: _loadPreview,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(l10n.nfPreviewRefresh),
                ),
              ]),
              if (_preview == null)
                const LinearProgressIndicator()
              else if (_preview!.isEmpty)
                Text(l10n.nfPreviewNone, style: theme.textTheme.bodySmall)
              else
                for (final p in _preview!)
                  Padding(
                    key: ValueKey('nf-preview-${p.productId}'),
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text.rich(TextSpan(children: [
                      TextSpan(
                          text: p.current,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      const TextSpan(text: '  →  '),
                      TextSpan(
                          text: p.next,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: p.changes ? FontWeight.w600 : FontWeight.normal)),
                    ])),
                  ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('nf-save'),
          onPressed: _busy ? null : _save,
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// メーカー
// ---------------------------------------------------------------------------

class _MakersTab extends ConsumerStatefulWidget {
  const _MakersTab();

  @override
  ConsumerState<_MakersTab> createState() => _MakersTabState();
}

class _MakersTabState extends ConsumerState<_MakersTab> {
  String _search = '';

  Future<void> _rename(MakerEntry m) async {
    final l10n = AppLocalizations.of(context);
    final c = TextEditingController(text: m.name);
    final name = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.nfRename),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.nfMakersHint, style: Theme.of(d).textTheme.bodySmall),
          TextField(
            key: const ValueKey('nf-maker-name'),
            controller: c,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.nfNewName),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(l10n.actionCancel)),
          FilledButton(
              key: const ValueKey('nf-maker-save'), onPressed: () => Navigator.pop(d, c.text.trim()), child: Text(l10n.actionSave)),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == m.name || !mounted) return;
    final r = await ref.read(productNamingRepositoryProvider).renameMaker(m.id, name);
    if (!mounted) return;
    r.when(
      success: (n) {
        ref.invalidate(makersProvider);
        _snack(context, l10n.nfMakerRenamed(n));
      },
      failure: (f) => _snack(context, humanizeApiErrorMessage(l10n, f.message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: TextField(
          key: const ValueKey('nf-maker-search'),
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.nfSearchMaker),
          onSubmitted: (v) => setState(() => _search = v.trim()),
        ),
      ),
      Expanded(
        child: ref.watch(makersProvider(_search)).when(
              loading: () => LoadingView(message: l10n.loading),
              error: (e, _) =>
                  ErrorStateView(message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => ref.invalidate(makersProvider)),
              data: (makers) => ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                children: [
                  Text(l10n.nfMakersHint, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: AppSpacing.sm),
                  for (final m in makers)
                    Card(
                      key: ValueKey('nf-maker-${m.id}'),
                      child: ListTile(
                        title: Text(m.name),
                        subtitle: Text([l10n.nfProducts(m.products), if (m.dialects > 0) l10n.nfDialects(m.dialects)].join(' · ')),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () => _rename(m),
                      ),
                    ),
                ],
              ),
            ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// 属性の値
// ---------------------------------------------------------------------------

class _ValuesTab extends ConsumerStatefulWidget {
  const _ValuesTab();

  @override
  ConsumerState<_ValuesTab> createState() => _ValuesTabState();
}

class _ValuesTabState extends ConsumerState<_ValuesTab> {
  int? _attributeId;
  final _from = TextEditingController();
  final _to = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  Future<void> _rename() async {
    final l10n = AppLocalizations.of(context);
    final id = _attributeId;
    if (id == null || _from.text.trim().isEmpty || _to.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final r = await ref.read(productNamingRepositoryProvider).renameAttributeValue(id, _from.text.trim(), _to.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    r.when(
      success: (n) {
        _from.clear();
        _to.clear();
        _snack(context, l10n.nfValueRenamed(n));
      },
      failure: (f) => _snack(context, humanizeApiErrorMessage(l10n, f.message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final attrs = ref.watch(productAttributesProvider).valueOrNull ?? const <ProductAttributeDef>[];
    final ids = {for (final a in attrs) a.id};
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(l10n.nfValuesHint, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<int>(
          key: const ValueKey('nf-value-attr'),
          initialValue: ids.contains(_attributeId) ? _attributeId : null,
          decoration: InputDecoration(labelText: l10n.nfAttribute),
          items: [for (final a in attrs) DropdownMenuItem(value: a.id, child: Text(a.name))],
          onChanged: (v) => setState(() => _attributeId = v),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(children: [
          Expanded(
            child: TextField(
              key: const ValueKey('nf-value-from'),
              controller: _from,
              decoration: InputDecoration(labelText: l10n.nfFrom),
            ),
          ),
          const Padding(padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm), child: Icon(Icons.arrow_forward)),
          Expanded(
            child: TextField(
              key: const ValueKey('nf-value-to'),
              controller: _to,
              decoration: InputDecoration(labelText: l10n.nfTo),
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            key: const ValueKey('nf-value-save'),
            onPressed: _busy ? null : _rename,
            icon: const Icon(Icons.drive_file_rename_outline),
            label: Text(l10n.nfRenameEverywhere),
          ),
        ),
      ],
    );
  }
}
