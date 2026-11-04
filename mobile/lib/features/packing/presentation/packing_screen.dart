import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../outbound_file/data/outbound_file_repository.dart';
import '../../outbound_file/presentation/outbound_file_screen.dart' show outboundFileSaverProvider, outboundTabOpenerProvider;
import '../../shipment/application/packaging_providers.dart' show cartonTypesProvider;
import '../../shipment/domain/packaging.dart' show CartonType;
import '../../outbound/domain/outbound.dart' show ShipDestination;
import '../data/packing_list_excel.dart';
import '../data/packing_repository.dart';
import '../domain/packing.dart';
import '../domain/packing_list_reader.dart' show PackingListRead;
import 'packing_lists_screen.dart';

/// The rows of a shipping list that go in boxes: those shipped (or kept, for
/// 在庫外出荷), each under the mark of its 注番.
List<PackDemand> packDemandsOf(OutboundFileDetail d) => [
      for (final l in d.lines)
        if (l.action != 'skip' && (d.file.planned || d.file.proxy ? l.quantity : l.shippedQuantity) > 0)
          PackDemand(
            fileLineId: l.id,
            productId: l.productId,
            jan: l.jan,
            code: l.code,
            name: l.productName,
            maker: l.maker,
            quantity: d.file.planned || d.file.proxy ? l.quantity : l.shippedQuantity,
            unitWeightG: l.unitWeightG,
            mark: packMarkOf(l.orderNumber),
          ),
    ];

String _esc(String s) => const HtmlEscape(HtmlEscapeMode.element).convert(s);

/// Box labels to print, one to a page: the box number large, of how many,
/// where it goes, what is in it and what it weighs.
String packingLabelsHtml(List<PackBox> boxes, {ShipDestination? shipTo, String? title}) {
  final b = StringBuffer()
    ..write('<!doctype html><html><head><meta charset="utf-8"><title>${_esc(title ?? 'Labels')}</title><style>'
        '@page{size:100mm 150mm;margin:5mm}body{font-family:system-ui,sans-serif;margin:0}'
        '.l{page-break-after:always;padding:4mm;border:1px dashed #999;margin:4mm;box-sizing:border-box}'
        '.no{font-size:56px;font-weight:800;line-height:1}.of{font-size:16px;color:#444}'
        '.to{font-size:13px;margin:6px 0;border-top:1px solid #000;padding-top:4px}'
        'table{font-size:11px;border-collapse:collapse;width:100%}td{border-bottom:1px solid #ddd;padding:1px 2px}'
        '.w{font-size:16px;font-weight:700;margin-top:6px}</style></head><body>');
  final perMark = <String, int>{};
  for (final x in boxes) {
    perMark[x.mark ?? ''] = (perMark[x.mark ?? ''] ?? 0) + 1;
  }
  for (final x in boxes) {
    b
      ..write('<div class="l"><div class="no">${_esc(x.label)}</div>')
      ..write('<div class="of">C/No. ${x.boxNo} / ${perMark[x.mark ?? '']}</div>');
    if (shipTo != null) b.write('<div class="to">${_esc(shipTo.nameEn ?? shipTo.name)}<br>${_esc(shipTo.addressEn ?? shipTo.addressLine)}</div>');
    b.write('<table>');
    for (final i in x.items) {
      b.write('<tr><td>${_esc(i.code ?? i.jan ?? '')}</td><td>${_esc(i.name ?? '')}</td><td style="text-align:right">${i.quantity}</td></tr>');
    }
    b.write('</table>');
    if (x.weightKg != null) b.write('<div class="w">G.W. ${packingKg(x.weightKg!)} kg</div>');
    if (x.sizeText.isNotEmpty) b.write('<div>${_esc(x.sizeText)} cm</div>');
    b.write('</div>');
  }
  b.write('<script>window.onload=function(){window.print()}</script></body></html>');
  return b.toString();
}

/// 梱包: a shipping list's boxes — worked out from the products' cases and
/// our cartons, then checked on the floor box by box: each product scanned
/// or ticked, its count put right, the box weighed (a weight far from the
/// worked-out one is flagged), a label printed — and the packing list made
/// from them, checked against the shipping list.
class PackingScreen extends ConsumerStatefulWidget {
  const PackingScreen({super.key, required this.fileId});

  final int fileId;

  @override
  ConsumerState<PackingScreen> createState() => _PackingScreenState();
}

