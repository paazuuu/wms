import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/export/xlsx.dart';
import 'package:wms_mobile/features/outbound/data/outbound_repository.dart' show shipDestinationsProvider;
import 'package:wms_mobile/features/outbound/domain/outbound.dart' show ShipDestination;
import 'package:wms_mobile/features/outbound_file/data/outbound_costs_repository.dart';
import 'package:wms_mobile/features/outbound_file/data/outbound_file_repository.dart';
import 'package:wms_mobile/features/outbound_file/presentation/outbound_costs_panel.dart' show costFilePickerProvider;
import 'package:wms_mobile/features/outbound_file/domain/outbound_plan.dart';
import 'package:wms_mobile/features/outbound_file/domain/outbound_sheet.dart';
import 'package:wms_mobile/features/outbound_file/presentation/outbound_file_detail_screen.dart';
import 'package:wms_mobile/features/outbound_file/presentation/outbound_file_screen.dart';
import 'package:wms_mobile/features/product/application/product_providers.dart';
import 'package:wms_mobile/features/product/domain/product.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';
import 'package:wms_mobile/features/warehouse_context/domain/warehouse.dart';

import '../../support/fake_outbound_costs_repository.dart';
import '../../support/fake_outbound_file_repository.dart';
import '../../support/harness.dart';

final _plan = OutboundFileSummary(
  id: 5,
  warehouseId: 1,
  warehouseName: '本倉庫',
  shippedOn: DateTime(2026, 11, 20),
  fileName: '明細.xlsx',
  status: 'planned',
  lineCount: 2,
  quantityTotal: 35,
);

const _lines = [
  OutboundFileLine(
      id: 1, rowNo: 2, action: 'ship', productId: 1, jan: '4909999000014', productName: 'テストペン', quantity: 30, unitPrice: 50),
  OutboundFileLine(
      id: 2, rowNo: 3, action: 'ship', productId: 2, jan: '4909999000021', productName: 'テストノート', quantity: 5, unitPrice: 40),
];

const _library = [
  Product(
    id: 7,
    janCode: '4909999000069',
    name: 'テスト消しゴム',
    maker: 'テスト文具',
    sku: 'TS-140',
    stock: ProductStock(onHand: 9, warehouses: [WarehouseStock(warehouseId: 1, name: '本倉庫', onHand: 9)]),
  ),
];

const _overview = WarehouseOverview(
  warehouses: [Warehouse(id: 1, code: 'WH-01', name: '本倉庫')],
  totals: WarehouseTotals(),
);

