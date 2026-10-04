import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/fields_dialog.dart';
import '../../../core/ui/product_name.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../partners/domain/trading_partner.dart';
import '../../product/presentation/product_detail_screen.dart';
import '../../product/presentation/product_labels.dart';
import '../../product/presentation/product_lifecycle_ui.dart';
import '../../product_library/application/product_library_providers.dart';
import '../application/catalog_providers.dart';
import '../domain/catalog.dart';
import 'catalog_import_screen.dart' show importSuppliersProvider;
import 'catalog_thumb.dart';

String _yen(double v) => '¥${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2)}';
String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// One library item: what it is — with its own pictures, size and weight —
/// its stock when it is in the master, and a tab per supplier with what that
/// supplier calls it and its terms by branch: the ones in force now, and
/// every earlier one with its dates.
class CatalogItemScreen extends ConsumerWidget {
  const CatalogItemScreen({super.key, required this.itemId});

  final int itemId;

  Future<void> _addTerm(BuildContext context, WidgetRef ref, CatalogItem item, {int? partnerId, String? branch}) async {
    final l10n = AppLocalizations.of(context);
    var partner = partnerId;
    if (partner == null) {
      final suppliers = await ref.read(importSuppliersProvider.future).catchError((_) => const <TradingPartner>[]);
      if (!context.mounted) return;
      partner = await showDialog<int>(
        context: context,
        builder: (d) => SimpleDialog(
          title: Text(l10n.quoteSupplier),
          children: [
            for (final p in suppliers)
              SimpleDialogOption(key: ValueKey('cit-partner-${p.id}'), onPressed: () => Navigator.pop(d, p.id), child: Text(p.name)),
          ],
        ),
      );
      if (partner == null || !context.mounted) return;
    }
    final v = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => FieldsDialog(
        title: l10n.citAddTerm,
        keyPrefix: 'cit',
        fields: {
          'branch': (l10n.ciBranch, branch ?? ''),
          'valid_from': (l10n.citValidFromField, _day(DateTime.now())),
          'unit_price': (l10n.quoteUnitPriceLabel, ''),
          'list_price': (l10n.pdListPrice, ''),
          'discount_rate': (l10n.citRateField, ''),
          'case_quantity': (l10n.quoteCaseLabel, ''),
          'their_code': (l10n.quoteTheirCode, ''),
          'their_name': (l10n.citTheirName, ''),
        },
        saveKey: const ValueKey('cit-save'),
        saveLabel: l10n.productSave,
        cancelLabel: l10n.actionCancel,
      ),
    );
    if (v == null || !context.mounted) return;
    final rate = double.tryParse(v['discount_rate'] ?? '');
    final r = await ref.read(catalogRepositoryProvider).addTerm(item.id, {
      'partner_id': partner,
      'branch': v['branch'],
      'valid_from': v['valid_from'],
      'unit_price': v['unit_price'],
      'list_price': v['list_price'],
      // 60 or 0.6 both mean 60%.
      'discount_rate': rate == null ? null : (rate > 2 ? rate / 100 : rate),
      'case_quantity': v['case_quantity'],
      'their_code': v['their_code'],
      'their_name': v['their_name'],
    });
    if (!context.mounted) return;
    switch (r) {
      case ApiSuccess():
        ref.invalidate(catalogHistoryProvider(item.id));
        ref.invalidate(catalogListProvider);
      case ApiFailure(:final message):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
  }

