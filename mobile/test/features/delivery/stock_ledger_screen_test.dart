// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/delivery/application/delivery_providers.dart';
import 'package:wms_mobile/features/delivery/domain/stock_item.dart';
import 'package:wms_mobile/features/delivery/domain/stock_movement.dart';
import 'package:wms_mobile/features/delivery/domain/stock_position.dart';
import 'package:wms_mobile/features/delivery/presentation/stock_ledger_screen.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';

import '../../support/harness.dart';

const _jan = '4902505632037';

List<StockMovement> _movements() => [
      StockMovement(
        id: 2,
        janCode: _jan,
        productName: 'ペン',
        warehouseName: 'メイン倉庫',
        movementType: 'SHIP',
        quantity: -20,
        quantityBefore: 50,
        quantityAfter: 30,
        referenceType: 'shipment_plan',
        referenceId: '7',
        createdAt: DateTime(2026, 9, 9, 14, 30),
      ),
      StockMovement(
        id: 1,
        janCode: _jan,
        productName: 'ペン',
        warehouseName: 'メイン倉庫',
        movementType: 'RECEIPT',
        quantity: 50,
        quantityBefore: 0,
        quantityAfter: 50,
        referenceType: 'reconciliation',
        referenceId: '3',
        createdAt: DateTime(2026, 9, 9, 10, 0),
      ),
    ];

void main() {
  testWidgets('ledger shows each movement with its before → after', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    final container = ProviderContainer(overrides: [
      stockRepositoryProvider.overrideWithValue(
          FakeStockRepository(const [], movements: _movements())),
    ]);
    addTearDown(container.dispose);

    await pumpAppWith(
      tester,
      container,
      const StockLedgerScreen(janCode: _jan, productName: 'ペン'),
    );

    // Movement types are localized, and the signed delta carries its sign.
    expect(find.text('出庫'), findsOneWidget);
    expect(find.text('入庫'), findsOneWidget);
    expect(find.text('-20'), findsOneWidget);
    expect(find.text('+50'), findsOneWidget);

    // before → after for both rows.
    expect(find.text('50 → 30'), findsOneWidget);
    expect(find.text('0 → 50'), findsOneWidget);

    // The originating document is shown so a change is traceable.
    expect(find.textContaining('shipment_plan #7'), findsOneWidget);
    expect(find.textContaining('reconciliation #3'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  test('stock list scopes its query to the active warehouse', () async {
    final repo = FakeStockRepository(
        [StockItem(janCode: _jan, onHand: 30, productName: 'ペン')]);
    final container = ProviderContainer(overrides: [
      stockRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    // Hold a subscription so the autoDispose provider stays alive across the
    // warehouse switch.
    final sub = container.listen(stockListProvider, (_, __) {});
    addTearDown(sub.close);

    await container.read(stockListProvider.future);
    expect(repo.lastWarehouseId, isNull);

    container.read(activeWarehouseIdProvider.notifier).state = 2;
    await container.read(stockListProvider.future);
    expect(repo.lastWarehouseId, 2);
  });

  testWidgets('the ledger opens with what the quantity consists of',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    final repo = FakeStockRepository(const [], movements: _movements())
      ..positions = {
        7: StockPosition(
          productId: 7,
          warehouseId: 1,
          onHand: 100,
          reserved: 30,
          available: 20,
          allocated: 30,
          parcels: [
            StockParcel(status: 'OK', statusName: '良品', quantity: 50),
            StockParcel(
              status: 'QUARANTINE',
              statusName: '隔離',
              quantity: 50,
              lotId: 3,
              lotCode: 'A-2024/05',
            ),
          ],
        ),
      };
    final container = ProviderContainer(overrides: [
      stockRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    await pumpAppWith(
      tester,
      container,
      const StockLedgerScreen(janCode: _jan, productName: 'ペン', productId: 7),
    );
    await tester.pumpAndSettle();

    // §5's numbers, each labelled — not one total that means four things.
    expect(find.text('在庫内訳'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('引当可能'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('予約済み'), findsOneWidget);
    expect(find.text('出荷不可'), findsOneWidget);

    // The per-status split behind them, with the lot a held parcel came from.
    expect(find.text('隔離 · ロット A-2024/05'), findsOneWidget);
    expect(find.text('良品'), findsOneWidget);

    // The history is still there, below it.
    expect(find.text('50 → 30'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('over-promised stock is called out, not hidden by a zero',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    final repo = FakeStockRepository(const [], movements: _movements())
      ..positions = {
        7: StockPosition(
          productId: 7,
          warehouseId: 1,
          onHand: 20,
          reserved: 40,
          available: -20,
          allocated: 40,
        ),
      };
    final container = ProviderContainer(overrides: [
      stockRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    await pumpAppWith(
      tester,
      container,
      const StockLedgerScreen(janCode: _jan, productName: 'ペン', productId: 7),
    );
    await tester.pumpAndSettle();

    expect(find.text('-20'), findsWidgets);
    expect(find.text('予約が引当可能数を超えています'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a JAN with no product says so instead of showing zeroes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    final repo = FakeStockRepository(const [], movements: _movements());
    final container = ProviderContainer(overrides: [
      stockRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    await pumpAppWith(
      tester,
      container,
      // No productId: 0058's case, stock received against a JAN the product
      // master does not know yet.
      const StockLedgerScreen(janCode: _jan, productName: 'ペン'),
    );
    await tester.pumpAndSettle();

    expect(find.text('このJANは商品マスタに未登録です'), findsOneWidget);
    expect(find.text('在庫内訳'), findsNothing);
    // Asking for a position would have been meaningless, so it is not asked.
    expect(repo.lastPositionQuery, isNull);

    await tester.binding.setSurfaceSize(null);
  });
}
