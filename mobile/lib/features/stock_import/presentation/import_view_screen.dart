import '../../payments/data/payments_repository.dart' show OpenPayments, paymentsProvider;
import '../../payments/presentation/payments_screen.dart' show PaymentCard;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/selectable_app.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../jan_catalog/data/jan_catalog_repository.dart';
import '../../master_import/data/master_import_repository.dart';
import '../../master_import/domain/master_import.dart';
import '../../auth/application/auth_controller.dart';
import '../../master_import/presentation/master_import_labels.dart';
import '../../product/application/product_providers.dart';
import '../data/stock_import_repository.dart';
import '../../notation/presentation/notation_labels.dart';
import '../../qc/domain/inspection.dart' show normalizeJan;
import '../domain/stock_file.dart';
import '../domain/stock_ledger.dart';
import 'reading_check_screen.dart';
import 'reading_export.dart';
import 'stock_file_import_screen.dart' show documentDateSourceLabel;
import 'stock_inspection_screen.dart' show keptUntilText;

/// One import with its lines, for the viewer.
final importDetailProvider = FutureProvider.autoDispose.family<MasterImport, int>((ref, id) async {
  final r = await ref.watch(masterImportRepositoryProvider).detail(id);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

/// A kept file's bytes.
final importFileBytesProvider = FutureProvider.autoDispose.family<Uint8List, String>((ref, path) async {
  final r = await ref.watch(masterImportRepositoryProvider).download(path);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

/// What became of one row of the file.
enum ReadFate {
  /// Its stock went in (to the product with this JAN).
  inStock,

  /// Its JAN came earlier in the file: added to that row's line.
  merged,

  /// No JAN could be read from it.
  noJan,

  /// No quantity could be read from it.
  badQuantity,

  /// 商品ライブラリー had no product with its JAN (and none was registered).
  notInLibrary,

  /// Left out by hand before the stock went in.
  removed,

  /// Kept for inspection, not in stock yet (0148).
  awaiting,
}

/// A row's ledger columns (0150) in one line: each one the file had, by name.
String ledgerSummary(AppLocalizations l10n, LedgerFields f) => [
      for (final (label, v) in [
        (l10n.lgOrderDate, f.orderDate),
        (l10n.lgDeliveryDate, f.deliveryDate),
        (l10n.lgSerial, f.serial),
        (l10n.lgSupplier, f.supplier),
        (l10n.lgUnit, f.unit),
        (l10n.lgListPrice, f.listPrice),
        (l10n.lgUnitPrice, f.unitPrice),
        (l10n.lgUnitPriceTax, f.unitPriceTax),
        (l10n.lgAmount, f.amount),
        (l10n.lgOrderNumber, f.orderNumber),
      ])
        if (v.isNotEmpty) '$label $v',
    ].join(' · ');

/// A row as read, beside what became of it.
class ReadOutcome {
  const ReadOutcome({required this.row, required this.fate, this.line, this.fileQuantity});

  final ReadRow row;
  final ReadFate fate;

  /// The line that went in, for [ReadFate.inStock].
  final MasterImportLine? line;

  /// The quantity the file gave this JAN in all its rows, when it differs
  /// from what went in (corrected by hand).
  final int? fileQuantity;

  bool get doubtful =>
      !row.humanChecked && row.flags.any((f) => f.split(':').first != 'no_maker' && !humanFlags.contains(f));
}

int? _qty(String raw) {
  final t = raw.replaceAll(RegExp(r'[,，\s]'), '');
  final d = double.tryParse(t);
  return int.tryParse(t) ?? (d != null && d == d.roundToDouble() ? d.toInt() : null);
}

/// Each row the file was read as, with what became of it — the reading set
/// beside the stock it moved. An import from before 0146 has no reading
/// kept; its lines stand for the rows.
List<ReadOutcome> readOutcomes(MasterImport m) {
  final byJan = {for (final l in m.lines) l.janCode: l};
  if (m.readLines.isEmpty) {
    return [
      for (final l in m.lines)
        ReadOutcome(
          row: ReadRow(lineNo: l.lineNo, jan: l.janCode, name: l.supplierName ?? '', quantity: '${l.quantity}'),
          fate: _waiting(m, l) ? ReadFate.awaiting : ReadFate.inStock,
          line: l,
        ),
    ];
  }
  final rows = [for (final r in m.readLines) ReadRow.fromJson(r)];
  final unknown = m.skippedJans;
  // What the file gave each JAN over all its rows.
  final fileTotals = <String, int>{};
  for (final r in rows) {
    final jan = normalizeJan(r.jan);
    final q = _qty(r.quantity);
    if (jan != null && q != null && q >= 0) fileTotals[jan] = (fileTotals[jan] ?? 0) + q;
  }
  final seen = <String>{};
  return [
    for (final r in rows)
      () {
        if (r.humanRemoved) return ReadOutcome(row: r, fate: ReadFate.removed);
        final jan = normalizeJan(r.jan);
        if (jan == null || jan.length < 8 || jan.length > 14) return ReadOutcome(row: r, fate: ReadFate.noJan);
        final q = _qty(r.quantity);
        if (q == null || q < 0) return ReadOutcome(row: r, fate: ReadFate.badQuantity);
        if (!seen.add(jan)) return ReadOutcome(row: r, fate: ReadFate.merged, line: byJan[jan]);
        final line = byJan[jan];
        if (line == null) {
          return ReadOutcome(row: r, fate: unknown.contains(jan) ? ReadFate.notInLibrary : ReadFate.removed);
        }
        final total = fileTotals[jan];
        return ReadOutcome(
            row: r,
            fate: _waiting(m, line) ? ReadFate.awaiting : ReadFate.inStock,
            line: line,
            fileQuantity: total != line.quantity ? total : null);
      }(),
  ];
}

/// A line kept for inspection and not checked in yet (0148).
bool _waiting(MasterImport m, MasterImportLine l) =>
    m.status == MasterImportStatus.awaitingInspection && m.undoneAt == null && !l.inspected;

/// What became of a row, in words.
String readFateText(AppLocalizations l10n, ReadOutcome o) {
  final n = NumberFormat.decimalPattern();
  String signed(int v) => v > 0 ? '+${n.format(v)}' : n.format(v);
  return switch (o.fate) {
    ReadFate.inStock => l10n.ivFateIn(
        o.line?.name ?? o.line?.janCode ?? '',
        n.format(o.line?.onHandBefore ?? 0),
        n.format(o.line?.onHandAfter ?? 0),
        signed(o.line?.added ?? 0)),
    ReadFate.merged => l10n.ivFateMerged,
    ReadFate.noJan => l10n.ivFateNoJan,
    ReadFate.badQuantity => l10n.ivFateBadQty,
    ReadFate.notInLibrary => l10n.ivFateNotInLibrary,
    ReadFate.removed => l10n.ivFateRemoved,
    ReadFate.awaiting => l10n.ivFateAwaiting(o.line?.name ?? o.line?.janCode ?? '', n.format(o.line?.quantity ?? 0)),
  };
}

/// 読み取り結果を見る; the reading as a sheet in a browser tab of its own
/// (not the app again); and the same as an Excel file.
class ImportViewButtons extends ConsumerWidget {
  const ImportViewButtons({super.key, required this.importId, this.known});

  final int importId;

  /// The import, when it is already loaded.
  final MasterImport? known;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
      // 読み取り結果を見る: the same table as when it was read and checked,
      // beside the original (0165); the import's details from there.
      if (known == null)
        OutlinedButton.icon(
          key: ValueKey('iv-open-$importId'),
          onPressed: () => openReadingTable(context, ref, importId),
          icon: const Icon(Icons.compare_outlined, size: 18),
          label: Text(l10n.ivOpen),
        ),
      if (kIsWeb)
        TextButton.icon(
          key: ValueKey('iv-tab-$importId'),
          onPressed: () => openReadingTab(context, ref, importId, known: known),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: Text(l10n.ivOpenTab),
        ),
      TextButton.icon(
        key: ValueKey('iv-xlsx-$importId'),
        onPressed: () => downloadReading(context, ref, importId, known: known),
        icon: const Icon(Icons.table_view_outlined, size: 18),
        label: Text(l10n.ivDownloadXlsx),
      ),
    ]);
  }
}

/// The reading as it was checked when it came in: the same table, beside
/// the original, read only — the catalog and weight columns as they stand,
/// and what became of each row (反映). The import's details (memo, paid,
/// undo) one tap away.
Future<void> openReadingTable(BuildContext context, WidgetRef ref, int importId, {MasterImport? known}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  MasterImport m;
  try {
    m = known ?? await ref.read(importDetailProvider(importId).future);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, '$e'))));
    return;
  }
  final file = m.files.where((f) => f.kind == 'original').firstOrNull;
  Uint8List? bytes;
  if (file != null) {
    try {
      bytes = await ref.read(importFileBytesProvider(file.path).future);
    } catch (_) {
      bytes = null;
    }
  }
  if (!context.mounted) return;
  final outcomes = readOutcomes(m);
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (c) => ReadingCheckScreen(
      rows: [for (final o in outcomes) o.row],
      fileName: file?.name ?? m.originalName,
      bytes: bytes,
      readOnly: true,
      catalogLookup: (jans) => lookupJans(ref.read(janCatalogRepositoryProvider), jans),
      results: {for (final o in outcomes) o.row.lineNo: readFateText(l10n, o)},
      actions: [
        if (known == null)
          TextButton.icon(
            key: ValueKey('iv-details-$importId'),
            onPressed: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => ImportViewScreen(importId: importId))),
            icon: const Icon(Icons.info_outline, size: 18),
            label: Text(l10n.ivDetails),
          ),
      ],
    ),
  ));
}

