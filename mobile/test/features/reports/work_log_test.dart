import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:wms_mobile/core/export/xlsx.dart';
import 'package:wms_mobile/features/admin/data/menu_visibility_repository.dart' show showPricesProvider;
import 'package:wms_mobile/l10n/app_localizations.dart';
import 'package:wms_mobile/features/reports/data/work_log_repository.dart';
import 'package:wms_mobile/features/reports/domain/report_table.dart';
import 'package:wms_mobile/features/reports/presentation/report_view.dart';
import 'package:wms_mobile/features/reports/presentation/reports_hub_screen.dart';
import 'package:wms_mobile/features/reports/presentation/work_log_screen.dart';

import '../../support/fake_work_log_repository.dart';
import '../../support/harness.dart';

// A synthetic month: two receipts, a shipment, a 在庫外出荷 and a memo.
final _entries = [
  WorkLogEntry(kind: 'receipt', day: DateTime(2026, 11, 2), docDay: DateTime(2026, 10, 31), warehouseName: '本倉庫',
      partner: 'テスト商事', fileName: '納品書_1102.pdf', lines: 22, quantity: 480, status: 'awaiting_inspection',
      note: '箱潰れ2箱あり。写真を保存済み', amount: 120000, by: 'テスト太郎'),
  WorkLogEntry(kind: 'unplanned', day: DateTime(2026, 11, 3), warehouseName: '本倉庫', partner: 'テスト文具',
      fileName: '予定外.xlsx', lines: 4, quantity: 430, status: 'stock_done', by: 'テスト花子'),
  WorkLogEntry(kind: 'outbound', day: DateTime(2026, 11, 14), warehouseName: '第二倉庫', partner: 'テスト貿易',
      fileName: '出荷明細.xlsx', lines: 72, quantity: 0, short: 4600, cartons: 12, status: 'shipped',
      note: '午後便で出荷。インボイスは別送', amount: 30000, currency: 'CNY', freight: 8000),
  WorkLogEntry(kind: 'proxy', day: DateTime(2026, 11, 20), warehouseName: '本倉庫', partner: 'テスト海外',
      fileName: '手入力', lines: 3, quantity: 60, status: 'shipped', note: '委託先: テスト物流', fee: 1500),
  WorkLogEntry(kind: 'memo', day: DateTime(2026, 11, 21), warehouseName: '本倉庫',
      note: '12/1から入荷の受付は午前のみ。仕入先各社へ連絡済み。長いメモでも最後まで載ることを確かめるための文章です。'),
];

