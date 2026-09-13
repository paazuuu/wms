// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';
import 'package:wms_mobile/features/warehouse_context/domain/warehouse.dart';
import 'package:wms_mobile/features/work_orders/application/work_order_providers.dart';
import 'package:wms_mobile/features/work_orders/domain/work_order.dart';
import 'package:wms_mobile/features/work_orders/presentation/work_order_detail_screen.dart';
import 'package:wms_mobile/features/work_orders/presentation/work_order_list_screen.dart';

import '../../support/harness.dart';

WorkOrder _draftOrder() => const WorkOrder(
      id: 1,
      status: WorkOrderStatus.draft,
      woNumber: 'WO-000001',
      warehouseId: 1,
      warehouseName: '東京倉庫',
      outputJanCode: '4988601001053',
      outputProductName: 'テストキット',
      outputQuantity: 5,
      components: [
        WorkOrderComponent(
            id: 1, janCode: '4901234567890', productName: 'テスト部品', quantityRequired: 20),
      ],
    );

/// EntityAuditTimeline (rendered on the detail screen) reaches a real Dio
/// client if its own repository isn't overridden too, so both screens go
/// through [pumpApp] (which applies harness._defaultOverrides()) rather than
/// a hand-built ProviderContainer + pumpAppWith.
Future<void> _pumpList(WidgetTester tester, FakeWorkOrderRepository repo,
    {WarehouseOverview? overview}) async {
  await pumpApp(
    tester,
    const WorkOrderListScreen(),
    overrides: [
      workOrderRepositoryProvider.overrideWithValue(repo),
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

Future<void> _pumpDetail(WidgetTester tester, FakeWorkOrderRepository repo, int id) async {
  await pumpApp(
    tester,
    WorkOrderDetailScreen(workOrderId: id),
    overrides: [workOrderRepositoryProvider.overrideWithValue(repo)],
  );
}

void main() {
  testWidgets('lists work orders with number, output and status', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeWorkOrderRepository(orders: [_draftOrder()]);
    await _pumpList(tester, repo);

    expect(find.text('WO-000001'), findsOneWidget);
    expect(find.text('テストキット × 5'), findsOneWidget);
    expect(find.text('下書き'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('the empty state explains how to create the first work order',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeWorkOrderRepository();
    await _pumpList(tester, repo);

    expect(find.text('作業指示がまだありません'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('creating a work order opens its detail screen', (tester) async {
    // Taller than the other create-sheet tests: this form has more fields
    // (warehouse, output JAN/name/quantity, components, note) than fit a
    // 1000px-tall surface without scrolling.
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    final repo = FakeWorkOrderRepository();
    await _pumpList(tester, repo);

    await tester.tap(find.text('作業指示を作成'));
    await tester.pumpAndSettle();

    // JAN fields enforce digits-only input (real barcode scanning behavior),
    // so the test codes must be numeric or entry silently strips to empty.
    await tester.enterText(find.widgetWithText(TextField, 'JANコード'), '4988601001053');
    await tester.enterText(find.widgetWithText(TextField, '商品名'), 'テストキット');
    await tester.enterText(find.widgetWithText(TextField, '完成数量'), '5');
    await tester.tap(find.text('部材を追加'));
    await tester.pumpAndSettle();

    // The dialog's own JAN field shares the "JANコード" label with the
    // output field already on the sheet behind it — scope to the dialog.
    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.widgetWithText(TextField, 'JANコード')),
        '4901234567890');
    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.widgetWithText(TextField, '商品名')),
        'テスト部品');
    await tester.enterText(find.widgetWithText(TextField, '必要数量'), '20');
    await tester.tap(find.widgetWithText(FilledButton, '部材を追加'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('テスト部品'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '作成'));
    await tester.pumpAndSettle();

    expect(find.byType(WorkOrderDetailScreen), findsOneWidget);
    expect(find.text('テストキット × 5'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('driving a draft through start -> complete updates its status',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeWorkOrderRepository(orders: [_draftOrder()]);
    await _pumpDetail(tester, repo, 1);

    expect(find.text('下書き'), findsOneWidget);
    await tester.tap(find.text('作業開始'));
    await tester.pumpAndSettle();
    expect(find.text('作業中'), findsOneWidget);
    // The success SnackBar pumpAndSettle doesn't wait out (nothing is
    // animating while it just sits there) can cover the next button.
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
