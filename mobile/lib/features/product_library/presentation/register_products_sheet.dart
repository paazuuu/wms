import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/product_library_providers.dart';
import '../application/product_naming_providers.dart';
import '../../../core/api/api_result.dart';
import '../../product/application/product_providers.dart';
import '../data/english_name_suggester.dart';
import '../domain/product_image.dart';
import '../domain/product_naming.dart';

/// Opens [RegisterProductsSheet]; resolves to the products created (empty
/// when nothing was registered).
Future<List<RegisteredProduct>> showRegisterProductsSheet(
  BuildContext context, {
  required int? partnerId,
  required List<Map<String, dynamic>> lines,
}) async =>
    await showModalBottomSheet<List<RegisteredProduct>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: RegisterProductsSheet(partnerId: partnerId, lines: lines),
      ),
    ) ??
    const [];

/// A read document's lines that have no product yet, as products in our own
/// format (0111): the supplier's shorthand tidied, size and colour taken out
/// of the name into attributes, 単位 and 定価 carried over. A person checks
/// and corrects each one; registering creates them and learns the
/// supplier's writing against them at the same time.
class RegisterProductsSheet extends ConsumerStatefulWidget {
  const RegisterProductsSheet({super.key, required this.partnerId, required this.lines});

  final int? partnerId;

  /// Lines as `ReadLineResult.toProposeJson()` (or the import's own rows).
  final List<Map<String, dynamic>> lines;

  @override
  ConsumerState<RegisterProductsSheet> createState() => _RegisterProductsSheetState();
}

class _RegisterProductsSheetState extends ConsumerState<RegisterProductsSheet> {
  List<ProductProposal>? _items;
  String? _error;
  final Set<int> _chosen = {};
  int? _formatId;
  bool _busy = false;

  /// 英語標準名 per proposal row (§43): proposed by the AI or typed, saved
  /// with the product when it is registered.
  final Map<int, String> _nameEn = {};
  bool _suggesting = false;

