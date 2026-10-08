// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/product/application/product_filter.dart';
import 'package:wms_mobile/features/product/application/product_providers.dart';
import 'package:wms_mobile/features/product/domain/product.dart';
import 'package:wms_mobile/features/product/presentation/product_list_screen.dart';
import 'package:wms_mobile/features/product_library/application/product_library_providers.dart';
import 'package:wms_mobile/features/supply_chain/application/supply_chain_providers.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';
import 'package:wms_mobile/features/warehouse_context/domain/warehouse.dart';

import '../../support/harness.dart';

/// Pumped as someone who manages products (product.manage) unless [manage]
/// is false; [delete] adds product.delete (0119).
Future<ProviderContainer> _pump(
    WidgetTester tester, FakeProductRepository repo,
    {bool manage = true, bool delete = false, bool lifecycle = false, List<Warehouse> warehouses = const []}) async {
  final container = ProviderContainer(overrides: [
    productRepositoryProvider.overrideWithValue(repo),
    warehouseRepositoryProvider.overrideWithValue(
        FakeWarehouseRepository(WarehouseOverview(warehouses: warehouses, totals: const WarehouseTotals()))),
    scCanViewProvider.overrideWithValue(false),
  ]);
  addTearDown(container.dispose);
  await pumpAppWith(
    tester,
    container,
    ProviderScope(
      overrides: [
        productLibraryCanManageProvider.overrideWithValue(manage),
        productCanDeleteProvider.overrideWithValue(delete),
        productCanLifecycleProvider.overrideWithValue(lifecycle),
      ],
      child: const ProductListScreen(),
    ),
  );
  return container;
}

