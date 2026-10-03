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

import '../../support/harness.dart';

/// Pumped as someone who manages products (product.manage) unless [manage]
/// is false; [delete] adds product.delete (0119).
Future<ProviderContainer> _pump(
    WidgetTester tester, FakeProductRepository repo,
    {bool manage = true, bool delete = false, bool lifecycle = false}) async {
  final container = ProviderContainer(overrides: [
    productRepositoryProvider.overrideWithValue(repo),
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
    expect(find.byKey(const ValueKey('products-from-quote')), findsNothing);
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
    expect(find.byKey(const ValueKey('products-from-quote')), findsOneWidget);
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
      WarehouseStock(warehouseId: 2, name: '神戸倉庫', onHand: 10),
    ]),
  );
  const empty = Product(id: 2, janCode: '4901681233922', name: 'サラサ', maker: 'ゼブラ', stock: ProductStock());
  const sleeping = Product(id: 3, janCode: '4901480344041', name: 'バインダー', maker: 'コクヨ',
      status: 'inactive', lifecycleCode: 'discontinued', lifecycleReason: 'メーカー廃番');

  testWidgets('each product shows its stock, reserved and available, by warehouse', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(tester, FakeProductRepository(products: const [stocked, empty]));

    expect(find.text('在庫 40・引当 10・引当可能 30  (メイン倉庫 30 / 神戸倉庫 10)'), findsOneWidget);
    expect(find.text('在庫なし'), findsOneWidget);
    expect(find.text('2件を表示（全2件）'), findsOneWidget);
  });

  testWidgets('the library narrows by maker, supplier, stock and state', (tester) async {
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
    container.read(productFilterProvider.notifier).state = const ProductFilter(supplierIds: {4});
    await tester.pumpAndSettle();
    expect(find.text('ボールペン'), findsOneWidget);
    expect(find.text('サラサ'), findsNothing);

    container.read(productFilterProvider.notifier).state = const ProductFilter(stock: StockFilter.outOfStock);
    await tester.pumpAndSettle();
    expect(find.text('サラサ'), findsOneWidget);
    expect(find.text('ボールペン'), findsNothing);

    // A discontinued one shows under its state, with why.
    container.read(productFilterProvider.notifier).state =
        const ProductFilter(lifecycles: {ProductLifecycle.discontinued});
    await tester.pumpAndSettle();
    expect(find.text('バインダー'), findsOneWidget);
    expect(find.text('提供終了'), findsOneWidget);
    expect(find.text('メーカー廃番'), findsOneWidget);
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
}
