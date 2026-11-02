import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/scan/barcode_scan_screen.dart';
import '../../delivery_note/delivery_note.dart';
import '../../delivery_note/delivery_note_view_screen.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../evidence/application/evidence_providers.dart';
import '../../evidence/domain/import_document.dart';
import '../../evidence/presentation/evidence_screen.dart' show downloadEvidence;
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
import '../../unplanned_receipt/unplanned_flow.dart';
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

/// A scanned JAN checks its line in at once (0177): the goods in hand are
/// received, whatever the count — on by default; off, a scan only ticks.
final scanChecksInProvider = StateProvider<bool>((_) => true);

/// Opens the camera to scan (tests stand in for it).
final inspectionCameraProvider = Provider<
    Future<void> Function(
      BuildContext, {
      required String? Function(String code) validate,
      required void Function(String code) onScan,
      required String title,
    })>((ref) => (context, {required validate, required onScan, required title}) => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BarcodeScanScreen(
          title: title,
          continuous: true,
          duplicateWindow: const Duration(seconds: 2),
          validate: validate,
          onScan: onScan,
        ),
      ),
    ));

/// One file's lines to count: tick what was checked, change the count where
/// it differs from the file, and check them in.
class StockInspectionDetailScreen extends ConsumerStatefulWidget {
  const StockInspectionDetailScreen({super.key, required this.importId, this.day, this.tickAll = false});

  final int importId;

  /// Opened from 予定外の入荷 (0182): every line read is ticked at first —
  /// what is not needed is unticked by hand.
  final bool tickAll;

  /// Opened from 検品履歴カレンダー (0179): only the lines checked in that day
  /// (Japan time) are shown at first.
  final DateTime? day;

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

  /// The day narrowed to (0179), until 「すべての行を表示」.
  late DateTime? _day = widget.day == null ? null : DateTime(widget.day!.year, widget.day!.month, widget.day!.day);

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
          final first = _import == null;
          _import = data;
          _error = null;
          for (final l in data.lines) {
            _counts.putIfAbsent(l.lineNo, () => TextEditingController(text: '${l.quantity}'));
          }
          if (first && widget.tickAll) _ticked.addAll([for (final l in data.lines) if (!l.inspected) l.lineNo]);
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

  /// The delivery note read for this inspection (0178), and what came of it.
  List<NoteLine>? _note;
  String? _noteName;
  bool _noteReading = false;
  int _noteMatched = 0;
  List<NoteLine> _noteStrangers = const [];
  int _noteMissing = 0;

