// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';
import 'package:wms_mobile/features/warehouse_context/domain/warehouse.dart';
import 'package:wms_mobile/features/warehouse_context/presentation/add_warehouse_screen.dart';

import '../../support/harness.dart';

Future<FakeWarehouseRepository> _pump(WidgetTester tester,
    {FakeWarehouseRepository? repo}) async {
  final r = repo ??
      FakeWarehouseRepository(
          WarehouseOverview(warehouses: const [], totals: WarehouseTotals()));
  final container = ProviderContainer(overrides: [
    warehouseRepositoryProvider.overrideWithValue(r),
  ]);
  addTearDown(container.dispose);
  await pumpAppWith(tester, container, const AddWarehouseScreen());
  return r;
}

void main() {
  testWidgets('locations are off by default and no bins are created',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    final repo = await _pump(tester);

    // The bin options are not even offered until locations are switched on.
    expect(find.text('棚（ロケーション）で管理する'), findsOneWidget);
    expect(find.text('初期の棚を作成する'), findsNothing);
    expect(find.text('デフォルト入荷エリア'), findsNothing);

    await tester.enterText(find.byType(TextFormField).at(0), 'メイン倉庫');
    await tester.enterText(find.byType(TextFormField).at(1), 'MAIN');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(repo.created, hasLength(1));
    final submitted = repo.created.single;
    expect(submitted.usesLocations, isFalse);
    expect(submitted.createDefaultBins, isFalse);
    // And the wire payload must not ask the backend to seed bins.
    expect(submitted.toJson()['uses_locations'], isFalse);
    expect(submitted.toJson()['create_default_bins'], isFalse);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('turning locations on reveals the opt-in bin seeding',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    final repo = await _pump(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '神戸倉庫');
    await tester.enterText(find.byType(TextFormField).at(1), 'KOBE');

    await tester.tap(find.text('棚（ロケーション）で管理する'));
    await tester.pumpAndSettle();
    // Bin seeding now appears, but is still off until asked for.
    expect(find.text('初期の棚を作成する'), findsOneWidget);

    await tester.tap(find.text('初期の棚を作成する'));
    await tester.pumpAndSettle();
    expect(find.text('デフォルト入荷エリア'), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    final submitted = repo.created.single;
    expect(submitted.usesLocations, isTrue);
    expect(submitted.toJson()['create_default_bins'], isTrue);
    expect(submitted.toJson()['receiving_bin'], 'STAGE-01');

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'a permission-denied create shows the friendly message, not the raw RPC text (§34)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    final repo = FakeWarehouseRepository(
        WarehouseOverview(warehouses: const [], totals: WarehouseTotals()))
      ..failWith = 'not permitted: warehouse.manage required';
    await _pump(tester, repo: repo);

    await tester.enterText(find.byType(TextFormField).at(0), 'メイン倉庫');
    await tester.enterText(find.byType(TextFormField).at(1), 'MAIN');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(repo.created, isEmpty);
    expect(find.text('この操作を行う権限がありません。'), findsOneWidget);
    expect(find.textContaining('warehouse.manage'), findsNothing);

    await tester.binding.setSurfaceSize(null);
  });
}
