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
      'selected products open a purchase page defaulting to what is left to buy, linked oldest first',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2000));
    final repo = FakeDemandRepository(items: [_notebook(), _pen()])
      ..purchaseResult =
          const PurchaseFromDemandResult(purchaseOrderId: 9, lines: 1, links: 1);
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

    // Preferred supplier prefilled; quantity starts at 要発注 (3).
    expect(tester.widget<TextField>(find.byKey(const ValueKey('po-supplier-7-0'))).controller!.text,
        '新東光通商株式会社');
    expect(tester.widget<TextField>(find.byKey(const ValueKey('po-qty-7-0'))).controller!.text, '3');
    // Free stock (2) reaches SO-000007's 2 first; B waits 7 with 4 on order,
    // so the 3 bought are linked to B.
    expect(tester.widget<TextField>(find.byKey(const ValueKey('po-link-7-0-9'))).controller!.text, '');
    expect(tester.widget<TextField>(find.byKey(const ValueKey('po-link-7-0-10'))).controller!.text, '3');

    await tester.tap(find.text('発注を作成（1 社）'));
    await tester.pumpAndSettle();

    final sent = repo.purchases.single;
    expect(sent.supplierName, '新東光通商株式会社');
    expect(sent.supplierId, 5);
    expect(sent.lines.single.quantity, 3);
    expect(sent.lines.single.demands, [DemandLink(salesOrderLineId: 10, quantity: 3)]);
    expect(find.byType(PurchaseOrderDetailScreen), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'one product split across two suppliers makes two purchase orders, each linked by hand',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    final repo = FakeDemandRepository(items: [_notebook()]);
    await _pump(tester, repo);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('発注を作成（1 品目）'));
    await tester.pumpAndSettle();

    // Buy more than needed from the first supplier: 5, with 2 for B by hand.
    await tester.enterText(find.byKey(const ValueKey('po-qty-7-0')), '5');
    await tester.enterText(find.byKey(const ValueKey('po-link-7-0-10')), '2');
    await tester.pump();
    expect(find.text('紐付け 2 ・見込み（紐付けなし）3'), findsOneWidget);

    await tester.tap(find.text('仕入先を分ける'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('po-supplier-7-1')), '別の商会');
    await tester.enterText(find.byKey(const ValueKey('po-qty-7-1')), '4');
    await tester.enterText(find.byKey(const ValueKey('po-link-7-1-9')), '2');
    await tester.enterText(find.byKey(const ValueKey('po-link-7-1-10')), '2');
    await tester.pump();

    await tester.tap(find.text('発注を作成（2 社）'));
    await tester.pumpAndSettle();

    expect(repo.purchases, hasLength(2));
    final first = repo.purchases[0];
    expect(first.supplierName, '新東光通商株式会社');
    expect(first.lines.single.quantity, 5);
    expect(first.lines.single.demands, [DemandLink(salesOrderLineId: 10, quantity: 2)]);
    final second = repo.purchases[1];
    expect(second.supplierName, '別の商会');
    expect(second.supplierId, isNull);
    expect(second.lines.single.demands, [
      DemandLink(salesOrderLineId: 9, quantity: 2),
      DemandLink(salesOrderLineId: 10, quantity: 2),
    ]);
    expect(find.text('発注を 2 件作成しました'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('linking more than a row orders is refused before sending',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2000));
    final repo = FakeDemandRepository(items: [_notebook()]);
    await _pump(tester, repo);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('発注を作成（1 品目）'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('po-link-7-0-10')), '5');
    await tester.pump();

    expect(find.text('紐付け 5 が発注数 3 を超えています'), findsOneWidget);
    expect(
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, '発注を作成（1 社）')).onPressed,
        isNull);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('each supplier purchase bringing a product in is shown, with what is bought ahead',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    await _pump(tester, FakeDemandRepository(items: [
      OpenDemandItem(
        warehouseId: 1,
        productId: 9,
        janCode: '4900000000001',
        productName: '消しゴム',
        ordered: 0,
        promised: 0,
        shipped: 0,
        backordered: 0,
        available: 0,
        incoming: 10,
        incomingUnlinked: 6,
        canFillNow: 0,
        toPurchase: 0,
        incomingOrders: [
          IncomingPurchase(purchaseOrderId: 1, poNumber: 'PO-000001', supplierName: 'S1', outstanding: 4),
          IncomingPurchase(
              purchaseOrderId: 2, poNumber: 'PO-000002', supplierName: 'S2', outstanding: 6, unlinked: 6),
        ],
      ),
    ]));

    expect(find.text('見込みのみ'), findsOneWidget);
    expect(find.text('入荷予定 10（うち見込み 6）'), findsOneWidget);
    expect(find.text('PO-000001 · S1 · 残 4'), findsOneWidget);
    expect(find.text('PO-000002 · S2 · 残 6（見込み 6）'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
}
