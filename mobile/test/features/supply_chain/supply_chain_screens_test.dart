// Test fixtures are plain JSON-shaped literals.
// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/partners/application/trading_partner_providers.dart';
import 'package:wms_mobile/features/partners/domain/trading_partner.dart';
import 'package:wms_mobile/features/product/application/product_providers.dart';
import 'package:wms_mobile/features/product/domain/product.dart';
import 'package:wms_mobile/features/purchasing/domain/purchase_order.dart';
import 'package:wms_mobile/features/supply_chain/application/supply_chain_providers.dart';
import 'package:wms_mobile/features/supply_chain/domain/supply_chain.dart';
import 'package:wms_mobile/features/supply_chain/presentation/sc_bottleneck_screen.dart';
import 'package:wms_mobile/features/supply_chain/presentation/sc_cost_structure_screen.dart';
import 'package:wms_mobile/features/supply_chain/presentation/sc_dashboard_screen.dart';
import 'package:wms_mobile/features/supply_chain/presentation/sc_history_screen.dart';
import 'package:wms_mobile/features/supply_chain/presentation/sc_product_sheet.dart';
import 'package:wms_mobile/features/supply_chain/presentation/sc_purchase_check.dart';
import 'package:wms_mobile/features/supply_chain/presentation/sc_risk_screen.dart';
import 'package:wms_mobile/features/supply_chain/presentation/sc_routes_screen.dart';
import 'package:wms_mobile/features/supply_chain/presentation/sc_simulation_screen.dart';
import 'package:wms_mobile/features/supply_chain/presentation/sc_supplier_comparison_screen.dart';

import '../../support/harness.dart';
import 'sc_fixtures.dart';

Future<FakeSupplyChainRepository> _pump(
  WidgetTester tester,
  Widget screen, {
  FakeSupplyChainRepository? repo,
  bool manage = true,
  List<Override> extra = const [],
}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final r = repo ?? FakeSupplyChainRepository(dashboardRun: dashboardRun(), modelData: scModel());
  await pumpApp(tester, screen, overrides: [
    supplyChainRepositoryProvider.overrideWithValue(r),
    scCanViewProvider.overrideWithValue(true),
    scCanManageProvider.overrideWithValue(manage),
    ...extra,
  ]);
  return r;
}

