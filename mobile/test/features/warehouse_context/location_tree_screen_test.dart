// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';
import 'package:wms_mobile/features/warehouse_context/domain/location.dart';
import 'package:wms_mobile/features/warehouse_context/presentation/location_tree_screen.dart';

import '../../support/harness.dart';

List<Location> _tree() => [
      Location(
        id: 1,
        code: 'Z1',
        name: 'ゾーン1',
        locationType: 'STORAGE',
        zoneId: 3,
        children: [
          Location(
            id: 2,
            code: 'Z1-AISLE-1',
            locationType: 'STORAGE',
            children: [
              Location(
                id: 4,
                code: 'Z1-R-01-S3',
                name: '棚3',
                locationType: 'PICKING',
                binId: 11,
                onHand: 30,
              ),
            ],
          ),
        ],
      ),
      Location(
        id: 5,
        code: 'RECV-01',
        name: '入荷エリア',
        locationType: 'RECEIVING',
        pickable: false,
        receivable: true,
        isVirtual: true,
      ),
    ];

Future<ProviderContainer> _pump(
  WidgetTester tester,
  FakeLocationRepository repo, {
  int? warehouseId = 1,
}) async {
  final container = ProviderContainer(overrides: [
    locationRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  if (warehouseId != null) {
    container.read(activeWarehouseIdProvider.notifier).state = warehouseId;
  }
  await pumpAppWith(tester, container, const LocationTreeScreen());
  return container;
}

void main() {
  testWidgets('shows the tree with each node type, and stock only for bins',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeLocationRepository(roots: _tree());
    await _pump(tester, repo);

    expect(find.text('Z1'), findsOneWidget);
    // Roots start expanded, so the aisle under the zone is visible.
    expect(find.text('Z1-AISLE-1'), findsOneWidget);
    expect(find.textContaining('保管'), findsWidgets);

    // A virtual receiving area is marked as such.
    expect(find.text('RECV-01'), findsOneWidget);
    expect(find.text('仮想'), findsOneWidget);
    expect(find.textContaining('入荷'), findsWidgets);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a bin shows its quantity; a rack does not show a zero',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeLocationRepository(roots: _tree());
    await _pump(tester, repo);

    // Expand the aisle to reach the shelf.
    await tester.tap(find.text('Z1-AISLE-1'));
    await tester.pumpAndSettle();

    expect(find.text('Z1-R-01-S3'), findsOneWidget);
    expect(find.textContaining('在庫 30'), findsOneWidget);
    // "no stock here" and "not somewhere stock is counted" are different
    // answers, so the zone says nothing rather than 0.
    expect(find.textContaining('在庫 0'), findsNothing);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('inactive nodes are asked for only when requested', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeLocationRepository(roots: _tree());
    final container = await _pump(tester, repo);

    expect(repo.lastIncludeInactive, isFalse);

    container.read(showInactiveLocationsProvider.notifier).state = true;
    await tester.pumpAndSettle();

    // A deactivated rack hides its whole branch, so seeing it again has to be a
    // server-side ask, not a local filter.
    expect(repo.lastIncludeInactive, isTrue);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('adding under a node pre-fills that node as the parent',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeLocationRepository(roots: _tree());
    await _pump(tester, repo);

    // The + on the zone row.
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'コード'), 'Z1-AISLE-2');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.lastCreated?.code, 'Z1-AISLE-2');
    // Named by code: the operator is reading it off the rack.
    expect(repo.lastCreated?.parentCode, 'Z1');
    expect(repo.lastCreated?.warehouseId, 1);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a refused create keeps the sheet open with the reason',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeLocationRepository(roots: _tree())
      ..failCreateWith =
          'duplicate key value violates unique constraint "locations_warehouse_code_key"';
    await _pump(tester, repo);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'コード'), 'Z1');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.textContaining('locations_warehouse_code_key'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '保存'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('editing a node keeps its code and can switch it off',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeLocationRepository(roots: _tree());
    await _pump(tester, repo);

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();

    // The code is the handle every scan and parent reference uses, so it is
    // fixed once created.
    final code = tester.widget<TextField>(find.widgetWithText(TextField, 'コード'));
    expect(code.readOnly, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.lastUpdated?.id, 1);
    expect(repo.lastUpdated?.isActive, isFalse);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('with no active warehouse it says to pick one', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeLocationRepository(roots: _tree());
    await _pump(tester, repo, warehouseId: null);

    // A location belongs to a building, so there is nothing to show until one
    // is chosen.
    expect(find.text('倉庫を選ぶと表示できます'), findsOneWidget);
    expect(repo.lastWarehouseId, isNull);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('an empty warehouse explains what will appear', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeLocationRepository();
    await _pump(tester, repo);

    expect(find.text('ロケーションがまだありません'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
}