/// 読み取り結果 (0146): a file that changed stock, opened beside what was made
/// of it. On the left the original as it is — the PDF's pages, the picture,
/// the sheet's cells with their row numbers; on the right every row as it was
/// read (by the AI or cell by cell), what the reader was unsure of, and what
/// became of it: the product it went to with the stock before and after, the
/// quantity corrected by hand, or why it was left out.
class ImportViewScreen extends ConsumerWidget {
  const ImportViewScreen({super.key, required this.importId});

  final int importId;

  /// Takes the import back after asking: each line's change the other way.
  Future<void> _undo(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.ivUndoQ(importId)),
        content: Text(l10n.ivUndoBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l10n.actionCancel)),
          FilledButton(key: const ValueKey('iv-undo-ok'), onPressed: () => Navigator.pop(d, true), child: Text(l10n.ivUndo)),
        ],
      ),
    );
    if (ok != true) return;
    final r = await ref.read(stockImportRepositoryProvider).undo(importId);
    switch (r) {
      case ApiSuccess():
        ref.invalidate(importDetailProvider(importId));
        ref.invalidate(masterImportsProvider);
        ref.invalidate(productListProvider);
        ref.invalidate(pendingInspectionProvider);
        ref.invalidate(awaitingImportsProvider);
        messenger.showSnackBar(SnackBar(content: Text(l10n.ivUndoDone(importId))));
      case ApiFailure(:final message):
        messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(importDetailProvider(importId));
    return Scaffold(
      appBar: AppBar(
        title: Text(async.valueOrNull?.originalName ?? l10n.ivTitle(importId)),
        actions: [
          if (async.valueOrNull case final m? when m.source == 'stock_file')
            if (m.undoneAt != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Center(child: Text(l10n.ivUndone, key: const ValueKey('iv-undone'))),
              )
            else if ((m.status == MasterImportStatus.stockDone || m.status == MasterImportStatus.awaitingInspection) &&
                (ref.watch(authControllerProvider).user?.hasPermission('inventory.adjust') ?? false))
              TextButton.icon(
                key: const ValueKey('iv-undo'),
                onPressed: () => _undo(context, ref),
                icon: const Icon(Icons.undo),
                label: Text(l10n.ivUndo),
              ),
        ],
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: humanizeApiErrorMessage(l10n, '$e'),
          onRetry: () => ref.invalidate(importDetailProvider(importId)),
        ),
        data: (m) => LayoutBuilder(builder: (context, c) {
          final original = _OriginalPane(import: m);
          final read = _ReadPane(import: m);
          if (c.maxWidth >= 1000) {
            return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Each side selected on its own: see [SelectablePane].
              Expanded(child: SelectablePane(child: original)),
              const VerticalDivider(width: 1),
              Expanded(child: SelectablePane(child: read)),
            ]);
          }
          return DefaultTabController(
            length: 2,
            child: Column(children: [
              TabBar(tabs: [
                Tab(key: const ValueKey('iv-tab-original'), text: l10n.ivOriginal),
                Tab(key: const ValueKey('iv-tab-read'), text: l10n.ivRead),
              ]),
              Expanded(child: TabBarView(children: [original, read])),
            ]),
          );
        }),
      ),
    );
  }
}