void main() {
  testWidgets('lists products with JAN, category and price', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeProductRepository(products: const [
      Product(
        id: 1,
        janCode: '4902505632037',
        name: 'ボールペン',
        category: '文房具',
        price: 150,
      ),
    ]);
    await _pump(tester, repo);

    expect(find.text('ボールペン'), findsOneWidget);
    expect(find.text('4902505632037'), findsOneWidget);
    expect(find.text('文房具'), findsOneWidget);
    expect(find.text('¥150'), findsOneWidget);
    expect(find.text('取扱中'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('the empty state explains how to add the first product',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeProductRepository();
    await _pump(tester, repo);

    expect(find.text('商品がまだありません'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('adding a product via the form appears in the list',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeProductRepository();
    await _pump(tester, repo);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('new-manual')));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'JANコード'), '4901234567890');
    await tester.enterText(find.widgetWithText(TextField, '商品名'), 'テストペン');
    await tester.enterText(find.byKey(const ValueKey('product-maker')), 'テスト文具');
    await tester.enterText(find.widgetWithText(TextField, '価格'), '300');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('テストペン'), findsOneWidget);
    expect(find.text('¥300'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'a permission-denied save shows the friendly message, not the raw RPC text (§34)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeProductRepository()
      ..failCreateWith = 'not permitted: product.manage required';
    await _pump(tester, repo);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('new-manual')));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'JANコード'), '4901234567890');
    await tester.enterText(find.widgetWithText(TextField, '商品名'), 'テストペン');
    await tester.enterText(find.byKey(const ValueKey('product-maker')), 'テスト文具');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('この操作を行う権限がありません。'), findsOneWidget);
    expect(find.textContaining('product.manage'), findsNothing);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      "a new product's JAN field offers a scan button, not just the keyboard (§35)",
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeProductRepository();
    await _pump(tester, repo);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('new-manual')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.qr_code_scanner_outlined), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('tapping a product opens its detail, not the edit form',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeProductRepository(products: const [
      Product(id: 1, janCode: '4902505632037', name: 'ボールペン'),
    ]);
    await _pump(tester, repo);

    await tester.tap(find.text('ボールペン'));
    await tester.pumpAndSettle();

    // Master-detail: the list opens the product, and editing is an action on
    // the detail. (The form itself is covered by product_form_sheet_test.)
    expect(find.text('商品詳細'), findsOneWidget);
    expect(find.text('バーコード'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'JANコード'), findsNothing);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'deactivating a product asks for confirmation first (§36)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeProductRepository(products: const [
      Product(id: 1, janCode: '4902505632037', name: 'ボールペン'),
    ]);
    await _pump(tester, repo);

    // Reveal inactive products too, so the row survives its own deactivation
    // (the default list is active-only).
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pumpAndSettle();

    expect(find.text('取扱中'), findsOneWidget);
    await tester.tap(find.text('取扱中'));
    await tester.pumpAndSettle();

    expect(find.text('この商品を休眠にしますか？'), findsOneWidget);
    // Not yet applied — still shown as active behind the dialog.
    expect(find.text('取扱中'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '休眠にする'));
    await tester.pumpAndSettle();

    expect(find.text('休眠'), findsOneWidget);
  });

  testWidgets(
      'cancelling the confirmation leaves the product active',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeProductRepository(products: const [
      Product(id: 1, janCode: '4902505632037', name: 'ボールペン'),
    ]);
    await _pump(tester, repo);

    await tester.tap(find.text('取扱中'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'キャンセル'));
    await tester.pumpAndSettle();

    expect(find.text('取扱中'), findsOneWidget);
    expect(find.text('休眠'), findsNothing);
  });

  testWidgets(
      'reactivating an inactive product needs no confirmation',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeProductRepository(products: const [
      Product(id: 1, janCode: '4902505632037', name: 'ボールペン', status: 'inactive'),
    ]);
    await _pump(tester, repo);

    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pumpAndSettle();

    expect(find.text('休眠'), findsOneWidget);
    await tester.tap(find.text('休眠'));
    await tester.pumpAndSettle();

    // No dialog appears — reactivating is harmless (§36's "don't overuse
    // confirmations" side).
    expect(find.text('この商品を休眠にしますか？'), findsNothing);
    expect(find.text('取扱中'), findsOneWidget);
  });

  testWidgets('a card shows the SKU, base unit, pack units and tracking mode',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeProductRepository(products: const [
      Product(
        id: 1,
        janCode: '4902505632037',
        name: 'ボールペン',
        sku: 'PEN-001',
        trackingMode: TrackingMode.lot,
        baseUom: Uom(code: 'PCS', name: '個'),
        uoms: [
          ProductUom(
              code: 'PCS', name: '個', conversionFactor: 1, isBase: true),
          ProductUom(
              code: 'BOX', name: '箱', conversionFactor: 12, isBase: false),
        ],
        barcodes: [
          ProductBarcode(
            id: 1,
            barcode: '4902505632037',
            barcodeType: 'JAN',
            isPrimary: true,
            quantityPerScan: 1,
          ),
          ProductBarcode(
            id: 2,
            barcode: '14902505632034',
            barcodeType: 'CASE',
            isPrimary: false,
            quantityPerScan: 12,
            uom: 'BOX',
          ),
        ],
      ),
    ]);
    await _pump(tester, repo);

    // The supplier's barcode and this warehouse's own code, side by side.
    expect(find.text('4902505632037'), findsOneWidget);
    expect(find.text('PEN-001'), findsOneWidget);
    // What the quantities are counted in, and what a box converts to.
    expect(find.text('基本単位: 個'), findsOneWidget);
    expect(find.text('BOX = 12個'), findsOneWidget);
    // Lot-tracked, so receiving will ask for a lot — worth knowing beforehand.
    expect(find.text('ロット'), findsOneWidget);
    // Two codes reach this product.
    expect(find.text('コード 2 件'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('an untracked product with one code shows no chips at all',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeProductRepository(products: const [
      Product(id: 1, janCode: '4902505632037', name: 'ボールペン'),
    ]);
    await _pump(tester, repo);

    // Nothing to say is said with nothing: no base unit, no tracking chip, and
    // no code count for a product reachable by exactly one barcode. (The search
    // box's own hint mentions JANコード, hence the exact-text match here.)
    expect(find.text('追跡なし'), findsNothing);
    expect(find.text('コード 1 件'), findsNothing);
    expect(find.textContaining('基本単位'), findsNothing);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('someone who only views sees the products, with no add, edit or delete', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeProductRepository(products: const [
      Product(id: 1, janCode: '4902505632037', name: 'ボールペン'),
    ]);
    await _pump(tester, repo, manage: false);

    expect(find.text('ボールペン'), findsOneWidget);
    expect(find.byKey(const ValueKey('products-add')), findsNothing);
    expect(find.byKey(const ValueKey('products-from-library')), findsNothing);
    expect(find.byKey(const ValueKey('product-menu-1')), findsNothing);
    // The status reads, but tapping it changes nothing.
    await tester.tap(find.text('取扱中'));
    await tester.pumpAndSettle();
    expect(find.text('この商品を休眠にしますか？'), findsNothing);
  });

  testWidgets('managing products offers adding, editing and the quotation import, not deleting', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeProductRepository(products: const [
      Product(id: 1, janCode: '4902505632037', name: 'ボールペン'),
    ]);
    await _pump(tester, repo);

    expect(find.byKey(const ValueKey('products-add')), findsOneWidget);
    // 新規登録 offers a file of our own, the price book, and one by hand.
    await tester.tap(find.byKey(const ValueKey('products-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('new-file')), findsOneWidget);
    expect(find.byKey(const ValueKey('new-price-book')), findsOneWidget);
    expect(find.byKey(const ValueKey('new-manual')), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('product-menu-1')));
    await tester.pumpAndSettle();
    expect(find.text('編集'), findsOneWidget);
    expect(find.byKey(const ValueKey('product-delete-1')), findsNothing);
  });

  testWidgets('with product.delete an unused product is deleted after asking', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeProductRepository(products: const [
      Product(id: 1, janCode: '4902505632037', name: 'ボールペン'),
    ]);
    await _pump(tester, repo, delete: true);

    await tester.tap(find.byKey(const ValueKey('product-menu-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('product-delete-1')));
    await tester.pumpAndSettle();
    expect(find.text('この商品を削除しますか？'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('product-delete-confirm')));
    await tester.pumpAndSettle();

    expect(repo.deleted, [1]);
    expect(find.text('ボールペン'), findsNothing);
  });

  testWidgets('a product in use is not deleted; deactivating it is offered instead', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeProductRepository(products: const [
      Product(id: 1, janCode: '4902505632037', name: 'ボールペン'),
    ])..inUse.add(1);
    await _pump(tester, repo, delete: true);
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('product-menu-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('product-delete-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('product-delete-confirm')));
    await tester.pumpAndSettle();

    expect(repo.deleted, isEmpty);
    expect(find.byKey(const ValueKey('product-delete-deactivate')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('product-delete-deactivate')));
    await tester.pumpAndSettle();
    expect(find.text('休眠'), findsOneWidget);
  });

  const stocked = Product(
    id: 1, janCode: '4902505632037', name: 'ボールペン', maker: '三菱鉛筆',
    suppliers: [ProductSupplierRef(id: 4, name: '新東光通商')],
    stock: ProductStock(onHand: 40, reserved: 10, available: 30, warehouses: [
      WarehouseStock(warehouseId: 1, name: 'メイン倉庫', onHand: 30, reserved: 10, available: 20),
      WarehouseStock(warehouseId: 2, name: '神戸倉庫', onHand: 10, available: 10),
    ]),
  );
  const empty = Product(id: 2, janCode: '4901681233922', name: 'サラサ', maker: 'ゼブラ', stock: ProductStock());
  const sleeping = Product(id: 3, janCode: '4901480344041', name: 'バインダー', maker: 'コクヨ',
      status: 'inactive', lifecycleCode: 'discontinued', lifecycleReason: 'メーカー廃番');

  testWidgets('the library shows each product\'s spec and its stock, not its suppliers', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const sized = Product(
      id: 1, janCode: '4902505632037', name: 'ボールペン', maker: '三菱鉛筆',
      suppliers: [ProductSupplierRef(id: 4, name: '新東光通商')],
      stock: ProductStock(onHand: 40, reserved: 10, available: 30),
      widthMm: 10, depthMm: 10, heightMm: 140, unitWeightG: 12,
    );
    await _pump(tester, FakeProductRepository(products: const [sized, empty]));

    expect(find.text('10×10×140 mm · 12 g'), findsOneWidget);
    expect(find.textContaining('新東光通商'), findsNothing);
    expect(find.byKey(const ValueKey('pf-supplier')), findsNothing);
    expect(find.text('在庫 40 · 引当 10 · 出荷可能 30'), findsOneWidget);
    expect(find.byKey(const ValueKey('pl-stock-0-2')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('pl-stock-0-2'))).data, '在庫なし');
    expect(find.text('2件を表示（全2件）'), findsOneWidget);
  });

  const main = Warehouse(id: 1, code: 'MAIN', name: 'メイン倉庫');
  const kobe = Warehouse(id: 2, code: 'KOBE', name: '神戸倉庫');

  testWidgets('the warehouse shown is named and chosen in a band; its stock filter is its own', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(tester, FakeProductRepository(products: const [stocked, empty]), warehouses: const [main, kobe]);

    // Every warehouse to begin with, said so.
    expect(find.text('表示中の倉庫: 全倉庫'), findsOneWidget);
    expect(tester.widget<ChoiceChip>(find.byKey(const ValueKey('pl-wh-all'))).selected, isTrue);
    expect(find.text('在庫 40 · 引当 10 · 出荷可能 30 (メイン倉庫 30 / 神戸倉庫 10)'), findsOneWidget);
    expect(find.text('在庫あり 1品目・合計 40個'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pl-wh-2')));
    await tester.pumpAndSettle();
    expect(find.text('表示中の倉庫: 神戸倉庫'), findsOneWidget);
    expect(find.text('在庫 10 · 引当 0 · 出荷可能 10'), findsOneWidget);
    expect(find.text('この倉庫に在庫なし'), findsOneWidget);
    expect(find.text('在庫あり 1品目・合計 10個'), findsOneWidget);

    // Only what this warehouse holds.
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('pl-stock-filter')), matching: find.text('在庫あり')));
    await tester.pumpAndSettle();
    expect(find.text('ボールペン'), findsOneWidget);
    expect(find.text('サラサ'), findsNothing);
    expect(find.text('1件を表示（全2件）'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('pl-stock-filter')), matching: find.text('在庫なし')));
    await tester.pumpAndSettle();
    expect(find.text('ボールペン'), findsNothing);
    expect(find.text('サラサ'), findsOneWidget);
  });

  testWidgets('two warehouses side by side, each with its own choice and stock', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const osakaOnly = Product(
      id: 4, janCode: '4901234567894', name: 'クリップ', maker: 'コクヨ',
      stock: ProductStock(onHand: 7, available: 7, warehouses: [WarehouseStock(warehouseId: 1, name: 'メイン倉庫', onHand: 7, available: 7)]),
    );
    final container = await _pump(tester, FakeProductRepository(products: const [stocked, osakaOnly]),
        warehouses: const [main, kobe]);

    expect(find.byKey(const ValueKey('pl-warehouse-bar-1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('pl-split')));
    await tester.pumpAndSettle();

    // The first two warehouses, one per pane, side by side.
    expect(find.byKey(const ValueKey('pl-warehouse-bar-1')), findsOneWidget);
    expect(find.text('表示中の倉庫: メイン倉庫'), findsOneWidget);
    expect(find.text('表示中の倉庫: 神戸倉庫'), findsOneWidget);
    final left = tester.getCenter(find.byKey(const ValueKey('pl-warehouse-bar')));
    final right = tester.getCenter(find.byKey(const ValueKey('pl-warehouse-bar-1')));
    expect(right.dx, greaterThan(left.dx));
    expect(tester.widget<Text>(find.byKey(const ValueKey('pl-stock-0-1'))).data, '在庫 30 · 引当 10 · 出荷可能 20');
    expect(tester.widget<Text>(find.byKey(const ValueKey('pl-stock-1-1'))).data, '在庫 10 · 引当 0 · 出荷可能 10');
    expect(tester.widget<Text>(find.byKey(const ValueKey('pl-stock-1-4'))).data, 'この倉庫に在庫なし');

    // Only the second pane narrows to its stock.
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('pl-stock-filter-1')), matching: find.text('在庫あり')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pl-stock-1-4')), findsNothing);
    expect(find.byKey(const ValueKey('pl-stock-0-4')), findsOneWidget);

    // The second pane can show every warehouse too.
    await tester.tap(find.byKey(const ValueKey('pl-wh-1-all')));
    await tester.pumpAndSettle();
    expect(container.read(libraryPaneWarehouseProvider(1)), isNull);
    expect(find.text('表示中の倉庫: 全倉庫'), findsOneWidget);

    // Back to one pane, keeping its warehouse.
    await tester.tap(find.byKey(const ValueKey('pl-split')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pl-warehouse-bar-1')), findsNothing);
    expect(find.text('表示中の倉庫: メイン倉庫'), findsOneWidget);
  });

  testWidgets('on a narrow screen the two panes are one above the other', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(tester, FakeProductRepository(products: const [stocked]), warehouses: const [main, kobe]);
    await tester.tap(find.byKey(const ValueKey('pl-split')));
    await tester.pumpAndSettle();
    final top = tester.getCenter(find.byKey(const ValueKey('pl-warehouse-bar')));
    final bottom = tester.getCenter(find.byKey(const ValueKey('pl-warehouse-bar-1')));
    expect(bottom.dy, greaterThan(top.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('with one warehouse there is nothing to split', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(tester, FakeProductRepository(products: const [stocked]), warehouses: const [main]);
    expect(find.byKey(const ValueKey('pl-split')), findsNothing);
    expect(find.byKey(const ValueKey('pl-wh-1')), findsOneWidget);
  });

  testWidgets('the master narrows by maker and state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = await _pump(tester, FakeProductRepository(products: const [stocked, empty, sleeping]));

    // Active products only, by default.
    expect(find.text('2件を表示（全3件）'), findsOneWidget);
    expect(find.text('バインダー'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('pf-maker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pf-opt-ゼブラ')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('サラサ'), findsOneWidget);
    expect(find.text('ボールペン'), findsNothing);
    expect(find.text('メーカー: ゼブラ'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pf-clear')));
    await tester.pumpAndSettle();
    expect(find.text('ボールペン'), findsOneWidget);

    // A discontinued one shows under its state, with why.
    container.read(productFilterProvider.notifier).state =
        const ProductFilter(lifecycles: {ProductLifecycle.discontinued});
    await tester.pumpAndSettle();
    expect(find.text('バインダー'), findsOneWidget);
    expect(find.text('提供終了'), findsOneWidget);
    expect(find.text('メーカー廃番'), findsOneWidget);
  });

  testWidgets('an admin chooses all and removes them for good; ones in use are kept (0126)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeProductRepository(products: const [stocked, empty, Product(id: 4, janCode: '4900000000004', name: 'ノート')])
      ..inUse.add(1);
    await _pump(tester, repo, delete: true);

    // product.delete alone is enough to choose; the state buttons need product.lifecycle.
    await tester.tap(find.byKey(const ValueKey('lc-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lc-select-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lc-to-archived')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('lc-remove')));
    await tester.pumpAndSettle();
    expect(find.text('3件を商品ライブラリーから完全に削除しますか？'), findsOneWidget);
    // Not until 削除 is typed.
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('rm-confirm'))).onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey('rm-word')), '削除');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rm-confirm')));
    await tester.pumpAndSettle();

    expect(repo.deleteManyCalls.single, [1, 2, 4]);
    expect(repo.deleted, [2, 4]);
    expect(find.textContaining('2件を完全に削除しました。1件は在庫・入出荷などの記録があるため'), findsOneWidget);
    expect(find.text('ボールペン'), findsOneWidget);
    expect(find.text('ノート'), findsNothing);
  });

  testWidgets('without product.delete there is no removing for good', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(tester, FakeProductRepository(products: const [stocked]), lifecycle: true);
    await tester.tap(find.byKey(const ValueKey('lc-start')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lc-to-archived')), findsOneWidget);
    expect(find.byKey(const ValueKey('lc-remove')), findsNothing);
  });

  testWidgets('without product.lifecycle there is no choosing many', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(tester, FakeProductRepository(products: const [stocked]));
    expect(find.byKey(const ValueKey('lc-start')), findsNothing);
  });

  testWidgets('the administrator chooses all, excludes one, and archives the rest with a reason', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeProductRepository(products: const [stocked, empty, Product(id: 4, janCode: '4900000000004', name: 'ノート')]);
    await _pump(tester, repo, lifecycle: true);

    await tester.tap(find.byKey(const ValueKey('lc-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lc-select-all')));
    await tester.pumpAndSettle();
    expect(find.text('3件を選択中'), findsWidgets);
    // Tapping a chosen product leaves it out.
    await tester.tap(find.text('サラサ'));
    await tester.pumpAndSettle();
    expect(find.text('2件を選択中'), findsWidgets);

    // The actions are labelled buttons in the bar at the bottom.
    expect(find.byKey(const ValueKey('lc-bar')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lc-to-archived')));
    await tester.pumpAndSettle();
    expect(find.text('2件を「アーカイブ」にしますか？'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('lc-reason')), '取扱い終了');
    await tester.tap(find.byKey(const ValueKey('lc-confirm')));
    await tester.pumpAndSettle();

    final call = repo.lifecycleCalls.single;
    expect(call.ids, [1, 4]);
    expect(call.lifecycle, ProductLifecycle.archived);
    expect(call.reason, '取扱い終了');
    // Out of the library; the one left out stays.
    expect(find.text('ボールペン'), findsNothing);
    expect(find.text('ノート'), findsNothing);
    expect(find.text('サラサ'), findsOneWidget);
    expect(find.byKey(const ValueKey('lc-select-all')), findsNothing);
  });

  test('the old on/off switch and the lifecycle agree', () {
    expect(const Product(id: 1, janCode: 'x', name: 'x', status: 'inactive').lifecycle, ProductLifecycle.dormant);
    expect(const Product(id: 1, janCode: 'x', name: 'x', lifecycleCode: 'archived', status: 'inactive').lifecycle,
        ProductLifecycle.archived);
    expect(stocked.withLifecycle(ProductLifecycle.discontinued).status, 'inactive');
    expect(sleeping.withLifecycle(ProductLifecycle.active).isActive, isTrue);
    final j = Product.fromJson(const {
      'id': 9, 'jan_code': '1', 'name': 'n', 'status': 'inactive', 'lifecycle': 'discontinued',
      'stock': {'on_hand': 5, 'reserved': 1, 'available': 4, 'warehouses': [{'warehouse_id': 1, 'name': 'A', 'on_hand': 5}]},
      'suppliers': [{'id': 4, 'name': 'S'}],
    });
    expect(j.lifecycle, ProductLifecycle.discontinued);
    expect(j.stock!.warehouses.single.onHand, 5);
    expect(j.suppliers.single.id, 4);
  });

  testWidgets('a long press starts choosing; every state is a button, off until something is chosen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeProductRepository(products: const [stocked, empty]);
    await _pump(tester, repo, lifecycle: true);

    await tester.longPress(find.text('サラサ'));
    await tester.pumpAndSettle();
    expect(find.text('1件を選択中'), findsWidgets);
    for (final l in ProductLifecycle.values) {
      expect(find.byKey(ValueKey('lc-to-${l.wire}')), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('lc-clear')));
    await tester.pumpAndSettle();
    expect(tester.widget<ButtonStyleButton>(find.byKey(const ValueKey('lc-to-dormant'))).onPressed, isNull);

    await tester.tap(find.text('ボールペン'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lc-to-dormant')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lc-confirm')));
    await tester.pumpAndSettle();
    expect(repo.lifecycleCalls.single.ids, [1]);
    expect(repo.lifecycleCalls.single.lifecycle, ProductLifecycle.dormant);
    expect(repo.lifecycleCalls.single.reason, isNull);
  });

  testWidgets('the photo view shows the same products, filters and selection as the list', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeProductRepository(products: [
      stocked,
      empty,
      sleeping,
      const Product(id: 5, janCode: '4900000000005', name: '写真あり', imageCount: 2),
    ]);
    final container = await _pump(tester, repo, lifecycle: true);
    container.read(productPhotoViewProvider.notifier).state = true;
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('products-grid')), findsOneWidget);
    // Active ones only, as in the list: the discontinued one is not there.
    expect(find.byKey(const ValueKey('pl-product-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('pl-product-3')), findsNothing);
    expect(find.text('3件を表示（全4件）'), findsOneWidget);

    // 写真なし is a filter of the same list.
    await tester.tap(find.byKey(const ValueKey('pf-without-images')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pl-product-5')), findsNothing);
    expect(find.text('2件を表示（全4件）'), findsOneWidget);

    // A state change shows in both views at once.
    await tester.tap(find.byKey(const ValueKey('lc-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pl-product-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lc-to-archived')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lc-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pl-product-2')), findsNothing);
    container.read(productPhotoViewProvider.notifier).state = false;
    await tester.pumpAndSettle();
    expect(find.text('サラサ'), findsNothing);
    expect(find.text('ボールペン'), findsOneWidget);
  });

  testWidgets('when every product is archived, the empty list says so and shows them on a tap', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeProductRepository(products: [
      for (var i = 1; i <= 3; i++)
        Product(id: i, janCode: '490000000000$i', name: '商品$i', status: 'inactive', lifecycleCode: 'archived'),
    ]);
    await _pump(tester, repo, lifecycle: true);

    expect(find.text('商品がまだありません'), findsNothing);
    expect(find.text('絞り込みに合う商品がありません'), findsOneWidget);
    expect(find.textContaining('アーカイブ 3件'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pf-show-archived')));
    await tester.pumpAndSettle();
    expect(find.text('商品1'), findsOneWidget);
    expect(find.text('3件を表示（全3件）'), findsOneWidget);

    // From here they are made active together.
    await tester.tap(find.byKey(const ValueKey('lc-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lc-select-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lc-to-active')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lc-confirm')));
    await tester.pumpAndSettle();
    expect(repo.lifecycleCalls.single.lifecycle, ProductLifecycle.active);
    expect(repo.lifecycleCalls.single.ids, [1, 2, 3]);
  });

  testWidgets('a new product needs nothing filled in; a JAN already registered is an alert (0130)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeProductRepository(products: const [stocked]);
    await _pump(tester, repo);

    Future<void> openForm() async {
      await tester.tap(find.byKey(const ValueKey('products-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('new-manual')));
      await tester.pumpAndSettle();
    }

    // The JAN of the pen already in the library: an alert, nothing saved.
    await openForm();
    expect(find.byKey(const ValueKey('product-new-hint')), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'JANコード'), '4902505632037');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('product-dup-alert')), findsOneWidget);
    expect(find.text('このJANは「ボールペン」で登録済みのため、登録できません。'), findsOneWidget);
    expect(repo.addedOne, isEmpty);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Only a colour and a size: saved as it is.
    await tester.enterText(find.widgetWithText(TextField, 'JANコード'), '');
    await tester.enterText(find.byKey(const ValueKey('product-color')), '青');
    await tester.enterText(find.byKey(const ValueKey('product-w')), '10');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final added = repo.addedOne.single;
    expect(added['jan_code'], isNull);
    expect(added['maker'], isNull);
    expect(added['width_mm'], 10.0);
    expect((added['attributes'] as List).single['value'], '青');
  });

  testWidgets('imports kept back show in the alerts tab, with why, and are removed chosen or all (0130)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeProductRepository(products: const [stocked])
      ..alertList = const [
        ProductAlert(
          id: 1, reason: ProductAlertReason.janExists, janCode: '4902505632037', name: 'ボールペン（取引先の表記）',
          existingProductId: 1, existingName: 'ボールペン', sourceFile: 'own.xlsx', rowNo: 3,
        ),
        ProductAlert(id: 2, reason: ProductAlertReason.skuExists, name: '品番かぶり', itemCode: 'BP-1', existingName: 'ボールペン'),
        ProductAlert(id: 3, reason: ProductAlertReason.janInFile, janCode: '4999999000017', name: '同じJAN'),
      ];
    await _pump(tester, repo);

    expect(find.text('アラート（3）'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pm-tab-alerts')));
    await tester.pumpAndSettle();
    expect(find.text('JANがすでに登録されています'), findsOneWidget);
    expect(find.text('品番がすでに登録されています'), findsOneWidget);
    expect(find.text('同じファイルの中でJANが重複しています'), findsOneWidget);
    expect(find.text('own.xlsx　3行目'), findsOneWidget);
    expect(find.byKey(const ValueKey('al-existing-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('al-open-1')), findsOneWidget);

    // One chosen and removed for good.
    await tester.tap(find.byKey(const ValueKey('al-check-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('al-delete-selected')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('al-delete-confirm')));
    await tester.pumpAndSettle();
    expect(repo.deletedAlerts.first, [2]);
    expect(find.byKey(const ValueKey('al-2')), findsNothing);

    // The rest, all at once.
    await tester.tap(find.byKey(const ValueKey('al-delete-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('al-delete-confirm')));
    await tester.pumpAndSettle();
    expect(repo.deletedAlerts.last, isNull);
    expect(find.text('アラートはありません'), findsOneWidget);
  });
}
