// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/reports/application/report_providers.dart';
import 'package:wms_mobile/features/reports/domain/report.dart';
import 'package:wms_mobile/features/reports/presentation/report_builder_screen.dart';

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
    expect(find.text('7'), findsOneWidget);

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

    expect(find.text('保存済みのレポートはまだありません'), findsOneWidget);

    await tester.tap(find.text('実行'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, '保存'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'レポート名'), 'マイレポート');
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, '保存')));
    await tester.pumpAndSettle();

    expect(find.text('マイレポート'), findsOneWidget);
    expect(find.text('保存済みのレポートはまだありません'), findsNothing);

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

    // The three operational areas that had no reporting before are now
    // pickable, and running one renders its own columns.
    await tester.tap(find.byType(DropdownButtonFormField<ReportSource>));
    await tester.pumpAndSettle();
    expect(find.text('検品').last, findsOneWidget);
    expect(find.text('倉庫間移動'), findsWidgets);
    expect(find.text('出庫'), findsWidgets);

    await tester.tap(find.text('検品').last);
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

}
