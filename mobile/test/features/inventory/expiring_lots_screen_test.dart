// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/inventory/application/inventory_providers.dart';
import 'package:wms_mobile/features/inventory/presentation/expiring_lots_screen.dart';
import 'package:wms_mobile/features/product/domain/product_lot.dart';

import '../../support/harness.dart';

List<ExpiringLot> _lots() => [
      ExpiringLot(
        lotId: 6,
        lotCode: 'OLD-1',
        productId: 7,
        productName: 'ボールペン',
        janCode: '4901234567890',
        expiryDate: DateTime(2026, 1, 31),
        daysToExpiry: -40,
        isExpired: true,
      ),
      ExpiringLot(
        lotId: 5,
        lotCode: 'A-2024/05',
        productId: 7,
        productName: 'ボールペン',
        janCode: '4901234567890',
        expiryDate: DateTime(2026, 10, 5),
        daysToExpiry: 15,
        serialCount: 3,
      ),
    ];

Future<ProviderContainer> _pump(
    WidgetTester tester, FakeInventoryRepository repo) async {
  final container = ProviderContainer(overrides: [
    inventoryRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  await pumpAppWith(tester, container, const ExpiringLotsScreen());
  return container;
}

void main() {
  testWidgets('lists each lot with its product, date and time left',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    final repo = FakeInventoryRepository(lots: _lots());
    await _pump(tester, repo);

    expect(find.text('ボールペン'), findsNWidgets(2));
    expect(find.textContaining('A-2024/05'), findsOneWidget);
    expect(find.textContaining('期限 2026-10-05'), findsOneWidget);
    expect(find.textContaining('シリアル 3 件'), findsOneWidget);

    // Expired and expiring are different pills, because one is a decision and
    // the other is a warning.
    expect(find.text('期限切れ'), findsWidgets);
    expect(find.text('あと15日'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('the summary counts both kinds before any scrolling',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    final repo = FakeInventoryRepository(lots: _lots());
    await _pump(tester, repo);

    expect(find.text('期限切れ 1 件'), findsOneWidget);
    expect(find.text('期限間近 1 件'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('the horizon is a choice and reaches the server', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    final repo = FakeInventoryRepository(lots: _lots());
    final container = await _pump(tester, repo);

    // The default window.
    expect(repo.lastHorizon, 30);
    expect(find.text('30日以内'), findsWidgets);

    container.read(expiryHorizonProvider.notifier).state = 90;
    await tester.pumpAndSettle();

    // Refetched rather than filtered client-side: the server knows today's date.
    expect(repo.lastHorizon, 90);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('an empty window suggests widening it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    final repo = FakeInventoryRepository();
    await _pump(tester, repo);

    expect(find.text('期限が近いロットはありません'), findsOneWidget);
    expect(find.textContaining('期間を広げると'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
}
