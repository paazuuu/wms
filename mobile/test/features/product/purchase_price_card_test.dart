import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/ui/time_line_chart.dart';
import 'package:wms_mobile/features/partners/domain/trading_partner.dart';
import 'package:wms_mobile/features/product/data/purchase_price_repository.dart';
import 'package:wms_mobile/features/product/presentation/purchase_price_card.dart';
import 'package:wms_mobile/features/purchase_request/presentation/purchase_request_screen.dart' show requestSuppliersProvider;

import '../../support/fake_purchase_price_repository.dart';
import '../../support/harness.dart';

PurchasePrices _prices() => PurchasePrices(
      points: [
        PricePoint(id: 'r1-1', source: PriceSource.receipt, day: DateTime(2026, 7, 1), unitPrice: 80, unitPriceTax: 88,
            supplierId: 42, supplierName: 'テスト卸', quantity: 100, fileName: 'a.pdf'),
        PricePoint(id: 'r2-1', source: PriceSource.receipt, day: DateTime(2026, 8, 3), unitPrice: 78, unitPriceTax: 85.8,
            supplierId: 43, supplierName: 'サンプル商事', quantity: 50),
        PricePoint(id: 'm1', source: PriceSource.manual, day: DateTime(2026, 9, 9), unitPrice: 76, unitPriceTax: 83.6,
            supplierName: '電話の仕入先', quantity: 10, entryId: 1),
        PricePoint(id: 'o1', source: PriceSource.outbound, day: DateTime(2026, 10, 1), unitPrice: 90, unitPriceTax: 99,
            supplierName: 'テスト卸', quantity: 20, fileName: '到货明细.xlsx'),
      ],
      monthly: [
        PriceMonth(month: DateTime(2026, 7), average: 80, min: 80, max: 80, quantity: 100, count: 1),
        PriceMonth(month: DateTime(2026, 8), average: 78, min: 78, max: 78, quantity: 50, count: 1),
        PriceMonth(month: DateTime(2026, 9), average: 76, min: 76, max: 76, quantity: 10, count: 1),
      ],
      suppliers: [
        SupplierPrice(supplierName: '電話の仕入先', count: 1, average: 76, lastPrice: 76, lastDay: DateTime(2026, 9, 9)),
        SupplierPrice(supplierId: 43, supplierName: 'サンプル商事', count: 1, average: 78, lastPrice: 78, lastDay: DateTime(2026, 8, 3)),
        SupplierPrice(supplierId: 42, supplierName: 'テスト卸', count: 1, average: 80, lastPrice: 80, lastDay: DateTime(2026, 7, 1)),
      ],
    );

void main() {
  test('series: the month\'s average, each supplier, the rest folded, the shipping list on its own', () {
    const colors = [Colors.blue, Colors.orange, Colors.teal, Colors.amber];
    final s = purchasePriceSeries(_prices(),
        colors: colors, averageLabel: 'avg', othersLabel: 'others', outboundLabel: 'out', noSupplierLabel: '-');
    expect(s.map((e) => e.id), ['avg', 'id:42', 'others', 'outbound']);
    expect(s.first.points.map((p) => p.y), [80, 78, 76]);
    expect(s[2].points.length, 2);
    expect(s.last.points.single.y, 90);
    expect(s.last.color, Colors.amber);
  });

  testWidgets('the product\'s prices by supplier and month; one written and one withdrawn', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakePurchasePriceRepository(prices: _prices());
    await pumpApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: PurchasePriceCard(productId: 5))),
      overrides: [
        purchasePriceRepositoryProvider.overrideWithValue(repo),
        canRecordPurchasePriceProvider.overrideWithValue(true),
        requestSuppliersProvider.overrideWith((ref) async => const [TradingPartner(id: 42, name: 'テスト卸')]),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('仕入れ値の推移'), findsOneWidget);
    expect(find.byType(TimeLineChart), findsOneWidget);
    expect(find.text('月平均（全仕入先）'), findsOneWidget);
    expect(find.text('出荷リストの単価'), findsOneWidget);
    expect(find.byKey(const ValueKey('pp-supplier-id:43')), findsOneWidget);
    expect(find.text('最新 78（2026/08/03） · 平均 78 · 1回'), findsOneWidget);
    expect(find.byKey(const ValueKey('pp-month-2026-9')), findsOneWidget);
    expect(find.textContaining('2026/10/01 · 出荷リスト'), findsOneWidget);

    // A hand-written one can be withdrawn; one from a file cannot.
    expect(find.byKey(const ValueKey('pp-withdraw-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pp-withdraw-1')));
    await tester.pumpAndSettle();
    expect(repo.withdrawn, [1]);

    await tester.tap(find.byKey(const ValueKey('pp-record')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pp-save')));
    await tester.pumpAndSettle();
    expect(find.text('単価を入れてください'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('pp-price')), '72.5');
    await tester.tap(find.byKey(const ValueKey('pp-save')));
    await tester.pumpAndSettle();
    expect(find.text('仕入先を選ぶか名前を入れてください'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pp-supplier')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('テスト卸').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('pp-qty')), '30');
    await tester.tap(find.byKey(const ValueKey('pp-save')));
    await tester.pumpAndSettle();
    expect(repo.recorded.single['unit_price'], 72.5);
    expect(repo.recorded.single['supplier_id'], 42);
    expect(repo.recorded.single['quantity'], 30);
    expect(find.text('仕入れ値を記録しました'), findsOneWidget);
  });

  testWidgets('nothing yet: says where prices come from', (tester) async {
    await pumpApp(tester, const Scaffold(body: PurchasePriceCard(productId: 5)),
        overrides: [canRecordPurchasePriceProvider.overrideWithValue(false)]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pp-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('pp-record')), findsNothing);
  });

  testWidgets('hidden from someone who may not see what was paid', (tester) async {
    await pumpApp(tester, const Scaffold(body: PurchasePriceCard(productId: 5)), overrides: [
      purchasePriceRepositoryProvider.overrideWithValue(FakePurchasePriceRepository(failWith: 'not permitted: report.view required')),
      canRecordPurchasePriceProvider.overrideWithValue(false),
    ]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pp-card')), findsNothing);
  });
}
