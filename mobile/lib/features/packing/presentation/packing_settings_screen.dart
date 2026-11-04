import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../product/domain/product.dart';
import '../../shipment/presentation/carton_types_screen.dart';
import '../../stock_ops/presentation/stock_adjustment_screen.dart' show adjustProductMatches, adjustProductsProvider;
import '../data/packing_repository.dart';
import '../domain/packing.dart';
import 'packing_lists_screen.dart' show packingKg;

/// 箱と入数: the few cartons of ours (S, M, L …) and each product's own
/// case — how many go in, its size, what a full one weighs — set by hand
/// or learned from the packing lists uploaded.
class PackingSettingsScreen extends StatefulWidget {
  const PackingSettingsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<PackingSettingsScreen> createState() => _PackingSettingsScreenState();
}

class _PackingSettingsScreenState extends State<PackingSettingsScreen> {
  bool _cases = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final body = Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
        child: SegmentedButton<bool>(
          key: const ValueKey('pk-settings-mode'),
          segments: [
            ButtonSegment(value: true, label: Text(l10n.pkCasePacks), icon: const Icon(Icons.inventory_outlined)),
            ButtonSegment(value: false, label: Text(l10n.pkOurCartons), icon: const Icon(Icons.inbox_outlined)),
          ],
          selected: {_cases},
          onSelectionChanged: (s) => setState(() => _cases = s.first),
        ),
      ),
      Expanded(child: _cases ? const CasePacksView() : const CartonTypesScreen(embedded: true)),
    ]);
    return widget.embedded ? body : Scaffold(appBar: AppBar(title: Text(l10n.pkSettingsTitle)), body: body);
  }
}

String _dims(CasePack c) {
  String n(double? v) => v == null ? '?' : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());
  return c.lengthCm == null ? '' : '${n(c.lengthCm)}×${n(c.widthCm)}×${n(c.heightCm)} cm';
}

class CasePacksView extends ConsumerStatefulWidget {
  const CasePacksView({super.key});

  @override
  ConsumerState<CasePacksView> createState() => _CasePacksViewState();
}

