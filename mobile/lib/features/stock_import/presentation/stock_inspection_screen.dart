import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../master_import/data/master_import_repository.dart';
import '../../master_import/domain/master_import.dart';
import '../../product/application/product_providers.dart';
import '../../product/data/web_photos.dart';
import '../../product/data/market_names.dart';
import '../../product/domain/product.dart';
import '../../product/presentation/product_labels.dart' show gramsText;
import '../../product/presentation/product_marks_ui.dart';
import '../../product_library/application/product_library_providers.dart';
import '../../product_library/presentation/product_gallery_screen.dart';
import '../../product_library/presentation/product_thumb.dart';
import '../../shelf_notes/data/shelf_notes_repository.dart';
import '../../shelf_notes/presentation/shelf_notes_screen.dart';
import '../../qc/domain/inspection.dart' show normalizeJan;
import '../data/stock_import_repository.dart';
import '../domain/stock_ledger.dart';

/// Whether the person may check stock files in (0148).
bool canInspectStockFiles(WidgetRef ref) {
  final u = ref.watch(authControllerProvider).user;
  return (u?.hasPermission('inspection.confirm') ?? false) || (u?.hasPermission('inventory.adjust') ?? false);
}

/// 取込の検品 (0148): stock read from a file waits here, 「検品未完了」,
/// until someone counts it and checks it in. Only then is it in stock.
/// A separate screen from the import, so the one who reads the file in and
/// the one who counts the goods can be different people at different times.
class StockInspectionScreen extends ConsumerWidget {
  const StockInspectionScreen({super.key, this.openImportId});