  /// Correcting the item's own record: only what changed is sent (0125).
  Future<void> _edit(BuildContext context, WidgetRef ref, CatalogItem item) async {
    final l10n = AppLocalizations.of(context);
    String n(double? v) => v == null ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v');
    final current = <String, (String, String)>{
      'name': (l10n.citNameField, item.name),
      'maker': (l10n.pdMaker, item.maker ?? ''),
      'base_name': (l10n.pdBaseName, item.baseName ?? ''),
      'item_code': (l10n.pdCode, item.itemCode ?? ''),
      'jan_code': (l10n.pdJan, item.janCode ?? ''),
      'unit': (l10n.pdUnit, item.unit ?? ''),
      'list_price': (l10n.pdListPrice, n(item.listPrice)),
      'weight_g': (l10n.specWeightField, n(item.weightG)),
      'width_mm': ('${l10n.specWidth} (mm)', n(item.widthMm)),
      'depth_mm': ('${l10n.specDepth} (mm)', n(item.depthMm)),
      'height_mm': ('${l10n.specHeight} (mm)', n(item.heightMm)),
      'size_note': (l10n.specSizeNote, item.sizeNote ?? ''),
    };
    final v = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => FieldsDialog(
        title: l10n.citEdit,
        keyPrefix: 'cit-edit',
        fields: current,
        saveKey: const ValueKey('cit-edit-save'),
        saveLabel: l10n.productSave,
        cancelLabel: l10n.actionCancel,
      ),
    );
    if (v == null || !context.mounted) return;
    const numbers = {'list_price', 'weight_g', 'width_mm', 'depth_mm', 'height_mm'};
    final changed = <String, dynamic>{
      for (final e in v.entries)
        if (e.value.trim() != current[e.key]!.$2.trim())
          e.key: e.value.trim().isEmpty
              ? null
              : numbers.contains(e.key)
                  ? double.tryParse(e.value.trim().replaceAll(',', ''))
                  : e.value.trim(),
    };
    if (changed.isEmpty) return;
    final r = await ref.read(catalogRepositoryProvider).update(item.id, changed);
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    switch (r) {
      case ApiSuccess():
        ref.invalidate(catalogListProvider);
        messenger.showSnackBar(SnackBar(content: Text(l10n.citSaved)));
      case ApiFailure(:final message):
        messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(catalogListProvider);
    final item = async.valueOrNull?.where((i) => i.id == itemId).firstOrNull;
    final history = ref.watch(catalogHistoryProvider(itemId)).valueOrNull ?? const <CatalogTerm>[];
    final canManage = ref.watch(productLibraryCanManageProvider);

    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.clTitle)),
        body: async.isLoading ? LoadingView(message: l10n.loading) : EmptyStateView(icon: Icons.local_library_outlined, title: l10n.clEmpty),
      );
    }
    // A tab per supplier the item has ever had a term with.
    final partners = <int, String>{};
    for (final t in [...item.terms, ...history]) {
      partners.putIfAbsent(t.partnerId, () => t.partnerName);
    }

    final overview = _Overview(
      item: item,
      onAddTerm: canManage ? () => _addTerm(context, ref, item) : null,
      onEdit: canManage ? () => _edit(context, ref, item) : null,
    );
    return DefaultTabController(
      length: 1 + partners.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widenKana(item.name)),
          bottom: partners.isEmpty
              ? null
              : TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(key: const ValueKey('cit-tab-overview'), text: l10n.citOverview),
                    for (final e in partners.entries)
                      Tab(
                        key: ValueKey('cit-tab-${e.key}'),
                        text: switch (item.terms.where((t) => t.partnerId == e.key && t.unitPrice != null).firstOrNull) {
                          final t? => '${e.value}  ${_yen(t.unitPrice!)}',
                          _ => e.value,
                        },
                      ),
                  ],
                ),
        ),
        body: partners.isEmpty
            ? overview
            : TabBarView(children: [
                overview,
                for (final e in partners.entries)
                  _SupplierTermsTab(
                    key: ValueKey('cit-supplier-${e.key}'),
                    partnerName: e.value,
                    current: [for (final t in item.terms) if (t.partnerId == e.key) t],
                    history: [for (final t in history) if (t.partnerId == e.key) t],
                    onAdd: canManage ? (branch) => _addTerm(context, ref, item, partnerId: e.key, branch: branch) : null,
                  ),
              ]),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.item, this.onAddTerm, this.onEdit});

  final CatalogItem item;
  final VoidCallback? onAddTerm;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    Widget row(String k, String? v, String key) => v == null
        ? const SizedBox.shrink()
        : Padding(
            key: ValueKey(key),
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 120, child: Text(k, style: muted)),
              Expanded(child: Text(v, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500))),
            ]),
          );
    final i = item;
    final size = sizeText(l10n, width: i.widthMm, depth: i.depthMm, height: i.heightMm, note: i.sizeNote);
    return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
      // Its face, maker and name, large.
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CatalogThumb(key: const ValueKey('cit-face'), item: i, size: 120),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (i.maker != null)
                  Text(widenKana(i.maker!), style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
                Text(widenKana(i.name), style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(i.imageCount == 0 ? l10n.plNoImages : l10n.plImageCount(i.imageCount), style: muted),
                if (onEdit != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton.tonalIcon(
                    key: const ValueKey('cit-edit'),
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(l10n.citEdit),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.pdBasics, style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            row(l10n.pdMaker, i.maker == null ? null : widenKana(i.maker!), 'cit-maker'),
            row(l10n.pdBaseName, widenKana(i.baseName ?? i.name), 'cit-name'),
            row(l10n.pdCode, i.itemCode, 'cit-code'),
            row(l10n.pdJan, i.janCode, 'cit-jan'),
            row(l10n.pdSpec, i.spec, 'cit-spec'),
            for (final (n, v) in i.attributes) row(n, widenKana(v), 'cit-attr-$n'),
            row(l10n.pdUnit, i.unit, 'cit-unit'),
            row(l10n.pdListPrice, i.listPrice == null ? null : _yen(i.listPrice!), 'cit-list'),
            row(l10n.specSize, size ?? l10n.specNotEntered, 'cit-size'),
            row(l10n.specWeight, i.weightG == null ? l10n.specNotEntered : gramsText(i.weightG!), 'cit-weight'),
            row(l10n.citSourceFile, i.sourceFile, 'cit-file'),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.citSpecFromLibrary, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ]),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      // The master: whether it is there, and its stock when it is.
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.citMaster, style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            if (i.product case final p?) ...[
              Row(children: [
                Expanded(child: Text(p.name, style: theme.textTheme.titleSmall)),
                LifecyclePill(lifecycle: p.lifecycle),
              ]),
              if (!p.linked) Text(l10n.citFoundByJan, style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.xs),
              if (i.stock case final st?)
                StockLine(key: const ValueKey('cit-stock'), stock: st, style: theme.textTheme.titleSmall)
              else
                Text(l10n.stockNone),
              for (final w in i.stock?.warehouses ?? const [])
                Text('${w.name}　${l10n.stockWarehouseRow(w.onHand, w.reserved, w.available)}', style: theme.textTheme.bodySmall),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('cit-open-master'),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: p.id))),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(l10n.citOpenMaster),
                ),
              ),
            ] else
              Text(l10n.citNotInMaster, key: const ValueKey('cit-not-in-master')),
          ]),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.citCurrentTerms, style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            if (i.terms.isEmpty) Text(l10n.citNoTerms),
            for (final t in i.terms) _TermRow(term: t, showPartner: true),
            if (onAddTerm != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('cit-add-term'),
                  onPressed: onAddTerm,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.citAddTerm),
                ),
              ),
          ]),
        ),
      ),
    ]);
  }
}