  /// The checked note photographed or chosen, read, and its lines ticked:
  /// every JAN on it is taken as received, with the note's count. Lines
  /// not received (未発送) are unticked by hand before 検品完了.
  Future<void> _readNote() async {
    final camera = await askCameraOrFile(context);
    if (camera == null || !mounted) return;
    final f = await ref.read(deliveryNotePickerProvider)(camera: camera);
    if (f == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _noteReading = true;
      _error = null;
    });
    final r = await readDeliveryNoteKept(ref, f.name, f.bytes);
    if (!mounted) return;
    setState(() {
      _noteReading = false;
      switch (r) {
        case ApiSuccess(:final data):
          _applyNote(data.lines, f.name);
        case ApiFailure(:final message):
          _error = humanizeApiErrorMessage(l10n, message);
      }
    });
    // The note kept with this inspection, to look back at (0179).
    if (r case ApiSuccess(:final data) when data.documentId != null) {
      final id = data.documentId!;
      await ref.read(stockImportRepositoryProvider).linkInspectionDocument(widget.importId, id);
      if (mounted) ref.invalidate(inspectionDocumentsProvider(widget.importId));
    }
  }

  /// A line checked in by mistake, taken back (0179): its stock comes out
  /// again and it waits to be checked in once more.
  Future<void> _undo(MasterImportLine l) async {
    final l10n = AppLocalizations.of(context);
    final qty = l.inspectedQuantity ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.siUndoQ),
        content: Text(l10n.siUndoBody(l.name ?? l.janCode, qty), key: const ValueKey('si-undo-body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l10n.actionCancel)),
          FilledButton(
              key: const ValueKey('si-undo-confirm'),
              onPressed: () => Navigator.pop(d, true),
              child: Text(l10n.siUndoGo)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await ref.read(stockImportRepositoryProvider).uninspect(widget.importId, l.lineNo);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess():
        ref.invalidate(pendingInspectionProvider);
        ref.invalidate(awaitingImportsProvider);
        ref.invalidate(unplannedWaitingProvider(false));
        ref.invalidate(productListProvider);
        ref.invalidate(masterImportsProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.siUndone(l.name ?? l.janCode, qty))));
        await _load();
      case ApiFailure(:final message):
        setState(() => _error = humanizeApiErrorMessage(l10n, message));
    }
    if (mounted) setState(() => _busy = false);
  }

  void _applyNote(List<NoteLine> note, String name) {
    final open = _open;
    final used = <int>{};
    final strangers = <NoteLine>[];
    for (final n in note) {
      if (n.jan.isEmpty) continue;
      final hit = open.where((l) => l.janCode == n.jan && !used.contains(l.lineNo)).firstOrNull;
      if (hit == null) {
        // Already checked in is not a stranger.
        if (!(_import?.lines ?? const <MasterImportLine>[]).any((l) => l.janCode == n.jan)) strangers.add(n);
        continue;
      }
      used.add(hit.lineNo);
      if (n.quantity case final q? when q >= 0) _counts[hit.lineNo]?.text = '$q';
    }
    _ticked
      ..clear()
      ..addAll(used);
    _note = note;
    _noteName = name;
    _noteMatched = used.length;
    _noteStrangers = strangers;
    _noteMissing = open.length - used.length;
  }

  /// Lines checked in by a scan and not yet back from the server.
  final Set<int> _scanning = {};

  /// The check-ins scans asked for, one after another.
  Future<void> _scanQueue = Future.value();

  MasterImportLine? _lineFor(String raw) {
    final jan = normalizeJan(raw) ?? raw.trim();
    return _open.where((l) => l.janCode == jan && !_scanning.contains(l.lineNo)).firstOrNull;
  }

  /// A scanned or typed JAN: checked in at once with its count (the file's
  /// unless changed), or only ticked when scans do not check in.
  void _onScan(String raw) {
    final jan = normalizeJan(raw) ?? raw.trim();
    final hit = _lineFor(raw);
    final checkIn = ref.read(scanChecksInProvider) && canInspectStockFiles(ref);
    setState(() {
      _scanMiss = hit == null && jan.isNotEmpty ? jan : null;
      if (hit != null && !checkIn) _ticked.add(hit.lineNo);
    });
    _scan.clear();
    if (hit != null && checkIn) _scanIn(hit);
  }

  /// One line checked in from a scan, without asking: the goods are in hand.
  void _scanIn(MasterImportLine l) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final qty = _count(l) ?? l.quantity;
    _scanning.add(l.lineNo);
    setState(() {});
    _scanQueue = _scanQueue.then((_) async {
      final r = await ref.read(stockImportRepositoryProvider).inspect(widget.importId, [InspectedLine(l.lineNo, qty)]);
      if (!mounted) return;
      switch (r) {
        case ApiSuccess(:final data):
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              key: const ValueKey('si-scanned-in'),
              content: Text(l10n.siScannedIn(l.name ?? l.janCode, qty, data.left)),
            ));
          ref.invalidate(pendingInspectionProvider);
          ref.invalidate(awaitingImportsProvider);
          ref.invalidate(productListProvider);
          ref.invalidate(masterImportsProvider);
          await _load();
        case ApiFailure(:final message):
          setState(() => _error = humanizeApiErrorMessage(l10n, message));
      }
      if (mounted) setState(() => _scanning.remove(l.lineNo));
    });
  }

  /// The camera, kept open: each JAN read is checked in (or ticked).
  Future<void> _camera() async {
    final l10n = AppLocalizations.of(context);
    await ref.read(inspectionCameraProvider)(
      context,
      title: l10n.siCameraTitle(widget.importId),
      validate: (code) {
        final jan = normalizeJan(code) ?? code.trim();
        if (_lineFor(code) != null) return null;
        final any = (_import?.lines ?? const <MasterImportLine>[]).any((l) => l.janCode == jan);
        return any ? l10n.siScanAlreadyIn(jan) : l10n.siScanMiss(jan);
      },
      onScan: _onScan,
    );
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
    // 予定外の入荷 (0182): what is left unticked did not come — closed, so
    // the receipt does not wait for it (on by default; it can stay open).
    final left = _import?.unplanned ?? false
        ? [for (final l in _open) if (!_ticked.contains(l.lineNo)) l.lineNo]
        : const <int>[];
    var close = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.siConfirmQ),
        content: StatefulBuilder(
          builder: (c, set) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.siConfirmBody(lines.length, units, diff > 0 ? '+$diff' : '$diff'),
                key: const ValueKey('si-confirm-body')),
            if (left.isNotEmpty)
              CheckboxListTile(
                key: const ValueKey('si-close-left'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: close,
                onChanged: (v) => set(() => close = v ?? false),
                title: Text(l10n.siCloseLeft(left.length)),
                subtitle: Text(l10n.siCloseLeftHint),
              ),
          ]),
        ),
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
        var stillLeft = data.left;
        if (left.isNotEmpty && close) {
          final c = await ref.read(stockImportRepositoryProvider).closeLines(widget.importId, left);
          if (c case ApiSuccess(data: final n)) stillLeft -= n;
          if (!mounted) return;
        }
        ref.invalidate(pendingInspectionProvider);
        ref.invalidate(awaitingImportsProvider);
        ref.invalidate(unplannedWaitingProvider(false));
        ref.invalidate(productListProvider);
        ref.invalidate(masterImportsProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.siDone(data.lines, stillLeft))));
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
      if (_day case final d?) return inspectionDayOf(l) == d;
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
      appBar: AppBar(title: Text(l10n.siTitle(widget.importId)), actions: [
        // A note in hand, photographed, to look at with the goods' pictures.
        IconButton(
          key: const ValueKey('si-note-look'),
          tooltip: l10n.dnTitle,
          icon: const Icon(Icons.photo_library_outlined),
          onPressed: () =>
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DeliveryNoteViewScreen())),
        ),
      ]),
      body: m == null
          ? (_error == null ? const LoadingView() : ErrorStateView(message: _error!, onRetry: _load))
          // On a PC every line is one row; on a phone a card (0167).
          : LayoutBuilder(builder: (context, box) {
              final wide = box.maxWidth >= 1100;
              return ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 120),
                children: [
                  Text(m.originalName ?? '', style: theme.textTheme.titleMedium),
                  // 予定外の入荷 (0182): where it is on its way.
                  if (m.unplanned) ...[
                    UnplannedFlow(
                      states: unplannedStates(
                        checkedIn: m.status == MasterImportStatus.stockDone,
                        someIn: m.lines.any((l) => l.inspected),
                        invoiced: m.noInvoiceAt != null || m.lines.any((l) => l.invoicedImportId != null),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  // 予定外の入荷 (0181): who brought it.
                  if (m.unplanned)
                    Text([l10n.urLabel, if (m.supplierName case final s?) s].join(' · '),
                        key: const ValueKey('si-unplanned'),
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.tertiary)),
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
                  // The notes read while inspecting, kept to look back at (0179).
                  _InspectionFiles(importId: widget.importId),
                  if (open.isNotEmpty && _day == null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      key: const ValueKey('si-scan'),
                      controller: _scan,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.qr_code_scanner),
                        labelText: ref.watch(scanChecksInProvider) ? l10n.siScanIn : l10n.siScan,
                        border: const OutlineInputBorder(),
                        errorText: _scanMiss == null ? null : l10n.siScanMiss(_scanMiss!),
                        // The phone's camera: scan the goods one after another.
                        suffixIcon: IconButton(
                          key: const ValueKey('si-camera'),
                          tooltip: l10n.cameraScan,
                          icon: const Icon(Icons.photo_camera_outlined),
                          onPressed: _busy ? null : _camera,
                        ),
                      ),
                      onSubmitted: _onScan,
                    ),
                    // The note checked by hand, read back: its lines ticked (0178).
                    if (may) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
                        OutlinedButton.icon(
                          key: const ValueKey('si-note'),
                          onPressed: _busy || _noteReading ? null : _readNote,
                          icon: _noteReading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.document_scanner_outlined, size: 18),
                          label: Text(_noteReading ? l10n.dnReading : l10n.siNoteRead),
                        ),
                      ]),
                    ],
                    if (_note case final note?)
                      Card(
                        key: const ValueKey('si-note-summary'),
                        color: theme.colorScheme.tertiaryContainer,
                        margin: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(l10n.siNoteTicked(_noteName ?? '', _noteMatched), style: theme.textTheme.titleSmall),
                            Text(l10n.siNoteHint, style: theme.textTheme.bodySmall),
                            if (_noteMissing > 0)
                              Text(l10n.siNoteMissing(_noteMissing),
                                  key: const ValueKey('si-note-missing'), style: theme.textTheme.bodySmall),
                            for (final n in _noteStrangers)
                              Text(l10n.siNoteStranger(n.jan, n.name),
                                  key: ValueKey('si-note-stranger-${n.lineNo}'),
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                key: const ValueKey('si-note-view'),
                                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => DeliveryNoteViewScreen(lines: note, fileName: _noteName))),
                                icon: const Icon(Icons.photo_library_outlined, size: 18),
                                label: Text(l10n.siNoteView),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    if (may)
                      SwitchListTile(
                        key: const ValueKey('si-scan-checkin'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: ref.watch(scanChecksInProvider),
                        onChanged: (v) => ref.read(scanChecksInProvider.notifier).state = v,
                        title: Text(l10n.siScanCheckIn),
                        subtitle: Text(l10n.siScanCheckInHint, style: theme.textTheme.bodySmall),
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
                  // Only the lines checked in the day chosen on the calendar (0179).
                  if (_day case final d?)
                    Card(
                      key: const ValueKey('si-day'),
                      color: theme.colorScheme.secondaryContainer,
                      margin: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Row(children: [
                          const Icon(Icons.event_available_outlined),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              l10n.siDayOnly(DateFormat('y/MM/dd').format(d), visible.length,
                                  visible.fold<int>(0, (s, l) => s + (l.inspectedQuantity ?? 0))),
                              key: const ValueKey('si-day-text'),
                            ),
                          ),
                          TextButton(
                            key: const ValueKey('si-day-all'),
                            onPressed: () => setState(() => _day = null),
                            child: Text(l10n.siDayShowAll),
                          ),
                        ]),
                      ),
                    ),
                  // Narrowing many lines (0167).
                  if (_day == null)
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
                      // A receipt and the invoice that covered it go together (0181).
                      onUndo: l.inspected &&
                              may &&
                              !_busy &&
                              l.coveredByImportId == null &&
                              l.invoicedImportId == null
                          ? () => _undo(l)
                          : null,
                    ),
                ],
              );
            }),
      bottomNavigationBar: m == null || open.isEmpty || !may || _day != null
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
    this.onUndo,
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

  /// Takes a checked-in line back (0179); null where it cannot be.
  final VoidCallback? onUndo;

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
        ? Row(children: [
            Expanded(
                child: Text(
              switch (line) {
                MasterImportLine(coveredByImportId: final id?) => l10n.siCovered(id),
                MasterImportLine(notDelivered: true) => l10n.siNotDelivered,
                MasterImportLine(invoicedImportId: final id?) =>
                  '${l10n.siInspected(line.inspectedQuantity ?? 0, line.inspectedByName ?? '')}\n${l10n.siInvoiced(id)}',
                _ => l10n.siInspected(line.inspectedQuantity ?? 0, line.inspectedByName ?? ''),
              },
              key: ValueKey('si-inspected-${line.lineNo}'),
              style: muted,
            )),
            // Behind ⋯, so it is never pressed by mistake (0179).
            if (onUndo != null)
              PopupMenuButton<void>(
                key: ValueKey('si-more-${line.lineNo}'),
                tooltip: l10n.siMore,
                icon: const Icon(Icons.more_horiz, size: 20),
                itemBuilder: (_) => [
                  PopupMenuItem<void>(
                    key: ValueKey('si-undo-${line.lineNo}'),
                    onTap: onUndo,
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.undo),
                      title: Text(l10n.siUndo),
                    ),
                  ),
                ],
              ),
          ])
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
            c(done ? _wCount + 40 : _wCount, countField),
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
            SizedBox(width: done ? 220 : 110, child: countField),
          ]),
          if (actions.isNotEmpty) Wrap(children: actions),
        ]),
      ),
    );
  }
}