  /// Straight to this file's lines (from the import just made).
  final int? openImportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (openImportId case final id?) return StockInspectionDetailScreen(importId: id);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final list = ref.watch(awaitingImportsProvider);
    final fmt = DateFormat('y/MM/dd HH:mm');
    return Scaffold(
      appBar: AppBar(title: Text(l10n.featStockInspection)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(awaitingImportsProvider),
        child: list.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorStateView(
              message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => ref.invalidate(awaitingImportsProvider)),
          data: (items) => items.isEmpty
              ? ListView(children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Center(child: Text(l10n.siEmpty, key: const ValueKey('si-empty'))),
                  ),
                ])
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    Text(l10n.siIntro, style: theme.textTheme.bodySmall),
                    const SizedBox(height: AppSpacing.sm),
                    for (final a in items)
                      Card(
                        key: ValueKey('si-import-${a.id}'),
                        child: ListTile(
                          leading: const Icon(Icons.pending_actions_outlined),
                          title: Text(l10n.siFile(a.id, a.fileName ?? '')),
                          subtitle: Text([
                            if (a.warehouseName case final w?) w,
                            l10n.siLeft(a.left, a.lines, a.quantityLeft),
                            if (a.createdAt case final c?) l10n.siBy(a.createdByName ?? '', fmt.format(c)),
                          ].join(' · ')),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.of(context)
                                .push(MaterialPageRoute(builder: (_) => StockInspectionDetailScreen(importId: a.id)));
                            ref.invalidate(awaitingImportsProvider);
                          },
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// One file's lines to count: tick what was checked, change the count where
/// it differs from the file, and check them in.
class StockInspectionDetailScreen extends ConsumerStatefulWidget {
  const StockInspectionDetailScreen({super.key, required this.importId});

  final int importId;

  @override
  ConsumerState<StockInspectionDetailScreen> createState() => _StockInspectionDetailScreenState();
}

class _StockInspectionDetailScreenState extends ConsumerState<StockInspectionDetailScreen> {
  MasterImport? _import;
  String? _error;
  bool _busy = false;

  /// Lines ticked, and the count typed for each (the file's until changed).
  final Set<int> _ticked = {};
  final Map<int, TextEditingController> _counts = {};
  final _scan = TextEditingController();
  String? _scanMiss;

  /// Narrowing many lines (0167): words (商品名・JAN・品番・メーカー), makers,
  /// marks, and which lines (to check / checked / all).
  final _query = TextEditingController();
  final Set<String> _makers = {};
  final Set<String> _marks = {};
  String _which = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _counts.values) {
      c.dispose();
    }
    _scan.dispose();
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await ref.read(masterImportRepositoryProvider).detail(widget.importId);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      switch (r) {
        case ApiSuccess(:final data):
          _import = data;
          _error = null;
          for (final l in data.lines) {
            _counts.putIfAbsent(l.lineNo, () => TextEditingController(text: '${l.quantity}'));
          }
          _ticked.removeWhere((n) => data.lines.any((l) => l.lineNo == n && l.inspected));
        case ApiFailure(:final message):
          _error = humanizeApiErrorMessage(l10n, message);
      }
    });
  }

  List<MasterImportLine> get _open => [
        for (final l in _import?.lines ?? const <MasterImportLine>[])
          if (!l.inspected) l
      ];

  int? _count(MasterImportLine l) {
    final v = int.tryParse(_counts[l.lineNo]?.text.trim() ?? '');
    return v == null || v < 0 ? null : v;
  }

  /// A scanned or typed JAN ticks its line.
  void _onScan(String raw) {
    final jan = normalizeJan(raw) ?? raw.trim();
    final hit = _open.where((l) => l.janCode == jan).firstOrNull;
    setState(() {
      _scanMiss = hit == null && jan.isNotEmpty ? jan : null;
      if (hit != null) _ticked.add(hit.lineNo);
    });
    _scan.clear();
  }

  Future<void> _checkIn() async {
    final l10n = AppLocalizations.of(context);
    final lines = [
      for (final l in _open)
        if (_ticked.contains(l.lineNo)) l
    ];
    if (lines.isEmpty) return;
    final bad = lines.where((l) => _count(l) == null).toList();
    if (bad.isNotEmpty) {
      setState(() => _error = l10n.siBadCount(bad.first.name ?? bad.first.janCode));
      return;
    }
    final units = lines.fold<int>(0, (s, l) => s + _count(l)!);
    final diff = lines.fold<int>(0, (s, l) => s + _count(l)! - l.quantity);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.siConfirmQ),
        content: Text(l10n.siConfirmBody(lines.length, units, diff > 0 ? '+$diff' : '$diff'),
            key: const ValueKey('si-confirm-body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l10n.actionCancel)),
          FilledButton(
              key: const ValueKey('si-confirm'),
              onPressed: () => Navigator.pop(d, true),
              child: Text(l10n.siConfirmGo)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await ref
        .read(stockImportRepositoryProvider)
        .inspect(widget.importId, [for (final l in lines) InspectedLine(l.lineNo, _count(l)!)]);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        ref.invalidate(pendingInspectionProvider);
        ref.invalidate(awaitingImportsProvider);
        ref.invalidate(productListProvider);
        ref.invalidate(masterImportsProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.siDone(data.lines, data.left))));
        _ticked.clear();
        await _load();
      case ApiFailure(:final message):
        setState(() => _error = humanizeApiErrorMessage(l10n, message));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = _import;
    final may = canInspectStockFiles(ref);
    final open = _open;
    final ticked = [
      for (final l in open)
        if (_ticked.contains(l.lineNo)) l
    ];
    // Each line's product as the library has it: picture, names, maker,
    // 品番, attributes, weight, marks (0167); and its shelf notes.
    final products = {for (final p in ref.watch(productListProvider).valueOrNull ?? const <Product>[]) p.janCode: p};
    final notes = ref.watch(shelfNotesProvider).valueOrNull ?? const <ShelfNote>[];
    List<ShelfNote> notesOf(Product? p, String jan) => [
          for (final n in notes)
            if ((p != null && n.productId == p.id) || n.janCode == jan) n
        ];
    final makers = <String>{
      for (final l in m?.lines ?? const <MasterImportLine>[])
        if (products[l.janCode]?.maker case final mk? when mk.trim().isNotEmpty) mk.trim(),
    }.toList()
      ..sort();
    bool shown(MasterImportLine l) {
      final p = products[l.janCode];
      if (_which == 'open' && l.inspected) return false;
      if (_which == 'done' && !l.inspected) return false;
      if (_makers.isNotEmpty && !_makers.contains(p?.maker?.trim() ?? '')) return false;
      if (_marks.isNotEmpty && !(p?.marks.any(_marks.contains) ?? false)) return false;
      final q = _query.text.trim().toLowerCase();
      if (q.isEmpty) return true;
      return [l.name ?? '', l.janCode, p?.name ?? '', p?.baseName ?? '', p?.sku ?? '', p?.maker ?? '']
          .any((t) => t.toLowerCase().contains(q));
    }

    final visible = [
      for (final l in m?.lines ?? const <MasterImportLine>[])
        if (shown(l)) l
    ];
    final visibleOpen = [
      for (final l in visible)
        if (!l.inspected) l
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.siTitle(widget.importId))),
      body: m == null
          ? (_error == null ? const LoadingView() : ErrorStateView(message: _error!, onRetry: _load))
          // On a PC every line is one row; on a phone a card (0167).
          : LayoutBuilder(builder: (context, box) {
              final wide = box.maxWidth >= 1100;
              return ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 120),
                children: [
                  Text(m.originalName ?? '', style: theme.textTheme.titleMedium),
                  if (m.warehouseName case final w?) Text(w, style: theme.textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    m.status == MasterImportStatus.awaitingInspection
                        ? l10n.siOpenLines(open.length, m.lines.length)
                        : l10n.siAllDone,
                    key: const ValueKey('si-status'),
                    style: theme.textTheme.titleSmall,
                  ),
                  if (!may)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(l10n.siNoPermission, style: theme.textTheme.bodySmall),
                    ),
                  if (open.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      key: const ValueKey('si-scan'),
                      controller: _scan,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.qr_code_scanner),
                        labelText: l10n.siScan,
                        border: const OutlineInputBorder(),
                        errorText: _scanMiss == null ? null : l10n.siScanMiss(_scanMiss!),
                      ),
                      onSubmitted: _onScan,
                    ),
                    CheckboxListTile(
                      key: const ValueKey('si-all'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: visibleOpen.isNotEmpty && visibleOpen.every((l) => _ticked.contains(l.lineNo)),
                      onChanged: _busy || !may
                          ? null
                          : (v) => setState(() {
                                if (v == true) {
                                  _ticked.addAll(visibleOpen.map((l) => l.lineNo));
                                } else {
                                  _ticked.removeAll(visibleOpen.map((l) => l.lineNo));
                                }
                              }),
                      title: Text(visibleOpen.length == open.length ? l10n.siAll : l10n.siAllShown(visibleOpen.length)),
                    ),
                  ],
                  // Narrowing many lines (0167).
                  _Filters(
                    query: _query,
                    makers: makers,
                    chosenMakers: _makers,
                    marks: _marks,
                    which: _which,
                    shown: visible.length,
                    total: m.lines.length,
                    onChanged: () => setState(() {}),
                    onWhich: (w) => setState(() => _which = w),
                  ),
                  if (wide && visible.isNotEmpty) const _WideHeading(),
                  if (_error case final e?)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Text(e, key: const ValueKey('si-error'), style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  for (final l in visible)
                    _InspectLine(
                      key: ValueKey(l.inspected ? 'si-done-${l.lineNo}' : 'si-line-${l.lineNo}'),
                      line: l,
                      product: products[l.janCode],
                      notes: notesOf(products[l.janCode], l.janCode),
                      wide: wide,
                      ticked: _ticked.contains(l.lineNo),
                      count: _counts[l.lineNo]!,
                      enabled: !_busy && may,
                      onTick: (v) => setState(() => v ? _ticked.add(l.lineNo) : _ticked.remove(l.lineNo)),
                      onCount: () => setState(() {}),
                    ),
                ],
              );
            }),
      bottomNavigationBar: m == null || open.isEmpty || !may
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: FilledButton.icon(
                  key: const ValueKey('si-check-in'),
                  onPressed: _busy || ticked.isEmpty ? null : _checkIn,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: Text(l10n.siCheckIn(ticked.length)),
                ),
              ),
            ),
    );
  }
}

