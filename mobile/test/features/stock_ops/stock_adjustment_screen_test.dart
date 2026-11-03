import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/product/application/product_providers.dart';
import 'package:wms_mobile/features/product/domain/product.dart';
import 'package:wms_mobile/features/stock_ops/application/stock_ops_providers.dart';
import 'package:wms_mobile/features/stock_ops/domain/stock_ops.dart';
import 'package:wms_mobile/features/stock_ops/presentation/stock_adjustment_screen.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';
import 'package:wms_mobile/features/warehouse_context/domain/warehouse.dart';

import '../../support/harness.dart';

void main() {
  testWidgets('removing stock posts a negative delta', (tester) async {
    final repo = FakeStockOpsRepository();

    await pumpApp(
      tester,
      const StockAdjustmentScreen(),
      overrides: [
        stockOpsRepositoryProvider.overrideWithValue(repo),
        writeWarehouseIdProvider.overrideWithValue(3),
      ],
    );

    await tester.tap(find.text('在庫を調整'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('adj-jan')), '4901234567894');
    // "減少" is preselected; entering 5 must reach the server as -5.
    await tester.enterText(find.byKey(const Key('adj-quantity')), '5');
    await tester.tap(find.widgetWithText(FilledButton, '調整を確定'));
    await tester.pumpAndSettle();
    // A confirmation dialog gates the actual write (§36 — irreversible).
    expect(repo.lastDelta, isNull);
    await tester.tap(find.widgetWithText(FilledButton, '調整する'));
    await tester.pumpAndSettle();

    expect(repo.lastDelta, -5);
    expect(repo.lastWarehouseId, 3);
    expect(find.text('在庫を調整しました（-5）'), findsOneWidget);
  });

  testWidgets(
      'a permission-denied write shows the friendly message, not the raw RPC text (§34)',
      (tester) async {
    final repo = FakeStockOpsRepository()
      ..failWith = 'not permitted: inventory.adjust required';

    await pumpApp(
      tester,
      const StockAdjustmentScreen(),
      overrides: [
        stockOpsRepositoryProvider.overrideWithValue(repo),
        writeWarehouseIdProvider.overrideWithValue(3),
      ],
    );

    await tester.tap(find.text('在庫を調整'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('adj-jan')), '4901234567894');
    await tester.enterText(find.byKey(const Key('adj-quantity')), '5');
    await tester.tap(find.widgetWithText(FilledButton, '調整を確定'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '調整する'));
    await tester.pumpAndSettle();

    expect(find.text('この操作を行う権限がありません。'), findsOneWidget);
    expect(find.textContaining('inventory.adjust'), findsNothing);
  });

  testWidgets('the JAN field offers a scan button, not just the keyboard (§35)',
      (tester) async {
    final repo = FakeStockOpsRepository();

    await pumpApp(
      tester,
      const StockAdjustmentScreen(),
      overrides: [
        stockOpsRepositoryProvider.overrideWithValue(repo),
        writeWarehouseIdProvider.overrideWithValue(3),
      ],
    );

    await tester.tap(find.text('在庫を調整'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.qr_code_scanner_outlined), findsOneWidget);
  });

  testWidgets('cancelling the confirmation dialog posts nothing',
      (tester) async {
    final repo = FakeStockOpsRepository();

    await pumpApp(
      tester,
      const StockAdjustmentScreen(),
      overrides: [
        stockOpsRepositoryProvider.overrideWithValue(repo),
        writeWarehouseIdProvider.overrideWithValue(3),
      ],
    );

    await tester.tap(find.text('在庫を調整'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('adj-jan')), '4901234567894');
    await tester.enterText(find.byKey(const Key('adj-quantity')), '5');
    await tester.tap(find.widgetWithText(FilledButton, '調整を確定'));
    await tester.pumpAndSettle();

    expect(find.text('在庫を調整しますか？'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'キャンセル'));
    await tester.pumpAndSettle();

    expect(repo.lastDelta, isNull);
  });

  testWidgets('the chosen reason travels with the adjustment', (tester) async {
    final repo = FakeStockOpsRepository();

    await pumpApp(
      tester,
      const StockAdjustmentScreen(),
      overrides: [
        stockOpsRepositoryProvider.overrideWithValue(repo),
        writeWarehouseIdProvider.overrideWithValue(3),
      ],
    );

    await tester.tap(find.text('在庫を調整'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('adj-jan')), '4901234567894');
    await tester.enterText(find.byKey(const Key('adj-quantity')), '2');
    await tester.ensureVisible(find.text('紛失'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('紛失'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '調整を確定'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '調整する'));
    await tester.pumpAndSettle();

    expect(repo.lastReason, AdjustReason.loss);
    expect(repo.lastDelta, -2);
  });

  testWidgets('stock consumed internally is its own reason, not OTHER',
      (tester) async {
    final repo = FakeStockOpsRepository();

    await pumpApp(
      tester,
      const StockAdjustmentScreen(),
      overrides: [
        stockOpsRepositoryProvider.overrideWithValue(repo),
        writeWarehouseIdProvider.overrideWithValue(3),
      ],
    );

    await tester.tap(find.text('在庫を調整'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('adj-jan')), '4901234567894');
    await tester.enterText(find.byKey(const Key('adj-quantity')), '3');
    await tester.ensureVisible(find.text('社内消費'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('社内消費'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '調整を確定'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '調整する'));
    await tester.pumpAndSettle();

    expect(repo.lastReason, AdjustReason.internalUse);
    expect(repo.lastDelta, -3);
  });

  testWidgets('adding stock posts a positive delta', (tester) async {
    final repo = FakeStockOpsRepository();

    await pumpApp(
      tester,
      const StockAdjustmentScreen(),
      overrides: [
        stockOpsRepositoryProvider.overrideWithValue(repo),
        writeWarehouseIdProvider.overrideWithValue(3),
      ],
    );

    await tester.tap(find.text('在庫を調整'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('adj-jan')), '4901234567894');
    await tester.enterText(find.byKey(const Key('adj-quantity')), '5');
    await tester.tap(find.text('追加'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '調整を確定'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '調整する'));
    await tester.pumpAndSettle();

    expect(repo.lastDelta, 5);
  });

  testWidgets('with no resolvable warehouse the form refuses to open',
      (tester) async {
    final repo = FakeStockOpsRepository();

    await pumpApp(
      tester,
      const StockAdjustmentScreen(),
      overrides: [
        stockOpsRepositoryProvider.overrideWithValue(repo),
        writeWarehouseIdProvider.overrideWithValue(null),
      ],
    );

    await tester.tap(find.text('在庫を調整'));
    await tester.pumpAndSettle();

    expect(find.text('先に倉庫を選んでください'), findsOneWidget);
    expect(repo.lastDelta, isNull);
  });

  const lib = [
    Product(
      id: 1,
      janCode: '4909999000014',
      name: '試験用ボールペン 黒',
      maker: 'テスト文具',
      sku: 'BP-100',
      stock: ProductStock(onHand: 12, warehouses: [
        WarehouseStock(warehouseId: 3, name: '本倉庫', onHand: 7),
        WarehouseStock(warehouseId: 4, name: '別倉庫', onHand: 5),
      ]),
    ),
    Product(id: 2, janCode: '4909999000021', name: '試験用ノート A5', maker: 'サンプル紙工', sku: 'NT-A5'),
    Product(id: 3, janCode: '4909999000038', name: '試験用消しゴム', maker: 'テスト文具', sku: 'ER-3'),
  ];

  List<Override> withLibrary(FakeStockOpsRepository repo, {int? warehouseId = 3}) => [
        stockOpsRepositoryProvider.overrideWithValue(repo),
        writeWarehouseIdProvider.overrideWithValue(warehouseId),
        productRepositoryProvider.overrideWithValue(FakeProductRepository(products: lib)),
      ];

  testWidgets('pressing a product opens its adjustment, the JAN already chosen', (tester) async {
    final repo = FakeStockOpsRepository();
    await pumpApp(tester, const StockAdjustmentScreen(), overrides: withLibrary(repo));

    // Every product, with what it has in this warehouse.
    expect(find.text('試験用ボールペン 黒'), findsOneWidget);
    expect(find.text('試験用ノート A5'), findsOneWidget);
    expect(find.text('在庫 7'), findsOneWidget);

    await tester.tap(find.text('試験用ボールペン 黒'));
    await tester.pumpAndSettle();

    // No JAN to key: the product is shown, with its stock here.
    expect(find.byKey(const Key('adj-jan')), findsNothing);
    expect(find.byKey(const Key('adj-sheet-product')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('adj-on-hand'))).data, '7');

    await tester.enterText(find.byKey(const Key('adj-quantity')), '2');
    await tester.pumpAndSettle();
    // 減少 2 → 5 after.
    expect(tester.widget<Text>(find.byKey(const Key('adj-after'))).data, '5');

    await tester.tap(find.widgetWithText(FilledButton, '調整を確定'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '調整する'));
    await tester.pumpAndSettle();

    expect(repo.lastJan, '4909999000014');
    expect(repo.lastDelta, -2);
    expect(repo.lastWarehouseId, 3);
  });

  testWidgets('the search finds products by name, maker, JAN or 品番 (full-width too)', (tester) async {
    await pumpApp(tester, const StockAdjustmentScreen(), overrides: withLibrary(FakeStockOpsRepository()));
    final search = find.byKey(const Key('adj-search'));

    Future<void> type(String q) async {
      await tester.enterText(search, q);
      await tester.pumpAndSettle();
    }

    await type('テスト文具');
    expect(find.text('試験用ボールペン 黒'), findsOneWidget);
    expect(find.text('試験用消しゴム'), findsOneWidget);
    expect(find.text('試験用ノート A5'), findsNothing);

    await type('000021');
    expect(find.text('試験用ノート A5'), findsOneWidget);
    expect(find.text('試験用ボールペン 黒'), findsNothing);

    await type('ｂｐ－'); // full-width 品番
    expect(find.text('試験用ボールペン 黒'), findsOneWidget);
    expect(find.text('試験用消しゴム'), findsNothing);

    // Every word must match.
    await type('テスト 消し');
    expect(find.text('試験用消しゴム'), findsOneWidget);
    expect(find.text('試験用ボールペン 黒'), findsNothing);

    await type('見つからない');
    expect(find.text('条件に合う商品がありません'), findsOneWidget);
  });

  testWidgets('the maker filter and 在庫ありのみ narrow the list', (tester) async {
    await pumpApp(tester, const StockAdjustmentScreen(), overrides: withLibrary(FakeStockOpsRepository()));

    await tester.tap(find.byKey(const Key('adj-maker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('サンプル紙工').last);
    await tester.pumpAndSettle();
    expect(find.text('試験用ノート A5'), findsOneWidget);
    expect(find.text('試験用ボールペン 黒'), findsNothing);
    expect(find.text('1 / 3 件'), findsOneWidget);

    await tester.tap(find.text('絞り込みを解除'));
    await tester.pumpAndSettle();
    expect(find.text('3 / 3 件'), findsOneWidget);

    await tester.tap(find.byKey(const Key('adj-in-stock')));
    await tester.pumpAndSettle();
    expect(find.text('試験用ボールペン 黒'), findsOneWidget);
    expect(find.text('試験用ノート A5'), findsNothing);
  });

  testWidgets('a history entry opens that product again', (tester) async {
    final repo = FakeStockOpsRepository(adjustmentLog: const [
      StockAdjustment(id: 9, janCode: '4909999000014', quantityDelta: -1, reason: AdjustReason.damage, productName: '試験用ボールペン 黒'),
      StockAdjustment(id: 8, janCode: '4909999000999', quantityDelta: 3, reason: AdjustReason.other, productName: '旧商品'),
    ]);
    await pumpApp(tester, const StockAdjustmentScreen(), overrides: withLibrary(repo));

    await tester.tap(find.byKey(const Key('adj-tab-history')));
    await tester.pumpAndSettle();

    // The search narrows the history too.
    await tester.enterText(find.byKey(const Key('adj-search')), '旧商品');
    await tester.pumpAndSettle();
    expect(find.text('試験用ボールペン 黒'), findsNothing);
    // Not in the library: the JAN is filled in to be adjusted.
    await tester.tap(find.widgetWithText(Card, '旧商品'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('adj-jan'))).controller!.text, '4909999000999');
    Navigator.of(tester.element(find.byKey(const Key('adj-jan')))).pop();
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('adj-search')), '');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Card, '試験用ボールペン 黒'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('adj-sheet-product')), findsOneWidget);
    expect(find.byKey(const Key('adj-jan')), findsNothing);
  });

  test('adjustProductMatches: words, maker, stock here', () {
    final pen = lib.first;
    expect(adjustProductMatches(pen, ''), isTrue);
    expect(adjustProductMatches(pen, 'ボールペン bp-100'), isTrue);
    expect(adjustProductMatches(pen, '４９０９９９９００００１４'), isTrue);
    expect(adjustProductMatches(pen, 'ノート'), isFalse);
    expect(adjustProductMatches(pen, '', maker: 'サンプル紙工'), isFalse);
    expect(adjustOnHand(pen, 3), 7);
    expect(adjustOnHand(pen, null), 12);
    expect(adjustOnHand(pen, 9), 0);
    expect(adjustProductMatches(pen, '', inStockOnly: true, warehouseId: 9), isFalse);
  });

  test('a write only resolves "all warehouses" when there is exactly one', () {
    ProviderContainer containerFor(List<Warehouse> warehouses) =>
        ProviderContainer(overrides: [
          warehouseRepositoryProvider.overrideWithValue(
            FakeWarehouseRepository(WarehouseOverview(
              warehouses: warehouses,
              totals: const WarehouseTotals(),
            )),
          ),
        ]);

    const one = Warehouse(id: 1, code: 'MAIN', name: 'メイン倉庫');
    const two = Warehouse(id: 2, code: 'SUB', name: 'サブ倉庫');

    final single = containerFor([one]);
    addTearDown(single.dispose);
    final multi = containerFor([one, two]);
    addTearDown(multi.dispose);

    // The overview has to be resolved before the derived provider can read it.
    return Future.wait([
      single.read(warehouseOverviewProvider.future),
      multi.read(warehouseOverviewProvider.future),
    ]).then((_) {
      expect(single.read(writeWarehouseIdProvider), 1);
      // Two warehouses and no active one: never guess which building.
      expect(multi.read(writeWarehouseIdProvider), isNull);
    });
  });
}
