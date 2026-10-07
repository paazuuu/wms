import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/ai_health_screen.dart';
import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../application/product_providers.dart';
import '../data/spec_lookup.dart';
import '../domain/product.dart';

/// サイズ・重量を調べる (0141): the AI looks [product] up on the web with the
/// key chosen for it, and shows what it found and where. A person ticks what
/// to keep; it is saved as from the web, with the page. Resolves to true
/// when something was saved.
Future<bool> showSpecLookupSheet(BuildContext context, Product product) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SpecLookupSheet(product: product),
    ) ==
    true;

class _SpecLookupSheet extends ConsumerStatefulWidget {
  const _SpecLookupSheet({required this.product});

  final Product product;

  @override
  ConsumerState<_SpecLookupSheet> createState() => _SpecLookupSheetState();
}

class _SpecLookupSheetState extends ConsumerState<_SpecLookupSheet> {
  SpecLookupResult? _result;
  String? _error;
  bool _busy = true;
  bool _saving = false;
  bool _takeWeight = true;
  bool _takeSize = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final p = widget.product;
    final r = await ref.read(specLookupRepositoryProvider).lookup(SpecLookupRequest(
          name: p.name,
          maker: p.maker,
          code: p.sku,
          jan: p.janCode.isEmpty ? null : p.janCode,
          nameEn: p.nameEn,
        ));
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (r) {
        case ApiSuccess(:final data):
          _result = data;
          _takeWeight = data.hasWeight;
          _takeSize = data.hasSize;
        case ApiFailure(:final message):
          _error = message;
      }
    });
  }

  String _basis(AppLocalizations l10n, String? b) => switch (b) {
        'product' => l10n.slBasisProduct,
        'package' => l10n.slBasisPackage,
        _ => l10n.slBasisUnknown,
      };

  static String _n(double? v) =>
      v == null ? '—' : (v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1));

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final r = _result;
    if (r == null || (!_takeWeight && !_takeSize)) return;
    setState(() => _saving = true);
    final repo = ref.read(productRepositoryProvider);
    final note = [l10n.slSavedNote, if (r.note != null) r.note!].join(' ');
    String? failure;
    if (_takeWeight && r.hasWeight) {
      final w = await repo.setWeight(
        productId: widget.product.id,
        unitWeightG: r.weightG,
        source: 'web',
        url: r.bestUrl,
        note: r.weightBasis == 'package' ? '$note（${l10n.slBasisPackage}）' : note,
      );
      if (w case ApiFailure(:final message)) failure = message;
    }
    if (failure == null && _takeSize && r.hasSize) {
      final s = await repo.setSize(
        productId: widget.product.id,
        widthMm: r.widthMm,
        depthMm: r.depthMm,
        heightMm: r.heightMm,
        note: [if (r.sizeBasis == 'package') l10n.slBasisPackage, if (r.bestUrl != null) r.bestUrl!].join(' ').trim(),
        source: 'web',
      );
      if (s case ApiFailure(:final message)) failure = message;
    }
    if (!mounted) return;
    if (failure != null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, failure))));
      return;
    }
    ref.invalidate(productListProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.slSaved)));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final r = _result;
    final children = <Widget>[
      Text(l10n.slTitle, style: theme.textTheme.titleMedium),
      Text(widget.product.name, style: muted),
      const SizedBox(height: AppSpacing.md),
    ];
    if (_busy) {
      children.addAll([
        const LinearProgressIndicator(),
        const SizedBox(height: AppSpacing.xs),
        Text(l10n.slSearching, key: const ValueKey('sl-busy'), style: muted),
      ]);
    } else if (_error != null) {
      children.addAll([
        Text(humanizeApiErrorMessage(l10n, _error!), key: const ValueKey('sl-error'),
            style: TextStyle(color: theme.colorScheme.error)),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(onPressed: _run, icon: const Icon(Icons.refresh), label: Text(l10n.slRetry)),
      ]);
    } else if (r != null && r.errorKind != null && !r.found) {
      children.addAll([
        Text(r.errorKind == 'parse' ? l10n.slNothingFound : l10n.ahPingFailed(aiErrorKindLabel(l10n, r.errorKind)),
            key: const ValueKey('sl-error'), style: TextStyle(color: theme.colorScheme.error)),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(onPressed: _run, icon: const Icon(Icons.refresh), label: Text(l10n.slRetry)),
      ]);
    } else if (r != null && !r.found) {
      children.add(Text(l10n.slNothingFound, key: const ValueKey('sl-none'), style: muted));
    } else if (r != null) {
      children.addAll([
        CheckboxListTile(
          key: const ValueKey('sl-take-weight'),
          contentPadding: EdgeInsets.zero,
          value: _takeWeight && r.hasWeight,
          onChanged: r.hasWeight ? (v) => setState(() => _takeWeight = v ?? false) : null,
          title: Text(r.hasWeight ? l10n.slWeight('${_n(r.weightG)} g') : l10n.slWeightNone,
              key: const ValueKey('sl-weight')),
          subtitle: r.hasWeight ? Text(_basis(l10n, r.weightBasis)) : null,
        ),
        CheckboxListTile(
          key: const ValueKey('sl-take-size'),
          contentPadding: EdgeInsets.zero,
          value: _takeSize && r.hasSize,
          onChanged: r.hasSize ? (v) => setState(() => _takeSize = v ?? false) : null,
          title: Text(
            r.hasSize ? l10n.slSize(_n(r.widthMm), _n(r.depthMm), _n(r.heightMm)) : l10n.slSizeNone,
            key: const ValueKey('sl-size'),
          ),
          subtitle: r.hasSize ? Text(_basis(l10n, r.sizeBasis)) : null,
        ),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
          if (r.confidence != null)
            StatusPill(
              tone: r.confidence! >= 0.7 ? StatusTone.success : (r.confidence! >= 0.4 ? StatusTone.warning : StatusTone.danger),
              label: l10n.slConfidence((r.confidence! * 100).round()),
              dense: true,
            ),
          StatusPill(tone: StatusTone.info, label: l10n.slCheckPlease, dense: true),
        ]),
        if (r.note != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(r.note!, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.slSources, style: theme.textTheme.labelLarge),
        if (r.sourceUrl != null) SelectableText(r.sourceUrl!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
        for (final s in r.sources)
          if (s.url != r.sourceUrl)
            SelectableText([if (s.title != null) s.title!, s.url].join('  '),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
        if (r.sourceUrl == null && r.sources.isEmpty) Text(l10n.slNoSources, style: muted),
      ]);
    }
    if (r?.keyLabel != null || r?.keyFallback == true) {
      children.addAll([
        const SizedBox(height: AppSpacing.sm),
        Text(r!.keyFallback ? l10n.slKeyFallback(r.keyLabel ?? 'GEMINI_API_KEY') : l10n.slKey(r.keyLabel!),
            key: const ValueKey('sl-key'), style: muted),
      ]);
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          ...children,
          const SizedBox(height: AppSpacing.md),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.actionCancel)),
            const SizedBox(width: AppSpacing.sm),
            FilledButton.icon(
              key: const ValueKey('sl-save'),
              onPressed: _saving || r == null || !((_takeWeight && r.hasWeight) || (_takeSize && r.hasSize)) ? null : _save,
              icon: const Icon(Icons.check, size: 18),
              label: Text(l10n.slSave),
            ),
          ]),
        ]),
      ),
    );
  }
}
