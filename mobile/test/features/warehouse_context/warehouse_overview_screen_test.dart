// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';
import 'package:wms_mobile/features/warehouse_context/domain/warehouse.dart';
import 'package:wms_mobile/features/warehouse_context/presentation/warehouse_overview_screen.dart';

import '../../support/harness.dart';

void main() {
  testWidgets('lists every warehouse with its figures, totals and bins',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final warehouses = [
      Warehouse(
          id: 1,
          code: 'KOBE',
          name: '神戸倉庫',
          isDefault: true,
          skuCount: 120,
          onHand: 12430,
          inboundOpen: 12),
      Warehouse(
          id: 2,
          code: 'OSAKA',
          name: '大阪倉庫',
          skuCount: 80,
          onHand: 8210,
          outboundOpen: 9),
    ];
    final container = ProviderContainer(overrides: [
      warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(
        WarehouseOverview(
          warehouses: warehouses,
          totals: WarehouseTotals(
              warehouseCount: 2, skuCount: 200, onHand: 20640, inboundOpen: 12),
        ),
        binsByWarehouse: {
          1: [
            Bin(id: 1, code: 'STAGE-01', binType: 'STAGING'),
            Bin(id: 2, code: 'QC-01', binType: 'QC_HOLD'),
          ],
        },
      )),
    ]);
    addTearDown(container.dispose);

    await pumpAppWith(tester, container, const WarehouseOverviewScreen());

    // Both warehouses and their codes.
    expect(find.text('神戸倉庫'), findsOneWidget);
    expect(find.text('大阪倉庫'), findsOneWidget);
    expect(find.text('KOBE'), findsOneWidget);

    // Company totals row.
    expect(find.text('合計'), findsOneWidget);
    expect(find.text('20,640'), findsOneWidget);

    // Per-warehouse figures.
    expect(find.text('12,430'), findsOneWidget);
    expect(find.text('8,210'), findsOneWidget);

    // Bins of the first warehouse render as pills.
    expect(find.text('STAGE-01'), findsOneWidget);
    expect(find.text('QC-01'), findsOneWidget);

    // Tapping a warehouse makes it the active context.
    await tester.tap(find.text('大阪倉庫'));
    await tester.pumpAndSettle();
    expect(container.read(activeWarehouseIdProvider), 2);

    await tester.binding.setSurfaceSize(null);
  });
}
