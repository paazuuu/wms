import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/export/save_bytes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/open_window.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../payments/data/payments_repository.dart';
import '../../payments/domain/payment.dart';
import '../../payments/presentation/payments_screen.dart' show OrderFlowBar, PaymentsScreen, focusedOrderProvider;
import '../../master_import/data/master_import_repository.dart';
import '../../master_import/domain/master_import.dart';
import '../../master_import/presentation/master_import_labels.dart';
import '../../master_import/presentation/master_imports_screen.dart';
import '../../notation/domain/notation.dart' show ColumnField;
import '../../notation/presentation/notation_labels.dart';
import '../../price_book/application/price_book_providers.dart';
import '../../price_book/presentation/price_book_import_screen.dart';
import '../../product/application/product_providers.dart';
import '../../product/data/market_names.dart';
import '../../product/data/web_photos.dart';
import '../../product/data/spec_lookup.dart';
import '../../product_library/application/product_library_providers.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../../warehouse_context/domain/warehouse.dart';
import '../data/stock_import_repository.dart';
import '../../jan_catalog/data/jan_catalog_repository.dart';
import '../domain/stock_file.dart';
import '../domain/stock_ledger.dart';
import 'import_view_screen.dart';
import 'reading_check_screen.dart';
import 'stock_import_calendar_screen.dart';
import 'stock_inspection_screen.dart';

/// A chosen file: its name and bytes, or null when nothing was chosen.
typedef PickStockFile = Future<({String name, Uint8List bytes})?> Function();

Future<({String name, Uint8List bytes})?> _pickWithPicker() async {
  final r = await FilePicker.platform.pickFiles(
    withData: true,
    type: FileType.custom,
    // Sheets are read here; PDFs (text or scanned), pictures and old .xls by the AI.
    allowedExtensions: const ['xlsx', 'xlsm', 'csv', 'tsv', 'txt', 'xls', 'pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'],
  );
  final f = r?.files.firstOrNull;
  if (f?.bytes == null) return null;
  return (name: f!.name, bytes: f.bytes!);
}

/// Overridden in tests so nothing reaches for the platform.
final stockFilePickerProvider = Provider<PickStockFile>((_) => _pickWithPicker);

/// Where the template goes; overridden in tests.
final stockTemplateSaverProvider =
    Provider<Future<void> Function(String, Uint8List)>((_) => (n, b) async => saveBytes(n, b));

/// ファイルから在庫登録 (0144): a JAN and a quantity a row, from Excel or
/// CSV, into one warehouse — added to what is there, or set to the figure.
/// Read here without AI; nothing is booked until 在庫に反映.
///
/// Products are not made here: a JAN 商品ライブラリー does not have is
/// shown and left out, with the way to register it (価格台帳). Every file
/// that changed stock is kept, with its original, in 取込履歴.
class StockFileImportScreen extends ConsumerStatefulWidget {
  const StockFileImportScreen({super.key});

  @override
  ConsumerState<StockFileImportScreen> createState() => _StockFileImportScreenState();
}

class _StockFileImportScreenState extends ConsumerState<StockFileImportScreen> {
  int? _warehouseId;
  StockFileMode _mode = StockFileMode.add;
  String? _fileName;
  Uint8List? _bytes;
  StockSheet? _sheet;
  Map<String, String> _known = const {};

  /// What the chosen warehouse has of each JAN now, for 現在庫 ＋ ファイル.
  Map<String, int> _onHand = const {};

  /// JANs not in 商品ライブラリー but in 価格台帳: the item and its name there.
  Map<String, (int, String)> _book = const {};
  bool _badFile = false;
  bool _busy = false;

  /// The AI is reading the file (it can take a minute for a long PDF).
  bool _aiReading = false;

  /// Asking the server what unknown headings mean (0163).
  bool _judgingHeadings = false;

  /// The kept copy import-plan made of a file the AI read (0132).
  int? _documentId;

  /// Who the document is from, as read (an invoice always names them).
  String? _docSupplier;
  String? _docRegistration;
  bool _docPayee = false;

  /// The AI's work on the products just registered (商品名, photos): the
  /// 振込先 is read after it (0172).
  Future<void>? _aiWork;

  /// Products the file has that 商品ライブラリー does not: registered
  /// (through 価格台帳) before the stock goes in, so the whole file lands.
  bool _registerNew = true;

  /// The person has looked the reading over and says it is right: nothing
  /// goes in before. Cleared by a new file and by any change to a line.
  bool _checked = false;

  /// What the AI read has been set beside the original, row by row, in the
  /// table (読み取り結果の確認): the stock is worked out only after.
  bool _tableChecked = false;
  StockFileResult? _done;
  String? _error;

  /// The date the import is filed under (0148): read from the file, else the
  /// file's own, else today. Changeable before it goes in.
  DocumentDate? _docDate;

  /// Whether the supplier has been paid for it, and a memo (0148).
  bool _paid = false;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  List<StockFileLine> get _ready => [
        for (final l in _sheet?.lines ?? const <StockFileLine>[])
          if (_known.containsKey(l.janCode)) l,
      ];
  List<StockFileLine> get _unknown => [
        for (final l in _sheet?.lines ?? const <StockFileLine>[])
          if (!_known.containsKey(l.janCode)) l,
      ];

