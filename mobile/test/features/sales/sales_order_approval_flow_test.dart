// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/sales/application/sales_order_providers.dart';
import 'package:wms_mobile/features/sales/domain/sales_order.dart';
import 'package:wms_mobile/features/sales/presentation/sales_order_detail_screen.dart';
import 'package:wms_mobile/features/shipment/application/shipment_providers.dart';
import 'package:wms_mobile/features/shipment/domain/shipment.dart';
import 'package:wms_mobile/features/shipment/domain/shipment_status.dart';

import '../../support/harness.dart';

SalesOrder _submittedOrder() => const SalesOrder(
      id: 1,
      status: SalesOrderStatus.submitted,
      soNumber: 'SO-000001',
      customerName: '株式会社サンプル商事',
      warehouseId: 1,
      lines: [
        SalesOrderLine(
            id: 1, janCode: '4988601001053', productName: 'ノート', quantity: 4),
      ],
    );

SalesOrder _approvedOrder({
  List<SalesOrderReservation> reservations = const [],
  int? shipmentPlanId,
}) =>
    SalesOrder(
      id: 1,
      status: SalesOrderStatus.approved,
      soNumber: 'SO-000001',
      customerName: '株式会社サンプル商事',
      warehouseId: 1,
      lines: const [
        SalesOrderLine(
            id: 1, janCode: '4988601001053', productName: 'ノート', quantity: 4),
      ],
      reservations: reservations,
      shipmentPlanId: shipmentPlanId,
    );

Future<void> _pump(
  WidgetTester tester,
  FakeSalesOrderRepository repo, {
  List<Shipment> shipments = const [],
}) async {
  await pumpApp(
    tester,
    const SalesOrderDetailScreen(salesOrderId: 1),
    overrides: [
      salesOrderRepositoryProvider.overrideWithValue(repo),
      shipmentRepositoryProvider
          .overrideWithValue(FakeShipmentRepository(shipments)),
    ],
  );
}

void main() {
  testWidgets(
      'approving with a full reservation shows how much was reserved (§6, 0073)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeSalesOrderRepository(orders: [_submittedOrder()])
      ..approvalResult =
          const SalesOrderApprovalResult(reservedLines: 1, skipped: []);
    await _pump(tester, repo);

    await tester.tap(find.text('承認'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, '承認')));
    await tester.pumpAndSettle();

    expect(find.textContaining('引当 1 件'), findsOneWidget);
    expect(find.text('未引当'), findsNothing);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'a shortfall on approval is shown with a way to see which lines (§6, 0073)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeSalesOrderRepository(orders: [_submittedOrder()])
      ..approvalResult = const SalesOrderApprovalResult(
        reservedLines: 0,
        skipped: [
          SalesOrderApprovalSkip(
            lineId: 1,
            janCode: '4988601001053',
            reason: 'insufficient_available',
            available: 2,
            requested: 4,
          ),
        ],
      );
    await _pump(tester, repo);

    await tester.tap(find.text('承認'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, '承認')));
    await tester.pumpAndSettle();

    expect(find.textContaining('未引当 1 件'), findsOneWidget);

    await tester.tap(find.text('詳細'));
    await tester.pumpAndSettle();

    expect(find.text('引当できなかった明細'), findsOneWidget);
    expect(find.textContaining('在庫 2 / 必要 4'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'an approved order with no shipment yet offers to create one, not complete',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeSalesOrderRepository(orders: [_approvedOrder()])
      ..shipmentResult = const ShipmentFromSalesOrderResult(
          shipmentPlanId: 42, lines: 1, reservationsRelinked: 1);
    await _pump(tester, repo, shipments: [
      const Shipment(
          id: 42, shipmentNumber: 'SHP-000042', status: ShipmentStatus.open),
    ]);

    expect(find.text('出荷を作成'), findsOneWidget);
    expect(find.text('完了にする'), findsNothing);

    await tester.tap(find.text('出荷を作成'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, '出荷を作成')));
    await tester.pumpAndSettle();

    // Success navigates straight to the shipment it just created.
    expect(find.text('SHP-000042'), findsOneWidget);
    expect(repo.lastShipmentCreatedFor, 1);
  });

  testWidgets(
      'an approved order that already has a shipment can open it and still complete',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeSalesOrderRepository(orders: [
      _approvedOrder(
        shipmentPlanId: 42,
        reservations: const [
          SalesOrderReservation(
              id: 1,
              janCode: '4988601001053',
              quantity: 4,
              fulfilledQuantity: 0,
              status: 'ACTIVE'),
        ],
      )
    ]);

    await _pump(tester, repo, shipments: [
      const Shipment(
          id: 42, shipmentNumber: 'SHP-000042', status: ShipmentStatus.open),
    ]);

    // The primary action goes back to closing the order's own bookkeeping.
    expect(find.text('完了にする'), findsOneWidget);
    expect(find.text('出荷を開く'), findsOneWidget);

    await tester.tap(find.text('出荷を開く'));
    await tester.pumpAndSettle();

    expect(find.text('SHP-000042'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
}
