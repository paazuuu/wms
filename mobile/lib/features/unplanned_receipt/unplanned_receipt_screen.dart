import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error_text.dart';
import '../../core/api/api_result.dart';
import '../../core/export/save_bytes.dart' show mimeTypeFor;
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../delivery_note/delivery_note.dart' show askCameraOrFile, deliveryNotePickerProvider;
import '../jan_catalog/data/jan_catalog_repository.dart';
import '../master_import/data/master_import_repository.dart';
import '../product/application/product_providers.dart';
import '../product/data/spec_lookup.dart';
import '../product/data/web_photos.dart';
import '../product_library/application/product_library_providers.dart';
import '../qc/domain/inspection.dart' show normalizeJan;
import '../stock_import/data/stock_import_repository.dart';
import '../stock_import/domain/stock_file.dart';
import '../stock_import/presentation/reading_check_screen.dart';
import '../stock_import/presentation/stock_inspection_screen.dart'
    show StockInspectionDetailScreen, inspectionCameraProvider;
import '../warehouse_context/application/warehouse_providers.dart';
import '../warehouse_context/domain/warehouse.dart';
import 'unplanned_flow.dart';

/// 予定外の入荷 (0181, 0182): goods a regular supplier brought without an
/// order or an invoice first — nothing to import. It goes the way 発注 goes:
///  1. the delivery note that came with them is photographed or chosen (or,
///     with none, the goods are scanned);
///  2. what the AI read is checked beside the note (読み取り結果（表）) and put
///     right;
///  3. the products the library lacks are registered (by whoever adjusts
///     stock);
///  4. the ordinary 検品 screen opens with every line ticked: what did not
///     come is unticked, counts put right, and 検品完了 puts the rest in stock
///     (what stayed unticked is closed as not delivered).
/// The invoice that comes later goes in through 発注; what was received here
/// is tied to it, not added again.
class UnplannedReceiptScreen extends ConsumerStatefulWidget {
  const UnplannedReceiptScreen({super.key});

  @override
  ConsumerState<UnplannedReceiptScreen> createState() => _UnplannedReceiptScreenState();
}

class _UnplannedReceiptScreenState extends ConsumerState<UnplannedReceiptScreen> {
  int? _warehouseId;
  final _supplier = TextEditingController();
  final _scan = TextEditingController();

  /// The note, as read and checked.
  String? _fileName;
  Uint8List? _bytes;
  int? _documentId;
  DateTime? _noteDate;
  StockSheet? _sheet;
  List<ReadRow>? _readRows;
  bool _readChecked = false;

  /// Goods scanned (no note, or not on it): JAN → how many.
  final Map<String, int> _scanned = {};

  /// JAN → the library's name, for what is going in.
  Map<String, String> _known = const {};
  bool _reading = false;
  bool _busy = false;
  String? _error;

  /// The last one sent to 検品: its number.
  int? _done;

  @override
  void dispose() {
    _supplier.dispose();
    _scan.dispose();
    super.dispose();
  }

  void _reset() {
    _fileName = null;
    _bytes = null;
    _documentId = null;
    _noteDate = null;
    _sheet = null;
    _readRows = null;
    _readChecked = false;
    _scanned.clear();
    _known = const {};
    _supplier.clear();
  }

  /// Every line going to 検品: the note's as checked, then the goods scanned
  /// that are not on it.
  List<StockFileLine> get _lines {
    final fromNote = _readChecked ? (_sheet?.lines ?? const <StockFileLine>[]) : const <StockFileLine>[];
    final onNote = {for (final l in fromNote) l.janCode};
    var no = fromNote.fold<int>(0, (m, l) => l.lineNo > m ? l.lineNo : m);
    return [
      ...fromNote,
      for (final e in _scanned.entries)
        if (!onNote.contains(e.key)) StockFileLine(lineNo: ++no, janCode: e.key, quantity: e.value),
    ];
  }