/// Column widths of a line on a PC (0167), the heading's too.
const _wCheck = 44.0, _wPic = 64.0, _wName = 240.0, _wMaker = 110.0, _wCode = 130.0, _wJan = 130.0;
const _wAttrs = 150.0, _wWeight = 110.0, _wMarks = 84.0, _wFile = 70.0, _wCount = 100.0;

class _WideHeading extends StatelessWidget {
  const _WideHeading();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium;
    Widget h(double w, String t, {bool end = false}) =>
        SizedBox(width: w, child: Text(t, style: style, textAlign: end ? TextAlign.end : TextAlign.start));
    return Container(
      key: const ValueKey('si-heading'),
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          h(_wCheck, ''),
          h(_wPic, l10n.siColPhoto),
          h(_wName, l10n.pdMarketName),
          h(_wMaker, l10n.pdMaker),
          h(_wCode, l10n.pdCode),
          h(_wJan, l10n.pdJan),
          h(_wAttrs, l10n.siColAttrs),
          h(_wWeight, l10n.specWeight),
          h(_wMarks, l10n.siColMarks),
          h(_wFile, l10n.siColFile, end: true),
          const SizedBox(width: 8),
          h(_wCount, l10n.siCounted),
        ]),
      ),
    );
  }
}

/// Narrowing the lines (0167): words, makers, ★ / ⚠, which lines.
class _Filters extends StatelessWidget {
  const _Filters({
    required this.query,
    required this.makers,
    required this.chosenMakers,
    required this.marks,
    required this.which,
    required this.shown,
    required this.total,
    required this.onChanged,
    required this.onWhich,
  });

