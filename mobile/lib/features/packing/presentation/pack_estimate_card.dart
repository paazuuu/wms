import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../outbound_file/data/outbound_file_repository.dart';
import '../../shipment/domain/packaging.dart' show CartonType;
import '../domain/packing.dart';
import 'packing_lists_screen.dart' show packingKg;
import 'packing_screen.dart' show packDemandsOf;

/// 総重量の見積もり (0199): before anything is packed, what the shipment
/// will weigh — the products by weight and quantity, the cartons (how many,
/// one's weight) and the packing material — so the sea or air freight can
/// be told. The numbers are set here and kept with the list; unset, 未定.
class PackEstimateCard extends ConsumerStatefulWidget {
  const PackEstimateCard({super.key, required this.detail, this.cartons = const [], this.suggest});

  final OutboundFileDetail detail;

  /// Ours, for the usual carton's weight as a hint.
  final List<CartonType> cartons;

  /// How many boxes the products would take (worked out, not saved).
  final Future<int> Function()? suggest;

  @override
  ConsumerState<PackEstimateCard> createState() => _PackEstimateCardState();
}

String _field(num? v) {
  if (v == null) return '';
  return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

double? _parseKg(String t) {
  final s = t.trim().replaceAll(',', '.');
  return s.isEmpty ? null : double.tryParse(s);
}

int? _parseCount(String t) {
  final s = t.trim();
  return s.isEmpty ? null : int.tryParse(s);
}

class _PackEstimateCardState extends ConsumerState<PackEstimateCard> {
  late final _count = TextEditingController(text: _field(widget.detail.file.packCartonCount));
  late final _cartonKg = TextEditingController(text: _field(widget.detail.file.packCartonKg));
  late final _material = TextEditingController(text: _field(widget.detail.file.packMaterialKg));
  bool _busy = false;
  int? _suggested;

  @override
  void dispose() {
    _count.dispose();
    _cartonKg.dispose();
    _material.dispose();
    super.dispose();
  }

  bool get _valid =>
      (_count.text.trim().isEmpty || (_parseCount(_count.text) ?? -1) >= 0) &&
      (_cartonKg.text.trim().isEmpty || (_parseKg(_cartonKg.text) ?? -1) >= 0) &&
      (_material.text.trim().isEmpty || (_parseKg(_material.text) ?? -1) >= 0);

  bool get _dirty {
    final f = widget.detail.file;
    return _parseCount(_count.text) != f.packCartonCount ||
        _parseKg(_cartonKg.text) != f.packCartonKg ||
        _parseKg(_material.text) != f.packMaterialKg;
  }

  void _snack(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _save({bool clear = false}) async {
    final l10n = AppLocalizations.of(context);
    if (clear) {
      _count.clear();
      _cartonKg.clear();
      _material.clear();
    }
    setState(() => _busy = true);
    final id = widget.detail.file.id;
    final r = await ref.read(outboundFileRepositoryProvider).setPackEstimate(id,
        cartonCount: _parseCount(_count.text), cartonKg: _parseKg(_cartonKg.text), materialKg: _parseKg(_material.text));
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess():
        ref.invalidate(outboundFileDetailProvider(id));
        _snack(l10n.pkEstSaved);
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  Future<void> _suggest() async {
    final n = await widget.suggest?.call();
    if (n == null || !mounted) return;
    setState(() {
      _suggested = n;
      _count.text = '$n';
    });
  }

  Widget _input(String key, TextEditingController c, String label, String suffix, {bool decimal = true, String? helper}) =>
      SizedBox(
        width: 190,
        child: TextField(
          key: ValueKey(key),
          controller: c,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          decoration: InputDecoration(labelText: label, suffixText: suffix, isDense: true, helperText: helper, helperMaxLines: 2),
          onChanged: (_) => setState(() {}),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final e = packEstimateOf(packDemandsOf(widget.detail),
        cartonCount: _parseCount(_count.text), cartonKg: _parseKg(_cartonKg.text), materialKg: _parseKg(_material.text));
    final usual = widget.cartons.where((c) => c.active && c.isDefault).firstOrNull;
    final undecided = l10n.pkEstUndecided;

    Widget line(String label, String value, {Key? key, TextStyle? style, String? note}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Expanded(
              child: Text.rich(TextSpan(children: [
                TextSpan(text: label, style: style),
                if (note != null) TextSpan(text: '  $note', style: muted),
              ])),
            ),
            Text(value, key: key, style: style),
          ]),
        );

    return Card(
      key: const ValueKey('pk-estimate'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.scale_outlined, color: scheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(l10n.pkEstTitle, style: theme.textTheme.titleSmall)),
          ]),
          const SizedBox(height: 4),
          Text(l10n.pkEstHint, style: muted),
          const SizedBox(height: AppSpacing.md),
          Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.start, children: [
            _input('pk-est-count', _count, l10n.pkEstCartonCount, l10n.uomBox, decimal: false),
            _input('pk-est-carton-kg', _cartonKg, l10n.pkEstCartonKg, 'kg',
                helper: usual == null || usual.emptyWeightG <= 0
                    ? null
                    : '${usual.name}: ${packingKg(usual.emptyWeightG / 1000)} kg'),
            _input('pk-est-material-kg', _material, l10n.pkEstMaterialKg, 'kg'),
          ]),
          if (widget.suggest != null)
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: AppSpacing.sm, children: [
              TextButton.icon(
                key: const ValueKey('pk-est-suggest'),
                onPressed: _busy ? null : _suggest,
                icon: const Icon(Icons.calculate_outlined, size: 18),
                label: Text(l10n.pkEstSuggest),
              ),
              if (_suggested != null) Text(l10n.pkEstSuggested(_suggested!), key: const ValueKey('pk-est-suggested'), style: muted),
            ]),
          const Divider(height: AppSpacing.lg),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          line(l10n.pkEstProducts, '${packingKg(e.productKg)} kg',
              key: const ValueKey('pk-est-products'), note: l10n.pkDemandTotal(e.rows, e.quantity)),
          if (e.unknownRows > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(key: const ValueKey('pk-est-unknown'), children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: scheme.warning),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(l10n.pkEstUnknown(e.unknownRows, e.unknownQuantity),
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.warning)),
                ),
              ]),
            ),
          line(
            l10n.pkEstCartons(e.cartonCount == null ? undecided : '${e.cartonCount}',
                e.cartonKg == null ? undecided : packingKg(e.cartonKg!)),
            e.cartonsKg == null ? undecided : '${packingKg(e.cartonsKg!)} kg',
            key: const ValueKey('pk-est-cartons'),
          ),
          line(l10n.pkEstMaterial, e.materialKg == null ? undecided : '${packingKg(e.materialKg!)} kg',
              key: const ValueKey('pk-est-material')),
          const Divider(height: AppSpacing.md),
          line(l10n.pkEstTotal, '${packingKg(e.totalKg)} kg',
              key: const ValueKey('pk-est-total'),
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ]),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
            FilledButton.icon(
              key: const ValueKey('pk-est-save'),
              onPressed: _busy || !_valid || !_dirty ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(l10n.pkEstSave),
            ),
            if (!e.undecided || _dirty)
              TextButton(
                key: const ValueKey('pk-est-clear'),
                onPressed: _busy ? null : () => _save(clear: true),
                child: Text(l10n.pkEstClear),
              ),
            if (_dirty && _valid) Text(l10n.pkEstUnsaved, style: theme.textTheme.bodySmall?.copyWith(color: scheme.warning)),
          ]),
        ]),
      ),
    );
  }
}