  Future<void> _pick() async {
    final f = await ref.read(stockFilePickerProvider)();
    if (f == null || !mounted) return;
    setState(() {
      _busy = true;
      _done = null;
      _namesNote = null;
      _catalog = const {};
      _names = const {};
      _namesStopped = false;
      _error = null;
      _badFile = false;
      _fileName = f.name;
      _bytes = f.bytes;
      _sheet = null;
      _known = const {};
      _documentId = null;
      _docSupplier = null;
      _docRegistration = null;
      _docPayee = false;
      _aiWork = null;
      _checked = false;
      _tableChecked = false;
      _docDate = null;
      _paid = false;
      _note.clear();
    });
    StockSheet? sheet;
    List<List<String>>? rows;
    String? readDate;
    if (readsLocally(f.name)) {
      try {
        rows = readStockFile(f.name, f.bytes);
        sheet = parseStockRows(rows);
      } on FormatException {
        sheet = null;
      }
      // Headings the app's own words do not know (商品名称, メーカー品番, …):
      // the server says what they are — learned headings, then the AI — and
      // the sheet is read again with them (0163). Without an answer, the
      // sheet stands as read.
      if (sheet != null && sheet.header && sheet.unplaced.isNotEmpty && rows != null) {
        setState(() => _judgingHeadings = true);
        final m = await ref.read(masterImportRepositoryProvider).mapColumns(sheet.headings, sheet.samplesFrom(rows));
        if (!mounted) return;
        if (m case ApiSuccess(:final data) when data.isNotEmpty) sheet = parseStockRows(rows, meanings: data);
        setState(() => _judgingHeadings = false);
      }
    }
    // A PDF, a scan, a photo, an old .xls — or a sheet whose headings were
    // not found: the AI reads it (import-plan, nothing booked), and every
    // line it gives is to be checked here before it goes in.
    if (sheet == null || !sheet.header) {
      setState(() => _aiReading = true);
      // Row by row as the file has them, so a ledger (明細) keeps each 注番.
      final r = await ref.read(masterImportRepositoryProvider).read(f.name, f.bytes, keepRows: true);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      switch (r) {
        case ApiSuccess(:final data):
          if (data.lines.isEmpty) {
            setState(() {
              _busy = false;
              _aiReading = false;
              _error = data.aiFailure != null
                  ? masterProblemText(l10n, MasterProblem('ai_unavailable', value: data.aiFailure))
                  : l10n.sfAiNothing;
            });
            return;
          }
          _documentId = data.documentId;
          _docSupplier = data.supplierName;
          _docRegistration = data.registrationNumber;
          _docPayee = data.hasPayee;
          readDate = data.docDate;
          sheet = stockSheetFromRead([
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
          ]);
        case ApiFailure(:final message):
          setState(() {
            _busy = false;
            _aiReading = false;
            // A long PDF the AI could not finish within the server's time:
            // what to do instead, rather than the server's own words.
            _error = RegExp('timeout', caseSensitive: false).hasMatch(message)
                ? l10n.sfTooLong
                : humanizeApiErrorMessage(l10n, message);
          });
          return;
      }
    }
    _aiReading = false;
    final date = findDocumentDate(fileName: f.name, bytes: f.bytes, rows: rows, readDate: readDate);
    setState(() {
      _sheet = sheet;
      _docDate = date;
    });
    // Read by the AI: first set beside the original and corrected in the table.
    if (sheet.byAi) {
      // What the library has is looked up first, for the 確認用Excel meanwhile.
      await _lookup();
      if (!mounted) return;
      await _openTable();
      return;
    }
    await _lookup();
    unawaited(_lookUpNames());
  }

  /// 読み取り結果の確認: every row read, as a table beside the original, to
  /// correct; then the stock is worked out from what the person left.
  Future<void> _openTable() async {
    final sheet = _sheet;
    if (sheet == null) return;
    final rows = await Navigator.of(context).push<List<ReadRow>>(MaterialPageRoute(
      builder: (_) => ReadingCheckScreen(
        rows: sheet.read,
        fileName: _fileName,
        bytes: _bytes,
        // Each JAN against the makers' catalogs (0153).
        catalogLookup: (jans) => lookupJans(ref.read(janCatalogRepositoryProvider), jans),
        // Weights no catalog gives, found by the AI (0155): for whoever may.
        weightLookup: ref.read(productLibraryCanManageProvider)
            ? (asks) =>
                findWeightsWithAi(ref.read(specLookupRepositoryProvider), ref.read(janCatalogRepositoryProvider), asks)
            : null,
      ),
    ));
    if (rows == null || !mounted) return;
    setState(() {
      _sheet = stockSheetFromRead(rows, byAi: sheet.byAi);
      _tableChecked = true;
      _checked = false;
    });
    await _lookup();
    unawaited(_lookUpNames());
  }

  /// The chosen warehouse, as the screen shows it.
  int? get _whId {
    final warehouses = ref.read(warehouseOverviewProvider).valueOrNull?.warehouses ?? const <Warehouse>[];
    final active = ref.read(activeWarehouseIdProvider);
    return _warehouseId ?? (warehouses.any((w) => w.id == active) ? active : warehouses.firstOrNull?.id);
  }