  final TextEditingController query;
  final List<String> makers;
  final Set<String> chosenMakers;
  final Set<String> marks;
  final String which;
  final int shown;
  final int total;
  final VoidCallback onChanged;
  final ValueChanged<String> onWhich;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          key: const ValueKey('si-filter'),
          controller: query,
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.filter_list),
            labelText: l10n.siFilterHint,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final (k, label) in [
                ('all', l10n.siWhichAll),
                ('open', l10n.siWhichOpen),
                ('done', l10n.siWhichDone)
              ])
                ChoiceChip(
                  key: ValueKey('si-which-$k'),
                  label: Text(label),
                  selected: which == k,
                  onSelected: (_) => onWhich(k),
                ),
              const SizedBox(width: AppSpacing.sm),
              FilterChip(
                key: const ValueKey('si-mark-star'),
                avatar: const Icon(Icons.star, size: 16),
                label: Text(l10n.pfStarred),
                selected: marks.contains('star'),
                onSelected: (v) {
                  v ? marks.add('star') : marks.remove('star');
                  onChanged();
                },
              ),
              FilterChip(
                key: const ValueKey('si-mark-warning'),
                avatar: const Icon(Icons.warning_amber_rounded, size: 16),
                label: Text(l10n.pfWarned),
                selected: marks.contains('warning'),
                onSelected: (v) {
                  v ? marks.add('warning') : marks.remove('warning');
                  onChanged();
                },
              ),
              if (makers.length > 1)
                for (final mk in makers)
                  FilterChip(
                    key: ValueKey('si-maker-$mk'),
                    label: Text(mk),
                    selected: chosenMakers.contains(mk),
                    onSelected: (v) {
                      v ? chosenMakers.add(mk) : chosenMakers.remove(mk);
                      onChanged();
                    },
                  ),
              Text(l10n.siShown(shown, total), key: const ValueKey('si-shown'), style: theme.textTheme.bodySmall),
            ]),
      ]),
    );
  }
}

/// One line to check (or checked), with all its product tells of it (0167):
/// its picture, 商品名 and 表示名, maker, 品番, JAN, colour, size and the
/// rest, weight, ★ / ⚠ and shelf notes. On a PC on one row; on a phone a
/// card with every field. A picture, a weight and the marks can be put
/// right here, as the goods are in hand.
class _InspectLine extends ConsumerWidget {
  const _InspectLine({
    super.key,
    required this.line,
    required this.product,
    required this.notes,
    required this.wide,
    required this.ticked,
    required this.count,
    required this.enabled,
    required this.onTick,
    required this.onCount,
  });

  final MasterImportLine line;
  final Product? product;
  final List<ShelfNote> notes;
  final bool wide;
  final bool ticked;
  final TextEditingController count;
  final bool enabled;
  final ValueChanged<bool> onTick;
  final VoidCallback onCount;

