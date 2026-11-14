import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/export/xlsx.dart';
import 'package:wms_mobile/features/reports/application/report_providers.dart';
import 'package:wms_mobile/features/reports/data/report_export.dart';
import 'package:wms_mobile/features/reports/domain/report.dart';
import 'package:wms_mobile/features/reports/domain/report_table.dart';
import 'package:wms_mobile/features/reports/presentation/report_builder_screen.dart';
import 'package:wms_mobile/features/reports/presentation/report_view.dart';

import '../../support/harness.dart';

// Synthetic movements: two products, two kinds, two warehouses.
final _rows = <Map<String, dynamic>>[
  {'id': 1, 'warehouse_id': 1, 'warehouse_name': '本倉庫', 'created_at': '2026-11-03T01:00:00Z', 'movement_type': 'ADJUST',
    'jan_code': '4909999000014', 'product_name': 'テストペン', 'quantity_before': 10, 'quantity': 5, 'quantity_after': 15},
  {'id': 2, 'warehouse_id': 1, 'warehouse_name': '本倉庫', 'created_at': '2026-11-04T01:00:00Z', 'movement_type': 'SHIP',
    'jan_code': '4909999000021', 'product_name': 'テストノート', 'quantity_before': 8, 'quantity': -3, 'quantity_after': 5},
  {'id': 3, 'warehouse_id': 2, 'warehouse_name': '第二倉庫', 'created_at': '2026-11-05T01:00:00Z', 'movement_type': 'ADJUST',
    'jan_code': '4909999000014', 'product_name': 'テストペン', 'quantity_before': 0, 'quantity': 20, 'quantity_after': 20},
];

ReportResult get _result => ReportResult(source: ReportSource.stockMovements, rows: _rows);

Uint8List _font() => File('assets/fonts/pdf/ipag.ttf').readAsBytesSync();

void main() {
  test('the rows as people read them: headings, order, words, no inner ids, totals and pages', () {
    final t = reportTable(_result);
    expect(t.columns.map((c) => c.label), ['日時', '倉庫', '種類', 'JAN', '商品名', '変更前', '数量', '変更後']);
    expect(t.rows.first[2], '在庫調整');
    expect(t.rows[1][2], '出庫');
    expect(t.columns.where((c) => c.numeric).map((c) => c.key), ['quantity_before', 'quantity', 'quantity_after']);
    // Only what moved is added up; levels before and after are not.
    expect(t.totals(), [null, null, null, null, null, null, '22', null]);

    final pens = t.where({4: {'テストペン'}});
    expect(pens.rows, hasLength(2));
    expect(pens.where({1: {'第二倉庫'}}).rows.single[6], '20');
    expect(t.values(1), ['本倉庫', '第二倉庫']..sort());

    final many = ReportTable(columns: t.columns, rows: [for (var i = 0; i < 65; i++) t.rows.first]);
    expect(many.pages(30).map((p) => p.length), [30, 30, 5]);
  });

  test('Excel: the title and conditions on top, the rows, the numbers summed', () {
    final d = ReportDoc(
      title: '在庫履歴レポート',
      conditions: const ['期間: 2026/11/01 〜 2026/11/30'],
      table: reportTable(_result),
      madeAt: DateTime(2026, 11, 14, 10),
      countText: '3件',
      madeText: '作成 2026/11/14 10:00',
    );
    expect(d.fileStem, '在庫履歴レポート_20261114_1000');
    final rows = readXlsx(buildReportXlsx(d));
    expect(rows.first.first, '在庫履歴レポート');
    expect(rows[1].first, '期間: 2026/11/01 〜 2026/11/30');
    final head = rows.indexWhere((r) => r.isNotEmpty && r.first == '日時');
    expect(rows[head], contains('商品名'));
    expect(rows[head + 1], contains('テストペン'));
    expect(rows.last.first, '合計');
    expect(rows.last, contains('22'));
  });

  test('PDF: an A4 document with the Japanese written in', () async {
    final d = ReportDoc(
      title: '在庫履歴レポート',
      conditions: const ['倉庫: すべての倉庫'],
      table: reportTable(_result),
      madeAt: DateTime(2026, 11, 14, 10),
      countText: '3件',
      madeText: '作成 2026/11/14 10:00',
    );
    final bytes = await buildReportPdf(d, _font(), compress: false);
    final text = latin1.decode(bytes);
    expect(text, startsWith('%PDF-'));
    expect(text, contains('/MediaBox[0 0 595.27559 841.88976]'), reason: 'A4 portrait');
    expect(text, contains('IPAGothic'), reason: 'the Japanese font is in it');
  });

  testWidgets('a month picked sets the dates; the result narrowed by a column; Excel and PDF saved', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeReportRepository(rowsBySource: {ReportSource.stockMovements: _rows});
    final saved = <String>[];
    await pumpApp(tester, const ReportBuilderScreen(), overrides: [
      reportRepositoryProvider.overrideWithValue(repo),
      reportFileSaverProvider.overrideWithValue((n, b) async => saved.add(n)),
      reportPdfFontProvider.overrideWithValue(() async => _font()),
    ]);

    // The month before this one, from its 1st to its last day.
    final now = DateTime.now();
    final m = DateTime(now.year, now.month - 1);
    final label = '${m.year}/${m.month.toString().padLeft(2, '0')}';
    await tester.tap(find.byKey(const ValueKey('report-month-null')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('実行'));
    await tester.pumpAndSettle();
    final from = DateTime.parse(repo.lastFilters!['date_from'] as String).toLocal();
    final to = DateTime.parse(repo.lastFilters!['date_to'] as String).toLocal();
    expect(from, DateTime(m.year, m.month));
    expect(to.day, DateTime(m.year, m.month + 1, 0).day);
    expect((to.hour, to.minute), (23, 59), reason: 'the last day is in the report');

    // The page: title, conditions, headings, rows.
    expect(find.byKey(const ValueKey('report-page-1')), findsOneWidget);
    expect(find.text('在庫履歴レポート'), findsOneWidget);
    expect(find.textContaining('期間: $label/01'), findsOneWidget);
    expect(find.text('商品名'), findsWidgets);
    expect(find.text('第二倉庫'), findsOneWidget);

    // Only テストペン, from the 商品名 column's values.
    await tester.tap(find.byKey(const ValueKey('report-col-product_name')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('report-values-none')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('report-value-テストペン')));
    await tester.tap(find.byKey(const ValueKey('report-values-apply')));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3 件（列で絞り込み中）'), findsOneWidget);
    expect(find.text('テストノート'), findsNothing);
    expect(find.text('絞り込み（商品名）: テストペン'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('report-excel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('report-pdf')));
    await tester.pumpAndSettle();
    expect(saved, hasLength(2));
    expect(saved.first, endsWith('.xlsx'));
    expect(saved.last, endsWith('.pdf'));
    expect(saved.first, startsWith('在庫履歴レポート_'));

    await tester.tap(find.byKey(const ValueKey('report-filter-reset')));
    await tester.pumpAndSettle();
    expect(find.text('3 件'), findsOneWidget);
  });
}
