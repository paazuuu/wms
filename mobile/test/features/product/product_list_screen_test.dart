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
      'tapping the status pill deactivates a product (shown once inactive ones are visible)',
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

    expect(find.text('無効'), findsOneWidget);
  });
}
