import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/export/html_sheet.dart';
import '../../../core/export/xlsx.dart';
import '../../../core/ui/open_window.dart';
import '../../../l10n/app_localizations.dart';
import '../../master_import/data/master_import_repository.dart';
import '../../master_import/domain/master_import.dart';
import '../../master_import/presentation/master_import_labels.dart';
import '../../notation/presentation/notation_labels.dart';
import '../domain/stock_file.dart' show humanFlags;
import '../domain/stock_ledger.dart';
import 'import_view_screen.dart';
import 'stock_file_import_screen.dart' show documentDateSourceLabel, stockTemplateSaverProvider;

/// A reading laid out as a sheet: what the import is above, then every row
/// of the file as read beside what became of it.
class ReadingTable {
  const ReadingTable({required this.title, required this.top, required this.headers, required this.rows, required this.flagged});

  final String title;
  final List<List<Object?>> top;
  final List<String> headers;
  final List<List<Object?>> rows;
  final Set<(int, int)> flagged;
}

/// A purchase ledger's (明細) columns first, in its order (0150), then what
/// became of each row.
const _headers = [
  '行', '発注日', '入荷日', '番号', '仕入先', 'メーカー', '品番', 'JANコード', '商品名', '数量', '単位',
  '定価（税抜）', '単価（税抜）', '単価（税込）', '金額', '注番',
  'AIの迷い', '確認用Excelで直した', '結果', '商品', '反映前', '増減', '反映後', '検品',
];

/// Where the JAN, the quantity and the result are among [_headers].
const _janCol = 7, _qtyCol = 9, _resultCol = 18;

/// [m]'s reading as rows (0146 kept it; 0148 adds the inspection). The
/// file's own JAN and quantity stay as text, as they were written.
ReadingTable readingTable(AppLocalizations l10n, MasterImport m) {
  final fmt = DateFormat('y/MM/dd');
  final at = DateFormat('y/MM/dd HH:mm');
  final rows = <List<Object?>>[];
  final flagged = <(int, int)>{};
  for (final o in readOutcomes(m)) {
    final i = rows.length;
    final doubts = [for (final f in o.row.flags) if (!humanFlags.contains(f)) flagLabel(l10n, f)].join('、');
    final l = o.line;
    final g = o.row.ledger;
    rows.add([
      o.row.lineNo,
      g.orderDate,
      g.deliveryDate,
      g.serial,
      // The document's supplier when the line names none.
      g.supplier.isNotEmpty ? g.supplier : (m.supplierName ?? ''),
      o.row.maker,
      o.row.code,
      o.row.jan,
      o.row.name,
      o.row.quantity,
      g.unit,
      g.listPrice,
      g.unitPrice,
      g.unitPriceWithTax,
      g.amount,
      g.orderNumber,
      doubts,
      o.row.corrected ? '${o.row.aiJan ?? ''} / ${o.row.aiQuantity ?? ''} → ${o.row.jan} / ${o.row.quantity}' : '',
      readFateText(l10n, o),
      if (o.fate == ReadFate.inStock || o.fate == ReadFate.awaiting) l?.name ?? l?.janCode else '',
      if (o.fate == ReadFate.inStock) l?.onHandBefore else null,
      if (o.fate == ReadFate.inStock) l?.added else null,
      if (o.fate == ReadFate.inStock) l?.onHandAfter else null,
      switch (o.fate) {
        ReadFate.awaiting => l10n.miStatusAwaiting,
        ReadFate.inStock when l?.inspectedAt != null =>
          '${l10n.siInspected(l!.inspectedQuantity ?? 0, l.inspectedByName ?? '')} ${at.format(l.inspectedAt!)}',
        _ => '',
      },
    ]);
    if (o.doubtful) flagged.addAll({(i, _janCol), (i, _qtyCol)});
    if (o.fate != ReadFate.inStock && o.fate != ReadFate.merged && o.fate != ReadFate.awaiting) flagged.add((i, _resultCol));
  }
  final filed = m.filedOn;
  return ReadingTable(
    title: '${l10n.ivTitle(m.id)} · ${m.originalName ?? ''}',
    top: [
      ['読み取り結果', l10n.ivTitle(m.id)],
      ['ファイル', m.originalName ?? ''],
      if (filed != null)
        ['書類の日付', '${fmt.format(filed)}（${documentDateSourceLabel(l10n, DocumentDateSource.fromWire(m.documentDateSource))}）'],
      ['取り込んだ日時', m.createdAt == null ? '' : at.format(m.createdAt!)],
      ['倉庫', m.warehouseName ?? ''],
      ['状態', m.undoneAt != null ? l10n.ivUndone : masterStatusLabel(l10n, m.status)],
      ['読み取り', switch (m.readBy) { 'ai' => l10n.ivByAi, 'sheet' => l10n.ivBySheet, _ => l10n.ivByOld }],
      ['仕入先への振り込み', m.paid ? l10n.calPaid : l10n.calUnpaid],
      ['備考', m.note ?? ''],
      if (filed != null) ['保存期限', fmt.format(keptUntil(filed))],
    ],
    headers: _headers,
    rows: rows,
    flagged: flagged,
  );
}

