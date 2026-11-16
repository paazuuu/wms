// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/reports/application/report_providers.dart';
import 'package:wms_mobile/features/reports/domain/report.dart';
import 'package:wms_mobile/features/reports/presentation/report_builder_screen.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';
import 'package:wms_mobile/features/warehouse_context/domain/warehouse.dart';

import '../../support/harness.dart';

Future<void> _pump(WidgetTester tester, FakeReportRepository repo) async {
  await pumpApp(
    tester,
    const ReportBuilderScreen(),
    overrides: [reportRepositoryProvider.overrideWithValue(repo)],
  );
}

void main() {
  testWidgets('running a report displays the rows in a table', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeReportRepository(rowsBySource: {
      ReportSource.stockMovements: [
        {'id': 1, 'jan_code': '4988601001053', 'quantity': 7},
      ],
    });
    await _pump(tester, repo);

    await tester.tap(find.text('実行'));
    await tester.pumpAndSettle();

    expect(find.text('1 件'), findsOneWidget);
    expect(find.text('4988601001053'), findsOneWidget);
    // The cell, and the column's total under it.
    expect(find.text('7'), findsWidgets);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('the empty state shows when a report has no rows', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeReportRepository();
    await _pump(tester, repo);

    await tester.tap(find.text('実行'));
    await tester.pumpAndSettle();

    expect(find.text('該当するデータがありません'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('saving the current report adds it to the saved list',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeReportRepository(rowsBySource: {
      ReportSource.stockMovements: [
        {'id': 1, 'jan_code': '4988601001053', 'quantity': 7},
      ],
    });
    await _pump(tester, repo);

    expect(find.textContaining('保存した条件はまだありません'), findsOneWidget);

    await tester.tap(find.text('実行'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('report-save')));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '名前'), 'マイレポート');
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, '条件を保存')));
    await tester.pumpAndSettle();

    expect(find.text('マイレポート'), findsOneWidget);
    expect(find.textContaining('保存した条件はまだありません'), findsNothing);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('offers the inspection, transfer and shipment sources (0047)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeReportRepository(rowsBySource: {
      ReportSource.inspections: [
        {'id': 1, 'delivery_number': '0901', 'failed_quantity': 3},
      ],
    });
    await _pump(tester, repo);

    // Picked side by side; 入出庫履歴 is on at first and taken off here.
    expect(find.byKey(const ValueKey('report-source-inspections')), findsOneWidget);
    expect(find.byKey(const ValueKey('report-source-transfers')), findsOneWidget);
    expect(find.byKey(const ValueKey('report-source-shipments')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('report-source-stock_movements')));
    await tester.tap(find.byKey(const ValueKey('report-source-inspections')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('実行'));
    await tester.pumpAndSettle();

    expect(find.text('0901'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  test('every wire value round-trips through ReportSource.parse', () {
    for (final s in ReportSource.values) {
      expect(ReportSource.parse(s.wire), s, reason: s.wire);
    }
  });


  testWidgets('with warehouses in two countries a report can be narrowed to one (0093)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeReportRepository();
    await pumpApp(
      tester,
      const ReportBuilderScreen(),
      overrides: [
        reportRepositoryProvider.overrideWithValue(repo),
        warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(
          WarehouseOverview(
            warehouses: const [
              Warehouse(id: 1, code: 'TKY', name: '東京倉庫'),
              Warehouse(id: 2, code: 'SHA', name: '上海倉庫', countryCode: 'CN'),
            ],
            totals: const WarehouseTotals(),
          ),
        )),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('report-country')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('中国').last);
    await tester.pumpAndSettle();

    // Only the China warehouse is left to pick.
    await tester.tap(find.text('すべての倉庫'));
    await tester.pumpAndSettle();
    expect(find.text('上海倉庫'), findsWidgets);
    expect(find.text('東京倉庫'), findsNothing);
    await tester.tap(find.text('すべての倉庫').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('実行'));
    await tester.pumpAndSettle();
    expect(repo.lastFilters?['country_code'], 'CN');

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a single-country company sees no country picker', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    await _pump(tester, FakeReportRepository());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report-country')), findsNothing);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('one row of conditions; 状態・JAN・カテゴリ behind ⋮, shown as chips once set', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeReportRepository();
    await _pump(tester, repo);
    expect(find.byKey(const ValueKey('report-jan')), findsNothing, reason: 'not on screen until asked for');

    await tester.tap(find.byKey(const ValueKey('report-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('report-conditions')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('report-jan')), '4909999000014');
    await tester.tap(find.byKey(const ValueKey('report-conditions-ok')));
    await tester.pumpAndSettle();
    expect(find.text('JANコード: 4909999000014'), findsOneWidget);

    // The last 6 months from ⋮.
    await tester.tap(find.byKey(const ValueKey('report-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rp-last6')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('実行'));
    await tester.pumpAndSettle();
    expect(repo.lastFilters!['jan_code'], '4909999000014');
    final now = DateTime.now();
    expect(DateTime.parse(repo.lastFilters!['date_from'] as String).toLocal(), DateTime(now.year, now.month - 5));

    // The chip's cross takes the JAN off.
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('report-cond-JANコード（任意）')), matching: find.byType(Icon)).last);
    await tester.pumpAndSettle();
    expect(find.text('JANコード: 4909999000014'), findsNothing);
  });

  testWidgets('several kinds of data at once, one after another; what each is on hover', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeReportRepository(rowsBySource: {
      ReportSource.stockMovements: [
        {'id': 1, 'jan_code': '4909999000014', 'quantity': 7},
      ],
      ReportSource.auditLog: [
        {'id': 2, 'event_type': 'outbound.fee_set', 'entity_type': 'outbound_file'},
      ],
    });
    await _pump(tester, repo);
    final tip = tester.widget<Tooltip>(
        find.ancestor(of: find.byKey(const ValueKey('report-source-stock_movements')), matching: find.byType(Tooltip)).first);
    expect(tip.message, contains('在庫の数が変わったすべての記録'));

    await tester.tap(find.byKey(const ValueKey('report-source-audit_log')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('実行'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report-section-stock_movements')), findsOneWidget);
    expect(find.byKey(const ValueKey('report-section-audit_log')), findsOneWidget);
    expect(find.text('outbound.fee_set'), findsOneWidget);

    // Kept as conditions, with both kinds.
    await tester.tap(find.byKey(const ValueKey('report-save')));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '名前'), '月次の確認');
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
    await tester.pumpAndSettle();
    expect(find.text('入出庫履歴・監査ログ'), findsOneWidget);
  });
}