/// 検品時のファイル (0179): the delivery notes read while inspecting this
/// import, kept with it — to see again (a picture here, a PDF saved) or
/// download. Nothing when there are none.
class _InspectionFiles extends ConsumerWidget {
  const _InspectionFiles({required this.importId});

  final int importId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(inspectionDocumentsProvider(importId)).valueOrNull ?? const <ImportDocument>[];
    if (docs.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final at = DateFormat('y/MM/dd HH:mm');
    return Card(
      key: const ValueKey('si-files'),
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.siFiles(docs.length), style: theme.textTheme.titleSmall),
          for (final d in docs)
            ListTile(
              key: ValueKey('si-file-${d.id}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                  (d.contentType ?? '').startsWith('image/') ? Icons.image_outlined : Icons.picture_as_pdf_outlined),
              title: Text(d.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text([at.format(d.uploadedAt), if (d.uploadedByName case final n?) n].join(' · ')),
              trailing: Wrap(children: [
                IconButton(
                  key: ValueKey('si-file-open-${d.id}'),
                  tooltip: l10n.siFileOpen,
                  icon: const Icon(Icons.visibility_outlined),
                  onPressed: () => showKeptDocument(context, ref, d),
                ),
                IconButton(
                  key: ValueKey('si-file-dl-${d.id}'),
                  tooltip: l10n.siFileDownload,
                  icon: const Icon(Icons.download_outlined),
                  onPressed: () => downloadEvidence(context, ref, d),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}

/// A kept file seen again: a picture shown here (to zoom), anything else
/// (a PDF) saved to open.
Future<void> showKeptDocument(BuildContext context, WidgetRef ref, ImportDocument d) async {
  final isImage = (d.contentType ?? '').startsWith('image/') ||
      RegExp(r'\.(jpe?g|png|webp|gif)$', caseSensitive: false).hasMatch(d.fileName);
  if (!isImage) return downloadEvidence(context, ref, d);
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final r = await ref.read(evidenceRepositoryProvider).download(d);
  if (!context.mounted) return;
  switch (r) {
    case ApiSuccess(:final data):
      await showDialog<void>(
        context: context,
        builder: (c) => Dialog(
          key: const ValueKey('kept-doc-view'),
          insetPadding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              title: Text(d.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(c)),
            ),
            Flexible(child: InteractiveViewer(maxScale: 6, child: Image.memory(data, fit: BoxFit.contain))),
          ]),
        ),
      );
    case ApiFailure(:final message):
      messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
  }
}

/// The day (Japan time, as 検品履歴カレンダー counts it) a line was checked
/// in, or null.
DateTime? inspectionDayOf(MasterImportLine l) {
  final at = l.inspectedAt;
  if (at == null) return null;
  final jst = at.toUtc().add(const Duration(hours: 9));
  return DateTime(jst.year, jst.month, jst.day);
}

/// Grams as typed back into a field (12.5, not 12.50 g).
String gramsPlain(double g) => g == g.roundToDouble() ? g.toInt().toString() : '$g';

/// The date a stock file is kept until, in words (0148).
String keptUntilText(AppLocalizations l10n, DateTime filedOn) =>
    l10n.ivKeptUntil(DateFormat('y/MM/dd').format(keptUntil(filedOn)), keepYears);