class _OriginalPane extends ConsumerWidget {
  const _OriginalPane({required this.import});

  final MasterImport import;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final file = import.files.where((f) => f.kind == 'original').firstOrNull;
    if (file == null) {
      return Center(child: Text(l10n.ivNoOriginal, style: theme.textTheme.bodyMedium));
    }
    final bytes = ref.watch(importFileBytesProvider(file.path));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(children: [
          Expanded(child: Text(l10n.ivOriginal, style: theme.textTheme.titleSmall)),
          OutlinedButton.icon(
            key: const ValueKey('iv-save-original'),
            onPressed: () => downloadMasterFile(context, ref, file),
            icon: const Icon(Icons.download_outlined, size: 18),
            label: Text(l10n.ivSave),
          ),
        ]),
      ),
      Expanded(
        child: bytes.when(
          loading: () => LoadingView(message: l10n.loading),
          error: (e, _) => ErrorStateView(
            message: humanizeApiErrorMessage(l10n, '$e'),
            onRetry: () => ref.invalidate(importFileBytesProvider(file.path)),
          ),
          data: (b) => OriginalFileView(fileName: file.name, bytes: b),
        ),
      ),
    ]);
  }
}

/// A file as it is, to set a reading beside: a picture or a PDF's pages to
/// zoom into, a sheet's cells, else a word that it cannot be shown.
class OriginalFileView extends StatelessWidget {
  const OriginalFileView({super.key, required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = fileName.toLowerCase();
    if (const ['.png', '.jpg', '.jpeg', '.webp', '.gif'].any(name.endsWith)) {
      return InteractiveViewer(maxScale: 6, child: Image.memory(bytes, key: const ValueKey('iv-image')));
    }
    if (name.endsWith('.pdf')) return _PdfPages(bytes: bytes);
    if (readsLocally(fileName)) {
      try {
        return _SheetTable(rows: readStockFile(fileName, bytes));
      } on FormatException {
        // Falls through to the message below.
      }
    }
    return Center(child: Text(l10n.ivCannotShow, textAlign: TextAlign.center));
  }
}

/// A PDF's pages as pictures, one under the other, to zoom into. Drawn once:
/// whatever is rebuilt beside it (a table being typed into) does not draw
/// them again.
class _PdfPages extends StatefulWidget {
  const _PdfPages({required this.bytes});

