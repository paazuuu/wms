import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error_text.dart';
import '../../core/api/api_result.dart';
import '../../core/export/save_bytes.dart' show mimeTypeFor;
import '../../core/theme/app_spacing.dart';
import '../../core/ui/copy_text.dart';
import '../../l10n/app_localizations.dart';
import '../delivery_note/delivery_note.dart';
import '../master_import/data/master_import_repository.dart' show masterImportsProvider;
import '../price_book/application/price_book_providers.dart';
import '../product/application/product_providers.dart';
import '../product/data/market_names.dart' show marketNameOf;
import '../product/data/web_photos.dart';
import '../product/domain/product.dart';
import '../product_library/application/product_library_providers.dart';
import '../product_library/presentation/product_thumb.dart';
import '../qc/domain/inspection.dart' show normalizeJan;
import '../stock_import/data/stock_import_repository.dart';
import '../stock_import/domain/stock_file.dart';
import '../stock_import/presentation/stock_inspection_screen.dart'
    show StockInspectionDetailScreen, inspectionCameraProvider;
import '../warehouse_context/application/warehouse_providers.dart';
import '../warehouse_context/domain/warehouse.dart';

/// One good on the counter: from the note, or scanned.
class _Line {
  _Line({required this.lineNo, required this.jan, this.name = '', this.maker = '', this.code = '', int quantity = 1})
      : count = TextEditingController(text: '$quantity');

  final int lineNo;
  final String jan;
  final String name;
  final String maker;
  final String code;
  final TextEditingController count;
  bool ticked = true;

  int? get quantity {
    final v = int.tryParse(count.text.trim());
    return v == null || v < 0 ? null : v;
  }

  StockFileLine toStock(int qty) => StockFileLine(
        lineNo: lineNo,
        janCode: jan,
        quantity: qty,
        name: name.isEmpty ? null : name,
        maker: maker.isEmpty ? null : maker,
        code: code.isEmpty ? null : code,
      );
}

/// 予定外の入荷 (0181): goods a regular supplier brought without an order or
/// an invoice first — nothing to import. The delivery note that came with
/// them is photographed (or chosen), or the goods are scanned; every line
/// read is ticked with the note's count. What did not come is unticked,
/// counts are put right, and 検品完了 puts them in stock at once — kept as
/// 取込 #… with the note, to look back at or take a line back.
///
/// It is not a purchase to pay: the invoice that comes later goes in through
/// 発注 as usual, and the goods already received here are not added again.
class UnplannedReceiptScreen extends ConsumerStatefulWidget {
  const UnplannedReceiptScreen({super.key});

  @override
  ConsumerState<UnplannedReceiptScreen> createState() => _UnplannedReceiptScreenState();
}

class _UnplannedReceiptScreenState extends ConsumerState<UnplannedReceiptScreen> {
  int? _warehouseId;
  final _supplier = TextEditingController();
  final _scan = TextEditingController();
  final List<_Line> _lines = [];
  String? _fileName;
  int? _documentId;
  DateTime? _noteDate;
  bool _reading = false;
  bool _busy = false;
  String? _error;

  /// JAN → the picture kept for it, for goods the library does not have.
  Map<String, String> _janPhotos = const {};

  /// The last one put in: its number, lines and units.
  ({int importId, int lines, int units})? _done;

  @override
  void dispose() {
    _supplier.dispose();
    _scan.dispose();
    for (final l in _lines) {
      l.count.dispose();
    }
    super.dispose();
  }

  int get _nextNo => _lines.fold<int>(0, (m, l) => l.lineNo > m ? l.lineNo : m) + 1;

  void _clearLines() {
    for (final l in _lines) {
      l.count.dispose();
    }
    _lines.clear();
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
    final r = await readDeliveryNoteKept(ref, f.name, f.bytes);
    if (!mounted) return;
    setState(() {
      _reading = false;
      switch (r) {
        case ApiSuccess(:final data):
          // Lines already scanned stay; the note's are added (a JAN on both
          // takes the note's count).
          for (final n in data.lines) {
            if (n.jan.isEmpty) continue;
            final had = _lines.where((l) => l.jan == n.jan).firstOrNull;
            if (had != null) {
              if (n.quantity case final q?) had.count.text = '$q';
              had.ticked = true;
              continue;
            }
            _lines.add(_Line(
                lineNo: _nextNo, jan: n.jan, name: n.name, maker: n.maker, code: n.code, quantity: n.quantity ?? 1));
          }
          _fileName = f.name;
          _documentId = data.documentId;
          if ((data.supplier ?? '').trim().isNotEmpty && _supplier.text.trim().isEmpty) {
            _supplier.text = data.supplier!.trim();
          }
          _noteDate = DateTime.tryParse((data.date ?? '').replaceAll('/', '-'));
          if (!data.lines.any((n) => n.jan.isNotEmpty)) _error = l10n.urNoJanRead;
        case ApiFailure(:final message):
          _error = humanizeApiErrorMessage(l10n, message);
      }
    });
    unawaited(_loadPhotos());
  }

