import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/partners/application/trading_partner_providers.dart';
import 'package:wms_mobile/features/product/application/product_providers.dart';
import 'package:wms_mobile/features/product/domain/product.dart';
import 'package:wms_mobile/features/product/presentation/product_detail_screen.dart';
import 'package:wms_mobile/features/product/presentation/product_labels.dart';
import 'package:wms_mobile/features/shipment/application/packaging_providers.dart';
import 'package:wms_mobile/features/shipment/domain/packaging.dart';
import 'package:wms_mobile/features/shipment/presentation/carton_types_screen.dart';
import 'package:wms_mobile/features/shipment/presentation/shipment_weight_card.dart';
import 'package:wms_mobile/features/supply_chain/application/supply_chain_providers.dart';

import '../../support/harness.dart';

const _pen = Product(
  id: 1,
  janCode: '4901681233922',
  name: 'サラサドライ 0.5 青',
  baseUom: Uom(code: 'PCS', name: '本'),
  uoms: [
    ProductUom(code: 'PCS', name: '本', conversionFactor: 1, isBase: true),
    ProductUom(code: 'DOZEN', name: 'ダース', conversionFactor: 12, isBase: false,
        packageWeightG: 30, packWeightG: 156),
  ],
);

Future<FakeProductRepository> _pumpProduct(WidgetTester tester, Product product) async {
  await tester.binding.setSurfaceSize(const Size(1000, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final repo = FakeProductRepository(products: [product]);
  final container = ProviderContainer(overrides: [
    productRepositoryProvider.overrideWithValue(repo),
    tradingPartnerRepositoryProvider.overrideWithValue(FakeTradingPartnerRepository()),
    scCanViewProvider.overrideWithValue(false),
  ]);
  addTearDown(container.dispose);
  await pumpAppWith(tester, container, ProductDetailScreen(productId: product.id));
  return repo;
}

Future<FakePackagingRepository> _pumpCard(WidgetTester tester, ShipmentWeightEstimate weight) async {
  await tester.binding.setSurfaceSize(const Size(900, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final repo = FakePackagingRepository(weight: weight);
  await pumpApp(
    tester,
    const Scaffold(body: SingleChildScrollView(child: ShipmentWeightCard(planId: 7))),
    overrides: [packagingRepositoryProvider.overrideWithValue(repo)],
  );
  return repo;
}

void main() {
  test('grams read as g, and as kg from a kilogram up', () {
    expect(gramsText(10.5), '10.5 g');
    expect(gramsText(156), '156 g');
    expect(gramsText(1650), '1.65 kg');
    expect(gramsText(2000), '2 kg');
  });

  test('the estimate reads its goods, boxes and missing weights', () {
    final e = ShipmentWeightEstimate.fromJson(const {
      'lines': [
        {'product_id': 1, 'jan_code': 'a', 'product_name': 'A', 'quantity': 100, 'unit_weight_g': 10.5, 'line_weight_g': 1050},
        {'product_id': 2, 'jan_code': 'b', 'product_name': 'B', 'quantity': 50, 'unit_weight_g': null},
      ],
      'goods_weight_g': 1050, 'missing_weights': 1, 'cartons_from': 'planned',
      'planned': [{'carton_type_id': 2, 'carton_type': '80サイズ', 'quantity': 2, 'empty_weight_g': 250}],
      'carton_count': 2, 'boxes_weight_g': 500, 'packing_material_g': 100, 'total_weight_g': 1650,
    });
    expect(e.fromCartons, isFalse);
    expect(e.lines.where((l) => l.missing).single.productName, 'B');
    expect(e.planned.single.quantity, 2);
    expect(e.totalWeightG, 1650);
    expect(const CartonType(name: 'x', lengthCm: 40, widthCm: 30, heightCm: 30).sizeText, '40×30×30 cm');
  });

  testWidgets('a product without a weight says so, and one can be entered', (tester) async {
    final repo = await _pumpProduct(tester, _pen);

    expect(find.textContaining('まだ重量が入っていません'), findsOneWidget);
    // The dozen shows what it weighs.
    expect(find.textContaining('156 g'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('wt-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('wt-weight')), '10.5');
    await tester.tap(find.text('ネットで調べた値'));
    await tester.enterText(find.byKey(const ValueKey('wt-url')), 'https://example.com/pen');
    await tester.tap(find.byKey(const ValueKey('wt-save')));
    await tester.pumpAndSettle();

    final w = repo.setWeights.single;
    expect(w.unitWeightG, 10.5);
    expect(w.source, 'web');
    expect(w.url, 'https://example.com/pen');
  });

  testWidgets('a weight shows per base unit with where it came from, and can be cleared', (tester) async {
    const weighed = Product(
      id: 1, janCode: '4901681233922', name: 'サラサドライ 0.5 青',
      baseUom: Uom(code: 'PCS', name: '本'), unitWeightG: 10.5, weightSource: 'measured');
    final repo = await _pumpProduct(tester, weighed);

    expect(find.byKey(const ValueKey('wt-value')), findsOneWidget);
    expect(find.text('10.5 g / 1個'), findsOneWidget);
    expect(find.text('実測'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('wt-edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wt-clear')));
    await tester.pumpAndSettle();
    expect(repo.setWeights.single.unitWeightG, isNull);
  });

  testWidgets('a pack size is edited with its box weight', (tester) async {
    final repo = await _pumpProduct(tester, _pen);

    await tester.tap(find.byKey(const ValueKey('uom-DOZEN')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('uom-package')), '35');
    await tester.enterText(find.byKey(const ValueKey('uom-gross')), '170');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    final p = repo.setPacks.single;
    expect(p.uomCode, 'DOZEN');
    expect(p.factor, 12);
    expect(p.packageWeightG, 35);
    expect(p.grossWeightG, 170);
  });

  testWidgets('the shipment card adds goods, boxes and packing, and plans boxes', (tester) async {
    const weight = ShipmentWeightEstimate(
      lines: [
        WeightLine(productId: 1, janCode: 'a', productName: 'A', quantity: 100, unitWeightG: 10.5, lineWeightG: 1050),
        WeightLine(productId: 2, janCode: 'b', productName: 'ノートB', quantity: 50),
      ],
      goodsWeightG: 1050,
      missingWeights: 1,
      totalWeightG: 1050,
      suggested: [PlannedCarton(cartonTypeId: 1, cartonType: '80サイズ', quantity: 1)],
    );
    final repo = await _pumpCard(tester, weight);

    expect(find.text('≈ 1.05 kg'), findsOneWidget);
    expect(find.textContaining('1件の商品に重量がなく'), findsOneWidget);
    expect(find.textContaining('80サイズ×1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sw-plan')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sw-plus-2')));
    await tester.tap(find.byKey(const ValueKey('sw-plus-2')));
    await tester.pump();
    expect(find.text('2'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('sw-plan-save')));
    await tester.pumpAndSettle();

    final items = repo.planned.single;
    expect(items.single.cartonTypeId, 2);
    expect(items.single.quantity, 2);
  });

  testWidgets('a packed carton takes a box type, filling its weights', (tester) async {
    const weight = ShipmentWeightEstimate(
      fromCartons: true,
      cartons: [EstimateCarton(cartonId: 21, cartonNo: 1, contentsWeightG: 800)],
      cartonCount: 1,
      goodsWeightG: 800,
      totalWeightG: 800,
    );
    final repo = await _pumpCard(tester, weight);

    expect(find.textContaining('1箱目'), findsOneWidget);
    await tester.tap(find.byTooltip('ダンボールの種類と重さ'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sw-box-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('100サイズ').last);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const ValueKey('sw-box-empty'))).controller!.text, '400');
    await tester.tap(find.byKey(const ValueKey('sw-box-save')));
    await tester.pumpAndSettle();

    final p = repo.packaging.single;
    expect(p.cartonId, 21);
    expect(p.typeId, 2);
    expect(p.empty, 400);
    expect(p.material, 80);
  });

  testWidgets('box types are added with their size and weights', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakePackagingRepository();
    await pumpApp(tester, const CartonTypesScreen(),
        overrides: [packagingRepositoryProvider.overrideWithValue(repo)]);

    expect(find.text('100サイズ'), findsOneWidget);
    expect(find.textContaining('40×30×30 cm'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ct-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('ct-name')), '宅配袋');
    await tester.enterText(find.byKey(const ValueKey('ct-empty')), '40');
    await tester.enterText(find.byKey(const ValueKey('ct-max')), '2');
    await tester.tap(find.byKey(const ValueKey('ct-save')));
    await tester.pumpAndSettle();

    final t = repo.saved.single;
    expect(t.name, '宅配袋');
    expect(t.emptyWeightG, 40);
    expect(t.maxLoadKg, 2);
    expect(t.id, isNull);
  });
}
