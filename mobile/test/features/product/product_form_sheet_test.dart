// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/product/application/product_providers.dart';
import 'package:wms_mobile/features/product/domain/product.dart';
import 'package:wms_mobile/features/product/presentation/product_form_sheet.dart';

import '../../support/harness.dart';

/// The sheet is pumped directly rather than through the list screen: since the
/// product list's tap opens the *detail* screen, reaching the form from there
/// would make every assertion below depend on two screens it is not testing.
Future<void> _pumpSheet(
  WidgetTester tester,
  FakeProductRepository repo, {
  Product? product,
}) async {
  final container = ProviderContainer(overrides: [
    productRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  await pumpAppWith(
      tester, container, Scaffold(body: ProductFormSheet(product: product)));
}

void main() {
  testWidgets('the SKU and tracking mode are saved through set_product_identity',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeProductRepository(products: const [
      Product(id: 1, janCode: '4902505632037', name: 'ボールペン'),
    ]);
    await _pumpSheet(tester, repo,
        product: const Product(
            id: 1, janCode: '4902505632037', name: 'ボールペン'));

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
    await _pumpSheet(tester, repo,
        product: const Product(
            id: 1,
            janCode: '4902505632037',
            name: 'ボールペン',
            sku: 'PEN-001'));

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

  testWidgets('clearing the SKU sends an empty string, not null', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeProductRepository(products: const [
      Product(id: 1, janCode: '4902505632037', name: 'ボールペン', sku: 'PEN-001'),
    ]);
    await _pumpSheet(tester, repo,
        product: const Product(
            id: 1,
            janCode: '4902505632037',
            name: 'ボールペン',
            sku: 'PEN-001'));

    await tester.enterText(find.widgetWithText(TextField, 'SKU'), '');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    // null would mean "leave it alone" (0065), so an emptied field has to travel
    // as '' or the SKU could never be removed.
    expect(repo.lastIdentity?.sku, '');

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
    await _pumpSheet(tester, repo,
        product: const Product(
            id: 1, janCode: '4902505632037', name: 'ボールペン'));

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

  testWidgets('the picking rule is saved through its own set_picking_rule call',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeProductRepository(products: const [
      Product(id: 1, janCode: '4902505632037', name: 'ボールペン'),
    ]);
    await _pumpSheet(tester, repo,
        product: const Product(
            id: 1, janCode: '4902505632037', name: 'ボールペン'));

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('先入先出（FIFO）').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.lastPickingRule, (productId: 1, rule: 'FIFO'));

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('editing only the name sends no picking rule call',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeProductRepository(products: const [
      Product(id: 1, janCode: '4902505632037', name: 'ボールペン'),
    ]);
    await _pumpSheet(tester, repo,
        product: const Product(
            id: 1, janCode: '4902505632037', name: 'ボールペン'));

    await tester.enterText(
        find.widgetWithText(TextField, '商品名'), 'ボールペン（黒）');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.lastPickingRule, isNull);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'the QC requirement is saved through its own set_inspection_requirement call',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeProductRepository(products: const [
      Product(id: 1, janCode: '4902505632037', name: 'ボールペン'),
    ]);
    await _pumpSheet(tester, repo,
        product: const Product(
            id: 1, janCode: '4902505632037', name: 'ボールペン'));

    await tester.tap(find.widgetWithText(SwitchListTile, '入荷検品を必須にする'));
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.lastInspectionRequirement,
        (productId: 1, requiresInspection: true));

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('editing only the name sends no QC requirement call',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeProductRepository(products: const [
      Product(id: 1, janCode: '4902505632037', name: 'ボールペン'),
    ]);
    await _pumpSheet(tester, repo,
        product: const Product(
            id: 1, janCode: '4902505632037', name: 'ボールペン'));

    await tester.enterText(
        find.widgetWithText(TextField, '商品名'), 'ボールペン（黒）');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.lastInspectionRequirement, isNull);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets("an existing product's fixed JAN offers no scan button",
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeProductRepository();
    await _pumpSheet(tester, repo,
        product: const Product(
            id: 1, janCode: '4902505632037', name: 'ボールペン'));

    // The JAN is fixed once created, so there is nothing to re-scan into.
    expect(find.byIcon(Icons.qr_code_scanner_outlined), findsNothing);

    await tester.binding.setSurfaceSize(null);
  });
}
