// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/qc/application/inspection_providers.dart';
import 'package:wms_mobile/features/qc/domain/held_stock.dart';
import 'package:wms_mobile/features/qc/presentation/held_stock_screen.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';

import '../../support/harness.dart';

/// A parcel that has been sitting on the dock for four days, on a lot that runs
/// out in a week: the worst square on this screen.
HeldStock _stale() => HeldStock(
      productId: 7,
      warehouseId: 1,
      quantity: 40,
      janCode: '4901234567890',
      productName: 'ボールペン',
      lotId: 27,
      lotCode: 'NEAR',
      expiry: DateTime.now().add(const Duration(days: 7)),
      receivedAt: DateTime.now().subtract(const Duration(days: 4)),
    );

HeldStock _fresh() => HeldStock(
      productId: 8,
      warehouseId: 1,
      quantity: 2,
      janCode: '4902222222222',
      productName: 'ノート',
      receivedAt: DateTime.now().subtract(const Duration(hours: 2)),
    );

HeldStock _expired() => HeldStock(
      productId: 9,
      warehouseId: 1,
      quantity: 1,
      productName: '期限切れ品',
      lotCode: 'OLD',
      expiry: DateTime.now().subtract(const Duration(days: 2)),
    );

Future<ProviderContainer> _pump(
  WidgetTester tester,
  FakeInspectionRepository repo, {
  int? warehouseId = 1,
}) async {
  final container = ProviderContainer(overrides: [
    inspectionRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  if (warehouseId != null) {
    container.read(activeWarehouseIdProvider.notifier).state = warehouseId;
  }
  await pumpAppWith(tester, container, const HeldStockScreen());
  return container;
}

void main() {
  testWidgets('leads with how much of the building cannot ship', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeInspectionRepository()..held = [_stale(), _fresh()];
    await _pump(tester, repo);

    // The number that explains why a product reading "in stock" ships nothing.
    expect(find.text('合計 42 点（2 明細）が出荷できません'), findsOneWidget);
    expect(find.text('ボールペン'), findsOneWidget);
    expect(find.text('40 点'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('shows the lot, the expiry and how long it has waited',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeInspectionRepository()..held = [_stale()];
    await _pump(tester, repo);

    expect(find.text('ロット NEAR'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^期限 ')), findsOneWidget);
    // Days held is what turns a list into a priority.
    expect(find.text('4日経過'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('stock already past its date while held is marked as expired',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeInspectionRepository()..held = [_expired()];
    await _pump(tester, repo);

    expect(find.text('期限切れ品'), findsOneWidget);
    // The model, not the screen, decides what "expired" means, so the test
    // pins that rather than a colour.
    expect(_expired().isExpired, isTrue);
    expect(_fresh().isExpired, isFalse);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a parcel with no receipt date shows no age rather than zero',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeInspectionRepository()..held = [_expired()];
    await _pump(tester, repo);

    // "arrived today" and "we do not know when it arrived" are different facts.
    expect(_expired().daysHeld, isNull);
    expect(find.textContaining('日経過'), findsNothing);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('nothing held reads as good news', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeInspectionRepository();
    await _pump(tester, repo);

    expect(find.text('出荷できない在庫はありません'), findsOneWidget);
    expect(find.byIcon(Icons.verified_outlined), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('it is warehouse-scoped, and says so when no warehouse is chosen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeInspectionRepository()..held = [_stale()];
    await _pump(tester, repo, warehouseId: null);

    expect(find.text('倉庫を選ぶと表示できます'), findsOneWidget);
    expect(repo.lastHeldWarehouseId, isNull);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('the active warehouse is passed to the server', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeInspectionRepository()..held = [_stale()];
    await _pump(tester, repo, warehouseId: 3);

    expect(repo.lastHeldWarehouseId, 3);

    await tester.binding.setSurfaceSize(null);
  });

  group('dealing with held goods (0098)', () {
    HeldStock damaged() => HeldStock(
          productId: 11,
          warehouseId: 1,
          quantity: 6,
          janCode: '4903333333333',
          productName: '割れたコップ',
          statusCode: 'DAMAGED',
          statusName: '破損',
        );

    testWidgets('goods awaiting inspection are left to the inspection', (tester) async {
      final repo = FakeInspectionRepository()..held = [_fresh()];
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      expect(find.text('検品で合否を決めます'), findsOneWidget);
      expect(find.text('処理'), findsNothing);
    });

    testWidgets('a damaged parcel can be written off, and only with a reason', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      final repo = FakeInspectionRepository()..held = [damaged()];
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(find.text('破損'), findsWidgets);
      await tester.tap(find.text('処理'));
      await tester.pumpAndSettle();

      // Moving it to the status it is already in is not offered.
      expect(find.byKey(const ValueKey('disp-damaged')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('disp-scrap')));
      await tester.pumpAndSettle();
      expect(find.text('廃棄・返品には理由が必要です'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('disp-qty')), '4');
      await tester.enterText(find.byKey(const ValueKey('disp-note')), '水濡れ');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('disp-apply')));
      await tester.pumpAndSettle();

      expect(repo.lastDisposition?.action, HeldDisposition.scrap);
      expect(repo.lastDisposition?.quantity, 4);
      expect(repo.lastDisposition?.note, '水濡れ');
      expect(find.text('4 点を処理しました'), findsOneWidget);
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('releasing as good needs no reason, and more than held is refused',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      final repo = FakeInspectionRepository()..held = [damaged()];
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      await tester.tap(find.text('処理'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('disp-qty')), '7');
      await tester.pumpAndSettle();
      expect(find.text('6 点までです'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('disp-qty')), '2');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('disp-apply')));
      await tester.pumpAndSettle();
      expect(repo.lastDisposition?.action, HeldDisposition.release);
      expect(repo.lastDisposition?.quantity, 2);
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('a status chip narrows the list on the server', (tester) async {
      final repo = FakeInspectionRepository()..held = [_fresh(), damaged()];
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('held-filter-DAMAGED')));
      await tester.pumpAndSettle();
      expect(repo.lastHeldStatus, 'DAMAGED');
      expect(find.text('割れたコップ'), findsOneWidget);
      expect(find.text('ノート'), findsNothing);
    });
  });
}
