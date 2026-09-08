// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';
import 'package:wms_mobile/features/warehouse_context/domain/warehouse.dart';
import 'package:wms_mobile/features/warehouse_context/presentation/warehouse_picker.dart';

import '../../support/harness.dart';

WarehouseOverview _overview(List<Warehouse> warehouses) => WarehouseOverview(
      warehouses: warehouses,
      totals: WarehouseTotals(
        warehouseCount: warehouses.length,
        skuCount: warehouses.fold(0, (a, w) => a + w.skuCount),
        onHand: warehouses.fold(0, (a, w) => a + w.onHand),
      ),
    );

final _kobe = Warehouse(
    id: 1,
    code: 'KOBE',
    name: '神戸倉庫',
    isDefault: true,
    skuCount: 120,
    onHand: 12430);
final _osaka =
    Warehouse(id: 2, code: 'OSAKA', name: '大阪倉庫', skuCount: 80, onHand: 8210);

Future<ProviderContainer> _pump(
  WidgetTester tester,
  List<Warehouse> warehouses,
) async {
  final container = ProviderContainer(overrides: [
    warehouseRepositoryProvider
        .overrideWithValue(FakeWarehouseRepository(_overview(warehouses))),
  ]);
  addTearDown(container.dispose);
  await pumpAppWith(
    tester,
    container,
    const Scaffold(body: Center(child: WarehousePicker())),
  );
  return container;
}

void main() {
  testWidgets('single warehouse: shows its name, no "all warehouses" option',
      (tester) async {
    await _pump(tester, [_kobe]);

    expect(find.text('神戸倉庫'), findsOneWidget);

    await tester.tap(find.byType(WarehousePicker));
    await tester.pumpAndSettle();

    // Manage / add are always offered; "all warehouses" only from two up.
    expect(find.text('すべての倉庫'), findsNothing);
    expect(find.text('倉庫を追加'), findsOneWidget);
    expect(find.text('倉庫を管理'), findsOneWidget);
  });

  testWidgets('two warehouses: picker switches the active context',
      (tester) async {
    final container = await _pump(tester, [_kobe, _osaka]);

    // With more than one warehouse and no explicit choice, the scope starts
    // company-wide; the operator then picks the warehouse they work in.
    expect(container.read(activeWarehouseIdProvider), isNull);
    expect(find.text('すべての倉庫'), findsOneWidget);

    await tester.tap(find.byType(WarehousePicker));
    await tester.pumpAndSettle();

    await tester.tap(find.text('大阪倉庫').last);
    await tester.pumpAndSettle();

    expect(container.read(activeWarehouseIdProvider), 2);
    expect(container.read(activeWarehouseProvider)?.name, '大阪倉庫');
    expect(find.text('大阪倉庫'), findsOneWidget);
  });

  testWidgets('choosing "all warehouses" clears the scope', (tester) async {
    final container = await _pump(tester, [_kobe, _osaka]);
    container.read(activeWarehouseIdProvider.notifier).state = 1;
    await tester.pumpAndSettle();

    await tester.tap(find.byType(WarehousePicker));
    await tester.pumpAndSettle();
    await tester.tap(find.text('すべての倉庫'));
    await tester.pumpAndSettle();

    expect(container.read(activeWarehouseIdProvider), isNull);
  });
}
