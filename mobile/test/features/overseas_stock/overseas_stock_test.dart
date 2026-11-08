import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/export/xlsx.dart';
import 'package:wms_mobile/features/master_import/data/master_import_repository.dart';
import 'package:wms_mobile/features/master_import/domain/master_import.dart';
import 'package:wms_mobile/features/outbound/presentation/outbound_downloads.dart';
import 'package:wms_mobile/features/outbound_file/domain/outbound_sheet.dart';
import 'package:wms_mobile/features/overseas_stock/data/overseas_stock_repository.dart';
import 'package:wms_mobile/features/overseas_stock/domain/overseas_stock.dart';
import 'package:wms_mobile/features/overseas_stock/presentation/overseas_import_tab.dart';
import 'package:wms_mobile/features/overseas_stock/presentation/overseas_site_screen.dart';
import 'package:wms_mobile/features/overseas_stock/presentation/overseas_stock_screen.dart';
import 'package:wms_mobile/features/record_notes/data/record_notes_repository.dart';
import 'package:wms_mobile/features/record_notes/presentation/record_notes_panel.dart';
import 'package:wms_mobile/features/stock_import/domain/stock_file.dart' show HeadingMeaning;

import '../../support/fake_overseas_and_notes.dart';
import '../../support/harness.dart';

const _site = OverseasSite(id: 3, name: 'テスト上海支店', country: '中国', city: '上海');