class _PackingScreenState extends ConsumerState<PackingScreen> {
  List<PackBox>? _boxes;
  String? _error;
  bool _busy = false;
  int _at = 0;
  final _scan = TextEditingController();
  final _scanFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scan.dispose();
    _scanFocus.dispose();
    super.dispose();
  }

  void _snack(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _load() async {
    final r = await ref.read(packingRepositoryProvider).boxes(widget.fileId);
    if (!mounted) return;
    setState(() {
      switch (r) {
        case ApiSuccess(:final data):
          _boxes = data;
          _error = null;
          if (_at >= data.length) _at = 0;
        case ApiFailure(:final message):
          _error = message;
      }
    });
  }

  /// Boxes worked out afresh from the shipping list (those there were are
  /// put aside).
  Future<void> _plan(OutboundFileDetail d) async {
    final l10n = AppLocalizations.of(context);
    if ((_boxes ?? const []).isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(l10n.pkReplanQ),
          content: Text(l10n.pkReplanBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.actionCancel)),
            FilledButton(key: const ValueKey('pk-replan-ok'), onPressed: () => Navigator.pop(c, true), child: Text(l10n.pkReplan)),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);
    var cases = const <CasePack>[];
    var cartons = const <CartonType>[];
    try {
      cases = await ref.read(casePacksProvider.future);
    } catch (_) {
      // Without cases, all goes in our cartons.
    }
    try {
      cartons = await ref.read(cartonTypesProvider.future);
    } catch (_) {
      // Without cartons, a box to each row.
    }
    final boxes = planPacking(packDemandsOf(d), casePacks: {for (final c in cases) c.productId: c}, cartons: cartons);
    final r = await ref.read(packingRepositoryProvider).saveBoxes(widget.fileId, boxes);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess(:final data):
        _snack(l10n.pkPlanned(data));
        _at = 0;
        await _load();
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  /// One box changed: written at once, shown as it is now.
  Future<void> _update(int index, PackBox next, Map<String, dynamic> fields) async {
    final l10n = AppLocalizations.of(context);
    final before = _boxes![index];
    setState(() => _boxes = [..._boxes!]..[index] = next);
    if (before.id == null) return;
    final r = await ref.read(packingRepositoryProvider).updateBox(before.id!, fields);
    if (!mounted) return;
    if (r case ApiFailure(:final message)) {
      setState(() => _boxes = [..._boxes!]..[index] = before);
      _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  void _setQuantity(int bi, int ii, int q) {
    final b = _boxes![bi];
    final items = [...b.items]..[ii] = b.items[ii].copyWith(quantity: q);
    var next = b.copyWith(items: items);
    final fields = <String, dynamic>{
      'lines': [
        {'id': items[ii].id, 'quantity': q},
      ],
    };
    if (!b.ownCase) {
      final est = next.workedOutKg;
      next = est == null ? next.copyWith(clearEst: true) : next.copyWith(estKg: est);
      fields['est_kg'] = est;
    }
    _update(bi, next, fields);
  }

  void _tick(int bi, int ii, bool v) {
    final b = _boxes![bi];
    final items = [...b.items]..[ii] = b.items[ii].copyWith(checked: v);
    _update(bi, b.copyWith(items: items), {
      'lines': [
        {'id': items[ii].id, 'checked': v},
      ],
    });
  }

  void _checkBox(int bi, bool v) {
    final b = _boxes![bi];
    final next = v ? b.copyWith(checkedAt: DateTime.now()) : b.copyWith(clearChecked: true);
    _update(bi, next, {'checked': v});
    if (v && bi + 1 < _boxes!.length) setState(() => _at = bi + 1);
  }

  void _setCarton(int bi, String choice, List<CartonType> cartons) {
    final b = _boxes![bi];
    if (choice == 'own') {
      _update(bi, b.copyWith(ownCase: true, clearCarton: true), {'own_case': true, 'carton_type_id': null});
      return;
    }
    final t = cartons.firstWhere((c) => '${c.id}' == choice);
    final tare = (t.emptyWeightG + t.packingMaterialG) / 1000;
    var next = b.copyWith(
      ownCase: false,
      cartonTypeId: t.id,
      cartonType: t.name,
      lengthCm: t.lengthCm,
      widthCm: t.widthCm,
      heightCm: t.heightCm,
      tareKg: tare,
    );
    final est = next.workedOutKg;
    next = est == null ? next : next.copyWith(estKg: est);
    _update(bi, next, {
      'own_case': false,
      'carton_type_id': t.id,
      'length_cm': t.lengthCm,
      'width_cm': t.widthCm,
      'height_cm': t.heightCm,
      'tare_kg': tare,
      if (est != null) 'est_kg': est,
    });
  }

  void _setGross(int bi, String text) {
    final b = _boxes![bi];
    final v = double.tryParse(text.trim().replaceAll(',', '.'));
    if (text.trim().isEmpty) {
      _update(bi, b.copyWith(clearGross: true), {'gross_kg': null});
    } else if (v != null && v >= 0) {
      _update(bi, b.copyWith(grossKg: v), {'gross_kg': v});
    }
  }

  /// A JAN scanned: ticked in the box being packed, else in the first box
  /// not yet checked that has it (that box then being the one packed).
  void _scanned(String raw) {
    final l10n = AppLocalizations.of(context);
    final jan = raw.trim();
    _scan.clear();
    _scanFocus.requestFocus();
    final boxes = _boxes ?? const <PackBox>[];
    if (jan.isEmpty || boxes.isEmpty) return;
    int? find(int bi) {
      final b = boxes[bi];
      final i = b.items.indexWhere((x) => x.jan == jan && !x.checked);
      if (i >= 0) return i;
      final any = b.items.indexWhere((x) => x.jan == jan);
      return any >= 0 ? any : null;
    }

    var bi = _at;
    var ii = bi < boxes.length ? find(bi) : null;
    if (ii == null) {
      for (var k = 0; k < boxes.length; k++) {
        if (boxes[k].checked) continue;
        final f = find(k);
        if (f != null) {
          bi = k;
          ii = f;
          break;
        }
      }
    }
    if (ii == null) {
      _snack(l10n.pkScanNotHere(jan));
      return;
    }
    if (bi != _at) {
      setState(() => _at = bi);
      _snack(l10n.pkScanOtherBox(boxes[bi].label));
    }
    if (!boxes[bi].items[ii].checked) _tick(bi, ii, true);
  }

  Future<void> _editQuantity(int bi, int ii) async {
    final it = _boxes![bi].items[ii];
    final v = await showDialog<int>(context: context, builder: (_) => _QuantityDialog(item: it));
    if (v == null || v < 0 || v == it.quantity || !mounted) return;
    _setQuantity(bi, ii, v);
  }

  void _printLabels(List<PackBox> boxes, OutboundFileDetail d) {
    final tab = ref.read(outboundTabOpenerProvider)();
    final html = packingLabelsHtml(boxes, shipTo: d.file.shipTo, title: d.file.fileName);
    if (tab != null) {
      tab.show(html);
    } else {
      ref.read(outboundFileSaverProvider)('labels.html', utf8.encode(html));
    }
  }

  /// The packing list made from the boxes: kept with the shipping list and
  /// saved here.
  Future<void> _makeList(OutboundFileDetail d) async {
    final l10n = AppLocalizations.of(context);
    final boxes = _boxes ?? const <PackBox>[];
    if (boxes.isEmpty) return;
    setState(() => _busy = true);
    var cartons = const <CartonType>[];
    try {
      cartons = await ref.read(cartonTypesProvider.future);
    } catch (_) {
      // Named by size alone.
    }
    final f = d.file;
    final marks = boxes.map((b) => b.mark).whereType<String>().toSet().join(' / ');
    final bytes = buildPackingListXlsx(
      boxes,
      header: PlHeader.fromDestination(f.shipTo,
          date: DateFormat('y/MM/dd').format(f.shippedOn), marks: marks.isEmpty ? null : marks),
      cartons: cartons,
    );
    final dot = f.fileName.lastIndexOf('.');
    final name = 'PackingList_${dot > 0 ? f.fileName.substring(0, dot) : f.fileName}.xlsx';
    final repo = ref.read(packingRepositoryProvider);
    final up = await repo.upload(f.warehouseId, name, bytes);
    if (!mounted) return;
    if (up case ApiFailure(:final message)) {
      setState(() => _busy = false);
      _snack(humanizeApiErrorMessage(l10n, message));
      return;
    }
    final read = PackingListRead(sheets: const [], boxes: boxes);
    final add = await repo.addList(
      warehouseId: f.warehouseId,
      source: 'generated',
      fileId: f.id,
      improvedName: name,
      improvedPath: (up as ApiSuccess<String>).data,
      boxes: boxes.length,
      quantity: read.quantity,
      grossKg: double.parse(read.grossKg.toStringAsFixed(3)),
      cbm: double.parse(read.cbm.toStringAsFixed(4)),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (add) {
      case ApiSuccess():
        ref.invalidate(packingListsProvider);
        await ref.read(outboundFileSaverProvider)(name, bytes);
        _snack(l10n.pkListMade(name));
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detail = ref.watch(outboundFileDetailProvider(widget.fileId));
    final cartons = ref.watch(cartonTypesProvider).valueOrNull ?? const <CartonType>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pkTitle),
        actions: [
          IconButton(tooltip: l10n.pkReload, icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: detail.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(message: '$e', onRetry: () => ref.invalidate(outboundFileDetailProvider(widget.fileId))),
        data: (d) {
          if (_error != null) return ErrorStateView(message: humanizeApiErrorMessage(l10n, _error!), onRetry: _load);
          final boxes = _boxes;
          if (boxes == null) return LoadingView(message: l10n.loading);
          return _body(context, d, boxes, cartons);
        },
      ),
    );
  }

  Widget _body(BuildContext context, OutboundFileDetail d, List<PackBox> boxes, List<CartonType> cartons) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final demands = packDemandsOf(d);
    final diffs = packingDifferences(demands, boxes);
    final read = PackingListRead(sheets: const [], boxes: boxes);
    final checked = boxes.where((b) => b.checked).length;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.file.fileName, key: const ValueKey('pk-file-name'), style: theme.textTheme.titleMedium),
              Text(
                [
                  '${d.file.planned ? l10n.ofPlannedOn : l10n.ofShippedOn}: ${DateFormat('y/MM/dd').format(d.file.shippedOn)}',
                  if (d.file.shipTo != null) d.file.shipTo!.nameEn ?? d.file.shipTo!.name,
                  l10n.pkDemandTotal(demands.length, demands.fold(0, (a, x) => a + x.quantity)),
                ].join(' · '),
                style: muted,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (boxes.isNotEmpty) ...[
                Text(l10n.pkTotals(boxes.length, read.quantity, packingKg(read.grossKg), packingCbm(read.cbm)),
                    key: const ValueKey('pk-totals'), style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: boxes.isEmpty ? 0 : checked / boxes.length),
                const SizedBox(height: 4),
                Text(l10n.pkChecked(checked, boxes.length), key: const ValueKey('pk-progress')),
              ] else
                Text(l10n.pkNoBoxes, style: muted),
              const SizedBox(height: AppSpacing.md),
              Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                FilledButton.icon(
                  key: const ValueKey('pk-plan'),
                  onPressed: _busy || demands.isEmpty ? null : () => _plan(d),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(boxes.isEmpty ? l10n.pkPlan : l10n.pkReplan),
                ),
                if (boxes.isNotEmpty) ...[
                  OutlinedButton.icon(
                    key: const ValueKey('pk-labels'),
                    onPressed: () => _printLabels(boxes, d),
                    icon: const Icon(Icons.print_outlined),
                    label: Text(l10n.pkLabels),
                  ),
                  FilledButton.tonalIcon(
                    key: const ValueKey('pk-make-list'),
                    onPressed: _busy ? null : () => _makeList(d),
                    icon: const Icon(Icons.table_view_outlined),
                    label: Text(l10n.pkMakeList),
                  ),
                ],
                OutlinedButton.icon(
                  key: const ValueKey('pk-upload-for-file'),
                  onPressed: () => importPackingList(context, ref, fileId: widget.fileId),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(l10n.pkUpload),
                ),
              ]),
            ]),
          ),
        ),
        if (boxes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Card(
            key: const ValueKey('pk-diffs'),
            color: diffs.isEmpty ? null : scheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(diffs.isEmpty ? l10n.pkDiffNone : l10n.pkDiffSome(diffs.length),
                    style: theme.textTheme.titleSmall?.copyWith(color: diffs.isEmpty ? scheme.primary : scheme.onErrorContainer)),
                for (final (name, asked, packed) in diffs.take(30))
                  Text(l10n.pkDiffRow(name, asked, packed), style: TextStyle(color: scheme.onErrorContainer)),
              ]),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('pk-scan'),
            controller: _scan,
            focusNode: _scanFocus,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.qr_code_scanner),
              labelText: l10n.pkScan,
              helperText: l10n.pkScanHint(boxes[_at.clamp(0, boxes.length - 1)].label),
            ),
            onSubmitted: _scanned,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final (bi, b) in boxes.indexed) _boxCard(context, bi, b, cartons),
        ],
      ],
    );
  }

  Widget _boxCard(BuildContext context, int bi, PackBox b, List<CartonType> cartons) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final current = bi == _at;
    final choice = b.ownCase ? 'own' : (b.cartonTypeId == null ? null : '${b.cartonTypeId}');
    final options = <String, String>{
      'own': l10n.pkOwnCase,
      for (final c in cartons) '${c.id}': [c.name, if (c.sizeText != null) c.sizeText!].join(' '),
    };
    if (choice != null && !options.containsKey(choice)) options[choice] = b.cartonType ?? '#$choice';
    final off = b.offBy();
    return Card(
      key: ValueKey('pk-box-$bi'),
      shape: current
          ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: scheme.primary, width: 2))
          : null,
      child: InkWell(
        onTap: () => setState(() => _at = bi),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(b.label, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  [
                    if (b.sizeText.isNotEmpty) '${b.sizeText} cm',
                    if (b.estKg != null) l10n.pkEst(packingKg(b.estKg!)),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              Checkbox(
                key: ValueKey('pk-box-check-$bi'),
                value: b.checked,
                onChanged: (v) => _checkBox(bi, v ?? false),
              ),
              Text(l10n.pkBoxDone),
            ]),
            if (b.checked && b.checkedByName != null) Text(b.checkedByName!, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
              DropdownButton<String>(
                key: ValueKey('pk-carton-$bi'),
                value: choice,
                hint: Text(l10n.pkCartonPick),
                items: [for (final e in options.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => v == null ? null : _setCarton(bi, v, cartons),
              ),
              SizedBox(
                width: 140,
                child: TextFormField(
                  key: ValueKey('pk-gross-$bi-${b.grossKg}'),
                  initialValue: b.grossKg == null ? '' : packingKg(b.grossKg!),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: l10n.pkWeighed, suffixText: 'kg', isDense: true),
                  onFieldSubmitted: (t) => _setGross(bi, t),
                ),
              ),
              if (off)
                Row(mainAxisSize: MainAxisSize.min, key: ValueKey('pk-off-$bi'), children: [
                  Icon(Icons.warning_amber_rounded, color: scheme.error, size: 20),
                  const SizedBox(width: 4),
                  Text(l10n.pkOff((b.deviation! * 100).round()), style: TextStyle(color: scheme.error)),
                ]),
              IconButton(
                key: ValueKey('pk-label-$bi'),
                tooltip: l10n.pkLabel,
                icon: const Icon(Icons.print_outlined),
                onPressed: () {
                  final d = ref.read(outboundFileDetailProvider(widget.fileId)).valueOrNull;
                  if (d != null) _printLabels([b], d);
                },
              ),
            ]),
            const Divider(),
            for (final (ii, it) in b.items.indexed)
              Row(key: ValueKey('pk-item-$bi-$ii'), children: [
                Checkbox(value: it.checked, onChanged: (v) => _tick(bi, ii, v ?? false)),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(it.name ?? it.code ?? it.jan ?? '?', maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text([it.maker, it.code, it.jan].whereType<String>().join(' · '), style: theme.textTheme.bodySmall),
                  ]),
                ),
                TextButton(
                  key: ValueKey('pk-qty-$bi-$ii'),
                  onPressed: () => _editQuantity(bi, ii),
                  child: Text('× ${it.quantity}', style: theme.textTheme.titleMedium),
                ),
              ]),
          ]),
        ),
      ),
    );
  }
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({required this.item});

  final PackItem item;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late final _c = TextEditingController(text: '${widget.item.quantity}');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final it = widget.item;
    return AlertDialog(
      title: Text(it.name ?? it.code ?? it.jan ?? ''),
      content: TextField(
        key: const ValueKey('pk-qty-field'),
        controller: _c,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: l10n.pkQuantity),
        onSubmitted: (t) => Navigator.pop(context, int.tryParse(t.trim())),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('pk-qty-ok'),
          onPressed: () => Navigator.pop(context, int.tryParse(_c.text.trim())),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