  final Uint8List bytes;

  @override
  State<_PdfPages> createState() => _PdfPagesState();
}

class _PdfPagesState extends State<_PdfPages> {
  late Future<List<Uint8List>> _pages = _draw();

  // From a copy: in a browser the PDF reader takes the bytes it is given
  // for its own, and the file kept here would be empty the next time.
  Future<List<Uint8List>> _draw() async => [
        await for (final page in Printing.raster(Uint8List.fromList(widget.bytes), dpi: 120)) await page.toPng(),
      ];

  @override
  void didUpdateWidget(_PdfPages old) {
    super.didUpdateWidget(old);
    if (!identical(old.bytes, widget.bytes)) _pages = _draw();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<List<Uint8List>>(
      future: _pages,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text(l10n.ivCannotShow, textAlign: TextAlign.center));
        final pages = snap.data;
        if (pages == null) return LoadingView(message: l10n.loading);
        return InteractiveViewer(
          maxScale: 5,
          constrained: false,
          child: SizedBox(
            width: 900,
            child: Column(key: const ValueKey('iv-pdf'), children: [
              for (final p in pages)
                Padding(padding: const EdgeInsets.only(bottom: AppSpacing.md), child: Image.memory(p)),
            ]),
          ),
        );
      },
    );
  }
}

/// A sheet's cells as they are, with the row numbers the reading refers to.
class _SheetTable extends StatelessWidget {
  const _SheetTable({required this.rows});

  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cols = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    final shown = rows.take(500).toList();
    return SingleChildScrollView(
      key: const ValueKey('iv-sheet'),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(color: theme.colorScheme.outlineVariant),
          children: [
            for (var i = 0; i < shown.length; i++)
              TableRow(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text('${i + 1}', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ),
                for (var c = 0; c < cols; c++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(c < shown[i].length ? shown[i][c] : '', style: theme.textTheme.bodySmall),
                  ),
              ]),
          ],
        ),
      ),
    );
  }
}