  Future<void> _readNote() async {
    final camera = await askCameraOrFile(context);
    if (camera == null || !mounted) return;
    final f = await ref.read(deliveryNotePickerProvider)(camera: camera);
    if (f == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _reading = true;
      _error = null;
      _done = null;
    });
    // Row by row as the note has them; kept as the inspection's evidence.
    final r = await ref.read(masterImportRepositoryProvider).read(f.name, f.bytes, keepRows: true, purpose: 'ocr');
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        if (data.lines.isEmpty) {
          setState(() {
            _reading = false;
            _error = l10n.urNoJanRead;
          });
          return;
        }
        setState(() {
          _reading = false;
          _fileName = f.name;
          _bytes = f.bytes;
          _documentId = data.documentId;
          if ((data.supplierName ?? '').trim().isNotEmpty) _supplier.text = data.supplierName!.trim();
          _noteDate = DateTime.tryParse((data.docDate ?? '').replaceAll('/', '-'));
          _readRows = [
            for (final l in data.lines)
              ReadRow(
                lineNo: l.lineNo,
                jan: l.janCode,
                name: l.supplierName,
                quantity: l.quantity,
                maker: l.maker,
                code: l.productCode,
                flags: l.flags,
                ledger: LedgerFields.fromJson(l.ledger),
              ),
          ];
          _readChecked = false;
          _sheet = null;
        });
        await _openTable();
      case ApiFailure(:final message):
        setState(() {
          _reading = false;
          _error = humanizeApiErrorMessage(l10n, message);
        });
    }
  }

  /// 読み取り結果の確認: what the AI read, beside the note, to put right —
  /// as 発注 does.
  Future<void> _openTable() async {
    final rows = _sheet?.read ?? _readRows;
    if (rows == null) return;
    final checked = await Navigator.of(context).push<List<ReadRow>>(MaterialPageRoute(
      builder: (_) => ReadingCheckScreen(
        rows: rows,
        fileName: _fileName,
        bytes: _bytes,
        catalogLookup: (jans) => lookupJans(ref.read(janCatalogRepositoryProvider), jans),
        weightLookup: ref.read(productLibraryCanManageProvider)
            ? (asks) =>
                findWeightsWithAi(ref.read(specLookupRepositoryProvider), ref.read(janCatalogRepositoryProvider), asks)
            : null,
      ),
    ));
    if (checked == null || !mounted) return;
    setState(() {
      _sheet = stockSheetFromRead(checked);
      _readChecked = true;
    });
    await _lookup();
  }

  Future<void> _lookup() async {
    final jans = [for (final l in _lines) l.janCode];
    if (jans.isEmpty) return;
    final r = await ref.read(stockImportRepositoryProvider).known(jans);
    if (!mounted) return;
    if (r case ApiSuccess(:final data)) setState(() => _known = data);
  }

  /// A JAN scanned or typed: one more of it.
  void _onScan(String raw) {
    final jan = normalizeJan(raw) ?? raw.trim();
    _scan.clear();
    if (jan.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final onNote = _readChecked && (_sheet?.lines.any((l) => l.janCode == jan) ?? false);
    setState(() {
      _done = null;
      // On the note already: its count is put right on the 検品 screen.
      _error = onNote ? l10n.urOnNote(jan) : null;
      if (!onNote) _scanned[jan] = (_scanned[jan] ?? 0) + 1;
    });
    unawaited(_lookup());
  }

  Future<void> _camera() async {
    final l10n = AppLocalizations.of(context);
    await ref.read(inspectionCameraProvider)(context, title: l10n.urTitle, validate: (_) => null, onScan: _onScan);
  }

  /// Products registered, the lines kept for inspection as 予定外の入荷, and
  /// the 検品 screen opened with all of them ticked.
  Future<void> _toInspection(Warehouse wh) async {
    final l10n = AppLocalizations.of(context);
    final lines = [for (final l in _lines) if (l.quantity > 0) l];
    if (lines.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(stockImportRepositoryProvider);
    final known = await repo.known([for (final l in lines) l.janCode]);
    if (!mounted) return;
    final k = known is ApiSuccess<Map<String, String>> ? known.data : _known;
    final unknown = [for (final l in lines) if (!k.containsKey(l.janCode)) l];
    if (unknown.isNotEmpty) {
      final reg = await repo.registerProducts(unknown);
      if (!mounted) return;
      if (reg case ApiFailure(:final message)) {
        setState(() {
          _busy = false;
          _error = humanizeApiErrorMessage(l10n, message);
        });
        return;
      }
      ref.invalidate(productListProvider);
      // A picture for each from the web, meanwhile (kept per JAN, 0179).
      unawaited(findWebPhotos(ref.read(webPhotoRepositoryProvider), [for (final l in unknown) l.janCode]));
    }
    final r = await repo.unplannedStage(
      wh.id,
      lines,
      fileName: _fileName ?? l10n.urTitle,
      fileType: _fileName == null ? null : mimeTypeFor(_fileName!),
      supplier: _supplier.text.trim().isEmpty ? null : _supplier.text.trim(),
      documentId: _documentId,
      documentDate: _noteDate,
    );
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        // What was read, and the note itself, kept with the import — to set
        // beside each other later, as for 発注.
        if (_readChecked && _sheet != null) {
          await repo.note(data.importId, _sheet!.read, byAi: true, documentId: _documentId);
        }
        if (_bytes != null && _fileName != null) {
          await repo.keepFile(data.importId, _fileName!, _bytes!, mimeTypeFor(_fileName!));
        }
        if (!mounted) return;
        ref.invalidate(masterImportsProvider);
        ref.invalidate(pendingInspectionProvider);
        ref.invalidate(awaitingImportsProvider);
        setState(() {
          _busy = false;
          _done = data.importId;
          _reset();
        });
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => StockInspectionDetailScreen(importId: data.importId, tickAll: true)));
      case ApiFailure(:final message):
        setState(() {
          _busy = false;
          _error = humanizeApiErrorMessage(l10n, message);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final warehouses = ref.watch(warehouseOverviewProvider).valueOrNull?.warehouses ?? const <Warehouse>[];
    final active = ref.watch(activeWarehouseIdProvider);
    final whId = _warehouseId ?? (warehouses.any((w) => w.id == active) ? active : warehouses.firstOrNull?.id);
    final wh = warehouses.where((w) => w.id == whId).firstOrNull;
    final lines = _lines;
    final units = lines.fold<int>(0, (s, l) => s + l.quantity);
    final unknown = lines.where((l) => !_known.containsKey(l.janCode)).length;
    final hasNote = _readRows != null;
    final ready = lines.isNotEmpty && (!hasNote || _readChecked);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.urTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 120),
        children: [
          // Where this receipt is, as 発注 shows it.
          UnplannedFlow(
            states: unplannedStates(
              uploaded: hasNote || _scanned.isNotEmpty,
              readChecked: _readChecked || (!hasNote && _scanned.isNotEmpty),
              registered: false,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.urIntro, style: muted),
          const SizedBox(height: AppSpacing.sm),
          if (_done case final id?)
            Card(
              key: const ValueKey('ur-done'),
              color: theme.colorScheme.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: Text(l10n.urSent(id)),
                trailing: TextButton(
                  key: const ValueKey('ur-done-open'),
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => StockInspectionDetailScreen(importId: id))),
                  child: Text(l10n.urDoneOpen),
                ),
              ),
            ),
          if (warehouses.length > 1)
            DropdownButtonFormField<int>(
              key: const ValueKey('ur-warehouse'),
              initialValue: whId,
              decoration: InputDecoration(labelText: l10n.sfWarehouse),
              items: [for (final w in warehouses) DropdownMenuItem(value: w.id, child: Text(w.name))],
              onChanged: (v) => setState(() => _warehouseId = v),
            )
          else if (wh != null)
            Text('${l10n.sfWarehouse}: ${wh.name}', style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey('ur-supplier'),
            controller: _supplier,
            decoration: InputDecoration(
                labelText: l10n.urSupplier, helperText: l10n.urSupplierHint, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            key: const ValueKey('ur-note'),
            onPressed: _reading || _busy ? null : _readNote,
            icon: _reading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.document_scanner_outlined),
            label: Text(_reading ? l10n.dnReading : l10n.urReadNote),
          ),
          if (_fileName case final n?)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(l10n.urNoteKept(n), key: const ValueKey('ur-note-name'), style: muted),
            ),
          // Read but not yet checked: the check comes first, as for 発注.
          if (hasNote)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('ur-table'),
                onPressed: _busy ? null : _openTable,
                icon: Icon(_readChecked ? Icons.table_view_outlined : Icons.rule, size: 18),
                label: Text(_readChecked ? l10n.urTableAgain : l10n.urTableFirst),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey('ur-scan'),
            controller: _scan,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.qr_code_scanner),
              labelText: l10n.urScan,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                key: const ValueKey('ur-camera'),
                tooltip: l10n.cameraScan,
                icon: const Icon(Icons.photo_camera_outlined),
                onPressed: _busy ? null : _camera,
              ),
            ),
            onSubmitted: _onScan,
          ),
          if (_error case final e?)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(e, key: const ValueKey('ur-error'), style: TextStyle(color: theme.colorScheme.error)),
            ),
          if (lines.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(l10n.urReady(lines.length, units), key: const ValueKey('ur-summary'), style: theme.textTheme.titleSmall),
            if (unknown > 0)
              Text(l10n.urWillRegister(unknown), key: const ValueKey('ur-will-register'), style: muted),
            Text(l10n.urNextHint, style: muted),
            const SizedBox(height: AppSpacing.xs),
            for (final l in lines)
              ListTile(
                key: ValueKey('ur-line-${l.lineNo}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(_known[l.janCode] ?? l.name ?? l.code ?? l.janCode, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text([
                  'JAN ${l.janCode}',
                  if (!_known.containsKey(l.janCode)) l10n.urNewProduct,
                ].join(' · ')),
                trailing: Text('${l.quantity}', style: theme.textTheme.titleMedium),
              ),
          ],
        ],
      ),
      bottomNavigationBar: !ready || wh == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: FilledButton.icon(
                  key: const ValueKey('ur-next'),
                  onPressed: _busy ? null : () => _toInspection(wh),
                  icon: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.fact_check_outlined),
                  label: Text(l10n.urNext(lines.length)),
                ),
              ),
            ),
    );
  }
}