void main() {
  test('what a new file changes: added, left out, changed in quantity', () {
    OutboundPlanLine line(int row, String jan, int qty, {int? pid, String? name}) => OutboundPlanLine(
          row: OutboundRow(rowNo: row, jan: jan, quantity: qty),
          match: OutboundMatch(matchedBy: OutboundMatchedBy.jan, productId: pid, jan: jan, name: name),
          status: OutboundStatus.ok,
          action: OutboundAction.ship,
          shipped: qty,
          short: 0,
        );
    final d = outboundLinesDiff(_lines, [
      line(2, '4909999000014', 20, pid: 1, name: 'テストペン'),
      line(3, '4909999000069', 3, pid: 7, name: 'テスト消しゴム'),
    ]);
    expect(d.added.single, (name: 'テスト消しゴム', quantity: 3));
    expect(d.removed.single, (name: 'テストノート', quantity: 5));
    expect(d.changed.single, (name: 'テストペン', from: 30, to: 20));
  });

  Future<FakeOutboundFileRepository> pumpDetail(WidgetTester tester, OutboundFileSummary f) async {
    await tester.binding.setSurfaceSize(const Size(2400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeOutboundFileRepository(detailOf: (_) => OutboundFileDetail(file: f, lines: _lines));
    await pumpApp(tester, const OutboundFileDetailScreen(fileId: 5), overrides: [
      outboundFileRepositoryProvider.overrideWithValue(repo),
      productRepositoryProvider.overrideWithValue(FakeProductRepository(products: _library)),
      warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(_overview)),
      writeWarehouseIdProvider.overrideWithValue(1),
      shipDestinationsProvider.overrideWith((ref) async => const [ShipDestination(id: 31, name: 'テスト貿易')]),
    ]);
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('委託手数料 (0213): a 在庫外出荷 shows its fee and takes one typed in', (tester) async {
    await tester.binding.setSurfaceSize(const Size(2400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final f = OutboundFileSummary(
        id: 7, warehouseId: 1, shippedOn: DateTime(2026, 11, 20), fileName: '手入力', kind: 'proxy', principal: 'テスト物流');
    final repo = FakeOutboundFileRepository(detailOf: (_) => OutboundFileDetail(file: f, lines: _lines));
    await pumpApp(tester, const OutboundFileDetailScreen(fileId: 7), overrides: [
      outboundFileRepositoryProvider.overrideWithValue(repo),
      productRepositoryProvider.overrideWithValue(FakeProductRepository(products: _library)),
      warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(_overview)),
      writeWarehouseIdProvider.overrideWithValue(1),
    ]);
    expect(find.text('委託手数料: 未入力'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('of-fee-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('of-fee-field')), '¥2,500');
    await tester.tap(find.byKey(const ValueKey('of-fee-save')));
    await tester.pumpAndSettle();
    expect(repo.fees, [(7, 2500.0)]);
  });

  testWidgets('輸送費 (0214): typed, read off a bill kept as evidence, the bill opened and taken off', (tester) async {
    await tester.binding.setSurfaceSize(const Size(2400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeOutboundFileRepository(detailOf: (_) => OutboundFileDetail(file: _plan, lines: _lines));
    final costs = FakeOutboundCostsRepository(read: (subtotal: 3000, tax: 300, total: 3300));
    final saved = <String>[];
    await pumpApp(tester, const OutboundFileDetailScreen(fileId: 5), overrides: [
      outboundFileRepositoryProvider.overrideWithValue(repo),
      outboundCostsRepositoryProvider.overrideWithValue(costs),
      costFilePickerProvider.overrideWithValue(() async => [(name: '運賃請求書.pdf', bytes: Uint8List.fromList(const [1, 2]))]),
      outboundTabOpenerProvider.overrideWithValue(() => null),
      outboundFileSaverProvider.overrideWithValue((n, b) async => saved.add(n)),
      productRepositoryProvider.overrideWithValue(FakeProductRepository(products: _library)),
      warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(_overview)),
      writeWarehouseIdProvider.overrideWithValue(1),
    ]);
    expect(find.text('輸送費: 未入力'), findsOneWidget);
    // A list of our own stock has no 委託手数料.
    expect(find.byKey(const ValueKey('of-fee')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('of-freight-edit')));
    await tester.pumpAndSettle();
    expect(find.text('証拠のファイルはまだありません'), findsOneWidget);

    // A bill added: kept, and with no amount yet, read at once.
    await tester.tap(find.byKey(const ValueKey('oc-add')));
    await tester.pumpAndSettle();
    expect(costs.added.single.name, '運賃請求書.pdf');
    expect(costs.added.single.kind, OutboundCostKind.freight);
    expect(costs.reads, [100]);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('of-freight-field'))).controller!.text, '3,000');
    expect(find.textContaining('税抜 ¥3,000／税込 ¥3,300'), findsOneWidget);

    // Opened on the spot (saved where no tab opens) and downloaded.
    await tester.tap(find.byKey(const ValueKey('oc-open-100')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('oc-download-100')));
    await tester.pumpAndSettle();
    expect(saved, ['運賃請求書.pdf', '運賃請求書.pdf']);

    // Taken off after a confirm.
    await tester.tap(find.byKey(const ValueKey('oc-remove-100')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('oc-remove-ok')));
    await tester.pumpAndSettle();
    expect(costs.removed, [100]);
    expect(find.byKey(const ValueKey('oc-file-100')), findsNothing);

    // A wrong amount is not sent.
    await tester.enterText(find.byKey(const ValueKey('of-freight-field')), '-5');
    await tester.tap(find.byKey(const ValueKey('of-freight-save')));
    await tester.pumpAndSettle();
    expect(find.text('マイナスの金額は入れられません'), findsOneWidget);
    expect(costs.freights, isEmpty);
    await tester.enterText(find.byKey(const ValueKey('of-freight-field')), '¥3,200');
    await tester.tap(find.byKey(const ValueKey('of-freight-save')));
    await tester.pumpAndSettle();
    expect(costs.freights, [(5, 3200.0)]);
    expect(find.byKey(const ValueKey('of-freight-field')), findsNothing);
  });

  testWidgets('輸送費 (0214): once 出庫済み the costs are shown with their bills but not changed', (tester) async {
    await tester.binding.setSurfaceSize(const Size(2400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final shipped = OutboundFileSummary(
        id: 6, warehouseId: 1, shippedOn: DateTime(2026, 11, 20), fileName: '明細.xlsx', freightJpy: 4500);
    final costs = FakeOutboundCostsRepository();
    final saved = <String>[];
    await pumpApp(tester, const OutboundFileDetailScreen(fileId: 6), overrides: [
      outboundFileRepositoryProvider.overrideWithValue(FakeOutboundFileRepository(
          detailOf: (_) => OutboundFileDetail(file: shipped, lines: _lines, costsEditable: false, costFiles: const [
                OutboundCostFile(id: 9, kind: OutboundCostKind.freight, storagePath: '1/6/9-bill.pdf', fileName: '請求書.pdf'),
              ]))),
      outboundCostsRepositoryProvider.overrideWithValue(costs),
      outboundTabOpenerProvider.overrideWithValue(() => null),
      outboundFileSaverProvider.overrideWithValue((n, b) async => saved.add(n)),
      productRepositoryProvider.overrideWithValue(FakeProductRepository(products: _library)),
      warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(_overview)),
      writeWarehouseIdProvider.overrideWithValue(1),
    ]);
    expect(find.text('輸送費: ¥4,500'), findsOneWidget);
    expect(find.byKey(const ValueKey('of-freight-edit')), findsNothing);
    expect(find.byKey(const ValueKey('oc-locked')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('oc-chip-9')));
    await tester.pumpAndSettle();
    expect(costs.fetched, ['1/6/9-bill.pdf']);
    expect(saved, ['請求書.pdf']);
  });

  testWidgets('出荷単価 required (0212): a row without a price holds 出庫した', (tester) async {
    await tester.binding.setSurfaceSize(const Size(2400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final f = OutboundFileSummary(
      id: 5, warehouseId: 1, shippedOn: DateTime(2026, 11, 20), fileName: '明細.xlsx', status: 'planned',
      destinationId: 31, shipTo: const ShipDestination(id: 31, name: 'テスト貿易'));
    final repo = FakeOutboundFileRepository(detailOf: (_) => OutboundFileDetail(file: f, lines: const [
          OutboundFileLine(id: 1, rowNo: 2, action: 'ship', productId: 1, jan: '4909999000014', quantity: 30, unitPrice: 50),
          OutboundFileLine(id: 2, rowNo: 3, action: 'ship', productId: 2, jan: '4909999000021', quantity: 5),
        ]));
    await pumpApp(tester, const OutboundFileDetailScreen(fileId: 5), overrides: [
      outboundFileRepositoryProvider.overrideWithValue(repo),
      productRepositoryProvider.overrideWithValue(FakeProductRepository(products: _library)),
      warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(_overview)),
      writeWarehouseIdProvider.overrideWithValue(1),
    ]);
    await tester.tap(find.byKey(const ValueKey('of-confirm')));
    await tester.pumpAndSettle();
    expect(find.textContaining('出荷単価がない行があります（3行目）'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('of-confirm-check')));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('of-confirm-ok'))).onPressed, isNull);
  });

  testWidgets('no 出荷先カード yet (0210): said on the list, and chosen while editing', (tester) async {
    final repo = await pumpDetail(tester, _plan);
    expect(find.byKey(const ValueKey('of-card-required')), findsOneWidget);
    expect(find.text('出荷先カードを選ぶまで「出庫した」は押せません。夜の自動出庫もしません。'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('of-edit-lines')));
    await tester.pumpAndSettle();
    expect(find.text('出荷先: 未選択（出庫には必須）'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('of-edit-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sd-pick-31')));
    await tester.pumpAndSettle();
    expect(repo.destinations, [(5, 31)]);
  });

  testWidgets('中身を直す: a row left out, a quantity changed, a product added, a row’s currency', (tester) async {
    final repo = await pumpDetail(tester, _plan);
    expect(find.byKey(const ValueKey('of-edit-bar')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('of-edit-lines')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('of-edit-bar')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('of-line-include-3')));
    await tester.pumpAndSettle();
    expect(repo.lineEdits.last.$1, 5);
    expect(repo.lineEdits.last.$2, [
      {'line_id': 2, 'action': 'skip'},
    ]);

    await tester.tap(find.byKey(const ValueKey('of-line-qty-2')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('of-qty-field')), '20');
    await tester.tap(find.byKey(const ValueKey('of-qty-ok')));
    await tester.pumpAndSettle();
    expect(repo.lineEdits.last.$1, 5);
    expect(repo.lineEdits.last.$2, [
      {'line_id': 1, 'quantity': 20},
    ]);

    await tester.tap(find.byKey(const ValueKey('of-add-line')));
    await tester.pumpAndSettle();
    expect(find.text('追加する商品を選ぶ'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('of-pick-4909999000069')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('of-qty-field')), '3');
    await tester.tap(find.byKey(const ValueKey('of-qty-ok')));
    await tester.pumpAndSettle();
    expect(repo.lineEdits.last.$1, 5);
    expect(repo.lineEdits.last.$2, [
      {'add': true, 'product_id': 7, 'quantity': 3},
    ]);

    await tester.tap(find.byKey(const ValueKey('of-line-cur-2')));
    await tester.pumpAndSettle();
    expect(repo.currencies.last.$2, [
      {'row_no': 2, 'currency': 'CNY', 'source': 'manual'},
    ]);
  });

  testWidgets('通貨・レート: every row in one currency and the rate, from the detail', (tester) async {
    final repo = await pumpDetail(tester, _plan);
    await tester.tap(find.byKey(const ValueKey('of-currency-edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('of-currency-edit-CNY')));
    await tester.enterText(find.byKey(const ValueKey('of-currency-edit-fx')), '21.5');
    await tester.tap(find.byKey(const ValueKey('of-currency-edit-ok')));
    await tester.pumpAndSettle();
    final (id, lines, currency, fx) = repo.currencies.single;
    expect(id, 5);
    expect([for (final l in lines) l['currency']], ['CNY', 'CNY']);
    expect(currency, 'CNY');
    expect(fx, 21.5);
    expect(find.text('通貨とレートを保存しました'), findsOneWidget);
  });

  testWidgets('a shipped list cannot have its rows changed', (tester) async {
    await pumpDetail(
        tester,
        OutboundFileSummary(
            id: 5, warehouseId: 1, shippedOn: DateTime(2026, 11, 2), fileName: '明細.xlsx', status: 'shipped', lineCount: 2));
    expect(find.byKey(const ValueKey('of-edit-lines')), findsNothing);
    expect(find.byKey(const ValueKey('of-currency-edit')), findsOneWidget);
  });

  testWidgets('ファイルで差し替える: the new file read, what changes shown, the rows replaced', (tester) async {
    await tester.binding.setSurfaceSize(const Size(2600, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final book = buildXlsxBook([
      const XlsxSheet(name: '明细', headers: ['品番', 'ジャパンコード', '数量', '单价（税前）'], rows: [
        ['TS-100', '4909999000014', 20, 50],
        ['TS-140', '4909999000069', 3, 30],
      ]),
    ]);
    final repo = FakeOutboundFileRepository(
      detailOf: (_) => OutboundFileDetail(file: _plan, lines: _lines),
      matcher: (r) => switch (r['jan']) {
        '4909999000014' => const OutboundMatch(
            matchedBy: OutboundMatchedBy.jan, productId: 1, jan: '4909999000014', name: 'テストペン', onHand: 100),
        '4909999000069' => const OutboundMatch(
            matchedBy: OutboundMatchedBy.jan, productId: 7, jan: '4909999000069', name: 'テスト消しゴム', onHand: 9),
        _ => OutboundMatch.none,
      },
    );
    bool? result;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await Navigator.of(context)
                .push<bool>(MaterialPageRoute(builder: (_) => const OutboundReplaceScreen(fileId: 5))),
            child: const Text('open'),
          ),
        ),
      ),
      overrides: [
        outboundFileRepositoryProvider.overrideWithValue(repo),
        outboundFilePickerProvider.overrideWithValue(() async => (name: '新しい明細.xlsx', bytes: Uint8List.fromList(book))),
        warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(_overview)),
        writeWarehouseIdProvider.overrideWithValue(null),
        activeWarehouseIdProvider.overrideWith((ref) => null),
        productRepositoryProvider.overrideWithValue(FakeProductRepository(products: _library)),
      ],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('of-replace-banner')), findsOneWidget);
    // The warehouse is the list's: nothing to choose.
    expect(find.byKey(const ValueKey('of-warehouse')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('of-pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('of-post')));
    await tester.pumpAndSettle();
    expect(find.text('追加 1品目・外れる 1品目・数量が変わる 1品目'), findsOneWidget);
    expect(find.text('テスト消しゴム × 3'), findsOneWidget);
    expect(find.text('テストノート × 5'), findsOneWidget);
    expect(find.text('テストペン: 30 → 20'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('of-replace-ok')));
    await tester.pumpAndSettle();
    final r = repo.replaced.single;
    expect(r.id, 5);
    expect(r.fileName, '新しい明細.xlsx');
    expect(r.path, startsWith('1/'));
    expect([for (final l in r.lines) l.quantity], [20, 3]);
    expect(result, isTrue);
  });
}
