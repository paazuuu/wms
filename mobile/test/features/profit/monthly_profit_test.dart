import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/profit/data/profit_repository.dart';
import 'package:wms_mobile/features/profit/domain/monthly_profit.dart';
import 'package:wms_mobile/features/profit/presentation/monthly_profit_section.dart';

import '../../support/fake_profit_repository.dart';
import '../../support/harness.dart';

String _ym(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

void main() {
  final now = DateTime.now();
  final thisMonth = _ym(now);
  final lastMonth = _ym(DateTime(now.year, now.month - 1));

  // A pen bought at 60 and sold at 100; a note sold with no purchase price.
  final rows = [
    ProfitRow(month: lastMonth, productId: 1, jan: '4909999000014', name: 'テストペン', maker: 'テスト文具',
        quantity: 10, revenue: 1000, revenueCosted: 1000, cost: 600),
    ProfitRow(month: lastMonth, productId: 2, jan: '4909999000021', name: 'テストノート', maker: 'テスト紙工',
        quantity: 3, revenue: 150, revenueCosted: 0, cost: 0, qtyNoCost: 3),
    ProfitRow(month: thisMonth, productId: 1, jan: '4909999000014', name: 'テストペン', maker: 'テスト文具',
        quantity: 5, revenue: 2100, revenueCosted: 2100, cost: 350),
    ProfitRow(month: thisMonth, productId: 3, jan: '4909999000038', name: 'テスト消しゴム', maker: 'テスト紙工',
        quantity: 4, revenue: 200, revenueCosted: 200, cost: 280),
  ];

  test('months are filled in order and a missing purchase price stays out of the profit', () {
    final months = monthsBetween(DateTime(2026, 11), DateTime(2027, 2));
    expect(months, ['2026-11', '2026-12', '2027-01', '2027-02']);
    final m = profitByMonth([lastMonth, thisMonth], rows, (_) => true);
    expect(m.first.revenue, 1150);
    expect(m.first.profit, 400);
    expect(m.first.qtyNoCost, 3);
    expect(m.first.revenueNoCost, 150);
    expect(m.last.profit, 1750 - 80);
    final byProduct = profitByProduct(rows, (_) => true);
    expect(byProduct.first.first.name, 'テストペン');
    expect(byProduct.first.total.profit, 400 + 1750);
    expect(byProduct.last.first.name, 'テスト消しゴム');
  });

  testWidgets('the months as bars, narrowed by maker and by product', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeProfitRepository(rows);
    await pumpApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: MonthlyProfitSection())),
      overrides: [profitRepositoryProvider.overrideWithValue(repo)],
    );
    // The last 12 months up to this one.
    expect(repo.asked.single.from, DateTime(now.year, now.month - 11, 1));

    String totals() => tester.widget<Text>(find.byKey(const ValueKey('pf-totals'))).data!;
    expect(totals(), contains('売上 ¥3,450'));
    expect(totals(), contains('収益 ¥2,070'));
    expect(find.byKey(ValueKey('pf-bar-$lastMonth')), findsOneWidget);
    expect(find.byKey(ValueKey('pf-row-$thisMonth')), findsOneWidget);
    expect(find.textContaining('仕入値がわからない 3個（売上 ¥150）'), findsOneWidget);

    // One maker.
    await tester.tap(find.byKey(const ValueKey('pf-maker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('テスト紙工').last);
    await tester.pumpAndSettle();
    expect(totals(), contains('売上 ¥350'));
    expect(totals(), contains('収益 -¥80'));
    expect(find.byKey(const ValueKey('pf-product-p1')), findsNothing);

    // One product, from the list under the chart.
    await tester.tap(find.byKey(const ValueKey('pf-clear')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pf-product-p1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pf-product-chip')), findsOneWidget);
    expect(totals(), contains('売上 ¥3,100'));
    expect(totals(), contains('収益 ¥2,150'));
    expect(find.byKey(const ValueKey('pf-no-cost')), findsNothing);

    // By name, and the measure changed to sales.
    await tester.tap(find.byKey(const ValueKey('pf-clear')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('pf-search')), '消しゴム');
    await tester.pumpAndSettle();
    expect(totals(), contains('売上 ¥200'));
    await tester.tap(find.text('売上').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pf-chart')), findsOneWidget);
  });

  testWidgets('在庫外出荷 apart (0213): its fee is a cost, and each kind can be shown alone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final rows = [
      ProfitRow(month: thisMonth, productId: 1, name: 'テストペン', maker: 'テスト文具',
          quantity: 10, revenue: 1000, revenueCosted: 1000, cost: 600),
      ProfitRow(month: thisMonth, productId: 1, name: 'テストペン', maker: 'テスト文具',
          quantity: 10, revenue: 1000, revenueCosted: 1000, cost: 600, kind: 'proxy', fee: 150),
    ];
    await pumpApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: MonthlyProfitSection())),
      overrides: [profitRepositoryProvider.overrideWithValue(FakeProfitRepository(rows))],
    );
    String totals() => tester.widget<Text>(find.byKey(const ValueKey('pf-totals'))).data!;
    expect(totals(), contains('収益 ¥650'));
    expect(totals(), contains('委託手数料 ¥150'));
    expect(find.textContaining('自社在庫から ¥400　在庫外出荷 ¥250'), findsOneWidget);

    await tester.tap(find.text('在庫外出荷').first);
    await tester.pumpAndSettle();
    expect(totals(), contains('収益 ¥250'));
    await tester.tap(find.text('自社在庫から'));
    await tester.pumpAndSettle();
    expect(totals(), contains('収益 ¥400'));
    expect(totals(), isNot(contains('委託手数料')));
  });

  testWidgets('輸送費 (0214) is a cost: in the totals, the table and the split', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final rows = [
      ProfitRow(month: thisMonth, productId: 1, name: 'テストペン', maker: 'テスト文具',
          quantity: 10, revenue: 1000, revenueCosted: 1000, cost: 600, freight: 80),
      ProfitRow(month: thisMonth, productId: 1, name: 'テストペン', maker: 'テスト文具',
          quantity: 10, revenue: 1000, revenueCosted: 1000, cost: 600, kind: 'proxy', fee: 150, freight: 20),
    ];
    final m = profitByMonth([thisMonth], rows, (_) => true).single;
    expect(m.costAll, 600 + 600 + 150 + 100);
    expect(m.profitStock, 320);
    expect(m.profitProxy, 230);
    await pumpApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: MonthlyProfitSection())),
      overrides: [profitRepositoryProvider.overrideWithValue(FakeProfitRepository(rows))],
    );
    String totals() => tester.widget<Text>(find.byKey(const ValueKey('pf-totals'))).data!;
    expect(totals(), contains('原価 ¥1,450'));
    expect(totals(), contains('収益 ¥550'));
    expect(totals(), contains('輸送費 ¥100'));
    expect(find.textContaining('自社在庫から ¥320　在庫外出荷 ¥230'), findsOneWidget);
    expect(find.text('輸送費'), findsWidgets);
    expect(ProfitRow.fromJson({'month': thisMonth, 'product_name': 'x', 'freight': '12.5'}).freight, 12.5);
  });

  testWidgets('nothing shipped yet says so', (tester) async {
    await pumpApp(tester, const Scaffold(body: SingleChildScrollView(child: MonthlyProfitSection())));
    expect(find.byKey(const ValueKey('pf-empty')), findsOneWidget);
  });
}