  Future<void> _suggestEnglish() async {
    final l10n = AppLocalizations.of(context);
    final items = _items;
    if (items == null) return;
    final asked = [
      for (final (i, p) in items.indexed)
        if (_chosen.isEmpty || _chosen.contains(i))
          NameRequest(
            index: p.row,
            supplierName: '${p.source['product_name'] ?? ''}'.trim().isNotEmpty ? '${p.source['product_name']}' : p.name,
            maker: p.maker,
            code: p.code,
            spec: p.attributes.values.isEmpty ? null : p.attributes.values.join(' '),
          ),
    ];
    setState(() => _suggesting = true);
    final r = await ref.read(englishNameSuggesterProvider).suggest(asked);
    if (!mounted) return;
    setState(() => _suggesting = false);
    final messenger = ScaffoldMessenger.of(context);
    switch (r) {
      case ApiSuccess(:final data):
        setState(() => _nameEn.addAll(data));
        messenger.showSnackBar(SnackBar(content: Text(l10n.rpEnglishSuggested(data.length))));
      case ApiFailure(:final message):
        messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ref.read(productNamingRepositoryProvider).propose(widget.partnerId, widget.lines);
    if (!mounted) return;
    setState(() {
      r.when(
        success: (items) {
          _items = items;
          _chosen
            ..clear()
            ..addAll([for (final (i, p) in items.indexed) if (p.complete) i]);
        },
        failure: (f) => _error = f.message,
      );
    });
  }

  Future<void> _register() async {
    final l10n = AppLocalizations.of(context);
    final items = _items;
    if (items == null) return;
    final picked = [for (final i in _chosen.toList()..sort()) items[i]];
    if (picked.any((p) => !p.complete)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.rpNeedsMaker)));
      return;
    }
    setState(() => _busy = true);
    final r = await ref.read(productNamingRepositoryProvider).register(widget.partnerId, picked, formatId: _formatId);
    if (!mounted) return;
    setState(() => _busy = false);
    r.when(
      success: (created) async {
        // The English standard name goes with the product it was made for.
        final products = ref.read(productRepositoryProvider);
        for (final c in created) {
          final en = _nameEn[c.row]?.trim() ?? '';
          if (en.isNotEmpty) await products.setNameEn(c.productId, en);
        }
        if (!mounted) return;
        ref.invalidate(productLibraryProvider);
        Navigator.pop(context, created);
      },
      failure: (f) =>
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, f.message)))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final formats = ref.watch(nameFormatsProvider).valueOrNull ?? const <NameFormat>[];
    final attrs = ref.watch(productAttributesProvider).valueOrNull ?? const <ProductAttributeDef>[];
    final template = (formats.where((f) => f.id == _formatId).firstOrNull ??
                formats.where((f) => f.isDefault).firstOrNull)
            ?.template ??
        '{base} {attr:size} {attr:color}';
    final items = _items;

    final Widget body;
    if (_error != null) {
      body = ErrorStateView(message: humanizeApiErrorMessage(l10n, _error!), onRetry: () {
        setState(() => _error = null);
        _load();
      });
    } else if (items == null) {
      body = LoadingView(message: l10n.loading);
    } else if (items.isEmpty) {
      body = EmptyStateView(icon: Icons.check_circle_outline, title: l10n.rpNone);
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        children: [
          Text(l10n.rpIntro, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<int?>(
            key: const ValueKey('rp-format'),
            initialValue: formats.any((f) => f.id == _formatId) ? _formatId : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.pnFormat),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Text(l10n.pnFormatDefault(formats.where((f) => f.isDefault).firstOrNull?.name ?? '')),
              ),
              for (final f in formats)
                if (f.active) DropdownMenuItem<int?>(value: f.id, child: Text(f.name)),
            ],
            onChanged: (v) => setState(() => _formatId = v),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('rp-suggest-en'),
              onPressed: _suggesting || _busy ? null : _suggestEnglish,
              icon: _suggesting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.translate, size: 18),
              label: Text(l10n.rpSuggestEnglish),
            ),
          ),
          Text(l10n.rpSuggestEnglishHint,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.md),
          for (final (i, p) in items.indexed)
            _ProposalCard(
              key: ValueKey('rp-item-${p.row}'),
              proposal: p,
              template: template,
              attributeNames: {for (final a in attrs) a.key: a.name},
              chosen: _chosen.contains(i),
              nameEn: _nameEn[p.row] ?? '',
              onNameEn: (v) => _nameEn[p.row] = v,
              onChosen: (v) => setState(() => v ? _chosen.add(i) : _chosen.remove(i)),
              onChanged: (next) => setState(() {
                _items = [for (final (j, q) in items.indexed) j == i ? next : q];
              }),
            ),
        ],
      );
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
        child: Row(children: [
          Expanded(child: Text(l10n.rpTitle, style: theme.textTheme.titleMedium)),
        ]),
      ),
      Expanded(child: body),
      if (items != null && items.isNotEmpty)
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('rp-register'),
                onPressed: _busy || _chosen.isEmpty ? null : _register,
                icon: const Icon(Icons.library_add_check_outlined),
                label: Text(l10n.rpRegister(_chosen.length)),
              ),
            ),
          ),
        ),
    ]);
  }
}

class _ProposalCard extends StatefulWidget {
  const _ProposalCard({
    super.key,
    required this.proposal,
    required this.template,
    required this.attributeNames,
    required this.chosen,
    required this.onChosen,
    required this.onChanged,
    this.nameEn = '',
    this.onNameEn,
  });

  /// 英語標準名 (§43) for this proposal.
  final String nameEn;
  final ValueChanged<String>? onNameEn;

  final ProductProposal proposal;
  final String template;
  final Map<String, String> attributeNames;
  final bool chosen;
  final ValueChanged<bool> onChosen;
  final ValueChanged<ProductProposal> onChanged;

  @override
  State<_ProposalCard> createState() => _ProposalCardState();
}

