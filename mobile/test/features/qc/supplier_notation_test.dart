// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/product/application/product_providers.dart';
import 'package:wms_mobile/features/product/domain/product.dart';
import 'package:wms_mobile/features/qc/application/attachment_providers.dart';
import 'package:wms_mobile/features/qc/application/inspection_providers.dart';
import 'package:wms_mobile/features/qc/domain/bulk_inspection.dart';
import 'package:wms_mobile/features/qc/domain/inspection.dart';
import 'package:wms_mobile/features/qc/presentation/bulk_inspection_screen.dart';
import 'package:wms_mobile/features/qc/presentation/inspection_detail_screen.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';
import 'package:wms_mobile/features/warehouse_context/domain/warehouse.dart';
import 'package:wms_mobile/features/warehouse_context/domain/warehouse_role.dart';
import 'package:wms_mobile/features/warehouse_context/presentation/warehouse_overview_screen.dart';

import '../../support/harness.dart';

/// One line converted from the supplier's writing, one nothing matched.
Inspection _delivery({InspectionMethod method = InspectionMethod.full}) => Inspection(
      id: 1,
      status: QcResult.pending,
      deliveryNumber: 'T-0103',
      supplierName: 'テスト問屋',
      method: method,
      samplePercent: method == InspectionMethod.sample ? 10 : null,
      sampleMin: method == InspectionMethod.sample ? 2 : null,
      items: [
        InspectionItem(
          id: 10,
          productId: 81,
          janCode: '4999000001045',
          productName: 'TEST 麦茶',
          productSku: 'MG-1',
          productMaker: 'テスト食品',
          srcJanCode: '1234567890128',
          srcProductCode: 'ｍｕｇｉ－１',
          srcProductName: 'ムギチャ',
          convertedBy: 'supplier_code',
          expectedQuantity: 50,
          actualQuantity: 50,
          passedQuantity: 0,
          failedQuantity: 0,
          discrepancy: 0,
          result: QcResult.pending,
          sampleQuantity: method == InspectionMethod.sample ? 5 : null,
        ),
        InspectionItem(
          id: 11,
          janCode: '4988888888888',
          productName: '謎の茶',
          srcJanCode: '4988888888888',
          srcProductCode: 'X-9',
          srcProductName: '謎の茶',
          srcMaker: '謎メーカー',
          expectedQuantity: 3,
          actualQuantity: 3,
          passedQuantity: 0,
          failedQuantity: 0,
          discrepancy: 0,
          result: QcResult.pending,
        ),
      ],
    );