/// The reading as an .xlsx workbook.
Uint8List readingXlsx(ReadingTable t) => buildXlsx(
      sheetName: '読み取り結果',
      headers: t.headers,
      rows: t.rows,
      flagged: t.flagged,
      top: t.top,
      widths: const [6, 10, 10, 8, 20, 14, 16, 16, 32, 9, 6, 10, 10, 10, 11, 14, 24, 24, 40, 28, 9, 9, 9, 28],
    );

/// The reading as a spreadsheet-looking web page, for a browser tab.
String readingHtml(AppLocalizations l10n, ReadingTable t) =>
    htmlSheet(title: t.title, headers: t.headers, rows: t.rows, flagged: t.flagged, top: t.top, downloadHint: l10n.ivTabHint);

String readingFileName(MasterImport m) {
  final base = (m.originalName ?? 'file').replaceAll(RegExp(r'\.[A-Za-z0-9]+$'), '');
  return '読み取り結果_${m.id}_$base.xlsx';
}

Future<MasterImport?> _load(BuildContext context, WidgetRef ref, int importId, MasterImport? known) async {
  if (known != null) return known;
  final r = await ref.read(masterImportRepositoryProvider).detail(importId);
  if (!context.mounted) return null;
  switch (r) {
    case ApiSuccess(:final data):
      return data;
    case ApiFailure(:final message):
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(AppLocalizations.of(context), message))));
      return null;
  }
}

/// Saves the reading as Excel.
Future<void> downloadReading(BuildContext context, WidgetRef ref, int importId, {MasterImport? known}) async {
  final l10n = AppLocalizations.of(context);
  final m = await _load(context, ref, importId, known);
  if (m == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  await ref.read(stockTemplateSaverProvider)(readingFileName(m), readingXlsx(readingTable(l10n, m)));
  messenger.showSnackBar(SnackBar(content: Text(l10n.ivXlsxSaved)));
}

/// Opens the reading as a sheet in a new browser tab. The tab is opened at
/// once (a browser only lets a click open one); where it cannot be, the
/// Excel file is saved instead.
Future<void> openReadingTab(BuildContext context, WidgetRef ref, int importId, {MasterImport? known}) async {
  final l10n = AppLocalizations.of(context);
  final tab = openHtmlTab();
  if (tab == null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.ivTabBlocked)));
    await downloadReading(context, ref, importId, known: known);
    return;
  }
  final m = await _load(context, ref, importId, known);
  if (m == null || !context.mounted) {
    tab.close();
    return;
  }
  tab.show(readingHtml(l10n, readingTable(l10n, m)));
}