class _SupplierTermsTab extends StatelessWidget {
  const _SupplierTermsTab({super.key, required this.partnerName, required this.current, required this.history, this.onAdd});

  final String partnerName;
  final List<CatalogTerm> current;
  final List<CatalogTerm> history;
  final void Function(String? branch)? onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final currentIds = {for (final t in current) t.id};
    // By branch: the one in force first, then the rest, newest first.
    final byWhere = <String, List<CatalogTerm>>{};
    for (final t in history.isEmpty ? current : history) {
      byWhere.putIfAbsent(t.where ?? '', () => []).add(t);
    }
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    Widget fact(String k, String v, String key) => Padding(
          key: ValueKey(key),
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 120, child: Text(k, style: muted)),
            Expanded(child: Text(v, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500))),
          ]),
        );
    String rate(double r) => '${(r * 100).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')}%';
    // What it calls the product and on what terms, now, branch by branch.
    final now = current.isNotEmpty ? current : history.take(1).toList();
    return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
      Card(
        key: const ValueKey('cit-naming'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.citHowTheyCall, style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            if (now.every((t) => t.theirName == null && t.theirCode == null))
              Text(l10n.citNoNaming, style: muted),
            for (final t in now) ...[
              if (now.length > 1 || t.where != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(t.where ?? l10n.citAllBranches, style: theme.textTheme.titleSmall),
                ),
              if (t.theirName != null) fact(l10n.citTheirName, widenKana(t.theirName!), 'cit-their-name-${t.id}'),
              if (t.theirCode != null) fact(l10n.citTheirCodeLabel, widenKana(t.theirCode!), 'cit-their-code-${t.id}'),
              if (t.unitPrice != null) fact(l10n.quoteUnitPriceLabel, _yen(t.unitPrice!), 'cit-their-price-${t.id}'),
              if (t.listPrice != null) fact(l10n.pdListPrice, _yen(t.listPrice!), 'cit-their-list-${t.id}'),
              if (t.discountRate != null) fact(l10n.citRateLabel, rate(t.discountRate!), 'cit-their-rate-${t.id}'),
              if (t.caseQuantity != null) fact(l10n.quoteCaseLabel, '${t.caseQuantity}', 'cit-their-case-${t.id}'),
            ],
          ]),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Text(l10n.citSupplierHint(partnerName), style: theme.textTheme.bodySmall),
      const SizedBox(height: AppSpacing.sm),
      for (final e in byWhere.entries)
        Card(
          key: ValueKey('cit-where-${e.key}'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(e.key.isEmpty ? l10n.citAllBranches : e.key, style: theme.textTheme.titleSmall)),
                if (onAdd != null)
                  TextButton.icon(
                    key: ValueKey('cit-add-${e.key}'),
                    onPressed: () => onAdd!(e.key.isEmpty ? null : e.key),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.citNewTerm),
                  ),
              ]),
              for (final t in e.value)
                _TermRow(term: t, current: currentIds.contains(t.id), showPartner: false),
            ]),
          ),
        ),
      if (onAdd != null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('cit-add-branch'),
            onPressed: () => onAdd!(null),
            icon: const Icon(Icons.add_business_outlined, size: 18),
            label: Text(l10n.citAddBranch),
          ),
        ),
    ]);
  }
}