Future<(FakeOverseasStockRepository, FakeMasterImportRepository, FakeRecordNotesRepository)> _pumpSite(
  WidgetTester tester, {
  ({String name, Uint8List bytes})? file,
  FakeOverseasStockRepository? repo,
  FakeMasterImportRepository? ai,
  int tab = 1,
  double width = 1600,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final r = repo ?? FakeOverseasStockRepository(sites: [_site]);
  final m = ai ?? FakeMasterImportRepository();
  final notes = FakeRecordNotesRepository();
  await pumpApp(tester, OverseasSiteScreen(site: _site, initialTab: tab), overrides: [
    overseasStockRepositoryProvider.overrideWithValue(r),
    masterImportRepositoryProvider.overrideWithValue(m),
    recordNotesRepositoryProvider.overrideWithValue(notes),
    overseasFilePickerProvider.overrideWithValue(() async => file),
    noteFilePickerProvider.overrideWithValue(() async => [(name: '契約書.pdf', bytes: Uint8List.fromList([1, 2]))]),
    saveFileProvider.overrideWithValue((n, b) async {}),
  ]);
  await tester.pumpAndSettle();
  return (r, m, notes);
}

void main() {
  group('reading', () {
    test('a sheet’s rows with a quantity; a total and a blank left out', () {
      final sheet = parseOutboundSheet('在庫', [
        ['JAN', '品番', '商品名', '数量'],
        ['4909999000014', 'TP-1', 'テストペン', '12'],
        ['', 'TN-2', 'テストノート', '3'],
        ['合計', '', '', '15'],
        ['', '', '', ''],
      ]);
      final lines = overseasLinesFromSheet(sheet);
      expect([for (final l in lines) '${l.rowNo}:${l.jan}:${l.code}:${l.quantity}'],
          ['2:4909999000014:TP-1:12', '3:null:TN-2:3']);
    });

    test('what the AI read; a heading the AI judged', () {
      final lines = overseasLinesFromAi(const [
        MasterLine(lineNo: 1, janCode: '4909999000014', name: 'テストペン', quantity: '1,200', unit: '個'),
        MasterLine(lineNo: 2, supplierCode: 'S-9', name: 'テスト消しゴム', quantity: '4'),
        MasterLine(lineNo: 3),
      ]);
      expect([for (final l in lines) '${l.jan}:${l.code}:${l.quantity}:${l.unit}'],
          ['4909999000014:null:1200:個', 'null:S-9:4:null']);
      expect(overseasColumnOfField('product_name'), OutboundColumn.name);
      expect(overseasColumnOfField('supplier_code'), OutboundColumn.code);
      expect(overseasColumnOfField('unit_price'), isNull);
      expect(overseasReadsAsSheet('stock.XLSX'), isTrue);
      expect(overseasReadsAsSheet('stock.pdf'), isFalse);
    });
  });

  testWidgets('拠点: added, opened on its file tab; archived', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeOverseasStockRepository(sites: [
      OverseasSite(
          id: 3, name: 'テスト上海支店', country: '中国', noteCount: 2,
          latest: OverseasImport(id: 1, asOf: DateTime(2026, 11, 1), lineCount: 2, units: 15)),
    ]);
    await pumpApp(tester, const OverseasStockScreen(), overrides: [
      overseasStockRepositoryProvider.overrideWithValue(repo),
      recordNotesRepositoryProvider.overrideWithValue(FakeRecordNotesRepository()),
      masterImportRepositoryProvider.overrideWithValue(FakeMasterImportRepository()),
    ]);
    await tester.pumpAndSettle();
    expect(find.textContaining('2026/11/01 時点 · 2品目・15'), findsOneWidget);
    expect(find.textContaining('メモ 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('os-site-archive-3')));
    await tester.pumpAndSettle();
    expect(repo.archived, [(3, true)]);

    await tester.tap(find.byKey(const ValueKey('os-add-site')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('os-site-ok')));
    await tester.pumpAndSettle();
    expect(find.text('拠点名を入れてください'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('os-site-name')), 'テストパートナー');
    await tester.tap(find.text('パートナー会社'));
    await tester.enterText(find.byKey(const ValueKey('os-site-country')), '台湾');
    await tester.tap(find.byKey(const ValueKey('os-site-ok')));
    await tester.pumpAndSettle();
    expect(repo.saved.single['name'], 'テストパートナー');
    expect(repo.saved.single['kind'], 'partner');
    // Opened on reading its first file.
    expect(find.byType(OverseasSiteScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('os-pick')), findsOneWidget);
  });

  testWidgets('全拠点の在庫: each product with what every site holds', (tester) async {
    final repo = FakeOverseasStockRepository()
      ..products = [
        OverseasProduct(jan: '4909999000014', name: 'テストペン', total: 12, ours: 'テストペン（自社）', sites: [
          OverseasHolding(siteId: 3, siteName: 'テスト上海支店', quantity: 7, asOf: DateTime(2026, 11, 5)),
          OverseasHolding(siteId: 4, siteName: 'テストパートナー', kind: 'partner', quantity: 5, asOf: DateTime(2026, 11, 3)),
        ]),
      ];
    await pumpApp(tester, const OverseasStockScreen(), overrides: [overseasStockRepositoryProvider.overrideWithValue(repo)]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('os-tab-overview')));
    await tester.pumpAndSettle();
    expect(find.text('合計 12'), findsOneWidget);
    expect(find.text('テスト上海支店  7（11/05）'), findsOneWidget);
    expect(find.text('自社ライブラリーにあり: テストペン（自社）'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('os-overview-search')), 'ペン');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(repo.queries.last, 'ペン');
  });

  testWidgets('an Excel: columns read, rows ticked and a quantity changed, registered with the file', (tester) async {
    final book = buildXlsxBook([
      const XlsxSheet(name: '在庫', headers: ['JANコード', '品番', '商品名', '数量'], rows: [
        ['4909999000014', 'TP-1', 'テストペン', 12],
        ['4909999000021', 'TN-2', 'テストノート', 3],
        ['', 'TE-3', 'テスト消しゴム', 8],
      ]),
    ]);
    final (repo, ai, _) = await _pumpSite(tester, file: (name: '上海在庫.xlsx', bytes: Uint8List.fromList(book)));
    await tester.tap(find.byKey(const ValueKey('os-pick')));
    await tester.pumpAndSettle();
    expect(ai.askedHeadings, isEmpty);
    expect(find.text('列で読み取り'), findsOneWidget);
    expect(find.byKey(const ValueKey('os-original')), findsOneWidget);
    expect(find.text('3行を読み取り · 登録する 3行・合計 23'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('os-include-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('os-qty-4')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('os-qty-field')), '10');
    await tester.tap(find.byKey(const ValueKey('os-qty-ok')));
    await tester.pumpAndSettle();
    expect(find.text('3行を読み取り · 登録する 2行・合計 22'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('os-register')));
    await tester.pumpAndSettle();
    final r = repo.imported.single;
    expect(r['site'], 3);
    expect(r['read_by'], 'sheet');
    expect(r['path'], '3/1-上海在庫.xlsx');
    expect(r['sheet'], '在庫');
    expect((r['columns'] as Map).keys, containsAll(['jan', 'code', 'name', 'quantity']));
    expect([for (final l in r['lines'] as List<OverseasLine>) '${l.code}:${l.quantity}'], ['TP-1:12', 'TE-3:10']);
    // The stock tab shows what was registered.
    expect(find.byKey(const ValueKey('os-stock-latest')), findsOneWidget);
    expect(find.textContaining('2品目・22'), findsOneWidget);
  });

  testWidgets('headings not known: the AI judges the columns', (tester) async {
    final csv = utf8.encode('Item,Barcode,Stock Left\nテストペン,4909999000014,5\nテストノート,4909999000021,2\n');
    final ai = FakeMasterImportRepository()
      ..meanings = const [
        HeadingMeaning(index: 0, header: 'Item', field: 'product_name'),
        HeadingMeaning(index: 2, header: 'Stock Left', field: 'quantity'),
      ];
    final (repo, _, _) = await _pumpSite(tester, file: (name: 'stock.csv', bytes: Uint8List.fromList(csv)), ai: ai);
    await tester.tap(find.byKey(const ValueKey('os-pick')));
    await tester.pumpAndSettle();
    expect(ai.askedHeadings.single, ['Item', 'Barcode', 'Stock Left']);
    expect(find.text('AIが列を判定しました（2列）'), findsWidgets);
    expect(find.text('2行を読み取り · 登録する 2行・合計 7'), findsOneWidget);
    // The note of what the AI did goes away.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('os-register')));
    await tester.pumpAndSettle();
    expect([for (final l in repo.imported.single['lines'] as List<OverseasLine>) '${l.jan}:${l.name}:${l.quantity}'],
        ['4909999000014:テストペン:5', '4909999000021:テストノート:2']);
  });

  testWidgets('a PDF: read by the AI, checked, registered as read by the AI', (tester) async {
    final ai = FakeMasterImportRepository(
      readResult: const MasterRead(lines: [
        MasterLine(lineNo: 1, janCode: '4909999000014', name: 'テストペン', quantity: '30'),
        MasterLine(lineNo: 2, productCode: 'TN-2', name: 'テストノート', quantity: '6'),
      ]),
    );
    // Narrow: the PDF is not drawn beside the table (its pages are drawn
    // by the browser's PDF reader, not in a test).
    final (repo, _, _) =
        await _pumpSite(tester, file: (name: '在庫表.pdf', bytes: Uint8List.fromList([37, 80, 68, 70])), ai: ai, width: 1000);
    await tester.tap(find.byKey(const ValueKey('os-pick')));
    await tester.pumpAndSettle();
    expect(ai.reads, 1);
    expect(ai.readKeptRows, isTrue);
    expect(find.text('AIで読み取り'), findsOneWidget);
    expect(find.text('2行を読み取り · 登録する 2行・合計 36'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('os-register')));
    await tester.pumpAndSettle();
    expect(repo.imported.single['read_by'], 'ai');
    expect(repo.uploads, ['在庫表.pdf', '在庫表_読み取り結果.xlsx']);
    expect(repo.readPaths[9], '3/1-在庫表_読み取り結果.xlsx');
  });

  testWidgets('履歴: a file taken back; メモ with a file on the site', (tester) async {
    final repo = FakeOverseasStockRepository(sites: [_site])
      ..importList = [
        OverseasImport(id: 7, asOf: DateTime(2026, 11, 5), fileName: 'b.xlsx', lineCount: 1, units: 7),
        OverseasImport(id: 6, asOf: DateTime(2026, 11, 1), fileName: 'a.xlsx', lineCount: 2, units: 13, undoneAt: DateTime(2026, 11, 6)),
      ];
    final (_, _, notes) = await _pumpSite(tester, repo: repo, tab: 2);
    expect(find.byKey(const ValueKey('os-import-undo-6')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('os-import-undo-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('os-undo-ok')));
    await tester.pumpAndSettle();
    expect(repo.undone, [7]);

    await tester.tap(find.byKey(const ValueKey('os-tab-notes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rn-empty')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rn-add')));
    await tester.pumpAndSettle();
    expect(find.text('メモを書くか、ファイルを選んでください'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('rn-body')), '月末に棚卸しの予定');
    await tester.tap(find.byKey(const ValueKey('rn-attach')));
    await tester.pumpAndSettle();
    expect(find.text('添付するファイル 1件'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rn-add')));
    await tester.pumpAndSettle();
    expect(notes.notes[(NoteSubject.overseasSite, 3)]!.single.body, '月末に棚卸しの予定');
    expect(notes.files.single.$2, '契約書.pdf');
    expect(find.text('月末に棚卸しの予定'), findsOneWidget);
    expect(find.text('契約書.pdf'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rn-edit-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('rn-edit-field')), '月末に棚卸し（確定）');
    await tester.tap(find.byKey(const ValueKey('rn-edit-ok')));
    await tester.pumpAndSettle();
    expect(find.text('月末に棚卸し（確定）'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rn-remove-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rn-remove-ok')));
    await tester.pumpAndSettle();
    expect(notes.removed, [1]);
    expect(find.byKey(const ValueKey('rn-empty')), findsOneWidget);
  });
}
