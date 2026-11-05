import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/export/xlsx.dart';
import 'package:wms_mobile/features/outbound_file/data/outbound_file_repository.dart';
import 'package:wms_mobile/features/product/application/product_providers.dart';
import 'package:wms_mobile/features/product/domain/product.dart';
import 'package:wms_mobile/features/transfers/presentation/transfer_board_screen.dart';
import 'package:wms_mobile/features/warehouse_context/domain/warehouse_role.dart';
import 'package:wms_mobile/features/transfers/application/transfer_providers.dart';
import 'package:wms_mobile/features/transfers/domain/transfer_order.dart';
import 'package:wms_mobile/features/transfers/presentation/transfer_detail_screen.dart';
import 'package:wms_mobile/features/transfers/presentation/transfer_list_screen.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';
import 'package:wms_mobile/features/warehouse_context/domain/warehouse.dart';

import '../../support/fake_outbound_file_repository.dart';
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

  const twoWarehouses = WarehouseOverview(
    warehouses: [
      Warehouse(id: 1, code: 'MAIN', name: '神戸倉庫'),
      Warehouse(id: 2, code: 'SUB', name: '大阪倉庫'),
    ],
    totals: WarehouseTotals(),
  );
  const library = [
    Product(
      id: 1,
      janCode: '4909999000014',
      name: 'テストペン',
      maker: 'テスト文具',
      sku: 'TS-100',
      stock: ProductStock(onHand: 30, warehouses: [WarehouseStock(warehouseId: 1, name: '神戸倉庫', onHand: 30)]),
    ),
    Product(
      id: 2,
      janCode: '4909999000021',
      name: 'テストノート',
      stock: ProductStock(onHand: 5, warehouses: [WarehouseStock(warehouseId: 2, name: '大阪倉庫', onHand: 5)]),
    ),
  ];
  const order = TransferOrder(
    id: 9,
    transferNumber: 'TR-000009',
    sourceWarehouseId: 1,
    sourceWarehouseName: '神戸倉庫',
    destinationWarehouseId: 2,
    destinationWarehouseName: '大阪倉庫',
  );

  Future<FakeTransferRepository> openBoard(WidgetTester tester, {String? failWith, List<Override> more = const []}) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final transferRepo = FakeTransferRepository(order: order)..failWith = failWith;
    await pumpApp(tester, const TransferListScreen(), overrides: [
      warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(twoWarehouses)),
      transferRepositoryProvider.overrideWithValue(transferRepo),
      productRepositoryProvider.overrideWithValue(FakeProductRepository(products: library)),
      ...more,
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('移動を作成'));
    await tester.pumpAndSettle();
    return transferRepo;
  }

  testWidgets('the two warehouses side by side: only what the leaving one holds is offered; → moves it', (tester) async {
    final repo = await openBoard(tester);
    expect(find.byKey(const ValueKey('tb-src-4909999000014')), findsOneWidget);
    expect(find.byKey(const ValueKey('tb-src-4909999000021')), findsNothing, reason: 'not in 神戸倉庫');
    expect(find.text('ここに商品をドラッグ'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tb-add-4909999000014')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('tb-qty-field')), '40');
    await tester.pump();
    expect(find.text('在庫 30 を超えています'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('tb-qty-field')), '12');
    await tester.tap(find.byKey(const ValueKey('tb-qty-ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tb-line-4909999000014')), findsOneWidget);
    expect(find.textContaining('1品目・12個'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tb-create')));
    await tester.pumpAndSettle();
    expect(repo.created.single.lines.single.quantity, 12);
    expect(repo.created.single.sourceWarehouseId, 1);
    expect(repo.created.single.destinationWarehouseId, 2);
    expect(find.byType(TransferDetailScreen), findsOneWidget);
    expect(find.text('TR-000009'), findsOneWidget);
  });

  testWidgets('a product dragged across is to be moved', (tester) async {
    await openBoard(tester);
    final from = tester.getCenter(find.byKey(const ValueKey('tb-src-4909999000014')));
    final to = tester.getCenter(find.byKey(const ValueKey('tb-drop')));
    final g = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 50));
    await g.moveTo(Offset.lerp(from, to, 0.5)!);
    await tester.pump();
    await g.moveTo(to);
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tb-qty-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tb-qty-ok')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1品目・30個'), findsOneWidget, reason: 'all it holds, offered');
  });

  testWidgets('a file fills the right side: found rows in, the rest said', (tester) async {
    final book = buildXlsxBook([
      const XlsxSheet(name: '明细', headers: ['ジャパンコード', '数量'], rows: [
        ['4909999000014', 6],
        ['4909999000014', 4],
        ['4909999999990', 2],
      ]),
    ]);
    await openBoard(tester, more: [
      transferFilePickerProvider.overrideWithValue(() async => (name: 'move.xlsx', bytes: book)),
      outboundFileRepositoryProvider.overrideWithValue(FakeOutboundFileRepository(
        matcher: (r) => r['jan'] == '4909999000014'
            ? const OutboundMatch(matchedBy: OutboundMatchedBy.jan, productId: 1, jan: '4909999000014', name: 'テストペン')
            : OutboundMatch.none,
      )),
    ]);
    await tester.tap(find.byKey(const ValueKey('tb-file')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1品目・10個'), findsOneWidget);
    expect(find.textContaining('商品が見つからない行: 1'), findsOneWidget);
  });

  testWidgets(
      'a permission-denied create shows the friendly message, not the raw RPC text (§34)',
      (tester) async {
    await openBoard(tester, failWith: 'not permitted: transfer.create required');
    await tester.tap(find.byKey(const ValueKey('tb-add-4909999000014')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tb-qty-ok')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tb-create')));
    await tester.pumpAndSettle();
    expect(find.text('この操作を行う権限がありません。'), findsOneWidget);
    expect(find.textContaining('transfer.create'), findsNothing);
  });

  testWidgets('the list: by state, warehouse and word; leaving and coming apart', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const orders = [
      TransferOrder(id: 1, transferNumber: 'TR-1', sourceWarehouseId: 1, sourceWarehouseName: '神戸倉庫',
          destinationWarehouseId: 2, destinationWarehouseName: '大阪倉庫', status: TransferStatus.picking),
      TransferOrder(id: 2, transferNumber: 'TR-2', sourceWarehouseId: 2, sourceWarehouseName: '大阪倉庫',
          destinationWarehouseId: 1, destinationWarehouseName: '神戸倉庫', status: TransferStatus.completed),
      TransferOrder(id: 3, transferNumber: 'TR-3', sourceWarehouseId: 1, sourceWarehouseName: '神戸倉庫',
          destinationWarehouseId: 2, destinationWarehouseName: '大阪倉庫', status: TransferStatus.cancelled),
    ];
    await pumpApp(tester, const TransferListScreen(), overrides: [
      transferListProvider.overrideWith((ref) async => orders),
      activeWarehouseIdProvider.overrideWith((ref) => 1),
    ]);
    expect(find.text('神戸倉庫 から出す（出庫）（2）'), findsOneWidget);
    expect(find.text('神戸倉庫 に入る（入庫）（1）'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('tl-in')), matching: find.text('TR-2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tl-state-done')));
    await tester.pumpAndSettle();
    expect(find.text('TR-1'), findsNothing);
    expect(find.text('TR-2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tl-state-all')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('tl-search')), 'TR-3');
    await tester.pump();
    expect(find.widgetWithText(Card, 'TR-3'), findsOneWidget);
    expect(find.text('TR-1'), findsNothing);
  });

  testWidgets('choosing a warehouse in another country warns that the goods leave stock (0087)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    final warehouseRepo = FakeWarehouseRepository(const WarehouseOverview(
      warehouses: [
        Warehouse(id: 1, code: 'TKY', name: '東京倉庫'),
        Warehouse(id: 2, code: 'SH', name: '上海倉庫'),
      ],
      totals: WarehouseTotals(),
    ));
    await pumpApp(
      tester,
      const TransferListScreen(),
      overrides: [
        warehouseRepositoryProvider.overrideWithValue(warehouseRepo),
        transferRepositoryProvider.overrideWithValue(FakeTransferRepository(
            order: const TransferOrder(id: 1, sourceWarehouseId: 1, destinationWarehouseId: 2))),
        warehouseRoleRepositoryProvider.overrideWithValue(FakeWarehouseRoleRepository(const [
          WarehouseRole(id: 1, name: '東京倉庫', countryCode: 'JP'),
          WarehouseRole(id: 2, name: '上海倉庫', countryCode: 'CN'),
        ])),
      ],
    );

    await tester.tap(find.text('移動を作成'));
    await tester.pumpAndSettle();

    expect(find.text('東京倉庫（日本）'), findsWidgets);
    expect(find.textContaining('中国への国をまたぐ転送です'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
}
