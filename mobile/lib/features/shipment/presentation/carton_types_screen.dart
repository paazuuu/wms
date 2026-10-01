import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../product/presentation/product_labels.dart';
import '../application/packaging_providers.dart';
import '../domain/packaging.dart';

/// The boxes we ship in (0115): size, empty weight, the packing material
/// that usually goes in, and how much a box takes. Added and changed here;
/// a box no longer used is retired rather than deleted, since old cartons
/// still name it.
class CartonTypesScreen extends ConsumerWidget {
  const CartonTypesScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, [CartonType? type]) async {
    final draft = await showDialog<CartonType>(
      context: context,
      builder: (_) => _CartonTypeDialog(type: type),
    );
    if (draft == null || !context.mounted) return;
    final l10n = AppLocalizations.of(context);
    final r = await ref.read(packagingRepositoryProvider).saveCartonType(draft);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(switch (r) {
        ApiSuccess() => l10n.ctSaved,
        ApiFailure(:final message) => humanizeApiErrorMessage(l10n, message),
      }),
    ));
    ref.invalidate(allCartonTypesProvider);
    ref.invalidate(cartonTypesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final async = ref.watch(allCartonTypesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ctTitle)),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('ct-add'),
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.ctAdd),
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(message: '$e', onRetry: () => ref.invalidate(allCartonTypesProvider)),
        data: (types) => ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
          children: [
            Text(l10n.ctHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            for (final t in types)
              Card(
                child: ListTile(
                  key: ValueKey('ct-${t.id}'),
                  onTap: () => _edit(context, ref, t),
                  title: Row(children: [
                    Flexible(child: Text(t.name)),
                    if (t.isDefault) ...[
                      const SizedBox(width: AppSpacing.sm),
                      StatusPill(tone: StatusTone.success, label: l10n.ctDefault, dense: true),
                    ],
                    if (!t.active) ...[
                      const SizedBox(width: AppSpacing.sm),
                      StatusPill(tone: StatusTone.neutral, label: l10n.ctInactive, dense: true),
                    ],
                  ]),
                  subtitle: Text([
                    if (t.sizeText != null) t.sizeText!,
                    l10n.swEmpty(gramsText(t.emptyWeightG)),
                    l10n.swMaterialOf(gramsText(t.packingMaterialG)),
                    if (t.maxLoadKg != null) l10n.ctMaxLoadOf(formatFactor(t.maxLoadKg!)),
                  ].join(' · ')),
                  trailing: const Icon(Icons.edit_outlined),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CartonTypeDialog extends StatefulWidget {
  const _CartonTypeDialog({this.type});

  final CartonType? type;

  @override
  State<_CartonTypeDialog> createState() => _CartonTypeDialogState();
}

class _CartonTypeDialogState extends State<_CartonTypeDialog> {
  static String _n(double? v) => v == null ? '' : formatFactor(v);
  late final _name = TextEditingController(text: widget.type?.name ?? '');
  late final _l = TextEditingController(text: _n(widget.type?.lengthCm));
  late final _w = TextEditingController(text: _n(widget.type?.widthCm));
  late final _h = TextEditingController(text: _n(widget.type?.heightCm));
  late final _empty = TextEditingController(text: _n(widget.type?.emptyWeightG));
  late final _material = TextEditingController(text: _n(widget.type?.packingMaterialG));
  late final _max = TextEditingController(text: _n(widget.type?.maxLoadKg));
  late bool _default = widget.type?.isDefault ?? false;
  late bool _active = widget.type?.active ?? true;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _l, _w, _h, _empty, _material, _max]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) => double.tryParse(c.text.trim());

  void _save() {
    final l10n = AppLocalizations.of(context);
    if (_name.text.trim().isEmpty) {
      setState(() => _error = l10n.productValidationRequired);
      return;
    }
    final nums = [_l, _w, _h, _empty, _material, _max];
    if (nums.any((c) => c.text.trim().isNotEmpty && (_num(c) == null || _num(c)! < 0))) {
      setState(() => _error = l10n.wtInvalid);
      return;
    }
    Navigator.pop(
      context,
      CartonType(
        id: widget.type?.id,
        name: _name.text.trim(),
        lengthCm: _num(_l),
        widthCm: _num(_w),
        heightCm: _num(_h),
        emptyWeightG: _num(_empty) ?? 0,
        packingMaterialG: _num(_material) ?? 0,
        maxLoadKg: (_num(_max) ?? 0) > 0 ? _num(_max) : null,
        isDefault: _default,
        active: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget field(TextEditingController c, String label, String key, {String? suffix}) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: TextField(
            key: ValueKey(key),
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: label, suffixText: suffix),
          ),
        );

    return AlertDialog(
      title: Text(widget.type == null ? l10n.ctAdd : l10n.ctEdit),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('ct-name'),
                controller: _name,
                decoration: InputDecoration(labelText: l10n.ctName),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(children: [
                Expanded(child: field(_l, l10n.ctLength, 'ct-l', suffix: 'cm')),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: field(_w, l10n.ctWidth, 'ct-w', suffix: 'cm')),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: field(_h, l10n.ctHeight, 'ct-h', suffix: 'cm')),
              ]),
              field(_empty, l10n.ctEmptyWeight, 'ct-empty', suffix: 'g'),
              field(_material, l10n.ctMaterial, 'ct-material', suffix: 'g'),
              field(_max, l10n.ctMaxLoad, 'ct-max', suffix: 'kg'),
              SwitchListTile(
                key: const ValueKey('ct-default'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.ctDefault),
                value: _default,
                onChanged: (v) => setState(() => _default = v),
              ),
              SwitchListTile(
                key: const ValueKey('ct-active'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.ctActive),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              if (_error != null)
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(key: const ValueKey('ct-save'), onPressed: _save, child: Text(l10n.productSave)),
      ],
    );
  }
}