class _TermRow extends StatelessWidget {
  const _TermRow({required this.term, this.current = true, this.showPartner = false});

  final CatalogTerm term;
  final bool current;
  final bool showPartner;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final t = term;
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final period = t.validTo == null ? l10n.citFrom(_day(t.validFrom)) : l10n.citPeriod(_day(t.validFrom), _day(t.validTo!));
    return Opacity(
      opacity: current ? 1 : 0.6,
      child: Padding(
        key: ValueKey('cit-term-${t.id}'),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(
                    [if (showPartner) t.partnerName, if (showPartner && t.where != null) '(${t.where})', period].join(' '),
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (!current) ...[
                  const SizedBox(width: 6),
                  StatusPill(tone: StatusTone.neutral, label: l10n.citPast, dense: true),
                ],
              ]),
              Text(
                [
                  if (t.listPrice != null) l10n.quoteListPrice(_yen(t.listPrice!)),
                  if (t.discountRate != null)
                    l10n.quoteRate('${(t.discountRate! * 100).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')}%'),
                  if (t.caseQuantity != null) l10n.quoteCase('${t.caseQuantity}'),
                  if (t.theirCode != null) l10n.supTheirCode(widenKana(t.theirCode!)),
                  if (t.theirName != null) l10n.supTheirName(widenKana(t.theirName!)),
                  if (t.sourceFile != null) t.sourceFile!,
                ].join('　'),
                style: muted,
              ),
            ]),
          ),
          Text(t.unitPrice == null ? l10n.supNoPrice : _yen(t.unitPrice!),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
