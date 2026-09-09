import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

    await tester.enterText(find.byType(TextField).first, '4901234567894');
    // "減少" is preselected; entering 5 must reach the server as -5.
    await tester.enterText(find.byType(TextField).at(1), '5');
    await tester.tap(find.widgetWithText(FilledButton, '調整を確定'));
    await tester.pumpAndSettle();

    expect(repo.lastDelta, -5);
    expect(repo.lastWarehouseId, 3);
    expect(find.text('在庫を調整しました（-5）'), findsOneWidget);
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

    await tester.enterText(find.byType(TextField).first, '4901234567894');
    await tester.enterText(find.byType(TextField).at(1), '2');
    await tester.ensureVisible(find.text('紛失'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('紛失'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '調整を確定'));
    await tester.pumpAndSettle();

    expect(repo.lastReason, AdjustReason.loss);
    expect(repo.lastDelta, -2);
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

    await tester.enterText(find.byType(TextField).first, '4901234567894');
    await tester.enterText(find.byType(TextField).at(1), '5');
    await tester.tap(find.text('追加'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '調整を確定'));
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