  /// Which of the file's JANs 商品ライブラリー has (matched by JAN alone:
  /// the file may call a product something else, and its stock still adds to
  /// that product), what the warehouse holds of them now, and which of the
  /// rest 価格台帳 knows.
  Future<void> _lookup() async {
    final sheet = _sheet;
    if (sheet == null || sheet.lines.isEmpty) {
      setState(() => _busy = false);
      return;
    }
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(stockImportRepositoryProvider);
    final jans = [for (final l in sheet.lines) l.janCode];
    final known = await repo.known(jans);
    if (!mounted) return;
    if (known case ApiFailure(:final message)) {
      setState(() {
        _busy = false;
        _error = humanizeApiErrorMessage(l10n, message);
      });
      return;
    }
    final k = (known as ApiSuccess<Map<String, String>>).data;
    final missing = [
      for (final j in jans)
        if (!k.containsKey(j)) j
    ];
    final wh = _whId;
    final onHand = wh == null
        ? null
        : await repo.onHand(wh, [
            for (final j in jans)
              if (k.containsKey(j)) j
          ]);
    final book = missing.isEmpty ? null : await repo.inPriceBook(missing);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _known = k;
      _onHand = onHand is ApiSuccess<Map<String, int>> ? onHand.data : const {};
      _book = book is ApiSuccess<Map<String, (int, String)>> ? book.data : const {};
    });
  }

  /// The lines whose product 商品ライブラリー lacks but can be made: 価格台帳
  /// has the JAN, or the file names the product.
  List<StockFileLine> get _registrable => [
        for (final l in _unknown)
          if (_book.containsKey(l.janCode) || l.registerName != null) l
      ];

  /// The file's products 商品ライブラリー lacks, registered through 価格台帳:
  /// those it has go in under its names; the rest are read into it first
  /// (JAN, name, maker, 品番 as the file has them), then registered. Their
  /// stock then goes in with the others. False when it failed (and said so).
  Future<bool> _registerUnknown() async {
    final l10n = AppLocalizations.of(context);
    final book = ref.read(priceBookRepositoryProvider);
    final todo = _registrable;
    final ids = [
      for (final l in todo)
        if (_book[l.janCode] case (final id, _)) id
    ];
    final fresh = [
      for (final l in todo)
        if (!_book.containsKey(l.janCode)) l
    ];
    if (fresh.isNotEmpty) {
      final r = await book.import([for (final l in fresh) l.toPriceBookLine(name: _nameFor(l))], sourceFile: _fileName);
      if (!mounted) return false;
      switch (r) {
        case ApiSuccess(:final data):
          ids.addAll(data.ids);
        case ApiFailure(:final message):
          setState(() => _error = humanizeApiErrorMessage(l10n, message));
          return false;
      }
    }
    if (ids.isEmpty) return true;
    final r = await book.toProducts(ids);
    if (!mounted) return false;
    switch (r) {
      case ApiSuccess():
        ref.invalidate(productListProvider);
        ref.invalidate(priceBookListProvider);
        // Those the file gave no name for: their 商品名 looked up on the web
        // meanwhile (0164), while the stock goes in.
        // And a picture for each from the web, for those with none (0166).
        final photos = ref.read(webPhotoRepositoryProvider);
        final work = Future.wait<void>([
          findWebPhotos(photos, [for (final l in todo) l.janCode]).then((added) {
            if (mounted && added > 0) ref.invalidate(productListProvider);
          }),
          _findNames([
            for (final l in todo)
              if (!_names.containsKey(l.janCode) && _nameFor(l) == null)
                NameAsk(jan: l.janCode, maker: l.maker, code: l.code, name: l.name),
          ]),
        ]);
        _aiWork = work;
        unawaited(work);
        return true;
      case ApiFailure(:final message):
        setState(() => _error = humanizeApiErrorMessage(l10n, message));
        return false;
    }
  }

  /// The names found for products just registered (0164), said when done.
  String? _namesNote;

  /// Once a person has checked what was read (a sheet read here needs no
  /// check): each JAN's place in the makers' catalogs, and the 商品名 the web
  /// gives (0164) — kept apart until the products are registered.
  Map<String, JanCatalogHit> _catalog = const {};
  Map<String, FoundName> _names = const {};
  bool _namesBusy = false;
  int _namesDone = 0;
  int _namesTotal = 0;
  bool _namesStopped = false;

  bool get _checkCleared => _sheet != null && (!_sheet!.byAi || _tableChecked);

  /// The 商品名 a line goes in under, as shops and the maker call it: the
  /// library's (when it is more than the 品番), the one the web gave, else the
  /// file's (when it is more than the 品番); blank when none is known.
  String? _nameFor(StockFileLine l) {
    // Not a name: the 品番 again, however it is written (UMR05S.33 /
    // UMR05S 33), or the JAN.
    bool real(String? n) {
      final t = n?.trim() ?? '';
      return t.isNotEmpty && t != l.janCode && !sameCode(t, l.code ?? '');
    }

    final library = _known[l.janCode] ?? _book[l.janCode]?.$2;
    if (real(library)) return library!.trim();
    if (_names[l.janCode] case final f? when f.usable) return f.name!.trim();
    if (real(l.name)) return l.name!.trim();
    return null;
  }

  /// Where the 商品名 was found: the catalog page, else the web page.
  ({String label, String url})? _whereFound(StockFileLine l, AppLocalizations l10n) {
    if (_catalog[l.janCode] case final h? when h.found && h.pageUrl != null) {
      return (label: l10n.sfInCatalog(h.catalogName ?? '', h.pageNumber ?? ''), url: h.pageUrl!);
    }
    if (_names[l.janCode] case final f? when f.usable && f.sourceUrl != null) {
      return (label: l10n.sfOnWeb, url: f.sourceUrl!);
    }
    return null;
  }

  /// After the check: the catalogs, the names asked before, then the web for
  /// the rest (whoever may register products). Runs meanwhile; the lines
  /// can be sent in before it ends.
  Future<void> _lookUpNames() async {
    final sheet = _sheet;
    if (sheet == null || !_checkCleared || sheet.lines.isEmpty) return;
    final jans = [for (final l in sheet.lines) l.janCode];
    final catalog = await lookupJans(ref.read(janCatalogRepositoryProvider), jans);
    if (!mounted) return;
    final repo = ref.read(marketNameRepositoryProvider);
    final before = await repo.cached(jans);
    if (!mounted) return;
    setState(() {
      _catalog = {..._catalog, ...catalog};
      if (before case ApiSuccess(:final data)) _names = {..._names, ...data};
    });
    if (!ref.read(productLibraryCanManageProvider)) return;
    final asks = [
      for (final l in sheet.lines)
        if (!_names.containsKey(l.janCode) && _nameFor(l) == null)
          NameAsk(jan: l.janCode, maker: l.maker, code: l.code, name: l.name),
    ];
    if (asks.isEmpty) return;
    setState(() {
      _namesBusy = true;
      _namesDone = 0;
      _namesTotal = asks.length;
    });
    final out = await findMarketNames(repo, asks, onProgress: (done, _) {
      if (mounted) setState(() => _namesDone = done);
    });
    if (!mounted) return;
    setState(() {
      _namesBusy = false;
      _names = {..._names, ...out.answers};
      _namesStopped = out.stoppedBy != null;
    });
  }

  Future<void> _findNames(List<NameAsk> asks) async {
    if (asks.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(marketNameRepositoryProvider);
    setState(() => _namesNote = l10n.sfNamesFinding(asks.length));
    final out = await findMarketNames(repo, asks);
    if (!mounted) return;
    ref.invalidate(productListProvider);
    ref.invalidate(priceBookListProvider);
    setState(() => _namesNote = [
          l10n.sfNamesFound(out.applied, out.asked),
          if (out.stoppedBy != null) l10n.plFindNamesStopped,
        ].join('\n'));
  }

  Future<void> _apply(Warehouse wh, {required bool register}) async {
    final l10n = AppLocalizations.of(context);
    final toRegister = register ? _registrable : const <StockFileLine>[];
    final lines = [..._ready, ...toRegister];
    // The same delivery put in twice is the costliest mistake there is.
    if (!await _passesDuplicateCheck(lines)) return;
    if (!mounted) return;
    final units = lines.fold<int>(0, (s, l) => s + l.quantity);
    final before = lines.fold<int>(0, (s, l) => s + (_onHand[l.janCode] ?? 0));
    final after = _mode == StockFileMode.add ? before + units : units;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.sfConfirmQ(wh.name)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_mode == StockFileMode.add ? l10n.sfConfirmAdd(lines.length, units) : l10n.sfConfirmSet(lines.length)),
          // Added stock waits for the inspector (0148); a count correction does not.
          if (_mode == StockFileMode.add) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.sfConfirmStage, key: const ValueKey('sf-confirm-stage')),
          ],
          if (toRegister.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.sfConfirmRegister(toRegister.length), key: const ValueKey('sf-confirm-register')),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.sfConfirmTotals(before, after),
            key: const ValueKey('sf-confirm-totals'),
            style: Theme.of(d).textTheme.titleSmall,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l10n.actionCancel)),
          FilledButton(
              key: const ValueKey('sf-confirm'),
              onPressed: () => Navigator.pop(d, true),
              child: Text(l10n.sfApplyShort)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    var send = lines;
    if (toRegister.isNotEmpty) {
      if (!await _registerUnknown()) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      await _lookup();
      if (!mounted) return;
      setState(() => _busy = true);
      send = _ready;
    }
    final repo = ref.read(stockImportRepositoryProvider);
    // Added stock is kept for inspection and goes in when it is checked; a
    // count correction (set) goes in at once.
    final r = _mode == StockFileMode.add
        ? await repo.stage(wh.id, send, fileName: _fileName, fileType: mimeTypeFor(_fileName ?? ''))
        : await repo.apply(wh.id, _mode, send, fileName: _fileName, fileType: mimeTypeFor(_fileName ?? ''));
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        // The date it is filed under, whether it is paid, and the memo.
        await repo.updateNotes(
          data.importId,
          date: _docDate,
          paid: _paid ? true : null,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        );
        // The original goes with the import; a failure here does not undo
        // the stock, it only leaves the history without the file.
        if (_bytes != null && _fileName != null) {
          await repo.keepFile(data.importId, _fileName!, _bytes!, mimeTypeFor(_fileName!));
        }
        // And what the file was read as, to set beside it later (0146).
        if (_sheet case final sh?) {
          await repo.note(data.importId, sh.read, byAi: sh.byAi, documentId: _documentId);
        }
        // So the same file, or the same lines again, is caught next time.
        await repo.fingerprint(
          data.importId,
          file: _bytes == null ? null : fileFingerprint(_bytes!),
          lines: linesFingerprint(send),
        );
        // Then, once the AI has done the products, where the invoice asks to
        // be paid and how much — the order's payment in 会計 (0172).
        if (!_docPayee) {
          final importId = data.importId;
          final payments = ref.read(paymentsRepositoryProvider);
          unawaited((_aiWork ?? Future<void>.value()).catchError((_) {}).then((_) => payments.readPayee(importId)).then((r) {
            if (r is ApiSuccess<Payee?> && r.data != null) ref.invalidate(paymentsProvider);
          }));
        }
        if (!mounted) return;
        ref.invalidate(productListProvider);
        ref.invalidate(masterImportsProvider);
        ref.invalidate(pendingInspectionProvider);
        ref.invalidate(awaitingImportsProvider);
        setState(() {
          _busy = false;
          _done = data;
          _sheet = null;
          _bytes = null;
        });
      case ApiFailure(:final message):
        setState(() {
          _busy = false;
          _error = humanizeApiErrorMessage(l10n, message);
        });
    }
  }

  /// The 確認用Excel of what was read: every row, what would become of it,
  /// and the cells to look at in yellow — to check it all at once, correct
  /// it, and choose the corrected file to put in.
  Future<void> _downloadReview() async {
    final sheet = _sheet;
    if (sheet == null) return;
    final l10n = AppLocalizations.of(context);
    final base = (_fileName ?? 'file').replaceAll(RegExp(r'\.[A-Za-z0-9]+$'), '');
    final bytes = buildReviewXlsx(
      fileName: _fileName ?? '',
      supplier: _docSupplier,
      registrationNumber: _docRegistration,
      sheet: sheet,
      inLibrary: _known.keys.toSet(),
      inPriceBook: _book.keys.toSet(),
      flagText: (f) => flagLabel(l10n, f),
    );
    await ref.read(stockTemplateSaverProvider)('在庫登録_確認用_$base.xlsx', bytes);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.sfReviewSaved)));
  }

  /// Whether to go on although an import of the same file, or of the same
  /// lines, is already in: adding it again would count the stock twice.
  Future<bool> _passesDuplicateCheck(List<StockFileLine> lines) async {
    final l10n = AppLocalizations.of(context);
    final r = await ref.read(stockImportRepositoryProvider).duplicates(
          file: _bytes == null ? null : fileFingerprint(_bytes!),
          lines: linesFingerprint(lines),
        );
    if (!mounted) return false;
    final found = r is ApiSuccess<List<DuplicateImport>> ? r.data : const <DuplicateImport>[];
    if (found.isEmpty) return true;
    final fmt = DateFormat('y/MM/dd HH:mm');
    final go = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: Theme.of(d).colorScheme.error),
        title: Text(l10n.sfDuplicateQ),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_mode == StockFileMode.add ? l10n.sfDuplicateAdd : l10n.sfDuplicateSet),
          const SizedBox(height: AppSpacing.sm),
          for (final f in found.take(5))
            Text(
              l10n.sfDuplicateLine(
                  f.importId, fmt.format(f.at), f.fileName ?? '', f.sameFile ? l10n.sfSameFile : l10n.sfSameLines),
              key: ValueKey('sf-dup-${f.importId}'),
              style: Theme.of(d).textTheme.bodySmall,
            ),
        ]),
        actions: [
          FilledButton(
              key: const ValueKey('sf-dup-cancel'),
              onPressed: () => Navigator.pop(d, false),
              child: Text(l10n.actionCancel)),
          TextButton(
              key: const ValueKey('sf-dup-go'),
              onPressed: () => Navigator.pop(d, true),
              child: Text(l10n.sfDuplicateGo)),
        ],
      ),
    );
    return go == true;
  }

  /// One line's quantity corrected by hand, or the line left out: what the
  /// AI read is checked here, before anything is booked.
  Future<void> _editLine(StockFileLine line) async {
    final result = await showDialog<int>(
      context: context,
      builder: (_) => _QtyDialog(title: _known[line.janCode] ?? line.name ?? line.janCode, line: line),
    );
    final sheet = _sheet;
    if (result == null || sheet == null || !mounted) return;
    setState(() => _checked = false);
    setState(() => _sheet = sheet.copyWith(lines: [
          for (final l in sheet.lines)
            if (l.janCode != line.janCode) l else if (result >= 0) l.copyWith(quantity: result),
        ]));
  }

  static String _signedDiff(int v) => v > 0 ? '+$v' : '$v';

  String _problemText(AppLocalizations l10n, StockFileProblem p) => switch (p.code) {
        'no_jan' => l10n.sfPbNoJan(p.lineNo, p.value ?? ''),
        _ => l10n.sfPbBadQty(p.lineNo, p.value ?? ''),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final canAdjust = ref.watch(authControllerProvider).user?.hasPermission('inventory.adjust') ?? false;
    final warehouses = ref.watch(warehouseOverviewProvider).valueOrNull?.warehouses ?? const <Warehouse>[];
    final active = ref.watch(activeWarehouseIdProvider);
    final whId = _warehouseId ?? (warehouses.any((w) => w.id == active) ? active : warehouses.firstOrNull?.id);
    final wh = warehouses.where((w) => w.id == whId).firstOrNull;
    final sheet = _sheet;
    final ready = _ready;
    final unknown = _unknown;
    final canManage = ref.watch(authControllerProvider).user?.hasPermission('product.manage') ?? false;
    final registrable = _registrable;
    final willRegister = canManage && _registerNew ? registrable.length : 0;
    // Lines whose product is not there and will not be made now.
    final leftOut = [
      for (final l in unknown)
        if (willRegister == 0 || !registrable.contains(l)) l
    ];
    final problems = [
      for (final p in sheet?.problems ?? const <StockFileProblem>[])
        if (p.code != 'not_item') p
    ];
    final notItems = (sheet?.problems ?? const <StockFileProblem>[]).where((p) => p.code == 'not_item').length;
    final done = _done;

    // Where this order is on its way (0173): the file, its check and the
    // stock here; inspection, payment and its proof after — the order's own
    // steps once it is in.
    final order = done == null
        ? null
        : ref.watch(paymentsProvider(const OpenPayments())).valueOrNull?.where((p) => p.importId == done.importId).firstOrNull;
    final flow = order != null
        ? [for (final k in OrderStepKind.values) order.stepStates[k]!]
        : [
            if (done != null || sheet != null) OrderStepState.done else OrderStepState.todo,
            if (done != null || _checked) OrderStepState.done else OrderStepState.todo,
            if (done != null) OrderStepState.done else OrderStepState.todo,
            for (var i = 3; i < 8; i++) OrderStepState.todo,
          ];
    final flowAt = flow.indexWhere((x) => x != OrderStepState.done);

    final importTab = ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 96),
        children: [
          Text(l10n.sfIntro, style: muted),
          const SizedBox(height: AppSpacing.sm),
          Text(flowAt < 0 ? l10n.ordAllDone : l10n.ordNow(OrderFlowBar.labels(l10n)[flowAt]),
              key: const ValueKey('sf-flow-now'), style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          OrderFlowBar(states: flow, current: flowAt),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<int>(
            key: const ValueKey('sf-warehouse'),
            initialValue: whId,
            decoration: InputDecoration(labelText: l10n.sfWarehouse),
            items: [for (final w in warehouses) DropdownMenuItem(value: w.id, child: Text(w.name))],
            onChanged: (v) {
              setState(() => _warehouseId = v);
              // The current stock is the new warehouse's.
              _lookup();
            },
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<StockFileMode>(
            key: const ValueKey('sf-mode'),
            segments: [
              ButtonSegment(value: StockFileMode.add, icon: const Icon(Icons.add), label: Text(l10n.sfModeAdd)),
              ButtonSegment(
                  value: StockFileMode.set, icon: const Icon(Icons.edit_outlined), label: Text(l10n.sfModeSet)),
            ],
            selected: {_mode},
            onSelectionChanged: (v) => setState(() => _mode = v.first),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(_mode == StockFileMode.add ? l10n.sfModeAddHint : l10n.sfModeSetHint, style: muted),
          Text(_mode == StockFileMode.add ? l10n.sfAddInspection : l10n.sfSetNoInspection,
              key: const ValueKey('sf-inspection-hint'), style: muted),
          // Replacing the stock is the exception: said plainly, every time.
          if (_mode == StockFileMode.set)
            Card(
              key: const ValueKey('sf-set-warning'),
              color: theme.colorScheme.errorContainer,
              margin: const EdgeInsets.only(top: AppSpacing.sm),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, color: theme.colorScheme.onErrorContainer),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(l10n.sfSetWarning, style: TextStyle(color: theme.colorScheme.onErrorContainer))),
                ]),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
            FilledButton.icon(
              key: const ValueKey('sf-pick'),
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(l10n.sfPick),
            ),
            OutlinedButton.icon(
              key: const ValueKey('sf-template'),
              onPressed: () => ref.read(stockTemplateSaverProvider)('在庫登録_記入用.xlsx', stockTemplateXlsx()),
              icon: const Icon(Icons.download_outlined),
              label: Text(l10n.sfTemplate),
            ),
            // The file chosen, as it is, to look at beside what was read.
            if (_bytes case final b? when _fileName != null)
              OutlinedButton.icon(
                key: const ValueKey('sf-view-original'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: Text(_fileName!)),
                    body: OriginalFileView(fileName: _fileName!, bytes: b),
                  ),
                )),
                icon: const Icon(Icons.visibility_outlined),
                label: Text(l10n.sfViewOriginal),
              ),
            // Everything read at once, to check and correct outside: the 確認用Excel.
            if (sheet != null && sheet.header)
              OutlinedButton.icon(
                key: const ValueKey('sf-review-xlsx'),
                onPressed: _busy ? null : _downloadReview,
                icon: const Icon(Icons.download_outlined),
                label: Text(l10n.sfReviewXlsx),
              ),
          ]),
          if (sheet != null && sheet.header)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(l10n.sfReviewHint, style: muted),
            ),
          if (_busy)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const LinearProgressIndicator(),
                if (_aiReading) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(l10n.sfAiReading, key: const ValueKey('sf-ai-reading'), style: muted),
                ],
                if (_judgingHeadings) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(l10n.sfJudgingHeadings, key: const ValueKey('sf-judging-headings'), style: muted),
                ],
              ]),
            ),
          if (_error case final e?)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text(e, key: const ValueKey('sf-error'), style: TextStyle(color: theme.colorScheme.error)),
            ),
          if (_badFile)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text(l10n.sfBadFile,
                  key: const ValueKey('sf-bad-file'), style: TextStyle(color: theme.colorScheme.error)),
            ),
          if (done != null)
            Card(
              key: const ValueKey('sf-done'),
              color: theme.colorScheme.secondaryContainer,
              margin: const EdgeInsets.only(top: AppSpacing.md),
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ListTile(
                    leading: Icon(done.staged ? Icons.pending_actions_outlined : Icons.check_circle_outline),
                    title: Text(done.staged
                        ? l10n.sfStaged(done.importId, done.lines, done.awaiting ?? 0)
                        : l10n.sfDone(done.importId, done.lines, done.change)),
                    subtitle: done.skipped.isEmpty ? null : Text(l10n.sfSkipped(done.skipped.length)),
                  ),
                  if (done.staged)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xs),
                      child: FilledButton.tonalIcon(
                        key: const ValueKey('sf-go-inspect'),
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => StockInspectionScreen(openImportId: done.importId))),
                        icon: const Icon(Icons.fact_check_outlined, size: 18),
                        label: Text(l10n.sfGoInspect),
                      ),
                    ),
                  if (_namesNote case final n?)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xs),
                      child: Text(n, key: const ValueKey('sf-names-note')),
                    ),
                  // What the file said and what was made of it, side by side.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: ImportViewButtons(importId: done.importId),
                  ),
                  // What is left of this order — inspection, payment, its proof.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0),
                    child: Builder(
                      builder: (tabContext) => FilledButton.tonalIcon(
                        key: const ValueKey('sf-see-order'),
                        onPressed: () {
                          ref.read(focusedOrderProvider.notifier).state = done.importId;
                          DefaultTabController.of(tabContext).animateTo(1);
                        },
                        icon: const Icon(Icons.timeline, size: 18),
                        label: Text(l10n.sfSeeOrder),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          if (sheet != null && !sheet.header)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text(l10n.sfNoHeader,
                  key: const ValueKey('sf-no-header'), style: TextStyle(color: theme.colorScheme.error)),
            ),
          if (sheet != null && sheet.header) ...[
            const SizedBox(height: AppSpacing.md),
            Text(l10n.sfRead(_fileName ?? '', sheet.lines.length, sheet.lines.fold<int>(0, (s, l) => s + l.quantity)),
                key: const ValueKey('sf-read'), style: theme.textTheme.titleSmall),
            if (sheet.byAi)
              Card(
                key: const ValueKey('sf-ai'),
                color: theme.colorScheme.tertiaryContainer,
                margin: const EdgeInsets.only(top: AppSpacing.sm),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(children: [
                    Icon(Icons.auto_awesome_outlined, color: theme.colorScheme.onTertiaryContainer),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.sfAiRead(sheet.lines.where((l) => l.doubtful).length),
                        style: TextStyle(color: theme.colorScheme.onTertiaryContainer),
                      ),
                    ),
                  ]),
                ),
              ),
            // Headings the app did not know, and what the server took them
            // for (0163): each heading → its meaning, and who decided it.
            if (sheet.meanings.isNotEmpty) _HeadingMeanings(sheet: sheet),
            // The table: to check against the original, and to correct again.
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    (sheet.byAi && !_tableChecked ? FilledButton.icon : OutlinedButton.icon)(
                      key: const ValueKey('sf-open-table'),
                      onPressed: _busy ? null : _openTable,
                      icon: const Icon(Icons.table_chart_outlined, size: 18),
                      label: Text(l10n.sfOpenTable),
                    ),
                    if (_tableChecked)
                      Text(
                        l10n.sfTableChecked(
                          sheet.read.where((r) => r.flags.contains(humanCorrectedFlag) && !r.humanRemoved).length,
                          sheet.read.where((r) => r.humanRemoved).length,
                        ),
                        key: const ValueKey('sf-table-checked'),
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                      ),
                  ]),
            ),
            if (sheet.byAi && !_tableChecked)
              Card(
                key: const ValueKey('sf-table-needed'),
                color: theme.colorScheme.tertiaryContainer,
                margin: const EdgeInsets.only(top: AppSpacing.sm),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(l10n.sfTableNeeded, style: TextStyle(color: theme.colorScheme.onTertiaryContainer)),
                ),
              ),
          ],
          if (sheet != null && sheet.header && (!sheet.byAi || _tableChecked)) ...[
            if (sheet.read.any((r) => r.corrected))
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(l10n.sfCorrectedRows(sheet.read.where((r) => r.corrected).length),
                    key: const ValueKey('sf-corrected'), style: theme.textTheme.bodySmall),
              ),
            // Every line that will go in — those the library has, and the
            // new ones to be registered — with the arithmetic for each.
            const SizedBox(height: AppSpacing.md),
            Text(l10n.sfGoingIn(ready.length + willRegister),
                key: const ValueKey('sf-going-in'), style: theme.textTheme.titleSmall),
            // 商品名 and catalog pages: only once what was read is checked.
            if (!_checkCleared)
              Text(l10n.sfNamesAfterCheck, key: const ValueKey('sf-names-after-check'), style: muted)
            else if (_namesBusy)
              Text(l10n.sfNamesLooking(_namesDone, _namesTotal), key: const ValueKey('sf-names-looking'), style: muted)
            else if (_namesStopped)
              Text(l10n.plFindNamesStopped, key: const ValueKey('sf-names-stopped'), style: muted),
            // On a PC the lines as a table, field by field as in the check;
            // on a phone, as a list.
            LayoutBuilder(builder: (context, c) {
              final going = [...ready, if (willRegister > 0) ...registrable];
              if (c.maxWidth >= goingInTableWidth) {
                return _GoingInTable(
                  lines: going,
                  known: _known,
                  book: _book,
                  nameFor: _nameFor,
                  whereFound: (l) => _whereFound(l, l10n),
                  onHand: _onHand,
                  mode: _mode,
                  onTap: _busy ? null : _editLine,
                );
              }
              return Column(children: [
                for (final l in going)
                  ListTile(
                    key: ValueKey('sf-line-${l.janCode}'),
                    dense: true,
                    onTap: _busy ? null : () => _editLine(l),
                    leading: l.doubtful || implausibleQuantity(l.quantity)
                        ? Tooltip(
                            message: implausibleQuantity(l.quantity) ? l10n.sfImplausible : l10n.sfDoubtful,
                            child: Icon(Icons.help_outline,
                                key: ValueKey('sf-doubt-${l.janCode}'), color: theme.colorScheme.error),
                          )
                        : null,
                    // The product's own name: the file may write it otherwise,
                    // and the JAN alone decides whose stock it is.
                    title: Text(_nameFor(l) ?? '', key: ValueKey('sf-name-${l.janCode}')),
                    subtitle: Text([
                      l.janCode,
                      if ((l.code ?? '').isNotEmpty) l.code!,
                      if (!_known.containsKey(l.janCode)) l10n.sfNewProduct,
                      if (l.name case final n?
                          when n.trim() != (_known[l.janCode] ?? _book[l.janCode]?.$2 ?? '').trim())
                        l10n.sfFileName(n),
                      if (l.merged > 1) l10n.sfMerged(l.merged),
                      if (implausibleQuantity(l.quantity)) l10n.sfImplausible,
                    ].join(' · ')),
                    trailing: Text(
                      () {
                        final before = _onHand[l.janCode] ?? 0;
                        return _mode == StockFileMode.add
                            ? l10n.sfLineAdd(before, l.quantity, before + l.quantity)
                            : l10n.sfLineSet(before, l.quantity, _signedDiff(l.quantity - before));
                      }(),
                      key: ValueKey('sf-calc-${l.janCode}'),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
              ]);
            }),
            if (unknown.isNotEmpty)
              Card(
                key: const ValueKey('sf-unknown'),
                color: theme.colorScheme.errorContainer,
                margin: const EdgeInsets.only(top: AppSpacing.sm),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l10n.sfNotInLibrary(unknown.length), style: theme.textTheme.labelLarge),
                    // The whole file lands: products the library lacks are
                    // registered through 価格台帳 (under its name when it has
                    // the JAN, else the file's), then their stock goes in.
                    if (canManage && registrable.isNotEmpty)
                      CheckboxListTile(
                        key: const ValueKey('sf-register-new'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _registerNew,
                        onChanged: _busy
                            ? null
                            : (v) => setState(() {
                                  _registerNew = v ?? false;
                                  _checked = false;
                                }),
                        title: Text(l10n.sfRegisterNew(registrable.length)),
                        subtitle: Text(l10n.sfRegisterNewHint),
                      )
                    else if (!canManage)
                      Text(l10n.sfNeedManage, style: theme.textTheme.bodySmall),
                    TextButton.icon(
                      key: const ValueKey('sf-price-book'),
                      onPressed: () async {
                        await Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const PriceBookImportScreen()));
                        // Read into the price book meanwhile: look again.
                        if (mounted) await _lookup();
                      },
                      icon: const Icon(Icons.request_quote_outlined, size: 18),
                      label: Text(l10n.sfOpenPriceBook),
                    ),
                  ]),
                ),
              ),
            // Every row that will not go in, and why — none hidden.
            if (leftOut.isNotEmpty || problems.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(l10n.sfLeftOut(leftOut.length + problems.length),
                  key: const ValueKey('sf-left-out'), style: theme.textTheme.titleSmall),
              for (final p in problems)
                ListTile(
                  key: ValueKey('sf-problem-${p.lineNo}'),
                  dense: true,
                  leading: Icon(Icons.block, color: theme.colorScheme.error, size: 20),
                  title: Text(_problemText(l10n, p)),
                ),
              for (final l in leftOut)
                ListTile(
                  key: ValueKey('sf-out-${l.janCode}'),
                  dense: true,
                  leading: Icon(Icons.block, color: theme.colorScheme.error, size: 20),
                  title: Text([l.janCode, if (l.name != null) l.name!].join(' ')),
                  subtitle: Text(canManage && l.registerName == null && !_book.containsKey(l.janCode)
                      ? l10n.sfNoNameToRegister
                      : l10n.sfNotRegistering),
                ),
            ],
            if (notItems > 0)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(l10n.sfNotItems(notItems), key: const ValueKey('sf-not-items'), style: muted),
              ),
            const SizedBox(height: AppSpacing.md),
            // Kept with the import for seven years (0148): the date it is
            // filed under, whether the supplier is paid, and a memo.
            _NotesCard(
              date: _docDate,
              paid: _paid,
              note: _note,
              enabled: !_busy,
              onDate: (d) => setState(() => _docDate = d),
              onPaid: (v) => setState(() => _paid = v),
            ),
            const SizedBox(height: AppSpacing.md),
            // The last look: nothing goes in until the person says it is right.
            CheckboxListTile(
              key: const ValueKey('sf-checked'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _checked,
              onChanged: _busy ? null : (v) => setState(() => _checked = v ?? false),
              title: Text(l10n.sfCheckedTitle),
              subtitle: Text(l10n.sfCheckedHint),
            ),
            FilledButton.icon(
              key: const ValueKey('sf-apply'),
              onPressed: !canAdjust || _busy || !_checked || ready.length + willRegister == 0 || wh == null
                  ? null
                  : () => _apply(wh, register: willRegister > 0),
              icon: const Icon(Icons.inventory_outlined),
              label: Text(_mode == StockFileMode.add
                  ? l10n.sfApplyStage(ready.length + willRegister)
                  : l10n.sfApply(ready.length + willRegister)),
            ),
            if (!canAdjust) Text(l10n.sfNoPermission, style: muted),
          ],
        ],
      );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.featStockFileImport),
          actions: [
            IconButton(
              key: const ValueKey('sf-calendar'),
              tooltip: l10n.calTitle,
              icon: const Icon(Icons.calendar_month_outlined),
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StockImportCalendarScreen())),
            ),
            IconButton(
              key: const ValueKey('sf-history'),
              tooltip: l10n.sfHistory,
              icon: const Icon(Icons.history),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MasterImportsScreen())),
            ),
          ],
          bottom: TabBar(tabs: [
            Tab(key: const ValueKey('sf-tab-import'), text: l10n.sfTabImport),
            Tab(key: const ValueKey('sf-tab-orders'), text: l10n.ordTabProgress),
          ]),
        ),
        body: TabBarView(children: [importTab, const PaymentsScreen(embedded: true)]),
      ),
    );
  }
}

