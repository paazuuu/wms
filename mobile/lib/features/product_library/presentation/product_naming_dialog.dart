import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../application/product_library_providers.dart';
import '../application/product_naming_providers.dart';
import '../domain/product_image.dart';
import '../domain/product_naming.dart';

/// A product's name, built from its parts in our format (0111): the base
/// name, 単位 and 定価 here, size and colour on the attributes tab, and the
/// format that puts them together — or a name typed by hand.
///
/// Pops true once saved.
class ProductNamingDialog extends ConsumerStatefulWidget {
  const ProductNamingDialog({super.key, required this.productId});

  final int productId;

  @override
  ConsumerState<ProductNamingDialog> createState() => _ProductNamingDialogState();
}

class _ProductNamingDialogState extends ConsumerState<ProductNamingDialog> {
  final _base = TextEditingController();
  final _unit = TextEditingController();
  final _price = TextEditingController();
  final _name = TextEditingController();
  int? _formatId;
  bool _manual = false;
  bool _loaded = false;
  bool _busy = false;

  @override
  void dispose() {
    _base.dispose();
    _unit.dispose();
    _price.dispose();
    _name.dispose();
    super.dispose();
  }

  void _fill(ProductNaming n) {
    if (_loaded) return;
    _loaded = true;
    _base.text = n.baseName ?? '';
    _unit.text = n.unit ?? '';
    _price.text = n.listPrice == null ? '' : _plain(n.listPrice!);
    _name.text = n.name;
    _formatId = n.formatId;
    _manual = n.manual;
  }

  static String _plain(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final base = _base.text.trim();
    if (!_manual && base.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.pnNeedsBase)));
      return;
    }
    setState(() => _busy = true);
    final r = await ref.read(productNamingRepositoryProvider).setNaming(
          widget.productId,
          ProductNamingDraft(
            baseName: base.isEmpty ? null : base,
            unit: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
            listPrice: double.tryParse(_price.text.trim().replaceAll(',', '')),
            formatId: _formatId,
            manual: _manual,
            name: _name.text.trim(),
          ),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    r.when(
      success: (_) {
        ref.invalidate(productNamingProvider(widget.productId));
        ref.invalidate(nameFormatsProvider);
        Navigator.pop(context, true);
      },
      failure: (f) =>
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, f.message)))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final naming = ref.watch(productNamingProvider(widget.productId));
    final formats = ref.watch(nameFormatsProvider).valueOrNull ?? const <NameFormat>[];
    final profile = ref.watch(productProfileProvider(widget.productId)).valueOrNull;
    final n = naming.valueOrNull;
    if (n != null) _fill(n);

    final chosen = formats.where((f) => f.id == _formatId).firstOrNull ?? formats.where((f) => f.isDefault).firstOrNull;
    final attrs = <String, String>{
      for (final a in profile?.attributes ?? const <ProductAttributeValue>[])
        if (a.value != null) a.attribute.key: a.value!,
    };
    final preview = _manual
        ? _name.text.trim()
        : renderProductName(chosen?.template ?? '{base}',
            base: _base.text.trim(), maker: n?.maker, code: n?.sku, jan: n?.janCode, unit: _unit.text.trim(), attributes: attrs);

    return AlertDialog(
      title: Text(l10n.pnTitle),
      content: SizedBox(
        width: 480,
        child: n == null
            ? (naming.hasError
                ? Text(humanizeApiErrorMessage(l10n, '${naming.error}'))
                : const LinearProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (n.baseName == null && !_manual)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(l10n.pnLegacy, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.tertiary)),
                      ),
                    TextField(
                      key: const ValueKey('pn-base'),
                      controller: _base,
                      enabled: !_manual,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(labelText: l10n.pnBaseName),
                    ),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('pn-unit'),
                          controller: _unit,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(labelText: l10n.pnUnit),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('pn-price'),
                          controller: _price,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(labelText: l10n.pnListPrice, prefixText: '¥'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<int?>(
                      key: const ValueKey('pn-format'),
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
                      onChanged: _manual ? null : (v) => setState(() => _formatId = v),
                    ),
                    SwitchListTile(
                      key: const ValueKey('pn-manual'),
                      contentPadding: EdgeInsets.zero,
                      value: _manual,
                      onChanged: (v) => setState(() => _manual = v),
                      title: Text(l10n.pnManual),
                    ),
                    if (_manual)
                      TextField(
                        key: const ValueKey('pn-name'),
                        controller: _name,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(labelText: l10n.pnName),
                      ),
                    const SizedBox(height: AppSpacing.md),
                    Text(l10n.pnPreview, style: theme.textTheme.labelMedium),
                    Text(preview, key: const ValueKey('pn-preview'), style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(l10n.pnAttrsHint, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('pn-save'),
          onPressed: _busy || n == null ? null : _save,
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
