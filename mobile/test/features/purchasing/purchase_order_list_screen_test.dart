// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/delivery/application/delivery_providers.dart';
import 'package:wms_mobile/features/purchasing/application/purchase_order_providers.dart';
import 'package:wms_mobile/features/purchasing/domain/purchase_order.dart';
import 'package:wms_mobile/features/purchasing/presentation/purchase_order_detail_screen.dart';
import 'package:wms_mobile/features/purchasing/presentation/purchase_order_list_screen.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';
import 'package:wms_mobile/features/warehouse_context/domain/warehouse.dart';

import '../../support/harness.dart';

PurchaseOrder _draftOrder() => const PurchaseOrder(
      id: 1,
      status: PurchaseOrderStatus.draft,
      poNumber: 'PO-000001',
      supplierName: '新東光通商株式会社',
      warehouseId: 1,
      warehouseName: '東京倉庫',
      lines: [
        PurchaseOrderLine(
            id: 1, janCode: '4988601001053', productName: 'ノート', quantity: 10, unitPrice: 120),
      ],
    );

/// EntityAuditTimeline (rendered on the detail screen) reaches a real Dio
/// client if its own repository isn't overridden too, so both screens go
/// through [pumpApp] (which applies harness._defaultOverrides()) rather than
/// a hand-built ProviderContainer + pumpAppWith.
Future<void> _pumpList(WidgetTester tester, FakePurchaseOrderRepository repo,
    {WarehouseOverview? overview}) async {
  await pumpApp(
    tester,
    const PurchaseOrderListScreen(),
    overrides: [
      purchaseOrderRepositoryProvider.overrideWithValue(repo),
      warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(
        overview ??
            WarehouseOverview(
              warehouses: const [Warehouse(id: 1, code: 'TKY', name: '東京倉庫')],
              totals: const WarehouseTotals(),
            ),
      )),
    ],
  );
}

Future<void> _pumpDetail(
  WidgetTester tester,
  FakePurchaseOrderRepository repo,
  int id, {
  List<Override> extraOverrides = const [],
}) async {
  await pumpApp(
    tester,
    PurchaseOrderDetailScreen(purchaseOrderId: id),
    overrides: [
      purchaseOrderRepositoryProvider.overrideWithValue(repo),
      ...extraOverrides,
    ],
  );
}

