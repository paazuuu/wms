import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/export/xlsx.dart';
import 'package:wms_mobile/core/ui/open_window.dart';
import 'package:wms_mobile/features/outbound/data/outbound_repository.dart' show shipDestinationsProvider;
import 'package:wms_mobile/features/outbound/domain/outbound.dart';
import 'package:wms_mobile/features/outbound_file/data/outbound_file_repository.dart';
import 'package:wms_mobile/features/outbound_file/presentation/outbound_file_screen.dart';
import 'package:wms_mobile/features/product/application/product_providers.dart';
import 'package:wms_mobile/features/product/domain/product.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';

import '../../support/fake_outbound_file_repository.dart';
import '../../support/harness.dart';

class _Tab implements HtmlTab {
  final shown = <(int, String)>[];

  @override
  void show(String html) {}

  @override
  void close() {}

  @override
  void showBytes(List<int> bytes, String contentType) => shown.add((bytes.length, contentType));
}

/// A workbook as people send it: a packing list first, the 明细 second.
Uint8List _book() => buildXlsxBook([
      const XlsxSheet(name: 'PL-BL', headers: ['箱番号', '品名', 'メーカー', '品番', '数量'], rows: [
        ['1', 'Pen', 'テスト文具', 'TS-100', '10'],
      ]),
      const XlsxSheet(name: '明细', headers: [
        '供货商', '品牌', '品番', 'ジャパンコード', '数量', '单价（税前）', '单价（税入）', '合计', '注番'
      ], rows: [
        ['テスト卸', 'テスト文具', 'TS-100', '4909999000014', 10, 50, 55, 550, 'BL'], // row 2: ok
        ['テスト卸', 'テスト文具', 'TS-110', '4909999000021', 5, 40, 44, 220, 'BL'], // row 3: 3 in stock
        ['テスト卸', 'テスト文具', 'TS-120', '4909999000045', 5, 40, 44, 220, 'HL'], // row 4: unknown JAN
        ['テスト卸', 'テスト文具', 'TS-130', '', 5, 40, 44, 220, 'HL'], // row 5: several by 品番
        ['テスト卸', 'テスト文具', 'TS-140', '', 4, 40, 44, 176, 'HL'], // row 6: no JAN, no match
      ]),
    ]);

OutboundMatch _match(Map<String, String?> r) => switch ((r['jan'], r['code'])) {
      ('4909999000014', _) => const OutboundMatch(
          matchedBy: OutboundMatchedBy.jan, productId: 1, jan: '4909999000014', name: 'テストペン', onHand: 100, unitWeightG: 10, lastPrice: 48),
      ('4909999000021', _) =>
        const OutboundMatch(matchedBy: OutboundMatchedBy.jan, productId: 2, jan: '4909999000021', name: 'テストノート', onHand: 3),
      (null, 'TS-130') => const OutboundMatch(matchedBy: OutboundMatchedBy.several, candidates: [
          OutboundCandidate(productId: 3, jan: '4909999000038', name: 'A'),
          OutboundCandidate(productId: 4, jan: '4909999000052', name: 'B'),
        ]),
      _ => OutboundMatch.none,
    };

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