/// A line's quantity, or -1 to leave the line out. The dialog owns its field,
/// so the field lives exactly as long as the dialog does.
class _QtyDialog extends StatefulWidget {
  const _QtyDialog({required this.title, required this.line});

  final String title;
  final StockFileLine line;

  @override
  State<_QtyDialog> createState() => _QtyDialogState();
}

class _QtyDialogState extends State<_QtyDialog> {
  late final _c = TextEditingController(text: '${widget.line.quantity}');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('sf-edit-qty'),
        controller: _c,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: l10n.sfQty, helperText: widget.line.janCode),
      ),
      actions: [
        TextButton(
          key: const ValueKey('sf-edit-remove'),
          onPressed: () => Navigator.pop(context, -1),
          child: Text(l10n.sfRemoveLine),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('sf-edit-ok'),
          onPressed: () {
            final q = int.tryParse(_c.text.replaceAll(RegExp(r'[,\s]'), ''));
            if (q != null && q >= 0) Navigator.pop(context, q);
          },
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}

/// The date an import is filed under, whether the supplier is paid, and a
/// memo — before it goes in.
class _NotesCard extends StatelessWidget {
  const _NotesCard({
    required this.date,
    required this.paid,
    required this.note,
    required this.enabled,
    required this.onDate,
    required this.onPaid,
  });

  final DocumentDate? date;
  final bool paid;
  final TextEditingController note;
  final bool enabled;
  final ValueChanged<DocumentDate> onDate;
  final ValueChanged<bool> onPaid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final d = date;
    return Card(
      key: const ValueKey('sf-notes'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (d != null)
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: AppSpacing.sm, children: [
              Icon(Icons.event_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
              Text(l10n.sfDocDate(DateFormat('y/MM/dd').format(d.date), documentDateSourceLabel(l10n, d.source)),
                  key: const ValueKey('sf-doc-date')),
              TextButton(
                key: const ValueKey('sf-doc-date-change'),
                onPressed: !enabled
                    ? null
                    : () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: d.date,
                          firstDate: DateTime(2000),
                          lastDate: now.add(const Duration(days: 31)),
                        );
                        if (picked != null) onDate(DocumentDate(picked, DocumentDateSource.manual));
                      },
                child: Text(l10n.sfDocDateChange),
              ),
            ]),
          CheckboxListTile(
            key: const ValueKey('sf-paid'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: paid,
            onChanged: enabled ? (v) => onPaid(v ?? false) : null,
            title: Text(l10n.ivPaid),
          ),
          TextField(
            key: const ValueKey('sf-note'),
            controller: note,
            enabled: enabled,
            minLines: 1,
            maxLines: 4,
            maxLength: 4000,
            decoration: InputDecoration(labelText: l10n.ivNote, border: const OutlineInputBorder()),
          ),
        ]),
      ),
    );
  }
}