void main() {
  testWidgets('lists purchase orders with number, supplier and status',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakePurchaseOrderRepository(orders: [_draftOrder()]);
    await _pumpList(tester, repo);

    expect(find.text('PO-000001'), findsOneWidget);
    expect(find.text('新東光通商株式会社'), findsOneWidget);
    expect(find.text('下書き'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('the empty state explains how to create the first order',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakePurchaseOrderRepository();
    await _pumpList(tester, repo);

    expect(find.text('発注がまだありません'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('creating a purchase order opens its detail screen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakePurchaseOrderRepository();
    await _pumpList(tester, repo);

    await tester.tap(find.text('発注を作成'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '仕入先名'), 'テスト仕入先');
    await tester.tap(find.text('明細を追加'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'JANコード'), '4988601001053');
    await tester.enterText(find.widgetWithText(TextField, '数量'), '5');
    await tester.tap(find.widgetWithText(FilledButton, '明細を追加'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '作成'));
    await tester.pumpAndSettle();

    expect(find.byType(PurchaseOrderDetailScreen), findsOneWidget);
    expect(find.text('テスト仕入先'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'a permission-denied create shows the friendly message, not the raw RPC text (§34)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakePurchaseOrderRepository()
      ..failWith = 'not permitted: po.manage required';
    await _pumpList(tester, repo);

    await tester.tap(find.text('発注を作成'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '仕入先名'), 'テスト仕入先');
    await tester.tap(find.text('明細を追加'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'JANコード'), '4988601001053');
    await tester.enterText(find.widgetWithText(TextField, '数量'), '5');
    await tester.tap(find.widgetWithText(FilledButton, '明細を追加'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '作成'));
    await tester.pumpAndSettle();

    expect(find.text('この操作を行う権限がありません。'), findsOneWidget);
    expect(find.textContaining('po.manage'), findsNothing);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'driving a draft through submit -> approve -> create delivery plan updates its status',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakePurchaseOrderRepository(orders: [_draftOrder()]);
    await _pumpDetail(tester, repo, 1);

    expect(find.text('下書き'), findsOneWidget);
    await tester.tap(find.text('提出'));
    await tester.pumpAndSettle();
    expect(find.text('提出済み'), findsOneWidget);
    // Each action shows a success SnackBar that pumpAndSettle doesn't wait
    // out (nothing is animating while it just sits there) — advance past its
    // default 4s duration so it isn't still covering the next button.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.text('承認'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, '承認')));
    await tester.pumpAndSettle();
    expect(find.text('承認済み'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Approving is bookkeeping only (0083): the primary action is creating
    // the delivery plan that will actually be received, not completing the
    // order outright. Confirming it navigates to the new plan's own
    // reconciliation screen, so this is where this order's own screen ends.
    await tester.tap(find.text('入荷予定を作成'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, '入荷予定を作成')));
    await tester.pumpAndSettle();
    expect(repo.lastDeliveryPlanCreatedFor, 1);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('creating a delivery plan reports how many lines it copied',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakePurchaseOrderRepository(orders: [
      const PurchaseOrder(
        id: 2,
        status: PurchaseOrderStatus.approved,
        poNumber: 'PO-000002',
        supplierName: '新東光通商株式会社',
        warehouseId: 1,
        warehouseName: '東京倉庫',
        lines: [
          PurchaseOrderLine(
              id: 1, janCode: '4988601001053', productName: 'ノート', quantity: 10),
        ],
      ),
    ])
      ..deliveryPlanResult =
          const DeliveryPlanFromPurchaseOrderResult(deliveryPlanId: 55, lines: 1);
    await _pumpDetail(tester, repo, 2, extraOverrides: [
      // The successful create navigates straight to ReconciliationScreen for
      // the new plan; a fake here keeps that a quick, harmless error state
      // instead of a real network call the test would otherwise wait on.
      deliveryRepositoryProvider.overrideWithValue(FakeDeliveryRepository([])),
    ]);

    await tester.tap(find.text('入荷予定を作成'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, '入荷予定を作成')));
    await tester.pumpAndSettle();

    expect(find.text('入荷予定を作成しました（明細 1 件）'), findsOneWidget);
    expect(repo.lastDeliveryPlanCreatedFor, 2);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'an order whose lines are all on a delivery plan offers to open it, not create another',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakePurchaseOrderRepository(orders: [
      const PurchaseOrder(
        id: 3,
        status: PurchaseOrderStatus.approved,
        poNumber: 'PO-000003',
        supplierName: '新東光通商株式会社',
        warehouseId: 1,
        deliveryPlanId: 60,
        deliveryPlans: [
          PurchaseOrderDeliveryPlan(id: 60, deliveryNumber: 'DP-000060', status: 'open'),
        ],
        lines: [
          PurchaseOrderLine(id: 1, janCode: '4988601001053', quantity: 10, planned: 10),
        ],
      ),
    ]);
    await _pumpDetail(tester, repo, 3);

    expect(find.text('入荷予定を作成'), findsNothing);
    expect(find.text('完了にする'), findsOneWidget);
    expect(find.byTooltip('入荷予定を開く'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'a split delivery offers a plan for the rest, and shows which orders it was bought for (0084)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    final repo = FakePurchaseOrderRepository(orders: [
      const PurchaseOrder(
        id: 4,
        status: PurchaseOrderStatus.approved,
        poNumber: 'PO-000004',
        supplierName: '新東光通商株式会社',
        warehouseId: 1,
        deliveryPlanId: 61,
        deliveryPlans: [
          PurchaseOrderDeliveryPlan(id: 61, deliveryNumber: 'DP-000061', status: 'completed'),
        ],
        lines: [
          PurchaseOrderLine(
            id: 1,
            janCode: '4988601001053',
            quantity: 10,
            planned: 6,
            received: 6,
            demands: [
              PurchaseOrderLineDemand(
                  salesOrderLineId: 9, salesOrderId: 7, soNumber: 'SO-000007', customerName: '顧客A', quantity: 4),
              PurchaseOrderLineDemand(
                  salesOrderLineId: 10, salesOrderId: 8, soNumber: 'SO-000008', customerName: '顧客B', quantity: 6),
            ],
          ),
        ],
      ),
    ]);
    await _pumpDetail(tester, repo, 4);

    expect(find.text('残りの入荷予定を作成'), findsOneWidget);
    expect(find.text('DP-000061'), findsOneWidget);
    expect(find.text('SO-000007 顧客A ×4'), findsOneWidget);
    expect(find.text('SO-000008 顧客B ×6'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
}
