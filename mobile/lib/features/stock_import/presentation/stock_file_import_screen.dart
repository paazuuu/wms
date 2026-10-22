import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/export/save_bytes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../master_import/data/master_import_repository.dart';
import '../../master_import/presentation/master_imports_screen.dart';
import '../../price_book/application/price_book_providers.dart';
import '../../price_book/presentation/price_book_import_screen.dart';
import '../../product/application/product_providers.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../../warehouse_context/domain/warehouse.dart';
import '../data/stock_import_repository.dart';
import '../domain/stock_file.dart';

/// A chosen file: its name and bytes, or null when nothing was chosen.
typedef PickStockFile = Future<({String name, Uint8List bytes})?> Function();

Future<({String name, Uint8List bytes})?> _pickWithPicker() async {
  final r = await FilePicker.platform.pickFiles(
    withData: true,
    type: FileType.custom,
    allowedExtensions: const ['xlsx', 'xlsm', 'csv', 'tsv', 'txt'],
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
    });
    StockSheet sheet;
    try {
      sheet = parseStockRows(readStockFile(f.name, f.bytes));
    } on FormatException {
      setState(() {
        _busy = false;
        _badFile = true;
      });
      return;
    }
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

  /// The JANs 価格台帳 has, into 商品ライブラリー under the names they have
  /// there; then their stock can be added like the others.
  Future<void> _registerFromBook() async {
    final l10n = AppLocalizations.of(context);
    final ids = [for (final l in _unknown) if (_book[l.janCode] case (final id, _)) id];
    if (ids.isEmpty) return;
    setState(() => _busy = true);
    final r = await ref.read(priceBookRepositoryProvider).toProducts(ids);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        ref.invalidate(productListProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.sfRegistered(data.created + data.linked))));
        await _lookup();
      case ApiFailure(:final message):
        setState(() {
          _busy = false;
          _error = humanizeApiErrorMessage(l10n, message);
        });
    }
  }

  Future<void> _apply(Warehouse wh) async {
    final l10n = AppLocalizations.of(context);
    final lines = _ready;
    final units = lines.fold<int>(0, (s, l) => s + l.quantity);
    final before = lines.fold<int>(0, (s, l) => s + (_onHand[l.janCode] ?? 0));
    final after = _mode == StockFileMode.add ? before + units : units;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.sfConfirmQ(wh.name)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_mode == StockFileMode.add ? l10n.sfConfirmAdd(lines.length, units) : l10n.sfConfirmSet(lines.length)),
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
    final repo = ref.read(stockImportRepositoryProvider);
    final r = await repo.apply(wh.id, _mode, lines, fileName: _fileName, fileType: mimeTypeFor(_fileName ?? ''));
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        // The original goes with the import; a failure here does not undo
        // the stock, it only leaves the history without the file.
        if (_bytes != null && _fileName != null) {
          await repo.keepFile(data.importId, _fileName!, _bytes!, mimeTypeFor(_fileName!));
        }
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
    final inBook = [for (final l in unknown) if (_book.containsKey(l.janCode)) l];
    final canManage = ref.watch(authControllerProvider).user?.hasPermission('product.manage') ?? false;
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
          if (_busy) const Padding(padding: EdgeInsets.all(AppSpacing.md), child: LinearProgressIndicator()),
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
              child: ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(l10n.sfDone(done.importId, done.lines, done.change)),
                subtitle: done.skipped.isEmpty ? null : Text(l10n.sfSkipped(done.skipped.length)),
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
            if (sheet.problems.isNotEmpty)
              Card(
                key: const ValueKey('sf-problems'),
                margin: const EdgeInsets.only(top: AppSpacing.sm),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l10n.sfProblems(sheet.problems.length), style: theme.textTheme.labelLarge),
                    for (final p in sheet.problems.take(20)) Text(_problemText(l10n, p), style: theme.textTheme.bodySmall),
                  ]),
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
                    Text(l10n.sfUnknown(unknown.length), style: theme.textTheme.labelLarge),
                    Text(unknown.take(10).map((l) => l.name == null ? l.janCode : '${l.janCode} ${l.name}').join('、'),
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: AppSpacing.xs),
                    // Those 価格台帳 already has: into the library under the
                    // names they have there, then their stock adds up too.
                    if (inBook.isNotEmpty) ...[
                      Text(l10n.sfInPriceBook(inBook.length), style: theme.textTheme.bodySmall),
                      if (canManage)
                        FilledButton.tonalIcon(
                          key: const ValueKey('sf-register-book'),
                          onPressed: _busy ? null : _registerFromBook,
                          icon: const Icon(Icons.inventory_2_outlined, size: 18),
                          label: Text(l10n.sfRegisterFromBook(inBook.length)),
                        )
                      else
                        Text(l10n.sfNeedManage, style: theme.textTheme.bodySmall),
                    ],
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
            const SizedBox(height: AppSpacing.sm),
            for (final l in ready.take(100))
              ListTile(
                key: ValueKey('sf-line-${l.janCode}'),
                dense: true,
                // The product's own name: the file may write it otherwise,
                // and the JAN alone decides whose stock it is.
                title: Text(_known[l.janCode] ?? l.name ?? l.janCode),
                subtitle: Text([
                  l.janCode,
                  if (l.name case final n? when n.trim() != (_known[l.janCode] ?? '').trim()) l10n.sfFileName(n),
                  if (l.merged > 1) l10n.sfMerged(l.merged),
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
            if (ready.length > 100) Text(l10n.supMore(ready.length - 100), style: muted),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              key: const ValueKey('sf-apply'),
              onPressed: !canAdjust || _busy || ready.isEmpty || wh == null ? null : () => _apply(wh),
              icon: const Icon(Icons.inventory_outlined),
              label: Text(l10n.sfApply(ready.length)),
            ),
            if (!canAdjust) Text(l10n.sfNoPermission, style: muted),
          ],
        ],
      ),
    );
  }
}