void main() {
  Future<FakeOutboundFileRepository> pump(WidgetTester tester,
      {FakeOutboundFileRepository? repo, int tab = 0, _Tab? html, bool proxy = false}) async {
    await tester.binding.setSurfaceSize(const Size(2600, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final r = repo ?? FakeOutboundFileRepository(matcher: _match);
    await pumpApp(tester, OutboundFileScreen(initialTab: tab, proxy: proxy), overrides: [
      outboundFileRepositoryProvider.overrideWithValue(r),
      outboundFilePickerProvider.overrideWithValue(() async => (name: '到货明细.xlsx', bytes: _book())),
      outboundTabOpenerProvider.overrideWithValue(() => html),
      outboundFileSaverProvider.overrideWithValue((n, b) async {}),
      writeWarehouseIdProvider.overrideWithValue(1),
      activeWarehouseIdProvider.overrideWith((ref) => null),
      productRepositoryProvider.overrideWithValue(FakeProductRepository(products: _library)),
      shipDestinationsProvider.overrideWith((ref) async => const [
            ShipDestination(id: 31, name: 'テスト貿易', nameEn: 'Test Trading', port: 'Shanghai', incoterms: 'FOB'),
          ]),
    ]);
    return r;
  }

  String status(WidgetTester tester, int row) => tester.widget<Text>(find.byKey(ValueKey('of-status-$row'))).data!;

  testWidgets('the 明细 sheet is read and each row shows what it is and what will be done', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('of-pick')));
    await tester.pumpAndSettle();

    expect(find.text('到货明细.xlsx'), findsOneWidget);
    // The sheet read is the 明细, not the packing list before it.
    expect(repo.matched.single.length, 5);
    expect(repo.matched.single.first, {'jan': '4909999000014', 'code': 'TS-100', 'maker': 'テスト文具'});
    expect(repo.matched.single[3]['jan'], isNull);

    expect(status(tester, 2), '出庫できる');
    expect(status(tester, 3), '在庫不足');
    expect(status(tester, 4), '未登録のJAN');
    expect(status(tester, 5), '候補が複数');
    expect(status(tester, 6), 'JANなし');
    // Three in stock for five: three go out, two are short.
    expect(tester.widget<Text>(find.byKey(const ValueKey('of-ship-3'))).data, '3');
    expect(tester.widget<Text>(find.byKey(const ValueKey('of-short-3'))).data, '2');
    expect(find.text('5行 · 出庫 2行 · 記録のみ 3行 · 除外 0行'), findsOneWidget);
    expect(find.byKey(const ValueKey('of-summary-short')), findsOneWidget);

    // Only the rows short of stock.
    await tester.tap(find.byKey(const ValueKey('of-filter-short')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('of-row-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('of-row-2')), findsNothing);
  });

  testWidgets('rows are changed by hand, a product chosen, and the list shipped (asked again when seen before)',
      (tester) async {
    final repo = await pump(tester, repo: FakeOutboundFileRepository(matcher: _match, duplicateOnce: true));
    await tester.tap(find.byKey(const ValueKey('of-pick')));
    await tester.pumpAndSettle();

    // Row 3 left out.
    await tester.tap(find.byKey(const ValueKey('of-action-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('of-action-3-skip')));
    await tester.pumpAndSettle();
    expect(find.text('5行 · 出庫 1行 · 記録のみ 3行 · 除外 1行'), findsOneWidget);

    // Row 6 has no JAN: its product chosen by its 品番.
    await tester.tap(find.byKey(const ValueKey('of-pick-6')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('of-pick-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('of-pick-4909999000069')));
    await tester.pumpAndSettle();
    expect(status(tester, 6), '出庫できる');
    expect(find.text('手で選んだ商品'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('of-post')));
    await tester.pumpAndSettle();
    expect(find.text('この内容で出庫しますか？'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('of-post-ok')));
    await tester.pumpAndSettle();
    // The same file was shipped before: asked, then posted again.
    expect(find.text('同じファイルはすでに出庫済みです。もう一度出庫しますか？'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('of-dup-again')));
    await tester.pumpAndSettle();

    expect(repo.uploaded.single.name, '到货明细.xlsx');
    final p = repo.posted.single;
    expect(p.allowDuplicate, isTrue);
    expect(p.path, '1/1-到货明细.xlsx');
    expect(p.sheet, '明细');
    expect([for (final l in p.lines) (l.rowNo, l.action, l.productId)], [
      (2, 'ship', 1),
      (3, 'skip', 2),
      (4, 'record', null),
      (5, 'record', null),
      (6, 'ship', 7),
    ]);
    expect(p.lines.first.unitPrice, 50);
    expect(p.lines.first.unitPriceTax, 55);
    expect(p.lines.first.supplier, 'テスト卸');
    expect(p.lines.last.matchedBy, 'picked');
    // Then the shipment itself.
    expect(find.text('出庫の詳細'), findsOneWidget);
  });

  testWidgets('出庫カレンダー: the month\'s lists, each opening its rows and its file, and undone', (tester) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, 5);
    final file = OutboundFileSummary(
      id: 4,
      warehouseId: 1,
      warehouseName: '本倉庫',
      shippedOn: day,
      fileName: '到货明细.xlsx',
      storagePath: '1/1-a.xlsx',
      lineCount: 2,
      shippedTotal: 13,
      shortTotal: 2,
      amountTotal: 770,
    );
    final html = _Tab();
    final repo = FakeOutboundFileRepository(
      files: [file],
      detailOf: (_) => OutboundFileDetail(file: file, lines: const [
        OutboundFileLine(id: 1, rowNo: 2, action: 'ship', jan: '4909999000014', productName: 'テストペン', quantity: 10, shippedQuantity: 10, unitWeightG: 10),
        OutboundFileLine(id: 2, rowNo: 3, action: 'ship', jan: '4909999000021', productName: 'テストノート', quantity: 5, shippedQuantity: 3, shortQuantity: 2),
      ]),
    );
    await pump(tester, repo: repo, tab: 1, html: html);

    expect(find.byKey(const ValueKey('of-count-5')), findsOneWidget);
    expect(find.textContaining('2行 · 出庫 13個'), findsOneWidget);
    expect(find.text('不足 2個'), findsOneWidget);
    // A day with nothing.
    await tester.tap(find.byKey(const ValueKey('of-day-6')));
    await tester.pumpAndSettle();
    expect(find.text('この日の出庫はありません'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('of-cal-all')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('of-file-4')));
    await tester.pumpAndSettle();
    expect(find.text('出庫の詳細'), findsOneWidget);
    expect(find.byKey(const ValueKey('of-line-3')), findsOneWidget);
    expect(find.text('0.1 kg'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('of-open-file')));
    await tester.pumpAndSettle();
    expect(html.shown.single.$2, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    await tester.tap(find.byKey(const ValueKey('of-download')));
    await tester.pumpAndSettle();
    expect(find.text('保存しました: 到货明细.xlsx'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('of-undo')));
    await tester.pumpAndSettle();
    expect(find.text('出庫した13個を在庫に戻します。ファイルと記録は残ります。'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('of-undo-ok')));
    await tester.pumpAndSettle();
    expect(repo.undone, [4]);
    expect(find.text('取り消しました（5個を在庫に戻しました）'), findsOneWidget);
  });

  testWidgets('代理出荷: rows typed in, kept as a record with 依頼元, nothing shipped', (tester) async {
    final repo = await pump(tester, proxy: true);
    expect(find.text('代理出荷'), findsWidgets);

    Future<void> add(Map<String, String> fields) async {
      await tester.tap(find.byKey(const ValueKey('pr-add-row')));
      await tester.pumpAndSettle();
      for (final e in fields.entries) {
        await tester.enterText(find.byKey(ValueKey('pr-row-${e.key}')), e.value);
      }
      await tester.tap(find.byKey(const ValueKey('pr-row-add')));
      await tester.pumpAndSettle();
    }

    // Something to know it by, and a quantity, are asked for.
    await tester.tap(find.byKey(const ValueKey('pr-add-row')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('pr-row-qty')), '3');
    await tester.tap(find.byKey(const ValueKey('pr-row-add')));
    await tester.pumpAndSettle();
    expect(find.text('商品名・JAN・品番のどれかを入れてください'), findsOneWidget);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    await add({'name': '預かり品の箱', 'qty': '4', 'price': '330'});
    await add({'jan': '4909999000014', 'qty': '2'});
    expect(status(tester, 1), 'ライブラリーにない');
    expect(status(tester, 2), 'ライブラリーにあり');
    // No stock here: nothing taken out, nothing short.
    expect(find.byKey(const ValueKey('of-ship-2')), findsNothing);
    expect(find.text('2行 · 記録 2行 · 除外 0行 · 数量 6'), findsWidgets);
    // A product in the library is still only recorded.
    await tester.tap(find.byKey(const ValueKey('of-action-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('of-action-2-ship')), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    // A row taken away again.
    await add({'code': 'XX-9', 'qty': '1'});
    await tester.tap(find.byKey(const ValueKey('pr-remove-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('of-row-3')), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('pr-principal')), 'テスト依頼元');
    await tester.tap(find.byKey(const ValueKey('of-post')));
    await tester.pumpAndSettle();
    expect(find.text('2行（数量 6）を記録します。在庫は動きません。'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('of-post-ok')));
    await tester.pumpAndSettle();

    expect(repo.uploaded, isEmpty);
    final p = repo.posted.single;
    expect(p.proxy, isTrue);
    expect(p.principal, 'テスト依頼元');
    expect(p.fileName, '手入力');
    expect(p.path, isNull);
    expect([for (final l in p.lines) (l.rowNo, l.action, l.productId)], [(1, 'record', null), (2, 'record', 1)]);
    expect(p.lines.first.productName, '預かり品の箱');
    expect(p.lines.first.unitPriceTax, 330);
    expect(p.lines.first.unitPrice, 300);
  });

  testWidgets('代理出荷 from a file: every row a record, typed rows numbered after the file\'s', (tester) async {
    final repo = await pump(tester, proxy: true);
    await tester.tap(find.byKey(const ValueKey('of-pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pr-add-row')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('pr-row-name')), '追加分');
    await tester.enterText(find.byKey(const ValueKey('pr-row-qty')), '1');
    await tester.tap(find.byKey(const ValueKey('pr-row-add')));
    await tester.pumpAndSettle();
    expect(status(tester, 3), 'ライブラリーにあり');
    expect(status(tester, 7), 'ライブラリーにない');

    await tester.tap(find.byKey(const ValueKey('of-post')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('of-post-ok')));
    await tester.pumpAndSettle();
    final p = repo.posted.single;
    expect(p.proxy, isTrue);
    expect(p.path, '1/1-到货明细.xlsx');
    expect(p.lines.map((l) => l.rowNo), [2, 3, 4, 5, 6, 7]);
    expect(p.lines.every((l) => l.action == 'record'), isTrue);
  });

  testWidgets('出庫カレンダー tells 代理出荷 apart and narrows to one kind', (tester) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, 5);
    final repo = FakeOutboundFileRepository(files: [
      OutboundFileSummary(id: 1, warehouseId: 1, shippedOn: day, fileName: '在庫分.xlsx', lineCount: 1, shippedTotal: 3),
      OutboundFileSummary(
          id: 2, warehouseId: 1, shippedOn: day, fileName: '手入力', kind: 'proxy', principal: 'テスト依頼元', lineCount: 2, quantityTotal: 6),
    ]);
    await pump(tester, repo: repo, tab: 1);
    expect(find.byKey(const ValueKey('of-file-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('of-proxy-2')), findsOneWidget);
    expect(find.text('依頼元: テスト依頼元'), findsOneWidget);
    expect(find.textContaining('2行 · 数量 6'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('of-cal-kind-proxy')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('of-file-1')), findsNothing);
    expect(find.byKey(const ValueKey('of-file-2')), findsOneWidget);

    // Withdrawn: nothing goes back into stock.
    await tester.tap(find.byKey(const ValueKey('of-file-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('of-detail-proxy')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('of-undo')));
    await tester.pumpAndSettle();
    expect(find.text('在庫は動きません。記録とファイルは「取り消し済み」として残ります。'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('of-undo-ok')));
    await tester.pumpAndSettle();
    expect(repo.undone, [2]);
    expect(find.text('記録を取り消しました'), findsOneWidget);
  });

  testWidgets('a 出荷先カード chosen when shipping goes with the list; the detail shows it as it was', (tester) async {
    final now = DateTime.now();
    final repo = FakeOutboundFileRepository(
      matcher: _match,
      detailOf: (id) => OutboundFileDetail(
        file: OutboundFileSummary(
          id: id,
          warehouseId: 1,
          shippedOn: DateTime(now.year, now.month, 3),
          fileName: '到货明细.xlsx',
          destination: 'テスト貿易',
          destinationId: 31,
          shipTo: const ShipDestination(id: 31, name: 'テスト貿易', nameEn: 'Test Trading', port: 'Shanghai', incoterms: 'FOB'),
        ),
        lines: const [],
      ),
    );
    await pump(tester, repo: repo);
    await tester.tap(find.byKey(const ValueKey('of-pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('of-pick-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sd-pick-31')));
    await tester.pumpAndSettle();
    expect(find.text('出荷先カード: テスト貿易'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('of-destination'))).controller!.text, 'テスト貿易');

    await tester.tap(find.byKey(const ValueKey('of-post')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('of-post-ok')));
    await tester.pumpAndSettle();
    expect(repo.destinations, [(1, 31)]);
    // The detail: the card as it was, with the export terms.
    expect(find.byKey(const ValueKey('of-ship-to')), findsOneWidget);
    expect(find.text('Test Trading'), findsOneWidget);
    expect(find.text('FOB'), findsOneWidget);
  });
}