void main() {
  test('the engine output parses, and scenario params go back as the engine reads them', () {
    final run = dashboardRun();
    final p = run.products.single;
    expect(p.unit[CostLine.purchase], 700);
    expect(p.unit.landed, closeTo(831.305, 1e-9));
    expect(p.chosen.single.routeName, 'A 船便');
    expect(p.options, hasLength(3));
    expect(run.bottlenecks.first.status, LoadStatus.exceeded);
    expect(run.risks.last.level, RiskLevel.high);

    const params = ScScenarioParams(
      supplierPriceMultiplier: 1.1,
      discountRates: {1: 0.65},
      seaFreightMultiplier: 1.2,
      warehouseCostMultiplier: 1,
      routeMode: 'air',
      enabledSuppliers: {2, 1},
      lotQuantity: 1000,
    );
    final json = params.toJson();
    expect(json, {
      'supplier_price_multiplier': 1.1,
      'discount_rate_overrides': {'1': 0.65},
      'freight_multipliers': {'sea': 1.2},
      'route_mode': 'air',
      'supplier_enabled': [1, 2],
      'lot_quantity': 1000,
    });
    expect(ScScenarioParams.fromJson(json), params.copyForTest());
  });

  testWidgets('the dashboard shows what is left after every cost, and what needs attention', (tester) async {
    final repo = await _pump(tester, const ScDashboardScreen());

    expect(find.byKey(const ValueKey('sc-kpi-revenue')), findsOneWidget);
    expect(find.text('¥21,600,000'), findsOneWidget); // 1,800 × 12,000
    expect(find.byKey(const ValueKey('sc-kpi-profit')), findsOneWidget);
    expect(find.text('48.8%'), findsWidgets);
    expect(find.text('容量超過・停止 1件'), findsOneWidget);
    expect(find.text('高リスク 1件'), findsOneWidget);
    expect(find.byKey(const ValueKey('sc-product-1')), findsOneWidget);
    expect(find.textContaining('Supplier A / A 船便'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sc-snapshot')));
    await tester.pumpAndSettle();
    expect(repo.lastSave, isTrue);
    expect(find.text('現在の状態を保存しました'), findsOneWidget);
  });

  testWidgets('with nothing to cost, the dashboard offers to take terms from purchase history', (tester) async {
    final repo = await _pump(tester, const ScDashboardScreen(), repo: FakeSupplyChainRepository());

    expect(find.text('まだ原価を計算できる商品がありません'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sc-seed')));
    await tester.pumpAndSettle();
    expect(repo.seedCalls, 1);
    expect(find.text('発注から2件、納品書から1件を取り込みました'), findsOneWidget);
  });

  testWidgets('a price rise is simulated next to the current numbers, with its causes', (tester) async {
    final repo = await _pump(
      tester,
      const ScSimulationScreen(),
      repo: FakeSupplyChainRepository(modelData: scModel(), comparison: priceUpComparison()),
    );

    await tester.enterText(find.byKey(const ValueKey('sc-sim-name')), '値上げ');
    await tester.enterText(find.byKey(const ValueKey('sc-sim-price')), '+10');
    await tester.enterText(find.byKey(const ValueKey('sc-sim-rate-1')), '65');
    await tester.tap(find.byKey(const ValueKey('sc-sim-route-air')));
    await tester.tap(find.byKey(const ValueKey('sc-sim-supplier-2')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sc-sim-run')));
    await tester.pumpAndSettle();

    final sent = repo.lastRunParams!.toJson();
    expect(sent['supplier_price_multiplier'], closeTo(1.1, 1e-9));
    expect(sent['discount_rate_overrides'], {'1': 0.65});
    expect(sent['route_mode'], 'air');
    expect(sent['supplier_enabled'], [1]);
    expect(repo.lastRunName, '値上げ');

    // Current and simulated are separate columns, and the change is signed.
    expect(find.byKey(const ValueKey('sc-compare-table')), findsOneWidget);
    expect(find.text('現在'), findsWidgets);
    expect(find.text('シミュレーション'), findsOneWidget);
    expect(find.text('-¥883,140'), findsWidgets);
    expect(find.text('変動の原因'), findsOneWidget);
    expect(find.text('+¥840,000'), findsWidgets); // 仕入 +¥70 × 12,000

    await tester.tap(find.byKey(const ValueKey('sc-sim-save')));
    await tester.pumpAndSettle();
    expect(repo.lastScenario?.name, '値上げ');
  });

  testWidgets('up to five scenarios are compared, and the system does not pick one', (tester) async {
    final multi = ScMultiComparison.fromJson({
      'baseline': {'name': '', 'summary': runJson()['summary'], 'risks_high': 1, 'bottlenecks_exceeded': 1, 'delta_profit': 0},
      'scenarios': [
        {'name': 'B', 'summary': runJson()['summary'], 'risks_high': 0, 'bottlenecks_exceeded': 1, 'delta_profit': 600000},
      ],
    });
    final repo = await _pump(tester, const ScSimulationScreen(),
        repo: FakeSupplyChainRepository(modelData: scModel(), multi: multi));

    await tester.enterText(find.byKey(const ValueKey('sc-sim-name')), 'B');
    await tester.tap(find.byKey(const ValueKey('sc-sim-choice-cheapest')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sc-sim-add-compare')));
    await tester.pumpAndSettle();
    expect(find.text('どれが最良かはシステムでは決めません。利益・納期・リスクを見て判断してください。'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sc-sim-run-compare')));
    await tester.pumpAndSettle();
    expect(repo.lastCompare!.single.$1, 'B');
    expect(repo.lastCompare!.single.$2.supplierChoice, 'cheapest');
    expect(find.byKey(const ValueKey('sc-multi-table')), findsOneWidget);
    expect(find.text('+¥600,000'), findsOneWidget);
  });

  testWidgets('suppliers are compared by what is left, and 掛率 are swept', (tester) async {
    final view = ScProductView.fromJson({
      'product': productJson(),
      'sweeps': [
        {'rate': 0.65, 'options': [optionJson(key: '1:100', partnerId: 1, partner: 'Supplier A', routeId: 100, route: 'A 船便', mode: 'sea', unit: unitJson(purchase: 650))]},
        {'rate': 0.75, 'options': [optionJson(key: '1:100', partnerId: 1, partner: 'Supplier A', routeId: 100, route: 'A 船便', mode: 'sea', unit: unitJson(purchase: 750))]},
      ],
    });
    final repo = await _pump(
      tester,
      const ScSupplierComparisonScreen(initialProductId: 1),
      repo: FakeSupplyChainRepository(modelData: scModel(), productViewData: view),
      extra: [
        tradingPartnerRepositoryProvider.overrideWithValue(FakeTradingPartnerRepository(partners: const [
          TradingPartner(id: 1, name: 'Supplier A'),
          TradingPartner(id: 2, name: 'Supplier B'),
          TradingPartner(id: 3, name: 'Supplier C'),
        ])),
      ],
    );

    expect(find.byKey(const ValueKey('sc-options-table')), findsOneWidget);
    expect(find.text('A 航空便'), findsOneWidget);
    expect(find.text('B 船便'), findsOneWidget);
    expect(find.text('70%'), findsWidgets);

    await tester.enterText(find.byKey(const ValueKey('sc-compare-rates')), '65,75');
    await tester.enterText(find.byKey(const ValueKey('sc-compare-qty')), '1000');
    await tester.tap(find.byKey(const ValueKey('sc-compare-apply')));
    await tester.pumpAndSettle();
    expect(repo.lastProduct!.rates, [0.65, 0.75]);
    expect(find.byKey(const ValueKey('sc-sweep-table')), findsOneWidget);

    // A new supplier's terms for this product.
    await tester.tap(find.byKey(const ValueKey('sc-add-term')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sc-term-partner')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supplier C').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('sc-term-list')), '1000');
    await tester.enterText(find.byKey(const ValueKey('sc-term-rate')), '68');
    await tester.enterText(find.byKey(const ValueKey('sc-term-lead')), '10');
    await tester.tap(find.byKey(const ValueKey('sc-term-save')));
    await tester.pumpAndSettle();
    expect(repo.lastTerm?.partnerId, 3);
    expect(repo.lastTerm?.productId, 1);
    expect(repo.lastTerm?.discountRate, closeTo(0.68, 1e-9));
    expect(repo.lastTerm?.leadTimeDays, 10);
  });

  testWidgets('a route is drawn leg by leg, and a leg can be taken into a scenario', (tester) async {
    await _pump(tester, const ScRoutesScreen());

    expect(find.byKey(const ValueKey('sc-route-100')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sc-leg-100-2')));
    await tester.pumpAndSettle();
    expect(find.text('船便 · 上海港 → 大阪港'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sc-apply-route')));
    await tester.pumpAndSettle();
    expect(find.byType(ScSimulationScreen), findsOneWidget);
    final chip = tester.widget<ChoiceChip>(find.byKey(const ValueKey('sc-sim-route-sea')));
    expect(chip.selected, isTrue);
  });

  testWidgets('a site over capacity shows its load, and a 14-day stop is costed', (tester) async {
    final repo = await _pump(
      tester,
      const ScBottleneckScreen(),
      repo: FakeSupplyChainRepository(dashboardRun: dashboardRun(), modelData: scModel(), comparison: portClosedComparison()),
    );

    expect(find.byKey(const ValueKey('sc-load-node-21')), findsOneWidget);
    expect(find.textContaining('負荷 125%'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sc-disruption-target')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('港: 大阪港').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sc-disruption-run')));
    await tester.pumpAndSettle();

    expect(repo.lastDisruptions!.single, containsPair('node_id', 21));
    expect(repo.lastDisruptions!.single, containsPair('days', 14.0));
    expect(find.byKey(const ValueKey('sc-disruption-impact')), findsOneWidget);
    expect(find.text('-¥107,250'), findsWidgets);
    expect(find.textContaining('代替: Supplier A / A 航空便'), findsOneWidget);
  });

  testWidgets('each risk says why, and a risk can be registered', (tester) async {
    final repo = await _pump(tester, const ScRiskScreen());

    expect(find.byKey(const ValueKey('sc-risk-supplier-1')), findsOneWidget);
    expect(find.text('• 遅延率 20%'), findsOneWidget);
    expect(find.text('• 登録リスク: 仕入先の値上げ'), findsOneWidget);
    expect(find.text('• 容量超過'), findsOneWidget);
    expect(find.byKey(const ValueKey('sc-risk-event-3')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sc-add-risk-event')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('sc-event-title')), '大阪港ストライキ');
    await tester.tap(find.byKey(const ValueKey('sc-event-save')));
    await tester.pumpAndSettle();
    expect(repo.lastEvent?.title, '大阪港ストライキ');
  });

  testWidgets('cost rules, duty and FX are kept as data, never in code', (tester) async {
    final repo = await _pump(tester, const ScCostStructureScreen());

    await tester.tap(find.byKey(const ValueKey('sc-tab-rules')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sc-rule-1')), findsOneWidget);
    expect(find.text('5.00%'), findsOneWidget); // 販売手数料

    await tester.tap(find.byKey(const ValueKey('sc-add-rule')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('sc-rule-name')), '梱包');
    await tester.enterText(find.byKey(const ValueKey('sc-rule-amount')), '120');
    await tester.tap(find.byKey(const ValueKey('sc-rule-save')));
    await tester.pumpAndSettle();
    expect(repo.lastRule?.name, '梱包');
    expect(repo.lastRule?.amount, 120);

    await tester.tap(find.byKey(const ValueKey('sc-tab-fx')));
    await tester.pumpAndSettle();
    expect(find.text('21.5 JPY'), findsOneWidget);
  });

  testWidgets('a saved scenario can be run again against today', (tester) async {
    await _pump(
      tester,
      const ScHistoryScreen(),
      repo: FakeSupplyChainRepository(modelData: scModel(), scenarioRows: [
        ScScenario.fromJson({
          'id': 4,
          'name': 'B追加',
          'params': {'supplier_choice': 'cheapest', 'freight_multiplier': 1.2},
          'last_run': {'profit': 1000000, 'baseline_profit': 900000},
        }),
      ]),
    );

    expect(find.textContaining('+¥100,000'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sc-scenario-run-4')));
    await tester.pumpAndSettle();
    expect(find.byType(ScSimulationScreen), findsOneWidget);
    expect(find.widgetWithText(TextField, 'B追加'), findsOneWidget);
    expect(tester.widget<ChoiceChip>(find.byKey(const ValueKey('sc-sim-choice-cheapest'))).selected, isTrue);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('sc-sim-freight'))).controller!.text, '+20');
  });

  testWidgets('the product detail card shows the current source and each option', (tester) async {
    await _pump(
      tester,
      const Scaffold(body: SingleChildScrollView(child: ScProductProfitCard(productId: 1))),
      repo: FakeSupplyChainRepository(productViewData: ScProductView.fromJson({'product': productJson()})),
    );

    expect(find.byKey(const ValueKey('sc-product-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('sc-waterfall-profit')), findsOneWidget);
    expect(find.textContaining('Supplier B / B 船便'), findsOneWidget);
  });

  testWidgets('a purchase that thins the margin is shown before it is placed (§30)', (tester) async {
    final repo = FakeSupplyChainRepository(checks: [
      ScPurchaseCheck.fromJson({
        'product_id': 1, 'partner_id': 1, 'name': 'ABC-001', 'unit_price': 900,
        'margin_before': 0.488, 'margin_after': 0.36, 'warn': ['margin_drop'],
        'drivers': [{'line': 'purchase', 'delta': 200}],
      }),
    ]);
    bool? go;
    await _pump(
      tester,
      Consumer(builder: (context, ref, _) => Scaffold(
            body: FilledButton(
              onPressed: () async => go = await scConfirmPurchaseProfit(context, ref,
                  supplierName: 'Supplier A',
                  warehouseId: 1,
                  lines: const [PurchaseOrderLineDraft(janCode: '4901234567894', quantity: 1000, unitPrice: 900)]),
              child: const Text('発注'),
            ),
          )),
      repo: repo,
      extra: [
        tradingPartnerRepositoryProvider.overrideWithValue(FakeTradingPartnerRepository(partners: const [TradingPartner(id: 1, name: 'Supplier A')])),
        productRepositoryProvider.overrideWithValue(FakeProductRepository(products: const [
          Product(id: 1, janCode: '4901234567894', name: 'ABC-001', maker: 'テスト文具'),
        ])),
      ],
    );

    await tester.tap(find.text('発注'));
    await tester.pumpAndSettle();
    expect(repo.lastCheckLines!.single, {'product_id': 1, 'partner_id': 1, 'unit_price': 900.0, 'quantity': 1000});
    expect(find.byKey(const ValueKey('sc-profit-warning')), findsOneWidget);
    expect(find.text('今回の条件では利益率が 48.8% → 36.0% に変わります。'), findsOneWidget);
    expect(find.text('利益率が大きく下がります'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sc-continue-order')));
    await tester.pumpAndSettle();
    expect(go, isTrue);
  });

  testWidgets('without the permission the order goes ahead unchecked', (tester) async {
    final repo = FakeSupplyChainRepository();
    bool? go;
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(
      tester,
      Consumer(builder: (context, ref, _) => Scaffold(
            body: FilledButton(
              onPressed: () async => go = await scConfirmPurchaseProfit(context, ref,
                  supplierName: 'Supplier A', warehouseId: 1, lines: const [PurchaseOrderLineDraft(janCode: '4901234567894', quantity: 1, unitPrice: 900)]),
              child: const Text('発注'),
            ),
          )),
      overrides: [supplyChainRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.tap(find.text('発注'));
    await tester.pumpAndSettle();
    expect(go, isTrue);
    expect(repo.lastCheckLines, isNull);
  });
}

extension on ScScenarioParams {
  /// The same params as they come back from JSON: multipliers of 1 dropped.
  ScScenarioParams copyForTest() => ScScenarioParams.fromJson(toJson());
}