  Future<void> _weight(BuildContext context, WidgetRef ref, Product p) async {
    final l10n = AppLocalizations.of(context);
    final c = TextEditingController(text: p.unitWeightG == null ? '' : gramsPlain(p.unitWeightG!));
    final v = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.siWeightTitle),
        content: TextField(
          key: const ValueKey('si-weight-field'),
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l10n.siWeightField, suffixText: 'g', helperText: l10n.siWeightHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(l10n.actionCancel)),
          FilledButton(
              key: const ValueKey('si-weight-save'),
              onPressed: () => Navigator.pop(d, c.text),
              child: Text(l10n.actionSave)),
        ],
      ),
    );
    if (v == null || !context.mounted) return;
    final g = double.tryParse(v.trim().replaceAll(',', ''));
    if (v.trim().isNotEmpty && (g == null || g <= 0)) return;
    final r = await ref
        .read(productRepositoryProvider)
        .setWeight(productId: p.id, unitWeightG: g, source: 'measured', note: l10n.siWeightNote);
    if (!context.mounted) return;
    ref.invalidate(productListProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(r is ApiSuccess ? l10n.siWeightSaved : humanizeApiErrorMessage(l10n, (r as ApiFailure).message))));
  }

  Future<void> _photos(BuildContext context, WidgetRef ref, Product p) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProductGalleryScreen(productId: p.id, productName: p.name, janCode: p.janCode)));
    ref.read(productFaceCacheProvider.notifier).invalidateProduct(p.id);
    ref.invalidate(productListProvider);
  }

  Future<void> _webPhoto(BuildContext context, WidgetRef ref, Product p) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text(l10n.pdPhotoSearching)));
    final r = await ref.read(webPhotoRepositoryProvider).find(productIds: [p.id], again: p.imageCount > 0);
    ref.read(productFaceCacheProvider.notifier).invalidateProduct(p.id);
    ref.invalidate(productListProvider);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(switch (r) {
        ApiSuccess(:final data) when data.any((x) => x.ok) => l10n.pdPhotoAdded,
        ApiSuccess(:final data) => l10n.pdPhotoNone(data.firstOrNull?.reason ?? ''),
        ApiFailure(:final message) => humanizeApiErrorMessage(l10n, message),
      }),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final p = product;
    final done = line.inspected;
    final counted = int.tryParse(count.text.trim());
    final differs = !done && counted != null && counted != line.quantity;
    final canManage = ref.watch(productLibraryCanManageProvider);
    final name = (p == null ? null : marketNameOf(p)) ?? line.name ?? '';
    final display = p != null && p.name.trim() != name.trim() ? p.name : null;
    final attrs = [for (final a in p?.attributes ?? const <ProductPart>[]) '${a.name}: ${a.value}'].join('  ');
    final weight = p?.unitWeightG == null ? l10n.specNotEntered : gramsText(p!.unitWeightG!);
    final noteLines = [
      for (final n in notes) [if ((n.location ?? '').isNotEmpty) '📍${n.location}', n.body].join(' ')
    ];

    final tick = done
        ? Icon(Icons.check_circle, color: scheme.primary, key: ValueKey('si-checked-${line.lineNo}'))
        : Checkbox(
            key: ValueKey('si-tick-${line.lineNo}'),
            value: ticked,
            onChanged: enabled ? (v) => onTick(v ?? false) : null,
          );
    final picture = p == null
        ? const SizedBox(width: 56, height: 56)
        : InkWell(
            key: ValueKey('si-photo-${line.lineNo}'),
            onTap: canManage ? () => _photos(context, ref, p) : null,
            child: ProductThumb(productId: p.id, janCode: p.janCode, productName: p.name, size: 56),
          );
    final countField = done
        ? Text(l10n.siInspected(line.inspectedQuantity ?? 0, line.inspectedByName ?? ''), style: muted)
        : TextField(
            key: ValueKey('si-count-${line.lineNo}'),
            controller: count,
            enabled: enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.end,
            decoration: InputDecoration(labelText: l10n.siCounted, isDense: true, border: const OutlineInputBorder()),
            onChanged: (_) => onCount(),
          );
    final actions = p == null
        ? const <Widget>[]
        : [
            if (canManage)
              IconButton(
                key: ValueKey('si-photos-${line.lineNo}'),
                tooltip: l10n.siPhotos,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_a_photo_outlined, size: 20),
                onPressed: () => _photos(context, ref, p),
              ),
            if (canManage)
              IconButton(
                key: ValueKey('si-web-photo-${line.lineNo}'),
                tooltip: p.imageCount == 0 ? l10n.pdPhotoFind : l10n.pdPhotoFindAnother,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.image_search_outlined, size: 20),
                onPressed: () => _webPhoto(context, ref, p),
              ),
            if (canManage)
              IconButton(
                key: ValueKey('si-weigh-${line.lineNo}'),
                tooltip: l10n.siWeightTitle,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.scale_outlined, size: 20),
                onPressed: () => _weight(context, ref, p),
              ),
            if (ref.watch(canWriteShelfNotesProvider))
              IconButton(
                key: ValueKey('si-note-${line.lineNo}'),
                tooltip: l10n.snAdd,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.sticky_note_2_outlined, size: 20),
                onPressed: () => editShelfNote(context, ref, product: p),
              ),
          ];
    final fileSaid = Text(
      [
        l10n.siFileSaid(line.quantity),
        if (differs)
          l10n.siDiff(counted - line.quantity > 0 ? '+${counted - line.quantity}' : '${counted - line.quantity}'),
        if (done && (line.inspectedQuantity ?? line.quantity) != line.quantity) l10n.siFileSaid(line.quantity),
      ].toSet().join(' · '),
      style: theme.textTheme.bodySmall?.copyWith(color: differs ? scheme.error : null),
    );
    final nameBlock = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(name.isEmpty ? l10n.plNameMissing : name,
          key: ValueKey('si-name-${line.lineNo}'),
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600, fontStyle: name.isEmpty ? FontStyle.italic : null),
          maxLines: 2,
          overflow: TextOverflow.ellipsis),
      if (display != null) Text(display, style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
      if (p != null) ProductWarningNote(product: p),
      for (final n in noteLines)
        Text(n, key: ValueKey('si-shelf-${line.lineNo}'), style: muted, maxLines: 2, overflow: TextOverflow.ellipsis),
    ]);

    if (wide) {
      Widget c(double w, Widget child) => SizedBox(width: w, child: child);
      return Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            c(_wCheck, tick),
            c(_wPic, Align(alignment: Alignment.centerLeft, child: picture)),
            c(_wName, Padding(padding: const EdgeInsets.only(right: 8), child: nameBlock)),
            c(_wMaker, Text(p?.maker ?? '', maxLines: 2, overflow: TextOverflow.ellipsis)),
            c(_wCode, Text(p?.sku ?? '', style: theme.textTheme.bodySmall, maxLines: 2)),
            c(_wJan, Text(line.janCode, style: theme.textTheme.bodySmall)),
            c(_wAttrs, Text(attrs, style: theme.textTheme.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis)),
            c(_wWeight, Text(weight, key: ValueKey('si-weight-${line.lineNo}'), style: theme.textTheme.bodySmall)),
            c(_wMarks, p == null ? const SizedBox.shrink() : ProductMarks(product: p, size: 18)),
            c(_wFile, Align(alignment: Alignment.centerRight, child: fileSaid)),
            const SizedBox(width: 8),
            c(_wCount, countField),
            ...actions,
          ]),
        ),
      );
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            tick,
            picture,
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                nameBlock,
                Text([if ((p?.maker ?? '').isNotEmpty) p!.maker!, if ((p?.sku ?? '').isNotEmpty) p!.sku!].join(' · '),
                    style: theme.textTheme.bodySmall),
                Text('JAN ${line.janCode}', style: muted),
                if (attrs.isNotEmpty) Text(attrs, style: muted),
                Text('${l10n.specWeight}: $weight', key: ValueKey('si-weight-${line.lineNo}'), style: muted),
              ]),
            ),
            if (p != null) ProductMarks(product: p, size: 20),
          ]),
          Row(children: [
            const SizedBox(width: 48),
            Expanded(child: fileSaid),
            SizedBox(width: done ? 180 : 110, child: countField),
          ]),
          if (actions.isNotEmpty) Wrap(children: actions),
        ]),
      ),
    );
  }
}

/// Grams as typed back into a field (12.5, not 12.50 g).
String gramsPlain(double g) => g == g.roundToDouble() ? g.toInt().toString() : '$g';

/// The date a stock file is kept until, in words (0148).
String keptUntilText(AppLocalizations l10n, DateTime filedOn) =>
    l10n.ivKeptUntil(DateFormat('y/MM/dd').format(keptUntil(filedOn)), keepYears);