/// How an import's date was found, in words.
String documentDateSourceLabel(AppLocalizations l10n, DocumentDateSource? s) => switch (s) {
      DocumentDateSource.content => l10n.sfDateContent,
      DocumentDateSource.uploaded || null => l10n.sfDateUploaded,
      DocumentDateSource.manual => l10n.sfDateManual,
    };

/// From this width the lines going in are a table.
const double goingInTableWidth = 900;

/// 在庫に入れる行 as a table: the product, its JAN, maker and 品番 side by
/// side, then the stock now, the change and the stock after — the same
/// field-by-field layout as the check. A row opens its quantity.
class _GoingInTable extends StatefulWidget {
  const _GoingInTable({
    required this.lines,
    required this.known,
    required this.book,
    required this.onHand,
    required this.mode,
    required this.onTap,
    required this.nameFor,
    required this.whereFound,
  });

  final List<StockFileLine> lines;
  final Map<String, String> known;
  final Map<String, (int, String)> book;

  /// The 商品名 shown (blank when none is known), and where it was found.
  final String? Function(StockFileLine) nameFor;
  final ({String label, String url})? Function(StockFileLine) whereFound;
  final Map<String, int> onHand;
  final StockFileMode mode;
  final void Function(StockFileLine)? onTap;

  @override
  State<_GoingInTable> createState() => _GoingInTableState();
}