void main() {
  test('the month as a table: kinds and statuses in words, memos in full, amounts only when asked', () {
    final l10n = lookupAppLocalizations(const Locale('ja'));
    final t = workLogTable(l10n, _entries);
    expect(t.columns.map((c) => c.label),
        ['日付', '区分', '倉庫', '仕入先・出荷先', 'ファイル', '行数', '数量', '状態', '担当', 'メモ・指示']);
    expect(t.columns.last.wrap, isTrue);
    expect(t.rows[0].sublist(0, 2), ['2026/11/02', '入荷']);
    expect(t.rows[0][7], '検品待ち');
    expect(t.rows[0].last, '箱潰れ2箱あり。写真を保存済み / 書類日付 2026/10/31');
    expect(t.rows[1][1], '予定外の入荷');
    expect(t.rows[2][7], '出庫済み / 不足 4600');
    expect(t.rows[2].last, contains('12箱'));
    expect(t.rows[3].sublist(1, 2), ['在庫外出荷']);
    expect(t.rows[3][7], '出荷済み（記録）');
    expect(t.rows[4][1], 'メモ・指示');
    expect(t.rows.expand((r) => r).join(), isNot(contains('120,000')), reason: 'no money unless asked');

    final money = workLogTable(l10n, _entries, amounts: true);
    expect(money.columns.map((c) => c.label), contains('金額'));
    expect(money.rows[0][9], '¥120,000');
    expect(money.rows[2][9], 'CNY 30,000\n輸送費 ¥8,000');
    expect(money.rows[3][9], '手数料 ¥1,500');

    // A long memo takes more than one line, and the pages follow the height.
    expect(reportRowHeight(t, t.rows[4]), greaterThan(26));
    final many = ReportTable(columns: t.columns, rows: [for (var i = 0; i < 40; i++) t.rows[4]]);
    final pages = paginateReport(many, conditionLines: 4);
    expect(pages.length, greaterThan(2));
    expect(pages.expand((p) => p).length, 40);
  });

  testWidgets('入出荷実績: this month by default, a kind left out, a supplier picked, saved as Excel', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeWorkLogRepository(_entries);
    final saved = <(String, Uint8List)>[];
    await pumpApp(tester, const WorkLogScreen(), overrides: [
      workLogRepositoryProvider.overrideWithValue(repo),
      reportFileSaverProvider.overrideWithValue((n, b) async => saved.add((n, b))),
    ]);
    await tester.pumpAndSettle();
    final now = DateTime.now();
    expect(repo.asked.single.from, DateTime(now.year, now.month));
    expect(repo.asked.single.to, DateTime(now.year, now.month + 1, 0));
    expect(repo.asked.single.amounts, isFalse);
    final month = '${now.year}/${now.month.toString().padLeft(2, '0')}';
    expect(find.text('入出荷実績 $month'), findsOneWidget);
    expect(find.text('入荷 2件・出庫 1件・在庫外出荷 1件・メモ 1件'), findsOneWidget);
    expect(find.textContaining('12/1から入荷の受付は午前のみ'), findsOneWidget);

    // Memos left out.
    await tester.tap(find.byKey(const ValueKey('wl-kind-memo')));
    await tester.pumpAndSettle();
    expect(find.textContaining('12/1から入荷の受付は午前のみ'), findsNothing);
    expect(find.text('入荷 2件・出庫 1件・在庫外出荷 1件・メモ 0件'), findsOneWidget);

    // One supplier, from the 取引先 column.
    await tester.tap(find.byKey(const ValueKey('report-col-partner')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('report-values-none')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('report-value-テスト商事')));
    await tester.tap(find.byKey(const ValueKey('report-values-apply')));
    await tester.pumpAndSettle();
    expect(find.text('1 / 4 件（列で絞り込み中）'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('report-excel')));
    await tester.pumpAndSettle();
    final rows = readXlsx(saved.single.$2);
    expect(saved.single.$1, startsWith('入出荷実績_'));
    expect(rows.first.first, '入出荷実績 $month');
    expect(rows.any((r) => r.contains('テスト商事')), isTrue);
    expect(rows.any((r) => r.contains('テスト貿易')), isFalse);
    expect(rows.any((r) => r.any((c) => c.contains('箱潰れ2箱あり'))), isTrue);

    // Amounts, asked for from ⋮, and shown as on.
    await tester.tap(find.byKey(const ValueKey('wl-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wl-amounts')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wl-amounts-on')), findsOneWidget);
    expect(repo.asked.last.amounts, isTrue);
    expect(find.text('金額'), findsWidgets);
  });

  testWidgets('without prices shown there is no amounts switch', (tester) async {
    final repo = FakeWorkLogRepository(_entries);
    await pumpApp(tester, const WorkLogScreen(), overrides: [
      workLogRepositoryProvider.overrideWithValue(repo),
      showPricesProvider.overrideWithValue(false),
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wl-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wl-amounts')), findsNothing);
    expect(find.byKey(const ValueKey('rp-last3')), findsOneWidget);
    expect(repo.asked.single.amounts, isFalse);
  });

  testWidgets('the period from ⋮: the last 3 months, then a month to a month, cleared back to this month', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeWorkLogRepository(_entries);
    await pumpApp(tester, const WorkLogScreen(), overrides: [workLogRepositoryProvider.overrideWithValue(repo)]);
    await tester.pumpAndSettle();
    final now = DateTime.now();

    await tester.tap(find.byKey(const ValueKey('wl-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rp-last3')));
    await tester.pumpAndSettle();
    expect(repo.asked.last.from, DateTime(now.year, now.month - 2));
    expect(repo.asked.last.to, DateTime(now.year, now.month + 1, 0));
    final m = DateFormat('y/MM');
    final span = '${m.format(DateTime(now.year, now.month - 2))}〜${m.format(now)}';
    expect(find.text(span), findsOneWidget);
    expect(find.text('入出荷実績 $span'), findsOneWidget);

    // A month to a month.
    await tester.tap(find.byKey(const ValueKey('wl-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rp-months')));
    await tester.pumpAndSettle();
    final from = DateTime(now.year, now.month - 5);
    await tester.tap(find.byKey(const ValueKey('rp-from')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(m.format(from)).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rp-months-ok')));
    await tester.pumpAndSettle();
    expect(repo.asked.last.from, from);

    // Back to one field: this month.
    await tester.tap(find.byKey(const ValueKey('rp-span-clear')));
    await tester.pumpAndSettle();
    expect(repo.asked.last.from, DateTime(now.year, now.month));
    expect(find.byKey(const ValueKey('rp-span')), findsNothing);
  });

  testWidgets('レポート: 入出庫履歴 and 入出荷実績 as tabs', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester, const ReportsHubScreen(), overrides: [
      workLogRepositoryProvider.overrideWithValue(FakeWorkLogRepository(_entries)),
    ]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rh-history')), findsOneWidget);
    expect(find.byKey(const ValueKey('report-source')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rh-activity')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wl-more')), findsOneWidget);
    expect(find.textContaining('入出荷実績'), findsWidgets);
  });
}
