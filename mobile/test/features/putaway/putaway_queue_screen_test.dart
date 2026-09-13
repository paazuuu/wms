// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/putaway/application/putaway_providers.dart';
import 'package:wms_mobile/features/putaway/domain/putaway_task.dart';
import 'package:wms_mobile/features/putaway/presentation/putaway_queue_screen.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';
import 'package:wms_mobile/features/warehouse_context/domain/warehouse.dart';

import '../../support/harness.dart';

const _task = PutawayTask(
  janCode: '4988601001053',
  productName: 'テスト商品',
  pendingQuantity: 30,
  warehouseOnHand: 48,
  binnedQuantity: 18,
  suggestedBinId: 7,
  suggestedBinCode: 'PA-TEST-A',
);

const _bin = BinLocation(
  binId: 7,
  binCode: 'PA-TEST-A',
  binType: 'PICKABLE',
  lines: [
    BinStockLine(janCode: '4988601001053', productName: 'テスト商品', onHand: 18),
  ],
);

/// A single warehouse, so [writeWarehouseIdProvider] resolves without the
/// operator picking one — the same fallback the real app uses.
WarehouseOverview _overview({bool usesLocations = true}) => WarehouseOverview(
      warehouses: [
        Warehouse(id: 1, code: 'TKY', name: '東京倉庫', usesLocations: usesLocations),
      ],
      totals: WarehouseTotals(),
    );

Future<void> _pump(
  WidgetTester tester,
  FakePutawayRepository repo, {
  bool usesLocations = true,
}) async {
  await pumpApp(
    tester,
    const PutawayQueueScreen(),
    overrides: [
      putawayRepositoryProvider.overrideWithValue(repo),
      warehouseRepositoryProvider.overrideWithValue(
          FakeWarehouseRepository(_overview(usesLocations: usesLocations))),
    ],
  );
}

void main() {
  testWidgets('lists what awaits put-away with its suggested bin',
      (tester) async {
    await _pump(tester, FakePutawayRepository(tasks: [_task]));

    expect(find.text('テスト商品'), findsOneWidget);
    expect(find.text('4988601001053'), findsOneWidget);
    // The pending quantity, not the warehouse balance, is the number shown big.
    expect(find.text('30'), findsOneWidget);
    expect(find.text('推奨: PA-TEST-A'), findsOneWidget);
    expect(find.text('うち 18 / 48 は棚入れ済み'), findsOneWidget);
    expect(find.text('1 品目'), findsOneWidget);
  });

  testWidgets('an empty queue in a location-managed warehouse reads as done',
      (tester) async {
    await _pump(tester, FakePutawayRepository());

    expect(find.text('棚入れ待ちはありません'), findsOneWidget);
  });

  testWidgets('a warehouse without locations says so instead of "all done"',
      (tester) async {
    await _pump(tester, FakePutawayRepository(), usesLocations: false);

    expect(find.text('この倉庫はロケーション管理なし'), findsOneWidget);
    expect(find.text('棚入れ待ちはありません'), findsNothing);
  });

  testWidgets('scanning a location shows what the shelf already holds',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    final repo = FakePutawayRepository(
      tasks: [_task],
      bins: {'PA-TEST-A': _bin},
    );
    await _pump(tester, repo);

    await tester.tap(find.text('テスト商品'));
    await tester.pumpAndSettle();

    expect(find.text('ロケーションをスキャン'), findsOneWidget);
    // Quantity input only appears once a location is resolved.
    expect(find.text('今回入れる数量'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'pa-test-a');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('現在の在庫'), findsOneWidget);
    expect(find.text('テスト商品 (4988601001053)'), findsOneWidget);
    expect(find.text('今回入れる数量'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('an unknown location code is refused before any confirm',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    final repo = FakePutawayRepository(tasks: [_task], bins: {'PA-TEST-A': _bin});
    await _pump(tester, repo);

    await tester.tap(find.text('テスト商品'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'NOPE-1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('この倉庫に「NOPE-1」というロケーションはありません'), findsOneWidget);
    expect(repo.confirmed, isEmpty);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('confirming a partial quantity posts it and refreshes the queue',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    final repo = FakePutawayRepository(
      tasks: [_task],
      bins: {'PA-TEST-A': _bin},
    );
    await _pump(tester, repo);

    await tester.tap(find.text('テスト商品'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'PA-TEST-A');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Prefilled with everything pending; put away only part of it.
    final quantityField = find.byType(TextField).last;
    await tester.enterText(quantityField, '18');
    await tester.pump();
    await tester.tap(find.text('棚入れを確定'));
    await tester.pumpAndSettle();

    expect(repo.confirmed, hasLength(1));
    expect(repo.confirmed.single.quantity, 18);
    expect(repo.confirmed.single.pendingAfter, 12);
    // The queue re-read, so the remaining 12 is what the card now shows.
    expect(find.text('12'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('more than is pending is refused client-side', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    final repo = FakePutawayRepository(
      tasks: [_task],
      bins: {'PA-TEST-A': _bin},
    );
    await _pump(tester, repo);

    await tester.tap(find.text('テスト商品'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'PA-TEST-A');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '31');
    await tester.pump();
    await tester.tap(find.text('棚入れを確定'));
    await tester.pumpAndSettle();

    expect(find.text('棚入れ待ちは 30 までです'), findsOneWidget);
    expect(repo.confirmed, isEmpty);

    await tester.binding.setSurfaceSize(null);
  });
}
