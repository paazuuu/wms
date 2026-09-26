// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/inventory/application/inventory_providers.dart';
import 'package:wms_mobile/features/inventory/domain/reservation.dart';
import 'package:wms_mobile/features/inventory/presentation/reservations_screen.dart';
import 'package:wms_mobile/features/product/application/product_providers.dart';
import 'package:wms_mobile/features/product/domain/product.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';

import '../../support/harness.dart';

Reservation _active() => Reservation(
      id: 3,
      productId: 7,
      productName: 'ボールペン',
      warehouseId: 1,
      quantity: 30,
      status: 'ACTIVE',
      fulfilledQuantity: 10,
      allocatedQuantity: 20,
      referenceType: 'sales_order',
      referenceId: 'SO-1',
      allocations: [
        StockAllocation(
          id: 9,
          stockUnitId: 11,
          quantity: 20,
          status: 'OK',
          lotId: 5,
          lotCode: 'A-2024/05',
        ),
      ],
    );

Future<ProviderContainer> _pump(
  WidgetTester tester,
  FakeInventoryRepository repo, {
  int? warehouseId = 1,
  List<Product> products = const [],
}) async {
  final container = ProviderContainer(overrides: [
    inventoryRepositoryProvider.overrideWithValue(repo),
    productRepositoryProvider
        .overrideWithValue(FakeProductRepository(products: products)),
  ]);
  addTearDown(container.dispose);
  if (warehouseId != null) {
    container.read(activeWarehouseIdProvider.notifier).state = warehouseId;
  }
  await pumpAppWith(tester, container, const ReservationsScreen());
  return container;
}

