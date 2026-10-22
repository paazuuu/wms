import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/open_window.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../master_import/data/master_import_repository.dart';
import '../../master_import/domain/master_import.dart';
import '../../auth/application/auth_controller.dart';
import '../../master_import/presentation/master_import_labels.dart';
import '../../product/application/product_providers.dart';
import '../data/stock_import_repository.dart';
import '../../notation/presentation/notation_labels.dart';
import '../../qc/domain/inspection.dart' show normalizeJan;
import '../domain/stock_file.dart';

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
}

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

  bool get doubtful => row.flags.any((f) => !const {'no_maker', 'human_corrected'}.contains(f.split(':').first));
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
          fate: ReadFate.inStock,
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
        return ReadOutcome(row: r, fate: ReadFate.inStock, line: line, fileQuantity: total != line.quantity ? total : null);
      }(),
  ];
}

/// 読み取り結果を見る, and on the web the same in a window of its own to keep
/// beside the app.
class ImportViewButtons extends StatelessWidget {
  const ImportViewButtons({super.key, required this.importId});

  final int importId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
      OutlinedButton.icon(
        key: ValueKey('iv-open-$importId'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ImportViewScreen(importId: importId))),
        icon: const Icon(Icons.compare_outlined, size: 18),
        label: Text(l10n.ivOpen),
      ),
      if (kIsWeb)
        TextButton.icon(
          key: ValueKey('iv-window-$importId'),
          onPressed: () {
            if (!openAppWindow('/import-view/$importId')) {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => ImportViewScreen(importId: importId)));
            }
          },
          icon: const Icon(Icons.open_in_new, size: 18),
          label: Text(l10n.ivWindow),
        ),
    ]);
  }
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
            else if (m.status == MasterImportStatus.stockDone &&
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
              Expanded(child: original),
              const VerticalDivider(width: 1),
              Expanded(child: read),
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
    final name = file.name.toLowerCase();
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
          data: (b) {
            if (const ['.png', '.jpg', '.jpeg', '.webp', '.gif'].any(name.endsWith)) {
              return InteractiveViewer(maxScale: 6, child: Image.memory(b, key: const ValueKey('iv-image')));
            }
            if (name.endsWith('.pdf')) return _PdfPages(bytes: b);
            if (readsLocally(file.name)) {
              try {
                return _SheetTable(rows: readStockFile(file.name, b));
              } on FormatException {
                // Falls through to the message below.
              }
            }
            return Center(child: Text(l10n.ivCannotShow, textAlign: TextAlign.center));
          },
        ),
      ),
    ]);
  }
}

/// A PDF's pages as pictures, one under the other, to zoom into.
class _PdfPages extends StatelessWidget {
  const _PdfPages({required this.bytes});

  final Uint8List bytes;

  Future<List<Uint8List>> _pages() async => [
        await for (final page in Printing.raster(bytes, dpi: 120)) await page.toPng(),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<List<Uint8List>>(
      future: _pages(),
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
    String signed(int v) => v > 0 ? '+${n.format(v)}' : n.format(v);
    String fate(ReadOutcome o) => switch (o.fate) {
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
        };
    return ListView(
      key: const ValueKey('iv-read'),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
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
                for (final f in o.row.flags.where((f) => f != 'human_corrected'))
                  Text('⚠ ${flagLabel(l10n, f)}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
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
                  fate(o),
                  key: ValueKey('iv-fate-${o.row.lineNo}'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: o.fate == ReadFate.inStock ? null : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}