class _ReadPane extends StatelessWidget {
  const _ReadPane({required this.import});

  final MasterImport import;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final m = import;
    final outcomes = readOutcomes(m);
    final into = outcomes.where((o) => o.fate == ReadFate.inStock).length;
    final out = outcomes.where((o) => o.fate != ReadFate.inStock && o.fate != ReadFate.merged).length;
    final doubts = outcomes.where((o) => o.doubtful).length;
    final n = NumberFormat.decimalPattern();
    final waiting = outcomes.where((o) => o.fate == ReadFate.awaiting).length;
    return ListView(
      key: const ValueKey('iv-read'),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (m.source == 'stock_file') ...[
          // The order's 8 steps (0173): where it is, and what is left.
          _OrderProgress(importId: m.id),
          _NotesPanel(import: m),
          const SizedBox(height: AppSpacing.sm),
        ],
        ImportViewButtons(importId: m.id, known: m),
        // Looked back at as it was checked: the table beside the original.
        if (outcomes.isNotEmpty)
          Consumer(
            builder: (context, ref, _) => Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: ValueKey('iv-table-${m.id}'),
                onPressed: () => openReadingTable(context, ref, m.id, known: m),
                icon: const Icon(Icons.table_chart_outlined, size: 18),
                label: Text(l10n.ivTable),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.ivRead, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          [
            switch (m.readBy) { 'ai' => l10n.ivByAi, 'sheet' => l10n.ivBySheet, _ => l10n.ivByOld },
            if (m.createdAt != null) DateFormat('y/MM/dd HH:mm').format(m.createdAt!),
            if (m.warehouseName != null) m.warehouseName!,
          ].join(' · '),
          style: muted,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
          Chip(key: const ValueKey('iv-count-rows'), label: Text(l10n.ivRows(outcomes.length))),
          Chip(key: const ValueKey('iv-count-in'), label: Text(l10n.ivIn(into))),
          Chip(key: const ValueKey('iv-count-out'), label: Text(l10n.ivOut(out))),
          if (doubts > 0) Chip(key: const ValueKey('iv-count-doubt'), label: Text(l10n.ivDoubts(doubts))),
          if (waiting > 0) Chip(key: const ValueKey('iv-count-awaiting'), label: Text(l10n.ivAwaitingCount(waiting))),
        ]),
        const SizedBox(height: AppSpacing.sm),
        for (final o in outcomes)
          Card(
            key: ValueKey('iv-row-${o.row.lineNo}'),
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(l10n.miLine(o.row.lineNo), style: theme.textTheme.labelLarge),
                  const SizedBox(width: AppSpacing.sm),
                  if (o.doubtful) Icon(Icons.help_outline, size: 18, color: theme.colorScheme.error),
                ]),
                // What the file says, as it says it.
                Text(
                  l10n.ivAsRead(
                    o.row.jan.isEmpty ? '—' : o.row.jan,
                    o.row.name.isEmpty ? '—' : o.row.name,
                    o.row.quantity.isEmpty ? '—' : o.row.quantity,
                  ),
                  key: ValueKey('iv-asread-${o.row.lineNo}'),
                  style: theme.textTheme.bodyMedium,
                ),
                if (o.row.maker.isNotEmpty || o.row.code.isNotEmpty)
                  Text([o.row.maker, o.row.code].where((v) => v.isNotEmpty).join(' · '), style: muted),
                if (!o.row.ledger.isEmpty)
                  Text(ledgerSummary(l10n, o.row.ledger), key: ValueKey('iv-ledger-${o.row.lineNo}'), style: muted),
                for (final f in o.row.flags.where((f) => !humanFlags.contains(f)))
                  Text('⚠ ${flagLabel(l10n, f)}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                if (o.row.humanChecked)
                  Text('✓ ${l10n.rcCheckedMark}', key: ValueKey('iv-checked-${o.row.lineNo}'),
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
                if (o.row.corrected)
                  Text(
                    l10n.ivCorrected(o.row.aiJan ?? '—', o.row.jan, o.row.aiQuantity ?? '—', o.row.quantity),
                    key: ValueKey('iv-corrected-${o.row.lineNo}'),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.tertiary),
                  ),
                if (o.fileQuantity case final q?)
                  Text(l10n.ivEdited(n.format(q), n.format(o.line?.quantity ?? 0)),
                      key: ValueKey('iv-edited-${o.row.lineNo}'), style: theme.textTheme.bodySmall),
                const SizedBox(height: 2),
                // What became of it.
                Text(
                  readFateText(l10n, o),
                  key: ValueKey('iv-fate-${o.row.lineNo}'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: o.fate == ReadFate.inStock
                        ? null
                        : o.fate == ReadFate.awaiting
                            ? theme.colorScheme.tertiary
                            : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}

/// The import's date, whether the supplier is paid, and the memo (0148) —
/// changeable here at any time by whoever may adjust stock.
/// This import as an order: its steps, upload to the transfer's proof, with
/// the payment's own (shown to those who see the books).
class _OrderProgress extends ConsumerWidget {
  const _OrderProgress({required this.importId});

  final int importId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order =
        ref.watch(paymentsProvider(const OpenPayments())).valueOrNull?.where((p) => p.importId == importId).firstOrNull;
    if (order == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PaymentCard(key: ValueKey('iv-order-$importId'), payment: order, initiallyOpen: true),
    );
  }
}

class _NotesPanel extends ConsumerStatefulWidget {
  const _NotesPanel({required this.import});

  final MasterImport import;

  @override
  ConsumerState<_NotesPanel> createState() => _NotesPanelState();
}

class _NotesPanelState extends ConsumerState<_NotesPanel> {
  late final TextEditingController _note = TextEditingController(text: widget.import.note ?? '');
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // The save button follows what is typed.
    _note.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save({DocumentDate? date, bool? paid, String? note}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final r = await ref.read(stockImportRepositoryProvider).updateNotes(widget.import.id, date: date, paid: paid, note: note);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess():
        ref.invalidate(importDetailProvider(widget.import.id));
        ref.invalidate(masterImportsProvider);
        messenger.showSnackBar(SnackBar(content: Text(l10n.ivSaved)));
      case ApiFailure(:final message):
        messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = widget.import;
    final may = ref.watch(authControllerProvider).user?.hasPermission('inventory.adjust') ?? false;
    final filed = m.filedOn;
    final fmt = DateFormat('y/MM/dd');
    return Card(
      key: const ValueKey('iv-notes'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (m.status == MasterImportStatus.awaitingInspection && m.undoneAt == null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(l10n.ivAwaiting, key: const ValueKey('iv-awaiting'),
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.tertiary)),
            ),
          if (filed != null)
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: AppSpacing.sm, children: [
              Icon(Icons.event_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
              Text(
                l10n.sfDocDate(fmt.format(filed), documentDateSourceLabel(l10n, DocumentDateSource.fromWire(m.documentDateSource))),
                key: const ValueKey('iv-doc-date'),
              ),
              if (may)
                TextButton(
                  key: const ValueKey('iv-doc-date-change'),
                  onPressed: _busy
                      ? null
                      : () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: filed,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now().add(const Duration(days: 31)),
                          );
                          if (picked != null) await _save(date: DocumentDate(picked, DocumentDateSource.manual));
                        },
                  child: Text(l10n.sfDocDateChange),
                ),
              Text(keptUntilText(l10n, filed), key: const ValueKey('iv-kept'), style: theme.textTheme.bodySmall),
            ]),
          CheckboxListTile(
            key: const ValueKey('iv-paid'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: m.paid,
            onChanged: !may || _busy ? null : (v) => _save(paid: v ?? false),
            title: Text(l10n.ivPaid),
            subtitle: m.paid && m.paidAt != null ? Text(l10n.ivPaidAt(DateFormat('y/MM/dd HH:mm').format(m.paidAt!))) : null,
          ),
          TextField(
            key: const ValueKey('iv-note'),
            controller: _note,
            enabled: may && !_busy,
            minLines: 1,
            maxLines: 6,
            maxLength: 4000,
            decoration: InputDecoration(labelText: l10n.ivNote, border: const OutlineInputBorder()),
          ),
          if (may)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                key: const ValueKey('iv-note-save'),
                onPressed: _busy || _note.text.trim() == (m.note ?? '').trim() ? null : () => _save(note: _note.text.trim()),
                child: Text(l10n.ivNoteSave),
              ),
            ),
        ]),
      ),
    );
  }
}
