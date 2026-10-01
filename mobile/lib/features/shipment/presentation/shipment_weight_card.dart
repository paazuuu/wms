import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../product/presentation/product_labels.dart';
import '../application/packaging_providers.dart';
import '../domain/packaging.dart';
import 'carton_types_screen.dart';

/// What the shipment should weigh (0115): the goods at each product's weight,
/// the boxes and the packing material. Before packing the boxes are the ones
/// planned here; once cartons exist, theirs — each with its own box type.
class ShipmentWeightCard extends ConsumerWidget {
  const ShipmentWeightCard({super.key, required this.planId, this.editable = true});

  final int planId;
  final bool editable;

  void _snack(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _planBoxes(BuildContext context, WidgetRef ref, ShipmentWeightEstimate e) async {
    final items = await showModalBottomSheet<List<PlannedCarton>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PlannedCartonsSheet(estimate: e),
    );
    if (items == null || !context.mounted) return;
    final l10n = AppLocalizations.of(context);
    final r = await ref.read(packagingRepositoryProvider).setPlannedCartons(planId, items);
    if (!context.mounted) return;
    if (r case ApiFailure(:final message)) {
      _snack(context, humanizeApiErrorMessage(l10n, message));
    }
    ref.invalidate(shipmentWeightProvider(planId));
  }

