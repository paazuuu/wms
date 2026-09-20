// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/product/application/product_providers.dart';
import 'package:wms_mobile/features/product/domain/product.dart';
import 'package:wms_mobile/features/product/presentation/product_list_screen.dart';

import '../../support/harness.dart';

Future<ProviderContainer> _pump(
    WidgetTester tester, FakeProductRepository repo) async {
  final container = ProviderContainer(overrides: [
    productRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  await pumpAppWith(tester, container, const ProductListScreen());
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
    expect(find.text('有効'), findsOneWidget);

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

  testWidgets(
      "an existing product's fixed JAN offers no scan button to replace it",
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeProductRepository(products: const [
      Product(id: 1, janCode: '4902505632037', name: 'ボールペン'),
    ]);
    await _pump(tester, repo);

    await tester.tap(find.text('ボールペン'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.qr_code_scanner_outlined), findsNothing);

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

    expect(find.text('有効'), findsOneWidget);
    await tester.tap(find.text('有効'));
    await tester.pumpAndSettle();

    expect(find.text('この商品を無効にしますか？'), findsOneWidget);
    // Not yet applied — still shown as active behind the dialog.
    expect(find.text('有効'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '無効にする'));
    await tester.pumpAndSettle();

    expect(find.text('無効'), findsOneWidget);
  });

  testWidgets(
      'cancelling the confirmation leaves the product active',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeProductRepository(products: const [
      Product(id: 1, janCode: '4902505632037', name: 'ボールペン'),
    ]);
    await _pump(tester, repo);

    await tester.tap(find.text('有効'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'キャンセル'));
    await tester.pumpAndSettle();

    expect(find.text('有効'), findsOneWidget);
    expect(find.text('無効'), findsNothing);
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

    expect(find.text('無効'), findsOneWidget);
    await tester.tap(find.text('無効'));
    await tester.pumpAndSettle();

    // No dialog appears — reactivating is harmless (§36's "don't overuse
    // confirmations" side).
    expect(find.text('この商品を無効にしますか？'), findsNothing);
    expect(find.text('有効'), findsOneWidget);
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

  testWidgets('the SKU and tracking mode are saved through set_product_identity',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeProductRepository(products: const [
      Product(id: 1, janCode: '4902505632037', name: 'ボールペン'),
    ]);
    await _pump(tester, repo);

    await tester.tap(find.text('ボールペン'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'SKU'), 'PEN-001');
    await tester.tap(find.byType(DropdownButtonFormField<TrackingMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('有効期限').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    // 0057 keeps identity on its own RPC, so this must not have gone through
    // update_product.
    expect(repo.lastIdentity?.id, 1);
    expect(repo.lastIdentity?.sku, 'PEN-001');
    expect(repo.lastIdentity?.trackingMode, TrackingMode.expiry);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('editing only the name sends no identity call', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeProductRepository(products: const [
      Product(id: 1, janCode: '4902505632037', name: 'ボールペン', sku: 'PEN-001'),
    ]);
    await _pump(tester, repo);

    await tester.tap(find.text('ボールペン'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, '商品名'), 'ボールペン（黒）');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    // Nothing about the identity changed, so `set_product_identity` is not
    // called — which is what keeps a rename from ever being refused by the
    // tracking-mode guard (§37-15).
    expect(repo.lastIdentity, isNull);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a tracking mode the server refuses is shown, not swallowed',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeProductRepository(products: const [
      Product(id: 1, janCode: '4902505632037', name: 'ボールペン'),
    ])
      ..failIdentityWith =
          'product 1 already has lots recorded; tracking_mode cannot become UNTRACKED';
    await _pump(tester, repo);

    await tester.tap(find.text('ボールペン'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<TrackingMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('シリアル').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    // The sheet stays open with the reason on it (§34: no silent failure).
    expect(find.textContaining('already has lots recorded'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '保存'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
}
