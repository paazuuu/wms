// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/virtual_stock/application/virtual_stock_providers.dart';
import 'package:wms_mobile/features/virtual_stock/data/virtual_stock_repository.dart';
import 'package:wms_mobile/features/virtual_stock/domain/virtual_stock.dart';
import 'package:wms_mobile/features/virtual_stock/presentation/virtual_stock_screen.dart';

import '../../support/fake_http_adapter.dart';
import '../../support/harness.dart';

final _summary = VirtualStockSummary(
  totals: VirtualFigures(opening: 0, arrived: 11, adjusted: -1, countDiff: -4, closing: 6),
  months: [
    VirtualMonth(month: '2026-08', figures: VirtualFigures(arrived: 6, closing: 6)),
    VirtualMonth(
        month: '2026-09',
        figures: VirtualFigures(opening: 6, arrived: 5, adjusted: -1, countDiff: -4, closing: 6)),
  ],
  products: [
    VirtualProduct(
      productId: 7,
      janCode: '4901234567894',
      productName: 'ボールペン',
      figures: VirtualFigures(opening: 0, arrived: 11, adjusted: -1, countDiff: -4, closing: 6),
      lastCountOn: DateTime(2026, 9, 27),
      lastCounted: 7,
    ),
  ],
);

Future<void> _pump(WidgetTester tester, FakeVirtualStockRepository repo) => pumpApp(
      tester,
      const VirtualStockScreen(),
      overrides: [virtualStockRepositoryProvider.overrideWithValue(repo)],
    );

void main() {
  testWidgets('shows the range total, each month and each product for the warehouse abroad',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    final repo = FakeVirtualStockRepository(
      warehouseList: [VirtualWarehouse(id: 2, name: '上海倉庫', countryCode: 'CN')],
      summaryResult: _summary,
    );
    await _pump(tester, repo);

    // Defaults to the last three months, ending at the end of this month.
    final now = DateTime.now();
    expect(repo.lastSummaryKey!.warehouseId, 2);
    expect(repo.lastSummaryKey!.from, DateTime(now.year, now.month - 2));
    expect(repo.lastSummaryKey!.to, DateTime(now.year, now.month + 1, 0));

    expect(find.text('+11'), findsWidgets);
    expect(find.text('-4'), findsWidgets);
    expect(find.text('2026-08'), findsOneWidget);
    expect(find.text('2026-09'), findsWidgets);
    expect(find.text('ボールペン'), findsOneWidget);
    expect(find.textContaining('最終実数 2026-09-27：7'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('fits a phone-width screen with large figures', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 1600));
    final big = VirtualFigures(opening: 123456, arrived: 234567, adjusted: -34567, countDiff: -45678, closing: 277778);
    final repo = FakeVirtualStockRepository(
      warehouseList: [VirtualWarehouse(id: 2, name: '上海倉庫', countryCode: 'CN')],
      summaryResult: VirtualStockSummary(totals: big, products: [
        VirtualProduct(productId: 7, janCode: '4901234567894', productName: 'とても長い商品名のボールペン', figures: big),
      ]),
    );
    await _pump(tester, repo);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('with no warehouse abroad it says where to set one', (tester) async {
    await _pump(tester, FakeVirtualStockRepository());
    expect(find.text('国外の倉庫がありません'), findsOneWidget);
  });

  testWidgets('a count typed in by hand is sent for the product', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    final repo = FakeVirtualStockRepository(
      warehouseList: [VirtualWarehouse(id: 2, name: '上海倉庫', countryCode: 'CN')],
      summaryResult: _summary,
    );
    await _pump(tester, repo);

    await tester.tap(find.byTooltip('実数・増減を入力'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('virtual-qty')), '7');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.recorded.single.type, VirtualEntryType.count);
    expect(repo.recorded.single.jan, '4901234567894');
    expect(repo.recorded.single.quantity, 7);
    expect(find.text('記録しました'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a known shipment out is recorded as a negative change', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    final repo = FakeVirtualStockRepository(
      warehouseList: [VirtualWarehouse(id: 2, name: '上海倉庫', countryCode: 'CN')],
    );
    await _pump(tester, repo);

    await tester.tap(find.text('実数・増減を入力'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('増減'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('virtual-jan')), '4901234567894');
    await tester.enterText(find.byKey(const ValueKey('virtual-qty')), '2');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.recorded.single.type, VirtualEntryType.adjust);
    expect(repo.recorded.single.quantity, -2);

    await tester.binding.setSurfaceSize(null);
  });

  test('summary() posts the warehouse and the day range', () async {
    late RequestOptions captured;
    final adapter = FakeHttpClientAdapter((options) {
      captured = options;
      return jsonResponseBody({
        'totals': {'opening': 0, 'arrived': 6, 'adjusted': 0, 'count_diff': 0, 'closing': 6},
        'months': [
          {'month': '2026-08', 'opening': 0, 'arrived': 6, 'adjusted': 0, 'count_diff': 0, 'closing': 6}
        ],
        'products': [
          {'product_id': 7, 'jan_code': '49', 'product_name': 'P', 'opening': 0, 'arrived': 6,
           'adjusted': 0, 'count_diff': 0, 'closing': 6,
           'last_count': {'occurred_on': '2026-08-31', 'counted': 6}}
        ],
      }, 200);
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://x.test/rest/v1'))..httpClientAdapter = adapter;
    final repo = VirtualStockRepositoryImpl(dio);

    final result = await repo.summary(2, from: DateTime(2026, 8), to: DateTime(2026, 9, 30));

    expect(captured.path, '/rpc/virtual_stock_summary');
    expect((captured.data as Map)['p_from'], '2026-08-01');
    expect((captured.data as Map)['p_to'], '2026-09-30');
    result.when(
      success: (s) {
        expect(s.totals.arrived, 6);
        expect(s.months.single.month, '2026-08');
        expect(s.products.single.lastCounted, 6);
      },
      failure: (f) => fail('$f'),
    );
  });
}
