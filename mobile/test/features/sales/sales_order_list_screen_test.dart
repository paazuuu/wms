// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/sales/application/sales_order_providers.dart';
import 'package:wms_mobile/features/sales/domain/sales_order.dart';
import 'package:wms_mobile/features/sales/presentation/sales_order_detail_screen.dart';
import 'package:wms_mobile/features/sales/presentation/sales_order_list_screen.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';
import 'package:wms_mobile/features/warehouse_context/domain/warehouse.dart';

import '../../support/harness.dart';

SalesOrder _draftOrder() => const SalesOrder(
      id: 1,
      status: SalesOrderStatus.draft,
      soNumber: 'SO-000001',
      customerName: '株式会社サンプル商事',
      warehouseId: 1,
      warehouseName: '東京倉庫',
      lines: [
        SalesOrderLine(
            id: 1, janCode: '4988601001053', productName: 'ノート', quantity: 4, unitPrice: 150),
      ],
    );

/// EntityAuditTimeline (rendered on the detail screen) reaches a real Dio
/// client if its own repository isn't overridden too, so both screens go
/// through [pumpApp] (which applies harness._defaultOverrides()) rather than
/// a hand-built ProviderContainer + pumpAppWith.
Future<void> _pumpList(WidgetTester tester, FakeSalesOrderRepository repo,
    {WarehouseOverview? overview}) async {
  await pumpApp(
    tester,
    const SalesOrderListScreen(),
    overrides: [
      salesOrderRepositoryProvider.overrideWithValue(repo),
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

Future<void> _pumpDetail(WidgetTester tester, FakeSalesOrderRepository repo, int id) async {
  await pumpApp(
    tester,
    SalesOrderDetailScreen(salesOrderId: id),
    overrides: [salesOrderRepositoryProvider.overrideWithValue(repo)],
  );
}

void main() {
  testWidgets('lists sales orders with number, customer and status',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeSalesOrderRepository(orders: [_draftOrder()]);
    await _pumpList(tester, repo);

    expect(find.text('SO-000001'), findsOneWidget);
    expect(find.text('株式会社サンプル商事'), findsOneWidget);
    expect(find.text('下書き'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('the empty state explains how to create the first order',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeSalesOrderRepository();
    await _pumpList(tester, repo);

    expect(find.text('受注がまだありません'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('creating a sales order opens its detail screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeSalesOrderRepository();
    await _pumpList(tester, repo);

    await tester.tap(find.text('受注を作成'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '顧客名'), 'テスト顧客');
    await tester.tap(find.text('明細を追加'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'JANコード'), '4988601001053');
    await tester.enterText(find.widgetWithText(TextField, '数量'), '3');
    await tester.tap(find.widgetWithText(FilledButton, '明細を追加'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '作成'));
    await tester.pumpAndSettle();

    expect(find.byType(SalesOrderDetailScreen), findsOneWidget);
    expect(find.text('テスト顧客'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'driving a draft through submit -> approve -> complete updates its status',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeSalesOrderRepository(orders: [_draftOrder()]);
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

    await tester.tap(find.text('完了にする'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, '完了にする')));
    await tester.pumpAndSettle();
    expect(find.text('完了'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
}
