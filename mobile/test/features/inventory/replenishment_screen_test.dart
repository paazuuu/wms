// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/inventory/application/inventory_providers.dart';
import 'package:wms_mobile/features/inventory/presentation/replenishment_screen.dart';
import 'package:wms_mobile/features/product/domain/warehouse_product.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';

import '../../support/harness.dart';

/// The case §31 exists for: a hundred on hand, ninety of them quarantined, so
/// only ten can cover an order — and the reorder point is fifty.
ReplenishmentSuggestion _blockedStock() => ReplenishmentSuggestion(
      warehouseId: 1,
      productId: 7,
      productName: 'ボールペン',
      janCode: '4901234567890',
      sku: 'PEN-001',
      reorderPoint: 50,
      maxStock: 200,
      onHand: 100,
      available: 10,
      shortfall: 40,
      suggestedQuantity: 190,
      preferredSupplierName: '文具商事',
      leadTimeDays: 7,
      baseUom: 'PCS',
    );

Future<ProviderContainer> _pump(
  WidgetTester tester,
  FakeInventoryRepository repo, {
  int? warehouseId = 1,
}) async {
  final container = ProviderContainer(overrides: [
    inventoryRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  if (warehouseId != null) {
    container.read(activeWarehouseIdProvider.notifier).state = warehouseId;
  }
  await pumpAppWith(tester, container, const ReplenishmentScreen());
  return container;
}

void main() {
  testWidgets('shows the order quantity, the gap and why stock is blocked',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    final repo = FakeInventoryRepository(suggestions: [_blockedStock()]);
    await _pump(tester, repo);

    expect(find.text('ボールペン'), findsOneWidget);
    // The number someone acts on gets the pill, with the base unit.
    expect(find.text('発注目安 190 PCS'), findsOneWidget);
    // Available against the line, not on-hand against the line.
    expect(find.textContaining('引当可能 10'), findsOneWidget);
    expect(find.textContaining('発注点 50'), findsOneWidget);
    expect(find.text('発注点まで 40'), findsOneWidget);
    // The explanation for a product that has stock and is still on this list.
    expect(find.text('うち出荷不可 90'), findsOneWidget);
    expect(find.textContaining('文具商事'), findsOneWidget);
    expect(find.textContaining('リードタイム 7日'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a product with no blocked stock shows no blocked line',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    final repo = FakeInventoryRepository(suggestions: [
      ReplenishmentSuggestion(
        warehouseId: 1,
        productId: 8,
        productName: 'ノート',
        reorderPoint: 30,
        onHand: 5,
        available: 5,
        shortfall: 25,
        suggestedQuantity: 25,
      ),
    ]);
    await _pump(tester, repo);

    expect(find.textContaining('うち出荷不可'), findsNothing);
    expect(find.text('発注目安 25'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('nothing under its line is an empty state, not an empty list',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    final repo = FakeInventoryRepository();
    await _pump(tester, repo);

    expect(find.text('補充が必要な商品はありません'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('with no active warehouse it says to pick one', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    final repo = FakeInventoryRepository(suggestions: [_blockedStock()]);
    await _pump(tester, repo, warehouseId: null);

    expect(find.text('倉庫を選ぶと表示できます'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
}
