// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/delivery/application/delivery_providers.dart';
import 'package:wms_mobile/features/delivery/domain/stock_item.dart';
import 'package:wms_mobile/features/delivery/domain/stock_movement.dart';
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
}
