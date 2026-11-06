import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/export/xlsx.dart';
import 'package:wms_mobile/core/ui/open_window.dart';
import 'package:wms_mobile/features/outbound/data/outbound_repository.dart' show shipDestinationsProvider;
import 'package:wms_mobile/features/outbound/domain/outbound.dart';
import 'package:wms_mobile/features/outbound_file/data/outbound_file_repository.dart';
import 'package:wms_mobile/features/outbound_file/domain/outbound_currency.dart';
import 'package:wms_mobile/features/outbound_file/presentation/outbound_file_screen.dart';
import 'package:wms_mobile/features/outbound_file/presentation/outbound_calendar_tab.dart' show OutboundCalendarScreen;
import 'package:wms_mobile/features/outbound_file/presentation/outbound_hub_screen.dart';
import 'package:wms_mobile/features/product/application/product_providers.dart';
import 'package:wms_mobile/features/product/domain/product.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';

import '../../support/fake_outbound_file_repository.dart';
import '../../support/harness.dart';

class _Tab implements HtmlTab {
  final shown = <(int, String)>[];
  final pages = <String>[];

  @override
  void show(String html) => pages.add(html);

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
      {FakeOutboundFileRepository? repo, int tab = 0, _Tab? html, bool proxy = false, List<(String, Uint8List)>? saved, Uint8List? book}) async {
    await tester.binding.setSurfaceSize(const Size(2600, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final r = repo ?? FakeOutboundFileRepository(matcher: _match);
    await pumpApp(tester, OutboundFileScreen(initialTab: tab, proxy: proxy), overrides: [
      outboundFileRepositoryProvider.overrideWithValue(r),
      outboundFilePickerProvider.overrideWithValue(() async => (name: '到货明细.xlsx', bytes: book ?? _book())),
      outboundTabOpenerProvider.overrideWithValue(() => html),
      outboundFileSaverProvider.overrideWithValue((n, b) async => saved?.add((n, b))),
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
    // 商品を選ぶ: for a row with no JAN or several candidates, not for a JAN
    // that is simply not in the library (to be registered). No 対応 column.
    expect(find.byKey(const ValueKey('of-pick-4')), findsNothing);
    expect(find.byKey(const ValueKey('of-pick-5')), findsOneWidget);
    expect(find.byKey(const ValueKey('of-pick-6')), findsOneWidget);
    expect(find.text('対応'), findsNothing);
    // Three in stock for five: three go out, two are short.
    expect(tester.widget<Text>(find.byKey(const ValueKey('of-ship-3'))).data, '3');
    expect(tester.widget<Text>(find.byKey(const ValueKey('of-short-3'))).data, '2');
    expect(find.text('5行 · 出庫 2行 · 照合できない 3行 · 除外 0行'), findsOneWidget);
    expect(find.byKey(const ValueKey('of-summary-short')), findsOneWidget);

    // The sheet read is beside the table, the rows not matched in red.
    expect(find.byKey(const ValueKey('of-original')), findsOneWidget);
    expect(find.text('到货明细.xlsx · 明细'), findsOneWidget);
    expect(find.byKey(const ValueKey('iv-left-out-4')), findsOneWidget);
    expect(find.byKey(const ValueKey('iv-left-out-6')), findsOneWidget);
    expect(find.byKey(const ValueKey('iv-left-out-2')), findsNothing);
    expect(find.byKey(const ValueKey('iv-left-out-3')), findsNothing, reason: 'short of stock, but ours');
    await tester.tap(find.byKey(const ValueKey('of-original-hide')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('of-original')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('of-original-show')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('of-original')), findsOneWidget);

    // Only the rows short of stock.
    await tester.tap(find.byKey(const ValueKey('of-filter-short')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('of-row-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('of-row-2')), findsNothing);
  });

  testWidgets('不足: every row the stock cannot cover is tagged, and 入荷の提案 opens and downloads', (tester) async {
    final tab = _Tab();
    final saved = <(String, Uint8List)>[];
    await pump(tester, html: tab, saved: saved);
    await tester.tap(find.byKey(const ValueKey('of-pick')));
    await tester.pumpAndSettle();

    // Row 2 ships whole; row 3 is 2 short; rows not found are short in full —
    // in the 不足 column.
    expect(find.byKey(const ValueKey('of-need-2')), findsNothing);
    expect(find.descendant(of: find.byKey(const ValueKey('of-need-3')), matching: find.text('2')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('of-need-4')), matching: find.text('5')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('of-need-6')), matching: find.text('4')), findsOneWidget);
    expect(find.text('不足（入荷が必要） 16個（4行）'), findsOneWidget);
    expect(find.text('在庫から出せる数 13個'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('of-filter-need')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('of-row-2')), findsNothing);
    expect(find.byKey(const ValueKey('of-row-4')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('of-proposal-open')));
    await tester.pumpAndSettle();
    final page = tab.pages.single;
    expect(page, contains('入荷の提案（出荷明細の不足分）'));
    expect(page, contains('TS-120'));
    expect(page, isNot(contains('TS-100')));
    expect(page, contains('合計 4品目'));

    await tester.tap(find.byKey(const ValueKey('of-proposal-download')));
    await tester.pumpAndSettle();
    expect(saved.single.$1, '入荷の提案_到货明细.xlsx');
    final sheet = readXlsxSheets(saved.single.$2).single;
    expect(sheet.name, '入荷の提案');
    final head = sheet.rows.indexWhere((r) => r.isNotEmpty && r.first == '品番');
    final rows = sheet.rows.skip(head + 1).toList();
    final heads = sheet.rows[head];
    // A plan to order from: no 状態; 入荷する数 split over three suppliers,
    // the first taking what the other two leave.
    expect(heads, isNot(contains('状態')));
    expect(heads.sublist(7, 12), ['不足（入荷が必要）', '入荷する数', '（表示名１）', '（表示名２）', '（表示名３）']);
    expect([for (final r in rows.take(4)) (r[0], r[7], r[9])],
        [('TS-110', '2', '2'), ('TS-120', '5', '5'), ('TS-130', '5', '5'), ('TS-140', '4', '4')]);
    expect(rows[4].first, '合計');
    expect(rows[4][7], '16');
    final xml = utf8.decode(ZipDecoder().decodeBytes(saved.single.$2).findFile('xl/worksheets/sheet1.xml')!.content as List<int>);
    expect(xml, contains('<f>I${head + 2}-K${head + 2}-L${head + 2}</f>'));
    // The page has the same columns as the Excel.
    expect(page, isNot(contains('<th>状態</th>')));
    expect(page, contains('value="（表示名２）"'));
    expect(page, contains('<th>入荷する数</th>'));

    // The list as read and checked, improved, to download again.
    await tester.tap(find.byKey(const ValueKey('of-filter-need')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('of-table-download')));
    await tester.pumpAndSettle();
    expect(saved.last.$1, '到货明细_照合済み.xlsx');
    final checked = readXlsxSheets(saved.last.$2).single;
    final h = checked.rows.indexWhere((r) => r.isNotEmpty && r.first == '行');
    final cols = checked.rows[h];
    expect(cols, isNot(contains('仕入先')));
    final body = checked.rows.skip(h + 1).take(5).toList();
    expect([for (final r in body) r[cols.indexOf('不足（入荷が必要）')]], ['', '2', '5', '5', '4']);
    expect(body[1][cols.indexOf('出庫数')], '3');
    expect(body.first[cols.indexOf('対象')], '○');

    // Unticked all at once, and ticked again.
    await tester.tap(find.byKey(const ValueKey('of-include-all')));
    await tester.pumpAndSettle();
    expect(find.text('5行 · 出庫 0行 · 照合できない 0行 · 除外 5行'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('of-include-all')));
    await tester.pumpAndSettle();
    expect(find.text('5行 · 出庫 2行 · 照合できない 3行 · 除外 0行'), findsOneWidget);
  });

  testWidgets('a long list is built as it scrolls, its heading kept in sight', (tester) async {
    final book = buildXlsxBook([
      XlsxSheet(name: '明细', headers: const ['品番', 'ジャパンコード', '数量'], rows: [
        for (var i = 0; i < 300; i++) ['TS-${1000 + i}', '', 1],
      ]),
    ]);
    await pump(tester, book: book);
    await tester.tap(find.byKey(const ValueKey('of-pick')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('of-row-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('of-row-301')), findsNothing, reason: 'not built until seen');
    await tester.scrollUntilVisible(find.byKey(const ValueKey('of-row-301')), 400,
        scrollable: find.descendant(of: find.byKey(const ValueKey('of-table-rows')), matching: find.byType(Scrollable)));
    expect(find.byKey(const ValueKey('of-row-301')), findsOneWidget);
    expect(find.byKey(const ValueKey('of-include-all')), findsOneWidget);
  });

  testWidgets('rows are changed by hand, a product chosen, and the list shipped (asked again when seen before)',
      (tester) async {
    final repo = await pump(tester, repo: FakeOutboundFileRepository(matcher: _match, duplicateOnce: true));
    await tester.tap(find.byKey(const ValueKey('of-pick')));
    await tester.pumpAndSettle();

    // Every row ticked to begin with; row 3 unticked: left out.
    expect(tester.widget<Checkbox>(find.byKey(const ValueKey('of-include-3'))).value, isTrue);
    await tester.tap(find.byKey(const ValueKey('of-include-3')));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byKey(const ValueKey('of-include-3'))).value, isFalse);
    expect(find.text('5行 · 出庫 1行 · 照合できない 3行 · 除外 1行'), findsOneWidget);

    // Row 6 has no JAN: its product chosen by its 品番.
    await tester.tap(find.byKey(const ValueKey('of-pick-6')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('of-pick-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('of-pick-4909999000069')));
    await tester.pumpAndSettle();
    expect(status(tester, 6), '出庫できる');
    expect(find.text('手で選んだ商品'), findsOneWidget);

    // Out of stock now, not as a plan.
    await tester.tap(find.text('今すぐ出庫'));
    await tester.pumpAndSettle();
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
    expect(p.plan, isFalse);
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

  testWidgets('在庫外出荷: rows typed in, kept as a record with 依頼元, nothing shipped', (tester) async {
    final saved = <(String, Uint8List)>[];
    final repo = await pump(tester, proxy: true, saved: saved);
    expect(find.text('在庫外出荷'), findsWidgets);

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
    // No 対応 column: whether a row goes is its tick alone.
    expect(find.byKey(const ValueKey('of-action-2')), findsNothing);

    // The rows typed in, as an Excel file.
    await tester.tap(find.byKey(const ValueKey('of-table-download')));
    await tester.pumpAndSettle();
    final table = readXlsxSheets(saved.single.$2).single;
    expect(saved.single.$1, startsWith('在庫外出荷_'));
    expect(table.name, '在庫外出荷');
    final head = table.rows.indexWhere((r) => r.isNotEmpty && r.first == '行');
    expect(table.rows[head], isNot(contains('在庫')), reason: 'no stock for a 在庫外出荷');
    expect(table.rows[head], isNot(contains('対応')));
    expect(table.rows[head + 1].sublist(0, 3), ['1', '○', 'ライブラリーにない']);
    expect(table.rows[head + 1][4], '預かり品の箱');
    await tester.pump(const Duration(seconds: 5)); // the 保存 note goes
    await tester.pumpAndSettle();

    // The day is 未定 to begin with.
    expect(find.textContaining('出庫日: 未定'), findsOneWidget);

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
    expect(repo.markedUndecided, hasLength(1), reason: 'kept with its day 未定');
  });

  testWidgets('在庫外出荷 from a file: every row a record, typed rows numbered after the file\'s', (tester) async {
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

  testWidgets('出庫カレンダー tells 在庫外出荷 apart and narrows to one kind', (tester) async {
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

  testWidgets('出荷手配: the sales side of shipping as tabs of one screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester, const OutboundHubScreen(), overrides: [
      outboundFileRepositoryProvider.overrideWithValue(FakeOutboundFileRepository()),
      writeWarehouseIdProvider.overrideWithValue(1),
      activeWarehouseIdProvider.overrideWith((ref) => null),
      shipDestinationsProvider.overrideWith((ref) async => const [ShipDestination(id: 31, name: 'テスト貿易', port: 'Shanghai')]),
    ]);
    for (final t in ['出荷明細の取込', '在庫外出荷', '出荷先カード', '出荷指示・梱包', '出荷の提案']) {
      expect(find.descendant(of: find.byType(TabBar), matching: find.text(t)), findsOneWidget);
    }
    // Each tab says what it is for when the pointer rests on it.
    expect(find.byTooltip(RegExp(r'^営業から届いた出荷明細')), findsOneWidget);
    expect(find.byTooltip(RegExp(r'^在庫を持たない直送')), findsOneWidget);
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    addTearDown(g.removePointer);
    await g.moveTo(tester.getCenter(find.byKey(const ValueKey('ob-hub-proxy'))));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('在庫を持たない直送・出荷代行の記録'), findsOneWidget);
    await g.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('of-pick')), findsOneWidget);
    expect(find.byKey(const ValueKey('pr-add-row')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('ob-hub-proxy')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pr-add-row')), findsOneWidget);
    expect(find.textContaining('直送（仕入先から相手先へ直接送る）'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ob-hub-cards')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sd-row-31')), findsOneWidget);
  });

  testWidgets('a link to 出荷先カード opens 出荷手配 at that tab', (tester) async {
    await pumpApp(tester, const OutboundHubScreen(tab: OutboundHubTab.cards), overrides: [
      outboundFileRepositoryProvider.overrideWithValue(FakeOutboundFileRepository()),
      shipDestinationsProvider.overrideWith((ref) async => const [ShipDestination(id: 31, name: 'テスト貿易')]),
    ]);
    expect(find.byKey(const ValueKey('sd-row-31')), findsOneWidget);
  });

  testWidgets('出庫カレンダー stands on its own (現場作業)', (tester) async {
    final now = DateTime.now();
    await pumpApp(tester, const OutboundCalendarScreen(), overrides: [
      outboundFileRepositoryProvider.overrideWithValue(FakeOutboundFileRepository(files: [
        OutboundFileSummary(id: 1, warehouseId: 1, shippedOn: DateTime(now.year, now.month, 5), fileName: '在庫分.xlsx'),
      ])),
      activeWarehouseIdProvider.overrideWith((ref) => null),
    ]);
    expect(find.text('出庫カレンダー'), findsOneWidget);
    expect(find.byKey(const ValueKey('of-file-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('of-cal-kind-proxy')), findsOneWidget);
  });

  testWidgets('出庫予定: registered with its day 未定 by default, no stock out yet', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('of-pick')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('of-plan-hint')), findsOneWidget);
    expect(find.text('出庫予定日: 未定'), findsOneWidget, reason: '未定 until a day is known');
    await tester.tap(find.byKey(const ValueKey('of-post')));
    await tester.pumpAndSettle();
    expect(find.textContaining('の出庫予定として登録します。在庫はまだ動きません。'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('of-post-ok')));
    await tester.pumpAndSettle();
    expect(repo.posted.single.plan, isTrue);
    expect(find.textContaining('出庫予定を登録しました（未定）'), findsOneWidget);
    // No day given: the list is 未定 until one is set (0197).
    expect(repo.markedUndecided, hasLength(1));
  });

  test('a price currency: as the headings say, or 元 when far under the purchase price', () {
    expect(currencyInHeadings(['单价（元）', '数量']), PriceCurrency.cny);
    expect(currencyInHeadings(['単価(円)']), PriceCurrency.jpy);
    expect(currencyInHeadings(['单价（税前）', '数量']), isNull);
    expect(priceLooksLikeCny(5.5, 100), isTrue);
    expect(priceLooksLikeCny(55, 100), isFalse);
    expect(priceLooksLikeCny(5.5, null), isFalse);
  });

  testWidgets('通貨: rows the AI judges to be in 元 are shown so, can be changed, and are kept', (tester) async {
    final ai = FakePriceCurrencyRepository({3: (PriceCurrency.cny, true), 4: (PriceCurrency.cny, false)});
    await tester.binding.setSurfaceSize(const Size(2600, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeOutboundFileRepository(matcher: _match);
    await pumpApp(tester, const OutboundFileScreen(), overrides: [
      outboundFileRepositoryProvider.overrideWithValue(repo),
      outboundFilePickerProvider.overrideWithValue(() async => (name: '到货明细.xlsx', bytes: _book())),
      outboundTabOpenerProvider.overrideWithValue(() => null),
      outboundFileSaverProvider.overrideWithValue((n, b) async {}),
      writeWarehouseIdProvider.overrideWithValue(1),
      activeWarehouseIdProvider.overrideWith((ref) => null),
      productRepositoryProvider.overrideWithValue(FakeProductRepository(products: _library)),
      priceCurrencyRepositoryProvider.overrideWithValue(ai),
    ]);
    await tester.tap(find.byKey(const ValueKey('of-pick')));
    await tester.pumpAndSettle();
    // Asked with what each was bought for (row 2: 48 円).
    expect(ai.asked.single.first.purchaseJpy, 48);
    expect(find.byKey(const ValueKey('of-currency')), findsOneWidget);
    expect(find.text('人民元と判断した行: 2 / 5'), findsOneWidget);
    expect(find.text('確信の低い行: 4'), findsOneWidget, reason: 'the AI unsure of row 4, and rows it left to our rule');
    expect(find.text('40 元'), findsNWidgets(2));
    // Row 4 put back to 円 by a tap on its price; the rate given.
    await tester.tap(find.byKey(ValueKey('of-cur-4-${40.0.hashCode}')));
    await tester.pumpAndSettle();
    expect(find.text('人民元と判断した行: 1 / 5'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('of-fx')), '21.5');
    await tester.tap(find.byKey(const ValueKey('of-post')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('of-post-ok')));
    await tester.pumpAndSettle();
    final (_, lines, main, fx) = repo.currencies.single;
    expect(main, 'JPY');
    expect(fx, 21.5);
    expect(lines.firstWhere((l) => l['row_no'] == 3), {'row_no': 3, 'currency': 'CNY', 'source': 'ai'});
    expect(lines.firstWhere((l) => l['row_no'] == 4), {'row_no': 4, 'currency': 'JPY', 'source': 'manual'});
    expect(lines.firstWhere((l) => l['row_no'] == 2)['source'], 'guess');
  });

  testWidgets('出庫日 未定: listed beside the calendar, a day set from there', (tester) async {
    final repo = FakeOutboundFileRepository()
      ..undecidedFiles = [
        OutboundFileSummary(
            id: 7, warehouseId: 1, shippedOn: DateTime(2026, 11, 5), fileName: '未定の明細.xlsx', status: 'planned',
            dateUndecided: true, lineCount: 3, quantityTotal: 30),
        OutboundFileSummary(
            id: 8, warehouseId: 1, shippedOn: DateTime(2026, 11, 5), fileName: '直送分.xlsx', kind: 'proxy',
            dateUndecided: true, lineCount: 1, quantityTotal: 4),
      ];
    await pumpApp(tester, const OutboundCalendarScreen(), overrides: [
      outboundFileRepositoryProvider.overrideWithValue(repo),
      activeWarehouseIdProvider.overrideWith((ref) => null),
    ]);
    // A 在庫外出荷 with no day is listed too (0198), marked as such.
    expect(find.text('出庫日 未定 2件'), findsOneWidget);
    expect(find.byKey(const ValueKey('of-undecided-7')), findsOneWidget);
    expect(find.textContaining('在庫外出荷 · 直送分.xlsx'), findsOneWidget);
    expect(repo.undecidedFiles[1].undecided, isTrue);
    await tester.tap(find.byKey(const ValueKey('of-undecided-set-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(repo.rescheduled.single.$1, 7);
  });

  testWidgets('a planned list on the calendar: confirmed by the warehouse, moved, or cancelled', (tester) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, 20);
    final plan = OutboundFileSummary(
        id: 5, warehouseId: 1, shippedOn: day, plannedOn: day, fileName: '到货明细.xlsx', status: 'planned', lineCount: 2, quantityTotal: 15);
    final repo = FakeOutboundFileRepository(
      files: [plan],
      detailOf: (_) => OutboundFileDetail(file: plan, lines: const [
        OutboundFileLine(id: 1, rowNo: 2, action: 'ship', productId: 1, jan: '4909999000014', productName: 'テストペン', quantity: 10),
        OutboundFileLine(id: 2, rowNo: 3, action: 'ship', productId: 2, jan: '4909999000021', productName: 'テストノート', quantity: 5),
      ]),
    );
    await pumpApp(tester, const OutboundCalendarScreen(), overrides: [
      outboundFileRepositoryProvider.overrideWithValue(repo),
      activeWarehouseIdProvider.overrideWith((ref) => null),
    ]);
    expect(find.byKey(const ValueKey('of-planned-5')), findsOneWidget);
    expect(find.textContaining('2行 · 数量 15'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('of-cal-kind-planned')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('of-file-5')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('of-file-5')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('of-detail-planned')), findsOneWidget);
    // No 出庫数 / 不足 yet.
    expect(find.byKey(const ValueKey('of-line-ship-2')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('of-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('2行（数量 15）を在庫から減らします。在庫が足りない分は不足として記録します。'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('of-confirm-ok')));
    await tester.pumpAndSettle();
    expect(repo.confirmed.single.$1, 5);
    expect(find.text('出庫を確定しました（7個）'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('of-reschedule')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(repo.rescheduled.single.$1, 5);

    await tester.tap(find.byKey(const ValueKey('of-undo')));
    await tester.pumpAndSettle();
    expect(find.text('在庫はまだ動いていません。予定は「取り消し済み」として残ります。'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('of-undo-ok')));
    await tester.pumpAndSettle();
    expect(repo.undone, [5]);
  });
}
