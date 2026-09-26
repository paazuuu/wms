// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/demand/application/demand_providers.dart';
import 'package:wms_mobile/features/demand/domain/open_demand.dart';
import 'package:wms_mobile/features/demand/presentation/open_demand_screen.dart';
import 'package:wms_mobile/features/purchasing/application/purchase_order_providers.dart';
import 'package:wms_mobile/features/purchasing/domain/purchase_order.dart';
import 'package:wms_mobile/features/purchasing/presentation/purchase_order_detail_screen.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';

import '../../support/harness.dart';

OpenDemandItem _notebook() => OpenDemandItem(
      warehouseId: 1,
      productId: 7,
      janCode: '4988601001053',
      productName: 'ノート',
      ordered: 12,
      promised: 3,
      shipped: 0,
      backordered: 9,
      available: 2,
      incoming: 4,
      canFillNow: 2,
      toPurchase: 3,
      preferredSupplierId: 5,
      preferredSupplierName: '新東光通商株式会社',
      lines: [
        OpenDemandLine(
          salesOrderLineId: 9,
          salesOrderId: 7,
          soNumber: 'SO-000007',
          customerName: '顧客A',
          ordered: 5,
          promised: 3,
          backordered: 2,
        ),
        OpenDemandLine(
          salesOrderLineId: 10,
          salesOrderId: 8,
          soNumber: 'SO-000008',
          customerName: '顧客B',
          ordered: 7,
          promised: 0,
          backordered: 7,
          onOrder: 4,
        ),
      ],
    );

OpenDemandItem _pen() => OpenDemandItem(
      warehouseId: 1,
      productId: 8,
      janCode: '4901234567894',
      productName: 'ボールペン',
      ordered: 5,
      promised: 5,
      shipped: 0,
      backordered: 5,
      available: 0,
      incoming: 5,
      canFillNow: 0,
      toPurchase: 0,
    );

Future<void> _pump(
  WidgetTester tester,
  FakeDemandRepository repo, {
  FakePurchaseOrderRepository? purchases,
}) async {
  // pumpApp's default fakes also cover the purchase order screen a created
  // order navigates to (its activity timeline included).
  await pumpApp(tester, const OpenDemandScreen(), overrides: [
    demandRepositoryProvider.overrideWithValue(repo),
    purchaseOrderRepositoryProvider
        .overrideWithValue(purchases ?? FakePurchaseOrderRepository()),
    activeWarehouseIdProvider.overrideWith((_) => 1),
  ]);
}

void main() {
  testWidgets('each product shows what is waiting and how it is covered',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    await _pump(tester, FakeDemandRepository(items: [_notebook(), _pen()]));

    expect(find.text('ノート'), findsOneWidget);
    expect(find.text('要発注 3'), findsOneWidget);
    // Covered by what is already on its way: nothing to buy, nothing to fill.
    expect(find.text('手配済み'), findsOneWidget);
    expect(find.text('在庫から引当（2）'), findsOneWidget);
    expect(find.text('待っている注文 2 件'), findsOneWidget);

    await tester.tap(find.text('待っている注文 2 件'));
    await tester.pumpAndSettle();
    expect(find.text('SO-000008 · 顧客B'), findsOneWidget);
    expect(find.text('受注 7 ・引当 0 ・残 7 ・発注中 4'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('nothing waiting is a calm empty state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    await _pump(tester, FakeDemandRepository());

    expect(find.text('待っている注文はありません'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('filling one product asks for that product only', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    final repo = FakeDemandRepository(items: [_notebook()])
      ..fillResult = const BackorderFillResult(reservedUnits: 2);
    await _pump(tester, repo);

    await tester.tap(find.text('在庫から引当（2）'));
    await tester.pumpAndSettle();

    expect(repo.fills.single.productId, 7);
    expect(repo.fills.single.lineId, isNull);
    expect(find.text('2 個を引当しました'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('one order can be served first, with a chosen quantity',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    final repo = FakeDemandRepository(items: [_notebook()])
      ..fillResult = const BackorderFillResult(reservedUnits: 1);
    await _pump(tester, repo);

    await tester.tap(find.text('待っている注文 2 件'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('この注文に引当').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '引当数'), '1');
    await tester.tap(find.widgetWithText(FilledButton, 'この注文に引当'));
    await tester.pumpAndSettle();

    expect(repo.fills.single.lineId, 10);
    expect(repo.fills.single.quantity, 1);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'selected products become one purchase order, defaulting to what is left to buy',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    final repo = FakeDemandRepository(items: [_notebook(), _pen()])
      ..purchaseResult =
          const PurchaseFromDemandResult(purchaseOrderId: 9, lines: 1, links: 2);
    final purchases = FakePurchaseOrderRepository(orders: [
      PurchaseOrder(
        id: 9,
        status: PurchaseOrderStatus.draft,
        poNumber: 'PO-000009',
        supplierName: '新東光通商株式会社',
        warehouseId: 1,
        lines: [PurchaseOrderLine(id: 1, janCode: '4988601001053', quantity: 3)],
      ),
    ]);
    await _pump(tester, repo, purchases: purchases);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('発注を作成（1 品目）'));
    await tester.pumpAndSettle();

    // The preferred supplier is prefilled; the quantity starts at 要発注.
    expect(find.widgetWithText(TextField, '新東光通商株式会社'), findsOneWidget);
    expect(find.widgetWithText(TextField, '3'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '作成'));
    await tester.pumpAndSettle();

    final sent = repo.purchases.single;
    expect(sent.supplierName, '新東光通商株式会社');
    expect(sent.supplierId, 5);
    expect(sent.lines.single.janCode, '4988601001053');
    expect(sent.lines.single.quantity, 3);
    expect(find.byType(PurchaseOrderDetailScreen), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('ordering less than the backorder is allowed', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    final repo = FakeDemandRepository(items: [_notebook()]);
    await _pump(tester, repo);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('発注を作成（1 品目）'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('demand-po-qty-7')), '1');
    // A different supplier's name drops the preferred supplier's record.
    await tester.enterText(
        find.widgetWithText(TextField, '新東光通商株式会社'), '別の仕入先');
    await tester.tap(find.widgetWithText(FilledButton, '作成'));
    await tester.pumpAndSettle();

    final sent = repo.purchases.single;
    expect(sent.lines.single.quantity, 1);
    expect(sent.supplierName, '別の仕入先');
    expect(sent.supplierId, isNull);

    await tester.binding.setSurfaceSize(null);
  });
}
