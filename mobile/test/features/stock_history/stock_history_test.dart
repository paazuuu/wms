// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/ui/time_line_chart.dart';
import 'package:wms_mobile/features/stock_history/data/stock_history_repository.dart';
import 'package:wms_mobile/features/stock_history/domain/stock_history.dart';
import 'package:wms_mobile/features/stock_history/presentation/stock_history_views.dart';

import '../../support/harness.dart';

final _history = ProductStockHistory.fromJson({
  'since': '2026-07-24T00:00:00Z',
  'start': 10,
  'current': 505,
  'events': [
    {
      'id': 1, 'at': '2026-08-01T01:00:00Z', 'method': 'receipt', 'type': 'RECEIPT', 'quantity': 20,
      'warehouse_name': '本社倉庫',
    },
    {
      'id': 2, 'at': '2026-09-10T02:00:00Z', 'method': 'file_stock', 'type': 'ADJUST', 'quantity': 500,
      'warehouse_name': '本社倉庫', 'file_name': '入荷_9月.xlsx', 'import_id': 8,
    },
    {'id': 3, 'at': '2026-10-01T03:00:00Z', 'method': 'ship', 'type': 'SHIP', 'quantity': -25, 'warehouse_name': '本社倉庫'},
  ],
});

final _inflow = LibraryInflow.fromJson({
  'since': '2026-07-24T00:00:00Z',
  'days': [
    {'day': '2026-08-01', 'method': 'receipt', 'units_in': 20, 'units_out': 0, 'products': 1},
    {'day': '2026-09-10', 'method': 'file_stock', 'units_in': 500, 'units_out': 0, 'products': 3},
    {'day': '2026-09-12', 'method': 'file_master', 'units_in': 100, 'units_out': 0, 'products': 2},
    {'day': '2026-10-01', 'method': 'ship', 'units_in': 0, 'units_out': 25, 'products': 1},
  ],
  'files': [
    {
      'import_id': 9, 'at': '2026-09-12T05:00:00Z', 'method': 'file_master', 'file_name': '請求書.pdf',
      'products': 2, 'units': 100, 'warehouse_name': '本社倉庫', 'by': '倉庫',
    },
    {
      'import_id': 8, 'at': '2026-09-10T02:00:00Z', 'method': 'file_stock', 'file_name': '入荷_9月.xlsx',
      'products': 3, 'units': 500, 'warehouse_name': '本社倉庫', 'by': '倉庫',
    },
  ],
});

void main() {
  test('a product\'s levels run from the start of the period to today', () {
    expect(_history.levels.map((l) => l.$2), [10, 30, 530, 505]);
    expect(_history.levels.last.$2, _history.current);
  });

  test('the library adds up by how stock came in, files counted together', () {
    expect(_inflow.totals, {StockGroup.file: 600, StockGroup.receipt: 20, StockGroup.adjust: 0, StockGroup.other: 0});
    final lines = _inflow.cumulative(DateTime(2026, 10, 21));
    expect(lines.keys, [StockGroup.file, StockGroup.receipt]);
    expect(lines[StockGroup.file]!.map((p) => p.$2), [0, 500, 600, 600]);
    expect(lines[StockGroup.file]!.last.$1, DateTime(2026, 10, 21));
  });

  testWidgets('a product shows its stock as a line, a dot where a file added, and every change', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeStockHistoryRepository(product: _history);
    await pumpApp(tester, const Scaffold(body: SingleChildScrollView(child: ProductStockChartCard(productId: 1, warehouseId: 1))),
        overrides: [stockHistoryRepositoryProvider.overrideWithValue(repo)]);

    expect(find.byKey(const ValueKey('sh-product-chart')), findsOneWidget);
    expect(find.text('ファイルから追加'), findsOneWidget);
    expect(find.text('期間のはじめ 10 → 今 505'), findsOneWidget);
    // The table: newest first, how, which file, and the stock after.
    final file = find.byKey(const ValueKey('sh-event-2'));
    expect(find.descendant(of: file, matching: find.text('+500　ファイルから在庫登録')), findsOneWidget);
    expect(find.descendant(of: file, matching: find.textContaining('入荷_9月.xlsx')), findsOneWidget);
    expect(find.descendant(of: file, matching: find.text('→ 530')), findsOneWidget);

    // The crosshair's readout says what happened at the nearest date.
    final chart = tester.getRect(find.byKey(const ValueKey('sh-product-chart')));
    await tester.tapAt(Offset(chart.left + 48 + (chart.width - 64) * 0.62, chart.center.dy));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chart-readout')), findsOneWidget);

    // Another period asks again.
    await tester.tap(find.byKey(const ValueKey('sh-days-30')));
    await tester.pumpAndSettle();
    expect(repo.asked.last, (1, 30));
  });

  testWidgets('the library shows units added by how, as running totals, and every file', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester, const Scaffold(body: LibraryInflowView(warehouseId: 1, warehouseName: '本社倉庫')),
        overrides: [stockHistoryRepositoryProvider.overrideWithValue(FakeStockHistoryRepository(library: _inflow))]);

    expect(find.descendant(of: find.byKey(const ValueKey('sh-total-file')), matching: find.text('600個')), findsOneWidget);
    expect(find.byKey(const ValueKey('sh-library-chart')), findsOneWidget);
    expect(tester.widget<TimeLineChart>(find.byKey(const ValueKey('sh-library-chart'))).series.map((s) => s.label),
        ['ファイル取込', '入荷・検品']);
    expect(find.text('在庫を変えたファイル（2件）'), findsOneWidget);
    final f = find.byKey(const ValueKey('sh-file-8'));
    expect(find.descendant(of: f, matching: find.text('入荷_9月.xlsx')), findsOneWidget);
    expect(find.descendant(of: f, matching: find.textContaining('ファイルから在庫登録')), findsOneWidget);
    expect(find.descendant(of: f, matching: find.text('3商品・+500個')), findsOneWidget);
  });
}