  /// Pictures kept for the JANs the library does not have (0179).
  Future<void> _loadPhotos() async {
    final known = <String>{};
    try {
      known.addAll((await ref.read(productListProvider.future)).map((p) => p.janCode));
    } catch (_) {}
    final jans = {for (final l in _lines) if (!known.contains(l.jan) && !_janPhotos.containsKey(l.jan)) l.jan}.toList();
    if (jans.isEmpty || !mounted) return;
    final r = await ref.read(webPhotoRepositoryProvider).janPhotos(jans, look: true);
    if (!mounted) return;
    if (r case ApiSuccess(:final data) when data.isNotEmpty) setState(() => _janPhotos = {..._janPhotos, ...data});
  }

  /// A JAN scanned or typed: one more of it, or a new line.
  void _onScan(String raw) {
    final jan = normalizeJan(raw) ?? raw.trim();
    _scan.clear();
    if (jan.isEmpty) return;
    setState(() {
      _done = null;
      final had = _lines.where((l) => l.jan == jan).firstOrNull;
      if (had != null) {
        had.count.text = '${(had.quantity ?? 0) + 1}';
        had.ticked = true;
      } else {
        _lines.add(_Line(lineNo: _nextNo, jan: jan));
      }
    });
    unawaited(_loadPhotos());
  }

  Future<void> _camera() async {
    final l10n = AppLocalizations.of(context);
    await ref.read(inspectionCameraProvider)(context, title: l10n.urTitle, validate: (_) => null, onScan: _onScan);
  }

  List<_Line> get _chosen => [
        for (final l in _lines)
          if (l.ticked && (l.quantity ?? 0) > 0) l
      ];