Future<void> _pump(WidgetTester tester, FakeInspectionRepository repo,
    {FakeProductRepository? products}) async {
  await tester.binding.setSurfaceSize(const Size(900, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(overrides: [
    fakeScanModeOverride(),
    inspectionRepositoryProvider.overrideWithValue(repo),
    attachmentRepositoryProvider.overrideWithValue(FakeAttachmentRepository()),
    productRepositoryProvider.overrideWithValue(products ?? FakeProductRepository()),
  ]);
  addTearDown(container.dispose);
  await pumpAppWith(tester, container, const InspectionDetailScreen(inspectionId: 1));
  await tester.pumpAndSettle();
}

void main() {
  test('a JAN compares as the server does: widths, hyphens, UPC and case codes', () {
    expect(normalizeJan('４９０１２３４-５６７８９４'), '4901234567894');
    expect(normalizeJan('14901234567894'), '4901234567894');
    expect(normalizeJan('04901234567894'), '4901234567894');
    expect(normalizeJan('012345678905'), '0012345678905');
    expect(normalizeJan('abc'), isNull);
  });

  testWidgets('ours in front, the supplier\'s writing faded beside it; unconverted lines block',
      (tester) async {
    final repo = FakeInspectionRepository(_delivery());
    await _pump(tester, repo);

    expect(find.text('4999000001045 · 品番 MG-1 · テスト食品'), findsOneWidget);
    expect(find.text('仕入先表記：ムギチャ · JAN 1234567890128 · 品番 ｍｕｇｉ－１'), findsOneWidget);
    final faded = tester.widget<Text>(find.byKey(const ValueKey('qc-src-10')));
    expect(faded.style!.color!.a, lessThan(1));

    expect(find.byKey(const ValueKey('qc-unconverted-11')), findsOneWidget);
    expect(find.byKey(const ValueKey('qc-unconverted-10')), findsNothing);
    expect(find.text('未変換 1行'), findsOneWidget);
    // An unconverted line cannot be passed on its own either.
    expect(find.byKey(const ValueKey('qc-pass-all-11')), findsNothing);
    expect(find.byKey(const ValueKey('qc-pass-all-10')), findsOneWidget);

    await tester.tap(find.text('検品を確定'));
    await tester.pumpAndSettle();
    expect(find.textContaining('自社商品に変換していない行が1行あります'), findsOneWidget);
    expect(repo.inspection.status, QcResult.pending);
  });

  testWidgets('a line is converted to one of ours, and the writing remembered', (tester) async {
    final repo = FakeInspectionRepository(_delivery());
    final products = FakeProductRepository(products: [
      Product(id: 82, janCode: '4999000001052', name: '謎の茶 ほうじ', sku: 'HJ-1', maker: 'テスト食品'),
    ]);
    await _pump(tester, repo, products: products);

    await tester.tap(find.byKey(const ValueKey('qc-convert-11')));
    await tester.pumpAndSettle();
    expect(find.text('自社商品に変換'), findsWidgets);
    // Opens on a search for how the supplier wrote it.
    expect(find.text('4999000001052 · 品番 HJ-1 · テスト食品'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('qc-convert-pick-82')));
    await tester.pumpAndSettle();
    expect(repo.lastConvert, (itemId: 11, productId: 82, remember: true));
    expect(find.text('「謎の茶 ほうじ」に変換しました'), findsOneWidget);
  });

  testWidgets('remembering can be switched off', (tester) async {
    final repo = FakeInspectionRepository(_delivery());
    final products = FakeProductRepository(products: [
      Product(id: 82, janCode: '4999000001052', name: '謎の茶 ほうじ'),
    ]);
    await _pump(tester, repo, products: products);
    await tester.tap(find.byKey(const ValueKey('qc-convert-11')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('qc-convert-remember')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('qc-convert-pick-82')));
    await tester.pumpAndSettle();
    expect(repo.lastConvert?.remember, isFalse);
  });

  testWidgets('a scan of the JAN as the supplier wrote it finds our line', (tester) async {
    final repo = FakeInspectionRepository(_delivery());
    await _pump(tester, repo);
    await tester.enterText(find.byType(TextField).first, '1234-5678-90128');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    // Per-piece scanning is off by default, so it asks for the count.
    expect(find.byKey(const ValueKey('qc-count-field')), findsOneWidget);
  });

  testWidgets('a sampling inspection counts scans toward the sample, then passes the line',
      (tester) async {
    final repo = FakeInspectionRepository(_delivery(method: InspectionMethod.sample));
    await _pump(tester, repo);
    expect(find.text('抜き取り検品（10%・最低2個）'), findsOneWidget);
    expect(find.text('抜き取り 0/5'), findsOneWidget);

    for (var i = 0; i < 4; i++) {
      await tester.enterText(find.byType(TextField).first, '4999000001045');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }
    expect(find.text('抜き取り 4/5'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('qc-sample-add-10')));
    await tester.pumpAndSettle();
    expect(find.text('TEST 麦茶：抜き取りが済み、この行を合格にしました'), findsOneWidget);
    expect(find.text('抜き取り 5/5'), findsOneWidget);
    expect(repo.counts.every((c) => c.mode == InspectionCountMode.sample), isTrue);
    final line = repo.inspection.items.first;
    expect(line.countedQuantity, 50);
  });

  testWidgets('bulk inspection leaves unconverted lines out', (tester) async {
    final repo = FakeInspectionRepository()
      ..openLineList = [
        OpenInspectionLine(
            itemId: 1, inspectionId: 10, reconciliationId: 100, productId: 81,
            janCode: '4999000001045', productName: 'TEST 麦茶', quantity: 50,
            srcProductName: 'ムギチャ'),
        OpenInspectionLine(
            itemId: 2, inspectionId: 10, reconciliationId: 100,
            janCode: '4988888888888', productName: '謎の茶', quantity: 3),
      ];
    await pumpApp(tester, const BulkInspectionScreen(), overrides: [
      inspectionRepositoryProvider.overrideWithValue(repo),
    ]);
    expect(find.text('未変換'), findsOneWidget);
    expect(find.text('仕入先表記：ムギチャ'), findsOneWidget);
    expect(find.text('選択 1 行・計 50 点'), findsOneWidget);
    final box = tester.widget<CheckboxListTile>(find.byKey(const ValueKey('bulk-qc-line-2')));
    expect(box.onChanged, isNull);
  });

  testWidgets('a warehouse is set to receive only, or to sample', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final roles = FakeWarehouseRoleRepository([
      WarehouseRole(id: 1, code: 'KOBE', name: '神戸倉庫', countryCode: 'JP'),
      WarehouseRole(id: 2, code: 'OUT', name: '委託倉庫', countryCode: 'JP'),
    ]);
    final container = ProviderContainer(overrides: [
      warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(
        WarehouseOverview(
          warehouses: [
            Warehouse(id: 1, code: 'KOBE', name: '神戸倉庫'),
            Warehouse(id: 2, code: 'OUT', name: '委託倉庫'),
          ],
          totals: WarehouseTotals(warehouseCount: 2),
        ),
      )),
      warehouseRoleRepositoryProvider.overrideWithValue(roles),
    ]);
    addTearDown(container.dispose);
    await pumpAppWith(tester, container, const WarehouseOverviewScreen());
    await tester.pumpAndSettle();

    // A new warehouse inspects everything.
    expect(find.text('全数検品'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('wh-inspection-edit-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wh-inspection-NONE')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wh-inspection-save')));
    await tester.pumpAndSettle();
    expect(roles.lastInspection?.id, 2);
    expect(roles.lastInspection?.mode, WarehouseInspectionMode.none);
    expect(find.text('検品不要（仕入のみ）'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('wh-inspection-edit-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wh-inspection-SAMPLE')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('wh-sample-percent')), '20');
    await tester.enterText(find.byKey(const ValueKey('wh-sample-min')), '3');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wh-inspection-save')));
    await tester.pumpAndSettle();
    expect(roles.lastInspection, (id: 1, mode: WarehouseInspectionMode.sample, percent: 20, min: 3));
    expect(find.text('抜き取り 20%（最低3）'), findsOneWidget);
  });
}