class _ProposalCardState extends State<_ProposalCard> {
  late final _base = TextEditingController(text: widget.proposal.baseName);
  late final _maker = TextEditingController(text: widget.proposal.maker ?? '');
  late final _code = TextEditingController(text: widget.proposal.code ?? '');
  late final _unit = TextEditingController(text: widget.proposal.unit ?? '');
  late final _price = TextEditingController(
      text: widget.proposal.listPrice == null
          ? ''
          : (widget.proposal.listPrice! == widget.proposal.listPrice!.roundToDouble()
              ? widget.proposal.listPrice!.toInt().toString()
              : widget.proposal.listPrice!.toString()));

  late final _nameEn = TextEditingController(text: widget.nameEn);

  @override
  void didUpdateWidget(covariant _ProposalCard old) {
    super.didUpdateWidget(old);
    // A proposal that just arrived replaces what the field shows.
    if (widget.nameEn != old.nameEn && widget.nameEn != _nameEn.text) _nameEn.text = widget.nameEn;
  }

  @override
  void dispose() {
    _nameEn.dispose();
    _base.dispose();
    _maker.dispose();
    _code.dispose();
    _unit.dispose();
    _price.dispose();
    super.dispose();
  }

  void _emit() {
    final price = double.tryParse(_price.text.trim().replaceAll(',', ''));
    widget.onChanged(widget.proposal.copyWith(
      baseName: _base.text.trim(),
      maker: _maker.text.trim(),
      code: _code.text.trim(),
      unit: _unit.text.trim(),
      listPrice: price,
      clearListPrice: price == null,
    ));
  }

  Widget _field(TextEditingController c, String label, String key, {TextInputType? type}) => TextField(
        key: ValueKey('rp-$key-${widget.proposal.row}'),
        controller: c,
        keyboardType: type,
        onChanged: (_) => _emit(),
        decoration: InputDecoration(labelText: label, isDense: true),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final p = widget.proposal;
    final name = renderProductName(widget.template,
        base: p.baseName, maker: p.maker, code: p.code, jan: p.janCode, unit: p.unit, attributes: p.attributes);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Checkbox(
              key: ValueKey('rp-choose-${p.row}'),
              value: widget.chosen,
              onChanged: (v) => widget.onChosen(v ?? false),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, key: ValueKey('rp-name-${p.row}'), style: theme.textTheme.titleSmall),
                Text('JAN ${p.janCode}', style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
              ]),
            ),
          ]),
          if (p.baseFromCode)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(children: [
                Icon(Icons.warning_amber, size: 16, color: theme.colorScheme.tertiary),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(l10n.rpFromCode,
                      key: ValueKey('rp-from-code-${p.row}'),
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.tertiary)),
                ),
              ]),
            ),
          _field(_base, l10n.pnBaseName, 'base'),
          TextField(
            key: ValueKey('rp-name-en-${widget.proposal.row}'),
            controller: _nameEn,
            onChanged: (v) => widget.onNameEn?.call(v),
            decoration: InputDecoration(labelText: l10n.rpEnglishName, isDense: true),
          ),
          Row(children: [
            Expanded(child: _field(_maker, l10n.ntFieldMaker, 'maker')),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _field(_code, l10n.ntFieldCode, 'code')),
          ]),
          Row(children: [
            Expanded(child: _field(_unit, l10n.pnUnit, 'unit')),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _field(_price, l10n.pnListPrice, 'price', type: const TextInputType.numberWithOptions(decimal: true))),
          ]),
          if (p.attributes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [
              for (final e in p.attributes.entries)
                InputChip(
                  key: ValueKey('rp-attr-${p.row}-${e.key}'),
                  label: Text('${widget.attributeNames[e.key] ?? e.key}: ${e.value}'),
                  deleteIcon: Icon(Icons.close, size: 16, key: ValueKey('rp-attr-drop-${p.row}-${e.key}')),
                  onDeleted: () => widget.onChanged(p.copyWith(attributes: {
                    for (final a in p.attributes.entries)
                      if (a.key != e.key) a.key: a.value,
                  })),
                ),
            ]),
          ],
        ]),
      ),
    );
  }
}