void main() {
  testWidgets('a reservation shows what is promised, pinned, shipped and not yet',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeInventoryRepository(reservationList: [_active()]);
    await _pump(tester, repo);

    expect(find.text('ボールペン'), findsOneWidget);
    expect(find.textContaining('受注 #SO-1'), findsOneWidget);
    expect(find.text('予約 30'), findsOneWidget);
    expect(find.text('引当済 20'), findsOneWidget);
    // 30 promised, 20 pinned: the 10 with no shelf behind it is worth naming,
    // because no picker can be sent for that part.
    expect(find.text('未引当 10'), findsOneWidget);
    expect(find.text('出荷済 10'), findsOneWidget);
    // Which parcel will supply it, with the lot a picker will look for.
    expect(find.text('引当先'), findsOneWidget);
    expect(find.textContaining('ロット A-2024/05'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a promise with no parcels chosen yet says so', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeInventoryRepository(reservationList: [
      Reservation(
        id: 4,
        productId: 7,
        productName: 'ボールペン',
        warehouseId: 1,
        quantity: 10,
        status: 'ACTIVE',
      ),
    ]);
    await _pump(tester, repo);

    // A valid state, not an error: the promise is made and the picker has not
    // been told which shelf.
    expect(find.text('引当先はまだ決まっていません'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a lapsed reservation is marked even though it reads ACTIVE',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeInventoryRepository(reservationList: [
      Reservation(
        id: 5,
        productId: 7,
        productName: 'ボールペン',
        warehouseId: 1,
        quantity: 10,
        status: 'ACTIVE',
        expiresAt: DateTime(2026, 1, 1),
        isExpired: true,
      ),
    ]);
    await _pump(tester, repo);

    expect(find.text('期限切れ'), findsOneWidget);
    expect(find.text('有効'), findsNothing);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('releasing asks first, then frees the promise', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeInventoryRepository(reservationList: [_active()]);
    await _pump(tester, repo);

    await tester.tap(find.widgetWithText(TextButton, '解放'));
    await tester.pumpAndSettle();

    expect(find.text('この予約を解放しますか？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '解放'));
    await tester.pumpAndSettle();

    expect(repo.releasedIds, [3]);
    // The list is filtered to ACTIVE, and the released row is no longer one.
    expect(find.text('ボールペン'), findsNothing);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a refused release is shown, not swallowed', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeInventoryRepository(reservationList: [_active()])
      ..failReleaseWith = 'reservation 3 is already RELEASED';
    await _pump(tester, repo);

    await tester.tap(find.widgetWithText(TextButton, '解放'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '解放'));
    await tester.pumpAndSettle();

    expect(find.textContaining('already RELEASED'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'fulfilling asks for a quantity, prefilled with what is outstanding',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeInventoryRepository(reservationList: [_active()]);
    await _pump(tester, repo);

    await tester.tap(find.widgetWithText(FilledButton, '出荷済みにする'));
    await tester.pumpAndSettle();

    // 30 promised, 10 already shipped: 20 is what is left to mark.
    expect(find.widgetWithText(TextField, '数量'), findsOneWidget);
    expect(find.text('20'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, '出荷済みにする').last);
    await tester.pumpAndSettle();

    expect(repo.lastFulfil?.id, 3);
    expect(repo.lastFulfil?.quantity, 20);
    // The list refreshes; nothing is left outstanding, so the button is gone.
    expect(find.widgetWithText(FilledButton, '出荷済みにする'), findsNothing);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a refused fulfil is shown, not swallowed', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeInventoryRepository(reservationList: [_active()])
      ..failFulfilWith = 'reservation 3 is FULFILLED';
    await _pump(tester, repo);

    await tester.tap(find.widgetWithText(FilledButton, '出荷済みにする'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '出荷済みにする').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('FULFILLED'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('over-allocated parcels come first, with why it happened',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeInventoryRepository(
      reservationList: [_active()],
      overAllocatedList: [
        OverAllocatedStock(
          stockUnitId: 11,
          productId: 7,
          productName: 'ボールペン',
          quantity: 20,
          allocated: 40,
          over: 20,
          warehouseId: 1,
          status: 'OK',
        ),
      ],
    );
    await _pump(tester, repo);

    expect(find.text('引当超過'), findsOneWidget);
    expect(find.text('在庫 20 / 引当 40（超過 20）'), findsOneWidget);
    // The explanation matters: this is the deliberate trade-off (a shipment is
    // never blocked by a plan), not a defect.
    expect(find.textContaining('出荷が先に取ったため'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('the status filter goes to the RPC', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeInventoryRepository(reservationList: [
      _active(),
      Reservation(
        id: 8,
        productId: 7,
        productName: '解放済みの品',
        warehouseId: 1,
        quantity: 5,
        status: 'RELEASED',
      ),
    ]);
    final container = await _pump(tester, repo);

    // ACTIVE by default: those are the ones holding stock.
    expect(repo.lastReservationQuery?.status, 'ACTIVE');
    expect(find.text('解放済みの品'), findsNothing);

    container.read(reservationStatusProvider.notifier).state = null;
    await tester.pumpAndSettle();

    expect(repo.lastReservationQuery?.status, isNull);
    expect(find.text('解放済みの品'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('the list is scoped to the active warehouse', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeInventoryRepository(reservationList: [_active()]);
    final container = await _pump(tester, repo, warehouseId: 2);

    expect(repo.lastReservationQuery?.warehouseId, 2);

    container.read(activeWarehouseIdProvider.notifier).state = 5;
    await tester.pumpAndSettle();
    expect(repo.lastReservationQuery?.warehouseId, 5);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('nothing promised and nothing over-allocated is an empty state',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeInventoryRepository();
    await _pump(tester, repo);

    expect(find.text('予約はありません'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('the unpinned part of a promise can be allocated to parcels',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeInventoryRepository(reservationList: [_active()])
      ..allocationOutcome = const AllocationOutcome(allocated: 6, short: 4);
    await _pump(tester, repo);

    await tester.tap(find.text('ロットを割当'));
    await tester.pumpAndSettle();

    // Asks for exactly what is unpinned, and says what could not be found.
    expect(repo.lastAllocate, (id: 3, quantity: 10));
    expect(find.text('6 個を割当（4 個は在庫が見つかりません）'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('one parcel can be un-pinned without dropping the promise',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeInventoryRepository(reservationList: [_active()]);
    await _pump(tester, repo);

    await tester.tap(find.byTooltip('割当を外す'));
    await tester.pumpAndSettle();

    expect(repo.releasedAllocationIds, [9]);
    expect(repo.releasedIds, isEmpty);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('stock can be reserved by hand by JAN code', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeInventoryRepository();
    await _pump(tester, repo, products: const [
      Product(id: 7, janCode: '4901234567894', name: 'ボールペン'),
    ]);

    await tester.tap(find.text('手動で引当'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'JANコード'), '4901234567894');
    await tester.enterText(find.widgetWithText(TextField, '数量'), '5');
    await tester.enterText(find.widgetWithText(TextField, '用途・メモ'), '社内使用');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '引当する'));
    await tester.pumpAndSettle();

    expect(repo.lastReserve,
        (productId: 7, warehouseId: 1, quantity: 5, note: '社内使用'));
    expect(find.text('引当を作成しました'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('an unknown JAN is refused before anything is reserved',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeInventoryRepository();
    await _pump(tester, repo);

    await tester.tap(find.text('手動で引当'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'JANコード'), '4900000000000');
    await tester.enterText(find.widgetWithText(TextField, '数量'), '5');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '引当する'));
    await tester.pumpAndSettle();

    expect(repo.lastReserve, isNull);
    expect(find.text('JAN 4900000000000 の商品が見つかりません'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
}
