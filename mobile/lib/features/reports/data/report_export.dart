import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/export/xlsx.dart';
import '../domain/report_table.dart';

/// A report as a document: its title, the conditions it was run with
/// (one line each) and when it was made.
class ReportDoc {
  const ReportDoc({
    required this.title,
    required this.conditions,
    required this.table,
    required this.madeAt,
    this.totalLabel = '合計',
    this.countText = '',
    this.madeText = '',
  });

  final String title;

  /// The words around the table, in the app's language: the totals row's
  /// first cell, the row count and when it was made.
  final String totalLabel;
  final String countText;
  final String madeText;
  final List<String> conditions;
  final ReportTable table;
  final DateTime madeAt;

  String get fileStem =>
      '${title.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_')}_${DateFormat('yyyyMMdd_HHmm').format(madeAt)}';
}

/// The report as an Excel sheet: title and conditions above, the heading
/// row, the rows, and the numeric columns summed underneath.
Uint8List buildReportXlsx(ReportDoc d) {
  final t = d.table;
  final totals = t.totals();
  return buildXlsx(
    sheetName: d.title.length > 31 ? d.title.substring(0, 31) : d.title,
    top: [
      [d.title],
      for (final c in d.conditions) [c],
      ['${d.madeText}　${d.countText}'],
      [],
    ],
    headers: [for (final c in t.columns) c.label],
    rows: [
      for (final r in t.rows)
        [
          for (final (i, c) in t.columns.indexed)
            c.numeric ? (num.tryParse(r[i].replaceAll(',', '')) ?? r[i]) : r[i],
        ],
    ],
    bottom: totals.any((v) => v != null)
        ? [
            [
              for (final (i, v) in totals.indexed)
                i == 0 && v == null ? d.totalLabel : (v == null ? '' : num.tryParse(v.replaceAll(',', '')) ?? v),
            ],
          ]
        : const [],
    widths: [for (final c in t.columns) (c.flex * 10).clamp(8, 48).toDouble()],
  );
}

/// The Japanese the PDF is written in (IPAGothic, kept as an asset and
/// fetched only now).
Future<Uint8List> loadReportPdfFont() async =>
    (await rootBundle.load('assets/fonts/pdf/ipag.ttf')).buffer.asUint8List();

/// The report as an A4 portrait PDF: a heading with the conditions, the
/// table with its heading row on every page, light stripes, the numeric
/// columns right-aligned and summed at the end, and page numbers.
Future<Uint8List> buildReportPdf(ReportDoc d, Uint8List fontBytes, {bool compress = true}) async {
  final font = pw.Font.ttf(ByteData.sublistView(fontBytes));
  final t = d.table;
  final totals = t.totals();
  const ink = PdfColor.fromInt(0xFF1F2328);
  const muted = PdfColor.fromInt(0xFF6B7280);
  const line = PdfColor.fromInt(0xFFD7DBE0);
  const head = PdfColor.fromInt(0xFFEEF1F4);
  const stripe = PdfColor.fromInt(0xFFF8F9FA);
  // Narrow tables read larger; wide ones shrink to fit the portrait page.
  final size = t.columns.length <= 6 ? 8.5 : (t.columns.length <= 9 ? 7.5 : 6.5);
  final doc = pw.Document(
      title: d.title, compress: compress, theme: pw.ThemeData.withFont(base: font, bold: font));
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
    header: (ctx) => ctx.pageNumber == 1
        ? pw.SizedBox()
        : pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Text(d.title, style: const pw.TextStyle(fontSize: 8, color: muted)),
          ),
    footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(d.madeText, style: const pw.TextStyle(fontSize: 7, color: muted)),
      pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: muted)),
    ]),
    build: (ctx) => [
      pw.Text(d.title, style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: ink)),
      pw.SizedBox(height: 6),
      for (final c in d.conditions) pw.Text(c, style: const pw.TextStyle(fontSize: 8.5, color: muted)),
      pw.Text(d.countText, style: const pw.TextStyle(fontSize: 8.5, color: muted)),
      pw.SizedBox(height: 10),
      pw.TableHelper.fromTextArray(
        headers: [for (final c in t.columns) c.label],
        data: [
          ...t.rows,
          if (totals.any((v) => v != null))
            [for (final (i, v) in totals.indexed) i == 0 && v == null ? d.totalLabel : (v ?? '')],
        ],
        headerCount: 1,
        headerStyle: pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold, color: ink),
        cellStyle: pw.TextStyle(fontSize: size, color: ink),
        headerDecoration: const pw.BoxDecoration(color: head),
        oddRowDecoration: const pw.BoxDecoration(color: stripe),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        headerAlignment: pw.Alignment.centerLeft,
        cellAlignments: {
          for (final (i, c) in t.columns.indexed) i: c.numeric ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        },
        headerAlignments: {
          for (final (i, c) in t.columns.indexed) i: c.numeric ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        },
        columnWidths: {for (final (i, c) in t.columns.indexed) i: pw.FlexColumnWidth(c.flex)},
        border: const pw.TableBorder(
          bottom: pw.BorderSide(color: line, width: 0.5),
          horizontalInside: pw.BorderSide(color: line, width: 0.5),
        ),
      ),
    ],
  ));
  return doc.save();
}