class _CasePacksViewState extends ConsumerState<CasePacksView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _snack(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _edit(CasePack? c) async {
    final l10n = AppLocalizations.of(context);
    var pack = c;
    if (pack == null) {
      final p = await showDialog<Product>(context: context, builder: (_) => const _PickProductDialog());
      if (p == null || !mounted) return;
      pack = CasePack(productId: p.id, caseQuantity: 0, jan: p.janCode, name: p.name, maker: p.maker, sku: p.sku);
    }
    final r = await showDialog<({CasePack? save, bool retire})>(context: context, builder: (_) => _CasePackDialog(pack: pack!));
    if (r == null || !mounted) return;
    final repo = ref.read(packingRepositoryProvider);
    if (r.retire) {
      final x = await repo.retireCasePack(pack.productId);
      _snack(switch (x) {
        ApiSuccess() => l10n.pkCaseRetired,
        ApiFailure(:final message) => humanizeApiErrorMessage(l10n, message),
      });
    } else if (r.save != null) {
      final x = await repo.saveCasePacks([r.save!]);
      _snack(switch (x) {
        ApiSuccess() => l10n.pkCaseSaved,
        ApiFailure(:final message) => humanizeApiErrorMessage(l10n, message),
      });
    }
    ref.invalidate(casePacksProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final async = ref.watch(casePacksProvider);
    final q = _search.text.trim().toLowerCase();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('pk-case-add'),
        onPressed: () => _edit(null),
        icon: const Icon(Icons.add),
        label: Text(l10n.pkCaseAdd),
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(message: '$e', onRetry: () => ref.invalidate(casePacksProvider)),
        data: (all) {
          final shown = [
            for (final c in all)
              if (q.isEmpty || [c.name, c.maker, c.jan, c.sku].any((s) => (s ?? '').toLowerCase().contains(q))) c,
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 96),
            children: [
              Text(l10n.pkCaseHint, style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const ValueKey('pk-case-search'),
                controller: _search,
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.pkCaseSearch, isDense: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(child: Text(l10n.pkCaseEmpty)),
                ),
              for (final c in shown)
                Card(
                  child: ListTile(
                    key: ValueKey('pk-case-${c.productId}'),
                    onTap: () => _edit(c),
                    title: Row(children: [
                      Flexible(child: Text(c.name ?? c.sku ?? c.jan ?? '#${c.productId}', overflow: TextOverflow.ellipsis)),
                      if (c.learned) ...[
                        const SizedBox(width: AppSpacing.sm),
                        StatusPill(tone: StatusTone.info, label: l10n.pkLearned(c.seenCount), dense: true),
                      ],
                    ]),
                    subtitle: Text([
                      if (c.maker != null) c.maker!,
                      if (c.sku != null) c.sku!,
                      if (c.jan != null) c.jan!,
                    ].join(' · ')),
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(l10n.pkCaseQty(c.caseQuantity), style: theme.textTheme.titleSmall),
                      Text([_dims(c), if (c.grossKg != null) '${packingKg(c.grossKg!)} kg'].where((s) => s.isNotEmpty).join(' · '),
                          style: theme.textTheme.bodySmall),
                    ]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PickProductDialog extends ConsumerStatefulWidget {
  const _PickProductDialog();

  @override
  ConsumerState<_PickProductDialog> createState() => _PickProductDialogState();
}

class _PickProductDialogState extends ConsumerState<_PickProductDialog> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final all = ref.watch(adjustProductsProvider).valueOrNull ?? const <Product>[];
    final shown = [for (final p in all) if (adjustProductMatches(p, _search.text)) p].take(50).toList();
    return AlertDialog(
      key: const ValueKey('pk-pick-dialog'),
      title: Text(l10n.pkCaseAdd),
      content: SizedBox(
        width: 460,
        height: 420,
        child: Column(children: [
          TextField(
            key: const ValueKey('pk-pick-search'),
            controller: _search,
            autofocus: true,
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.pkCaseSearch),
            onChanged: (_) => setState(() {}),
          ),
          Expanded(
            child: ListView(children: [
              for (final p in shown)
                ListTile(
                  key: ValueKey('pk-pick-${p.janCode}'),
                  dense: true,
                  title: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text([p.maker ?? '', p.janCode, p.sku ?? ''].where((s) => s.isNotEmpty).join(' · ')),
                  onTap: () => Navigator.pop(context, p),
                ),
            ]),
          ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel))],
    );
  }
}

class _CasePackDialog extends StatefulWidget {
  const _CasePackDialog({required this.pack});

  final CasePack pack;

  @override
  State<_CasePackDialog> createState() => _CasePackDialogState();
}

class _CasePackDialogState extends State<_CasePackDialog> {
  String _t(double? v) => v == null ? '' : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());
  late final _qty = TextEditingController(text: widget.pack.caseQuantity > 0 ? '${widget.pack.caseQuantity}' : '');
  late final _l = TextEditingController(text: _t(widget.pack.lengthCm));
  late final _w = TextEditingController(text: _t(widget.pack.widthCm));
  late final _h = TextEditingController(text: _t(widget.pack.heightCm));
  late final _kg = TextEditingController(text: _t(widget.pack.grossKg));

  @override
  void dispose() {
    for (final c in [_qty, _l, _w, _h, _kg]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _d(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = widget.pack;
    final qty = int.tryParse(_qty.text.trim());
    Widget num(String key, TextEditingController c, String label) => Expanded(
          child: TextField(
            key: ValueKey(key),
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: label, isDense: true),
            onChanged: (_) => setState(() {}),
          ),
        );
    return AlertDialog(
      key: const ValueKey('pk-case-dialog'),
      title: Text(p.name ?? p.sku ?? p.jan ?? '#${p.productId}'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (p.learned) Text(l10n.pkCaseLearnedHint(p.seenCount), style: Theme.of(context).textTheme.bodySmall),
          Row(children: [num('pk-case-qty', _qty, l10n.pkCaseQtyLabel)]),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            num('pk-case-l', _l, l10n.pkLength),
            const SizedBox(width: AppSpacing.sm),
            num('pk-case-w', _w, l10n.pkWidth),
            const SizedBox(width: AppSpacing.sm),
            num('pk-case-h', _h, l10n.pkHeight),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [num('pk-case-kg', _kg, l10n.pkCaseKg)]),
        ]),
      ),
      actions: [
        if (p.caseQuantity > 0)
          TextButton(
            key: const ValueKey('pk-case-retire'),
            onPressed: () => Navigator.pop(context, (save: null, retire: true)),
            child: Text(l10n.pkCaseRetire),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('pk-case-save'),
          onPressed: qty == null || qty <= 0
              ? null
              : () => Navigator.pop(context, (
                    save: CasePack(
                      productId: p.productId,
                      caseQuantity: qty,
                      lengthCm: _d(_l),
                      widthCm: _d(_w),
                      heightCm: _d(_h),
                      grossKg: _d(_kg),
                    ),
                    retire: false,
                  )),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
