import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/export/save_bytes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../master_import/data/master_import_repository.dart';
import '../../master_import/domain/master_import.dart';
import '../../master_import/presentation/master_import_labels.dart';
import '../../master_import/presentation/master_imports_screen.dart';
import '../../notation/presentation/notation_labels.dart';
import '../../price_book/application/price_book_providers.dart';
import '../../price_book/presentation/price_book_import_screen.dart';
import '../../product/application/product_providers.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../../warehouse_context/domain/warehouse.dart';
import '../data/stock_import_repository.dart';
import 'import_view_screen.dart';
import '../domain/stock_file.dart';

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

  /// The kept copy import-plan made of a file the AI read (0132).
  int? _documentId;

  /// Products the file has that 商品ライブラリー does not: registered
  /// (through 価格台帳) before the stock goes in, so the whole file lands.
  bool _registerNew = true;

  /// The person has looked the reading over and says it is right: nothing
  /// goes in before. Cleared by a new file and by any change to a line.
  bool _checked = false;
  StockFileResult? _done;
  String? _error;

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
      _error = null;
      _badFile = false;
      _fileName = f.name;
      _bytes = f.bytes;
      _sheet = null;
      _known = const {};
      _documentId = null;
      _checked = false;
    });
    StockSheet? sheet;
    if (readsLocally(f.name)) {
      try {
        sheet = parseStockRows(readStockFile(f.name, f.bytes));
      } on FormatException {
        sheet = null;
      }
    }
    // A PDF, a scan, a photo, an old .xls — or a sheet whose headings were
    // not found: the AI reads it (import-plan, nothing booked), and every
    // line it gives is to be checked here before it goes in.
    if (sheet == null || !sheet.header) {
      setState(() => _aiReading = true);
      final r = await ref.read(masterImportRepositoryProvider).read(f.name, f.bytes);
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
    setState(() => _sheet = sheet);
    await _lookup();
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
    final missing = [for (final j in jans) if (!k.containsKey(j)) j];
    final wh = _whId;
    final onHand = wh == null ? null : await repo.onHand(wh, [for (final j in jans) if (k.containsKey(j)) j]);
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
  List<StockFileLine> get _registrable =>
      [for (final l in _unknown) if (_book.containsKey(l.janCode) || (l.name ?? '').trim().isNotEmpty) l];

  /// The file's products 商品ライブラリー lacks, registered through 価格台帳:
  /// those it has go in under its names; the rest are read into it first
  /// (JAN, name, maker, 品番 as the file has them), then registered. Their
  /// stock then goes in with the others. False when it failed (and said so).
  Future<bool> _registerUnknown() async {
    final l10n = AppLocalizations.of(context);
    final book = ref.read(priceBookRepositoryProvider);
    final todo = _registrable;
    final ids = [for (final l in todo) if (_book[l.janCode] case (final id, _)) id];
    final fresh = [for (final l in todo) if (!_book.containsKey(l.janCode)) l];
    if (fresh.isNotEmpty) {
      final r = await book.import([for (final l in fresh) l.toPriceBookLine()], sourceFile: _fileName);
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
        return true;
      case ApiFailure(:final message):
        setState(() => _error = humanizeApiErrorMessage(l10n, message));
        return false;
    }
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
          FilledButton(key: const ValueKey('sf-confirm'), onPressed: () => Navigator.pop(d, true), child: Text(l10n.sfApplyShort)),
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
    final r = await repo.apply(wh.id, _mode, send, fileName: _fileName, fileType: mimeTypeFor(_fileName ?? ''));
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
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
        if (!mounted) return;
        ref.invalidate(productListProvider);
        ref.invalidate(masterImportsProvider);
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
              l10n.sfDuplicateLine(f.importId, fmt.format(f.at), f.fileName ?? '', f.sameFile ? l10n.sfSameFile : l10n.sfSameLines),
              key: ValueKey('sf-dup-${f.importId}'),
              style: Theme.of(d).textTheme.bodySmall,
            ),
        ]),
        actions: [
          FilledButton(key: const ValueKey('sf-dup-cancel'), onPressed: () => Navigator.pop(d, false), child: Text(l10n.actionCancel)),
          TextButton(key: const ValueKey('sf-dup-go'), onPressed: () => Navigator.pop(d, true), child: Text(l10n.sfDuplicateGo)),
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
    final leftOut = [for (final l in unknown) if (willRegister == 0 || !registrable.contains(l)) l];
    final problems = [for (final p in sheet?.problems ?? const <StockFileProblem>[]) if (p.code != 'not_item') p];
    final notItems = (sheet?.problems ?? const <StockFileProblem>[]).where((p) => p.code == 'not_item').length;
    final done = _done;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.featStockFileImport),
        actions: [
          IconButton(
            key: const ValueKey('sf-history'),
            tooltip: l10n.sfHistory,
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MasterImportsScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 96),
        children: [
          Text(l10n.sfIntro, style: muted),
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
              ButtonSegment(value: StockFileMode.set, icon: const Icon(Icons.edit_outlined), label: Text(l10n.sfModeSet)),
            ],
            selected: {_mode},
            onSelectionChanged: (v) => setState(() => _mode = v.first),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(_mode == StockFileMode.add ? l10n.sfModeAddHint : l10n.sfModeSetHint, style: muted),
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
          ]),
          if (_busy)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const LinearProgressIndicator(),
                if (_aiReading) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(l10n.sfAiReading, key: const ValueKey('sf-ai-reading'), style: muted),
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
              child: Text(l10n.sfBadFile, key: const ValueKey('sf-bad-file'), style: TextStyle(color: theme.colorScheme.error)),
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
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(l10n.sfDone(done.importId, done.lines, done.change)),
                    subtitle: done.skipped.isEmpty ? null : Text(l10n.sfSkipped(done.skipped.length)),
                  ),
                  // What the file said and what was made of it, side by side.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: ImportViewButtons(importId: done.importId),
                  ),
                ]),
              ),
            ),
          if (sheet != null && !sheet.header)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text(l10n.sfNoHeader, key: const ValueKey('sf-no-header'), style: TextStyle(color: theme.colorScheme.error)),
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
            // Everything at once, to check and correct outside: the 確認用Excel.
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                OutlinedButton.icon(
                  key: const ValueKey('sf-review-xlsx'),
                  onPressed: _busy ? null : _downloadReview,
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: Text(l10n.sfReviewXlsx),
                ),
                Text(l10n.sfReviewHint, style: muted),
              ]),
            ),
            if (sheet.read.any((r) => r.corrected))
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(l10n.sfCorrectedRows(sheet.read.where((r) => r.corrected).length),
                    key: const ValueKey('sf-corrected'), style: theme.textTheme.bodySmall),
              ),
            // Every line that will go in — those the library has, and the
            // new ones to be registered — with the arithmetic for each.
            const SizedBox(height: AppSpacing.md),
            Text(l10n.sfGoingIn(ready.length + willRegister), key: const ValueKey('sf-going-in'), style: theme.textTheme.titleSmall),
            for (final l in [...ready, if (willRegister > 0) ...registrable])
              ListTile(
                key: ValueKey('sf-line-${l.janCode}'),
                dense: true,
                onTap: _busy ? null : () => _editLine(l),
                leading: l.doubtful || implausibleQuantity(l.quantity)
                    ? Tooltip(
                        message: implausibleQuantity(l.quantity) ? l10n.sfImplausible : l10n.sfDoubtful,
                        child: Icon(Icons.help_outline, key: ValueKey('sf-doubt-${l.janCode}'), color: theme.colorScheme.error),
                      )
                    : null,
                // The product's own name: the file may write it otherwise,
                // and the JAN alone decides whose stock it is.
                title: Text(_known[l.janCode] ?? _book[l.janCode]?.$2 ?? l.name ?? l.janCode),
                subtitle: Text([
                  l.janCode,
                  if (!_known.containsKey(l.janCode)) l10n.sfNewProduct,
                  if (l.name case final n? when n.trim() != (_known[l.janCode] ?? _book[l.janCode]?.$2 ?? '').trim())
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
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PriceBookImportScreen()));
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
              Text(l10n.sfLeftOut(leftOut.length + problems.length), key: const ValueKey('sf-left-out'), style: theme.textTheme.titleSmall),
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
                  subtitle: Text(canManage && (l.name ?? '').trim().isEmpty && !_book.containsKey(l.janCode)
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
              label: Text(l10n.sfApply(ready.length + willRegister)),
            ),
            if (!canAdjust) Text(l10n.sfNoPermission, style: muted),
          ],
        ],
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