  /// Products the library lacks, registered through 価格台帳 (as 発注 does):
  /// the price book's when it has the JAN, else the note's name, maker and
  /// 品番. False when it failed (and said so).
  Future<bool> _register(List<_Line> unknown) async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(stockImportRepositoryProvider);
    final book = ref.read(priceBookRepositoryProvider);
    final inBook = await repo.inPriceBook([for (final l in unknown) l.jan]);
    final have = inBook is ApiSuccess<Map<String, (int, String)>> ? inBook.data : const <String, (int, String)>{};
    final ids = [for (final l in unknown) if (have[l.jan] case (final id, _)) id];
    final fresh = [for (final l in unknown) if (!have.containsKey(l.jan)) l];
    if (fresh.isNotEmpty) {
      final r = await book.import([for (final l in fresh) l.toStock(0).toPriceBookLine()], sourceFile: _fileName);
      switch (r) {
        case ApiSuccess(:final data):
          ids.addAll(data.ids);
        case ApiFailure(:final message):
          if (mounted) setState(() => _error = humanizeApiErrorMessage(l10n, message));
          return false;
      }
    }
    if (ids.isEmpty) return true;
    final r = await book.toProducts(ids);
    if (r case ApiFailure(:final message)) {
      if (mounted) setState(() => _error = humanizeApiErrorMessage(l10n, message));
      return false;
    }
    ref.invalidate(productListProvider);
    ref.invalidate(priceBookListProvider);
    // A picture for each from the web, meanwhile (kept per JAN, 0179).
    unawaited(findWebPhotos(ref.read(webPhotoRepositoryProvider), [for (final l in unknown) l.jan]));
    return true;
  }

  Future<void> _complete(Warehouse wh) async {
    final l10n = AppLocalizations.of(context);
    final lines = _chosen;
    if (lines.isEmpty) return;
    final bad = [for (final l in _lines) if (l.ticked && l.quantity == null) l];
    if (bad.isNotEmpty) {
      setState(() => _error = l10n.urBadCount(bad.first.jan));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(stockImportRepositoryProvider);
    final known = await repo.known([for (final l in lines) l.jan]);
    if (!mounted) return;
    if (known case ApiFailure(:final message)) {
      setState(() {
        _busy = false;
        _error = humanizeApiErrorMessage(l10n, message);
      });
      return;
    }
    final k = (known as ApiSuccess<Map<String, String>>).data;
    final unknown = [for (final l in lines) if (!k.containsKey(l.jan)) l];
    final canRegister = ref.read(productLibraryCanManageProvider);
    final units = lines.fold<int>(0, (s, l) => s + l.quantity!);
    setState(() => _busy = false);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.urConfirmQ(wh.name)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.urConfirmBody(lines.length, units), key: const ValueKey('ur-confirm-body')),
          if (unknown.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(canRegister ? l10n.urConfirmRegister(unknown.length) : l10n.urConfirmSkip(unknown.length),
                key: const ValueKey('ur-confirm-unknown')),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.urConfirmInvoice, style: Theme.of(d).textTheme.bodySmall),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l10n.actionCancel)),
          FilledButton(
              key: const ValueKey('ur-confirm'), onPressed: () => Navigator.pop(d, true), child: Text(l10n.urConfirmGo)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    if (unknown.isNotEmpty && canRegister && !await _register(unknown)) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (!mounted) return;
    final send = [
      for (final l in lines)
        if (canRegister || k.containsKey(l.jan)) l.toStock(l.quantity!)
    ];
    if (send.isEmpty) {
      setState(() {
        _busy = false;
        _error = l10n.urNothingKnown;
      });
      return;
    }
    final r = await repo.unplannedReceipt(
      wh.id,
      send,
      fileName: _fileName ?? l10n.urTitle,
      fileType: _fileName == null ? null : mimeTypeFor(_fileName!),
      supplier: _supplier.text.trim().isEmpty ? null : _supplier.text.trim(),
      documentId: _documentId,
      documentDate: _noteDate,
    );
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        ref.invalidate(productListProvider);
        ref.invalidate(masterImportsProvider);
        ref.invalidate(pendingInspectionProvider);
        setState(() {
          _busy = false;
          _done = (importId: data.importId, lines: send.length, units: send.fold<int>(0, (s, l) => s + l.quantity));
          _clearLines();
          _fileName = null;
          _documentId = null;
          _noteDate = null;
          _supplier.clear();
        });
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
    final products = {for (final p in ref.watch(productListProvider).valueOrNull ?? const <Product>[]) p.janCode: p};
    final chosen = _chosen;
    final units = chosen.fold<int>(0, (s, l) => s + l.quantity!);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.urTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 120),
        children: [
          Text(l10n.urIntro, style: muted),
          const SizedBox(height: AppSpacing.sm),
          if (_done case final d?)
            Card(
              key: const ValueKey('ur-done'),
              color: theme.colorScheme.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.check_circle),
                title: Text(l10n.urDone(d.importId, d.lines, d.units)),
                subtitle: Text(l10n.urDoneHint),
                trailing: TextButton(
                  key: const ValueKey('ur-done-open'),
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => StockInspectionDetailScreen(importId: d.importId))),
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
          if (_lines.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(l10n.urLines(_lines.length, chosen.length, units),
                key: const ValueKey('ur-summary'), style: theme.textTheme.titleSmall),
            Text(l10n.urLinesHint, style: muted),
            for (final l in _lines) _lineCard(context, l, products[l.jan]),
          ],
        ],
      ),
      bottomNavigationBar: _lines.isEmpty || wh == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: FilledButton.icon(
                  key: const ValueKey('ur-complete'),
                  onPressed: _busy || chosen.isEmpty ? null : () => _complete(wh),
                  icon: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.fact_check_outlined),
                  label: Text(l10n.urComplete(chosen.length, units)),
                ),
              ),
            ),
    );
  }

  Widget _lineCard(BuildContext context, _Line l, Product? p) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final name = p == null ? l.name : (marketNameOf(p) ?? p.name);
    final web = _janPhotos[l.jan];
    final picture = p != null
        ? ProductThumb(productId: p.id, janCode: p.janCode, productName: p.name, size: 64)
        : web != null
            ? ClipRRect(
                key: ValueKey('ur-webphoto-${l.lineNo}'),
                borderRadius: BorderRadius.circular(8),
                child: Image.network(web,
                    width: 64, height: 64, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _noPhoto(scheme)),
              )
            : _noPhoto(scheme);
    return Card(
      key: ValueKey('ur-line-${l.lineNo}'),
      color: l.ticked ? null : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(children: [
          Checkbox(
            key: ValueKey('ur-tick-${l.lineNo}'),
            value: l.ticked,
            onChanged: _busy ? null : (v) => setState(() => l.ticked = v ?? false),
          ),
          picture,
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name.isEmpty ? (l.code.isEmpty ? l10n.plNameMissing : l.code) : name,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600), maxLines: 2),
              if ([p?.maker ?? l.maker, p?.sku ?? l.code].any((x) => x.trim().isNotEmpty))
                Text([p?.maker ?? l.maker, p?.sku ?? l.code].where((x) => x.trim().isNotEmpty).join(' · '), style: muted),
              Row(children: [
                Text('JAN ${l.jan}', key: ValueKey('ur-jan-${l.lineNo}'), style: muted),
                CopyButton(value: l.jan, size: 14),
              ]),
              if (p == null)
                Text(l10n.dnNotInLibrary,
                    key: ValueKey('ur-new-${l.lineNo}'), style: muted?.copyWith(color: scheme.tertiary)),
            ]),
          ),
          SizedBox(
            width: 90,
            child: TextField(
              key: ValueKey('ur-count-${l.lineNo}'),
              controller: l.count,
              enabled: !_busy && l.ticked,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.end,
              decoration: InputDecoration(labelText: l10n.siCounted, isDense: true, border: const OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _noPhoto(ColorScheme scheme) => Container(
        width: 64,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
        child: Icon(Icons.image_not_supported_outlined, color: scheme.onSurfaceVariant),
      );
}