  Future<void> _cartonPackaging(BuildContext context, WidgetRef ref, EstimateCarton c) async {
    final result = await showModalBottomSheet<({int typeId, double? empty, double? material})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CartonPackagingSheet(carton: c),
    );
    if (result == null || !context.mounted) return;
    final l10n = AppLocalizations.of(context);
    final r = await ref.read(packagingRepositoryProvider).setCartonPackaging(c.cartonId,
        cartonTypeId: result.typeId, emptyWeightG: result.empty, packingMaterialG: result.material);
    if (!context.mounted) return;
    if (r case ApiFailure(:final message)) {
      _snack(context, humanizeApiErrorMessage(l10n, message));
    }
    ref.invalidate(shipmentWeightProvider(planId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final async = ref.watch(shipmentWeightProvider(planId));

    return Card(
      key: const ValueKey('ship-weight'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: async.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e', style: TextStyle(color: scheme.error)),
          data: (e) {
            final missing = e.lines.where((l) => l.missing).toList();
            Widget row(String label, String value, {Key? key, bool strong = false}) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Expanded(child: Text(label, style: strong ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium)),
                    Text(value,
                        key: key,
                        style: (strong ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)
                            ?.copyWith(fontFamily: AppFonts.mono)),
                  ]),
                );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                row(l10n.swGoods, gramsText(e.goodsWeightG)),
                row(l10n.swBoxes(e.cartonCount), gramsText(e.boxesWeightG)),
                row(l10n.swMaterial, gramsText(e.packingMaterialG)),
                const Divider(),
                row(l10n.swTotal, '≈ ${gramsText(e.totalWeightG)}', key: const ValueKey('sw-total'), strong: true),
                if (e.measuredWeightG != null)
                  row(l10n.swMeasured, gramsText(e.measuredWeightG!)),
                if (missing.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ExpansionTile(
                    key: const ValueKey('sw-missing'),
                    tilePadding: EdgeInsets.zero,
                    leading: Icon(Icons.warning_amber_outlined, color: scheme.tertiary),
                    title: Text(l10n.swMissing(missing.length), style: theme.textTheme.bodyMedium),
                    children: [
                      for (final l in missing)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(l.productName),
                          subtitle: Text('${l.janCode} · ${l.quantity}'),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                if (!e.fromCartons) ...[
                  Text(e.planned.isEmpty ? l10n.swNoPlan : l10n.swPlanned,
                      style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                  for (final p in e.planned)
                    Text('${p.cartonType} × ${p.quantity}', style: theme.textTheme.bodyMedium),
                  if (e.planned.isEmpty && e.suggested.isNotEmpty)
                    Text(l10n.swSuggest(e.suggested.map((s) => '${s.cartonType}×${s.quantity}').join(' / ')),
                        style: theme.textTheme.bodySmall),
                ] else ...[
                  for (final c in e.cartons)
                    ListTile(
                      key: ValueKey('sw-carton-${c.cartonNo}'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.swCarton(c.cartonNo, c.cartonType ?? l10n.swNoType)),
                      subtitle: Text([
                        if (c.emptyWeightG != null) l10n.swEmpty(gramsText(c.emptyWeightG!)),
                        if (c.packingMaterialG != null) l10n.swMaterialOf(gramsText(c.packingMaterialG!)),
                        l10n.swEstimate(gramsText(c.estimatedG)),
                      ].join(' · ')),
                      trailing: editable
                          ? IconButton(
                              tooltip: l10n.swSetBox,
                              icon: const Icon(Icons.inventory_2_outlined),
                              onPressed: () => _cartonPackaging(context, ref, c),
                            )
                          : null,
                    ),
                ],
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    if (editable && !e.fromCartons)
                      OutlinedButton.icon(
                        key: const ValueKey('sw-plan'),
                        onPressed: () => _planBoxes(context, ref, e),
                        icon: const Icon(Icons.inventory_2_outlined, size: 18),
                        label: Text(l10n.swPlanAction),
                      ),
                    TextButton.icon(
                      key: const ValueKey('sw-types'),
                      onPressed: () async {
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartonTypesScreen()));
                        ref.invalidate(shipmentWeightProvider(planId));
                      },
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      label: Text(l10n.ctTitle),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// How many of each box the shipment will need. Starts from the plan saved
/// so far, or from what the weight alone suggests.
class _PlannedCartonsSheet extends ConsumerStatefulWidget {
  const _PlannedCartonsSheet({required this.estimate});

  final ShipmentWeightEstimate estimate;

  @override
  ConsumerState<_PlannedCartonsSheet> createState() => _PlannedCartonsSheetState();
}

class _PlannedCartonsSheetState extends ConsumerState<_PlannedCartonsSheet> {
  late final Map<int, int> _counts = {
    for (final p in widget.estimate.planned) p.cartonTypeId: p.quantity,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final types = ref.watch(cartonTypesProvider);
    final suggested = {for (final s in widget.estimate.suggested) s.cartonTypeId: s.quantity};

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: types.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text('$e'),
        data: (list) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.swPlanAction, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(l10n.swGoodsLine(gramsText(widget.estimate.goodsWeightG)), style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.md),
              for (final t in list)
                ListTile(
                  key: ValueKey('sw-type-${t.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(t.name),
                  subtitle: Text([
                    if (t.sizeText != null) t.sizeText!,
                    l10n.swEmpty(gramsText(t.emptyWeightG)),
                    if (suggested[t.id] != null) l10n.swSuggestOne(suggested[t.id]!),
                  ].join(' · ')),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      key: ValueKey('sw-minus-${t.id}'),
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: (_counts[t.id] ?? 0) == 0
                          ? null
                          : () => setState(() => _counts[t.id!] = (_counts[t.id] ?? 0) - 1),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text('${_counts[t.id] ?? 0}',
                          key: ValueKey('sw-count-${t.id}'), textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                    ),
                    IconButton(
                      key: ValueKey('sw-plus-${t.id}'),
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setState(() => _counts[t.id!] = (_counts[t.id] ?? 0) + 1),
                    ),
                  ]),
                ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                key: const ValueKey('sw-plan-save'),
                onPressed: () => Navigator.pop(context, [
                  for (final e in _counts.entries)
                    if (e.value > 0) PlannedCarton(cartonTypeId: e.key, quantity: e.value),
                ]),
                child: Text(l10n.productSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One carton's box type, and its empty weight and packing material when
/// they differ from the type's.
class _CartonPackagingSheet extends ConsumerStatefulWidget {
  const _CartonPackagingSheet({required this.carton});

  final EstimateCarton carton;

  @override
  ConsumerState<_CartonPackagingSheet> createState() => _CartonPackagingSheetState();
}

class _CartonPackagingSheetState extends ConsumerState<_CartonPackagingSheet> {
  late int? _typeId = widget.carton.cartonTypeId;
  late final _empty = TextEditingController(text: _num(widget.carton.emptyWeightG));
  late final _material = TextEditingController(text: _num(widget.carton.packingMaterialG));

  static String _num(double? v) => v == null ? '' : formatFactor(v);

  @override
  void dispose() {
    _empty.dispose();
    _material.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final types = ref.watch(cartonTypesProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: types.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text('$e'),
        data: (list) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.swCarton(widget.carton.cartonNo, ''), style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<int>(
              key: const ValueKey('sw-box-type'),
              initialValue: list.any((t) => t.id == _typeId) ? _typeId : null,
              decoration: InputDecoration(labelText: l10n.swBoxType),
              items: [for (final t in list) DropdownMenuItem(value: t.id, child: Text(t.name))],
              onChanged: (v) => setState(() {
                _typeId = v;
                final t = list.firstWhere((t) => t.id == v);
                _empty.text = formatFactor(t.emptyWeightG);
                _material.text = formatFactor(t.packingMaterialG);
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('sw-box-empty'),
              controller: _empty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.ctEmptyWeight, suffixText: 'g'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('sw-box-material'),
              controller: _material,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.ctMaterial, suffixText: 'g'),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: const ValueKey('sw-box-save'),
              onPressed: _typeId == null
                  ? null
                  : () => Navigator.pop(context, (
                        typeId: _typeId!,
                        empty: double.tryParse(_empty.text.trim()),
                        material: double.tryParse(_material.text.trim()),
                      )),
              child: Text(l10n.productSave),
            ),
          ],
        ),
      ),
    );
  }
}