class _GoingInTableState extends State<_GoingInTable> {
  final _across = ScrollController();

  static const _widths = [32.0, 260.0, 140.0, 120.0, 150.0, 90.0, 90.0, 90.0, 260.0];

  @override
  void dispose() {
    _across.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final n = NumberFormat.decimalPattern();
    final head = theme.textTheme.labelMedium;
    String signed(int v) => v > 0 ? '+${n.format(v)}' : n.format(v);
    Widget cell(int i, Widget child, {bool end = false}) => Container(
          width: _widths[i],
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          alignment: end ? Alignment.centerRight : Alignment.centerLeft,
          child: child,
        );
    final headers = [
      '',
      l10n.sfColProduct,
      l10n.ntFieldJan,
      l10n.ntFieldMaker,
      l10n.ntFieldCode,
      l10n.sfColBefore,
      l10n.sfColChange,
      l10n.sfColAfter,
      l10n.sfColNote,
    ];
    return Scrollbar(
      controller: _across,
      thumbVisibility: true,
      child: SingleChildScrollView(
        key: const ValueKey('sf-going-table'),
        controller: _across,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            color: scheme.surfaceContainerHighest,
            child: Row(children: [
              for (final (i, h) in headers.indexed) cell(i, Text(h, style: head), end: i >= 5 && i <= 7),
            ]),
          ),
          for (final l in widget.lines)
            () {
              final before = widget.onHand[l.janCode] ?? 0;
              final add = widget.mode == StockFileMode.add;
              final change = add ? l.quantity : l.quantity - before;
              final after = add ? before + l.quantity : l.quantity;
              final big = implausibleQuantity(l.quantity);
              final name = widget.nameFor(l);
              final where = widget.whereFound(l);
              final notes = [
                if (!widget.known.containsKey(l.janCode)) l10n.sfNewProduct,
                if (l.name case final nm?
                    when nm.trim().isNotEmpty && nm.trim() != (name ?? '').trim() && nm.trim() != (l.code ?? '').trim())
                  l10n.sfFileName(nm),
                if (l.merged > 1) l10n.sfMerged(l.merged),
                if (big) l10n.sfImplausible,
              ];
              return InkWell(
                key: ValueKey('sf-line-${l.janCode}'),
                onTap: widget.onTap == null ? null : () => widget.onTap!(l),
                child: Container(
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
                  child: Row(children: [
                    cell(
                      0,
                      l.doubtful || big
                          ? Tooltip(
                              message: big ? l10n.sfImplausible : l10n.sfDoubtful,
                              child: Icon(Icons.help_outline,
                                  key: ValueKey('sf-doubt-${l.janCode}'), size: 18, color: scheme.error),
                            )
                          : const SizedBox.shrink(),
                    ),
                    // The 商品名 (blank when none is known), and the catalog
                    // page or web page it was found on.
                    cell(
                        1,
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name ?? '',
                              key: ValueKey('sf-name-${l.janCode}'), maxLines: 2, overflow: TextOverflow.ellipsis),
                          if (where != null)
                            InkWell(
                              key: ValueKey('sf-where-${l.janCode}'),
                              onTap: () => openExternalUrl(where.url),
                              child: Text(where.label,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.primary, decoration: TextDecoration.underline),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                        ])),
                    cell(2, Text(l.janCode, style: theme.textTheme.bodySmall)),
                    cell(3, Text(l.maker ?? '', maxLines: 1, overflow: TextOverflow.ellipsis)),
                    cell(4, Text(l.code ?? '', maxLines: 1, overflow: TextOverflow.ellipsis)),
                    cell(5, Text(n.format(before), key: ValueKey('sf-before-${l.janCode}')), end: true),
                    cell(6, Text(signed(change), key: ValueKey('sf-change-${l.janCode}')), end: true),
                    cell(
                      7,
                      Text(n.format(after),
                          key: ValueKey('sf-calc-${l.janCode}'),
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      end: true,
                    ),
                    cell(
                        8,
                        Text(notes.join(' · '),
                            style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              );
            }(),
        ]),
      ),
    );
  }
}

/// What the server took the unknown headings for (0163): 「商品名称」→ 品名
/// (AI). Headings a stock reading does not keep (規格, 入数) are named as
/// such, so nothing is silently dropped.
class _HeadingMeanings extends StatelessWidget {
  const _HeadingMeanings({required this.sheet});

  final StockSheet sheet;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    String field(String wire) => columnFieldLabel(l10n, ColumnField.values.where((f) => f.wire == wire).firstOrNull);
    String line(HeadingMeaning m) =>
        l10n.sfHeadingMeaning(m.header, field(m.field), columnSourceLabel(l10n, m.source));
    return Card(
      key: const ValueKey('sf-headings'),
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_awesome_outlined, size: 18),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: Text(l10n.sfHeadingsTitle, style: theme.textTheme.titleSmall)),
          ]),
          const SizedBox(height: AppSpacing.xs),
          for (final m in sheet.usedMeanings) Text(line(m), key: ValueKey('sf-heading-${m.index}')),
          for (final m in sheet.unusedMeanings)
            Text('${line(m)}　${l10n.sfHeadingUnused}', key: ValueKey('sf-heading-${m.index}'), style: muted),
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.sfHeadingsHint, style: muted),
        ]),
      ),
    );
  }
}
