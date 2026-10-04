// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/home/application/dashboard_providers.dart';
import 'package:wms_mobile/features/home/data/dashboard_charts_repository.dart';
import 'package:wms_mobile/features/home/domain/dashboard_charts.dart';
import 'package:wms_mobile/features/home/presentation/dashboard_charts.dart';

import '../../support/fake_http_adapter.dart';
import '../../support/harness.dart';

final _chart = StockChartData(
  warehouses: [
    ChartWarehouse(id: 1, name: '東京倉庫', countryCode: 'JP'),
    ChartWarehouse(id: 2, name: '大阪倉庫', countryCode: 'JP'),
    ChartWarehouse(id: 3, name: '上海倉庫', countryCode: 'CN', isVirtual: true),
  ],
  productCount: 14,
  countryCode: 'JP',
  countries: ['JP', 'CN'],
  products: [
    ChartProduct(
      productId: 1,
      janCode: '4901',
      productName: 'ボールペン',
      total: 55,
      free: 18,
      reserved: 12,
      unusable: 0,
      virtualAbroad: 25,
      byWarehouse: {'1': 20, '2': 10, '3v': 25},
    ),
    ChartProduct(
      productId: 2,
      janCode: '4902',
      productName: 'ノート',
      total: 30,
      free: 26,
      unusable: 4,
      byWarehouse: {'1': 30},
    ),
  ],
);

Future<void> _pump(WidgetTester tester, Widget child, FakeDashboardChartsRepository repo) =>
    pumpApp(
      tester,
      Scaffold(body: SingleChildScrollView(child: child)),
      overrides: [dashboardChartsRepositoryProvider.overrideWithValue(repo)],
    );

void main() {
  testWidgets('the stock chart stacks by warehouse, with a legend and each total at the tip',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    await _pump(tester, const StockBreakdownPanel(), FakeDashboardChartsRepository(chart: _chart));

    // Legend: every warehouse drawn, the abroad one marked virtual.
    expect(find.text('東京倉庫'), findsOneWidget);
    expect(find.text('大阪倉庫'), findsOneWidget);
    expect(find.text('上海倉庫（仮想）'), findsOneWidget);
    expect(find.text('ボールペン'), findsOneWidget);
    expect(find.text('55'), findsOneWidget);
    expect(find.text('日本：在庫の多い上位 2 商品（全 14 商品）'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('one country at a time: choosing China asks for China only (0090)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    final repo = FakeDashboardChartsRepository(chart: _chart);
    await _pump(tester, const StockBreakdownPanel(), repo);

    expect(find.widgetWithText(ChoiceChip, '日本'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '中国'));
    await tester.pumpAndSettle();

    expect(repo.lastCountry, 'CN');
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('switching to by-state shows free, reserved, not usable and abroad', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    await _pump(tester, const StockBreakdownPanel(), FakeDashboardChartsRepository(chart: _chart));

    await tester.tap(find.text('状態別'));
    await tester.pumpAndSettle();

    expect(find.text('空き'), findsOneWidget);
    expect(find.text('引当済'), findsOneWidget);
    expect(find.text('使用不可（保留・検品待ち）'), findsOneWidget);
    expect(find.text('国外（仮想）'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('the table view carries every number', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    await _pump(tester, const StockBreakdownPanel(), FakeDashboardChartsRepository(chart: _chart));

    await tester.tap(find.byTooltip('表で見る'));
    await tester.pumpAndSettle();

    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('合計'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('fits a phone-width screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    await _pump(tester, const StockBreakdownPanel(), FakeDashboardChartsRepository(chart: _chart));
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('recent purchase orders show supplier, destination warehouse and arrival',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    await _pump(
      tester,
      const RecentPurchaseOrdersPanel(),
      FakeDashboardChartsRepository(orders: [
        RecentPurchaseOrder(
          id: 9,
          status: 'APPROVED',
          poNumber: 'PO-000009',
          supplierName: '新東光通商',
          warehouseName: '東京倉庫',
          countryCode: 'JP',
          expectedDate: DateTime(2026, 10, 3),
          orderedUnits: 10,
          receivedUnits: 4,
        ),
      ]),
    );

    expect(find.text('PO-000009 · 新東光通商'), findsOneWidget);
    expect(find.text('宛先 東京倉庫（JP） · 納期 10/3'), findsOneWidget);
    expect(find.text('入荷 4 / 10'), findsOneWidget);
    expect(find.text('承認済み'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  test('stockChart() parses both breakdowns', () async {
    final adapter = FakeHttpClientAdapter((_) => jsonResponseBody({
          'warehouses': [
            {'id': 1, 'name': 'A', 'country_code': 'JP', 'virtual': false},
            {'id': 3, 'name': 'C', 'country_code': 'CN', 'virtual': true},
          ],
          'product_count': 1,
          'products': [
            {'product_id': 1, 'jan_code': '49', 'product_name': 'P', 'total': 35, 'free': 10,
             'reserved': 0, 'unusable': 0, 'virtual_abroad': 25,
             'by_warehouse': [
               {'warehouse_id': 1, 'quantity': 10},
               {'warehouse_id': 3, 'quantity': 25, 'virtual': true},
             ]}
          ],
        }, 200));
    final dio = Dio(BaseOptions(baseUrl: 'https://x.test/rest/v1'))..httpClientAdapter = adapter;

    final result = await DashboardChartsRepositoryImpl(dio).stockChart();

    result.when(
      success: (d) {
        expect(d.warehouses.last.isVirtual, isTrue);
        expect(d.products.single.byWarehouse, {'1': 10, '3v': 25});
        expect(d.products.single.virtualAbroad, 25);
      },
      failure: (f) => fail('$f'),
    );
  });

  testWidgets('stock under unregistered JANs is called out, with the way to register it (0094)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    final chart = StockChartData(
      warehouses: _chart.warehouses,
      products: _chart.products,
      productCount: 14,
      countryCode: 'JP',
      unregisteredJans: 2,
      unregisteredUnits: 1200,
    );
    await _pump(tester, const StockBreakdownPanel(), FakeDashboardChartsRepository(chart: chart));

    expect(find.text('商品ライブラリー未登録のJAN 2 件（計 1,200 個）はグラフに含まれていません'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('chart-unregistered-open')), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('no note when every JAN is registered', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    await _pump(tester, const StockBreakdownPanel(), FakeDashboardChartsRepository(chart: _chart));
    expect(find.byKey(const ValueKey('chart-unregistered-open')), findsNothing);
    await tester.binding.setSurfaceSize(null);
  });

  test('StockChartData reads the unregistered figure', () {
    final d = StockChartData.fromJson({
      'unregistered': {'jan_count': 3, 'units': 40},
    });
    expect(d.unregisteredJans, 3);
    expect(d.unregisteredUnits, 40);
    expect(StockChartData.fromJson(const {}).unregisteredJans, 0);
  });
}
