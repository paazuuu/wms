import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/transfers/application/transfer_providers.dart';
import 'package:wms_mobile/features/transfers/domain/transfer_order.dart';
import 'package:wms_mobile/features/transfers/presentation/transfer_detail_screen.dart';
import 'package:wms_mobile/features/transfers/presentation/transfer_list_screen.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';
import 'package:wms_mobile/features/warehouse_context/domain/warehouse.dart';

import '../../support/harness.dart';

void main() {
  testWidgets('creating a transfer requires at least two warehouses',
      (tester) async {
    final warehouseRepo = FakeWarehouseRepository(const WarehouseOverview(
      warehouses: [Warehouse(id: 1, code: 'MAIN', name: 'メイン倉庫')],
      totals: WarehouseTotals(),
    ));

    await pumpApp(
      tester,
      const TransferListScreen(),
      overrides: [warehouseRepositoryProvider.overrideWithValue(warehouseRepo)],
    );
    // Let the overview provider resolve before tapping.
    await tester.pumpAndSettle();

    await tester.tap(find.text('移動を作成'));
    await tester.pumpAndSettle();

    expect(find.text('倉庫が2つ以上必要です'), findsOneWidget);
  });

  testWidgets('creating a transfer opens the new order', (tester) async {
    final warehouseRepo = FakeWarehouseRepository(const WarehouseOverview(
      warehouses: [
        Warehouse(id: 1, code: 'MAIN', name: '神戸倉庫'),
        Warehouse(id: 2, code: 'SUB', name: '大阪倉庫'),
      ],
      totals: WarehouseTotals(),
    ));
    const order = TransferOrder(
      id: 9,
      transferNumber: 'TR-000009',
      sourceWarehouseId: 1,
      sourceWarehouseName: '神戸倉庫',
      destinationWarehouseId: 2,
      destinationWarehouseName: '大阪倉庫',
    );
    final transferRepo = FakeTransferRepository(order: order);

    await pumpApp(
      tester,
      const TransferListScreen(),
      overrides: [
        warehouseRepositoryProvider.overrideWithValue(warehouseRepo),
        transferRepositoryProvider.overrideWithValue(transferRepo),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('移動を作成'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('商品を追加'));
    await tester.pumpAndSettle();

    // Scope to the dialog: the sheet behind it has its own TextField (the
    // note), so an unscoped .first/.last would silently miss the dialog's.
    final dialogFields =
        find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
    await tester.enterText(dialogFields.first, '4901234567894');
    await tester.enterText(dialogFields.last, '10');
    await tester.tap(find.widgetWithText(FilledButton, '商品を追加'));
    await tester.pumpAndSettle();

    // The sheet's content can run below the fold on the small test viewport;
    // scroll the submit button into view before tapping.
    await tester.ensureVisible(find.widgetWithText(FilledButton, '移動を作成'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '移動を作成'));
    await tester.pumpAndSettle();

    // The new order's own detail screen is now showing.
    expect(find.byType(TransferDetailScreen), findsOneWidget);
    expect(find.text('TR-000009'), findsOneWidget);
  });
}
