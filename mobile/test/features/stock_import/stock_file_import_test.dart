import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/core/export/xlsx.dart';
import 'package:wms_mobile/features/auth/application/auth_controller.dart';
import 'package:wms_mobile/features/auth/domain/auth_user.dart';
import 'package:wms_mobile/features/master_import/data/master_import_repository.dart';
import 'package:wms_mobile/features/master_import/domain/master_import.dart';
import 'package:wms_mobile/features/price_book/application/price_book_providers.dart';
import 'package:wms_mobile/features/price_book/domain/price_book.dart';
import 'package:wms_mobile/features/stock_import/data/stock_import_repository.dart';
import 'package:wms_mobile/features/stock_import/domain/stock_file.dart';
import 'package:wms_mobile/features/stock_import/domain/stock_ledger.dart';
import 'package:wms_mobile/features/stock_import/presentation/reading_check_screen.dart';
import 'package:wms_mobile/features/stock_import/presentation/stock_file_import_screen.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';
import 'package:wms_mobile/features/warehouse_context/domain/warehouse.dart';

import '../../support/harness.dart';

// Synthetic JANs with a correct check digit.
const _jan1 = '4909999000014';
const _jan2 = '4909999000021';
const _jan3 = '4909999000038';

class _FakeStock implements StockImportRepository {
  _FakeStock(this.products, {this.stock = const {}, this.book = const {}, this.priceBook});

  final Map<String, String> products;
  final Map<String, int> stock;
  final Map<String, (int, String)> book;

  /// When given, what it registered counts as in 商品ライブラリー.
  final FakePriceBookRepository? priceBook;
  final notes = <(int, List<ReadRow>, bool, int?)>[];

  Map<String, String> get _library {
    final m = {...products};
    final pb = priceBook;
    if (pb == null) return m;
    final registered = {for (final ids in pb.toMaster) ...ids};
    for (final i in pb.items) {
      if (registered.contains(i.id) && i.janCode != null) m[i.janCode!] = i.name;
    }
    for (final imp in pb.imports) {
      for (var k = 0; k < imp.lines.length; k++) {
        if (registered.contains(1000 + k)) m['${imp.lines[k]['jan_code']}'] = '${imp.lines[k]['product_name']}';
      }
    }
    return m;
  }

  @override
  Future<ApiResult<bool>> note(int importId, List<ReadRow> read, {required bool byAi, int? documentId}) async {
    notes.add((importId, read, byAi, documentId));
    return const ApiSuccess(true);
  }

  /// What duplicates() answers; fingerprints and undos as asked.
  List<DuplicateImport> dupes = const [];
  final fingerprints = <(int, String?, String?)>[];
  final undone = <int>[];

  @override
  Future<ApiResult<List<DuplicateImport>>> duplicates({String? file, String? lines}) async => ApiSuccess(dupes);

  @override
  Future<ApiResult<bool>> fingerprint(int importId, {String? file, String? lines}) async {
    fingerprints.add((importId, file, lines));
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<int>> undo(int importId) async {
    undone.add(importId);
    return const ApiSuccess(1);
  }
  final applied = <(int, StockFileMode, List<StockFileLine>)>[];
  final kept = <(int, String)>[];

  @override
  Future<ApiResult<Map<String, String>>> known(List<String> jans) async =>
      ApiSuccess({for (final j in jans) if (_library.containsKey(j)) j: _library[j]!});

  @override
  Future<ApiResult<Map<String, int>>> onHand(int warehouseId, List<String> jans) async =>
      ApiSuccess({for (final j in jans) if (stock.containsKey(j)) j: stock[j]!});

  @override
  Future<ApiResult<Map<String, (int, String)>>> inPriceBook(List<String> jans) async =>
      ApiSuccess({for (final j in jans) if (book.containsKey(j)) j: book[j]!});

  @override
  Future<ApiResult<StockFileResult>> apply(int warehouseId, StockFileMode mode, List<StockFileLine> lines,
      {String? fileName, String? fileType}) async {
    applied.add((warehouseId, mode, lines));
    return ApiSuccess(StockFileResult(importId: 12, lines: lines.length, change: lines.fold(0, (s, l) => s + l.quantity)));
  }

  @override
  Future<ApiResult<bool>> keepFile(int importId, String fileName, Uint8List bytes, String contentType) async {
    kept.add((importId, fileName));
    return const ApiSuccess(true);
  }

  /// Added stock is staged for inspection (0148): recorded with the others
  /// in [applied], and here.
  final staged = <int>[];

  @override
  Future<ApiResult<StockFileResult>> stage(int warehouseId, List<StockFileLine> lines, {String? fileName, String? fileType}) async {
    applied.add((warehouseId, StockFileMode.add, lines));
    staged.add(12);
    return ApiSuccess(StockFileResult(
        importId: 12, lines: lines.length, change: 0, awaiting: lines.fold<int>(0, (s, l) => s + l.quantity)));
  }

  /// What updateNotes() was given: the date, paid and the memo.
  final notesSet = <(int, DocumentDate?, bool?, String?)>[];

  @override
  Future<ApiResult<bool>> updateNotes(int importId, {DocumentDate? date, bool? paid, String? note}) async {
    notesSet.add((importId, date, paid, note));
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<List<AwaitingImport>>> awaiting({int? warehouseId}) async => const ApiSuccess([]);

  @override
  Future<ApiResult<InspectionResult>> inspect(int importId, List<InspectedLine> lines) async =>
      const ApiSuccess(InspectionResult());

  @override
  Future<ApiResult<PendingInspection>> pendingInspection({int? warehouseId}) async =>
      const ApiSuccess(PendingInspection());

  @override
  Future<ApiResult<List<CalendarImport>>> calendar(DateTime from, DateTime to) async => const ApiSuccess([]);
}

/// 読み取った内容を確認しました — nothing goes in without it.
Future<void> _tick(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('sf-checked')));
  await tester.tap(find.byKey(const ValueKey('sf-checked')));
  await tester.pumpAndSettle();
}

Override _signedIn(List<String> permissions) => authControllerProvider.overrideWith((ref) =>
    fakeAuthControllerFor(AuthUser(id: 'u1', email: 'a@b.test', name: '倉庫', permissions: permissions)));


Future<_FakeStock> _pumpCsv(WidgetTester tester, String csv,
    {Map<String, String> products = const {}, Map<String, int> stock = const {}, List<String> perms = const ['inventory.adjust'],
    List<(String, Uint8List)>? saved, MasterImportRepository? reader, String name = 'a.csv'}) async {
  await tester.binding.setSurfaceSize(const Size(1000, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final repo = _FakeStock(products, stock: stock);
  await pumpApp(tester, const StockFileImportScreen(), overrides: [
    _signedIn(perms),
    stockImportRepositoryProvider.overrideWithValue(repo),
    if (reader != null) masterImportRepositoryProvider.overrideWithValue(reader),
    stockFilePickerProvider.overrideWithValue(() async => (name: name, bytes: Uint8List.fromList(utf8.encode(csv)))),
    if (saved != null) stockTemplateSaverProvider.overrideWithValue((n, b) async => saved.add((n, b))),
    warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(const WarehouseOverview(
      warehouses: [Warehouse(id: 1, code: 'WH-01', name: '本社倉庫')],
      totals: WarehouseTotals(),
    ))),
  ]);
  await tester.tap(find.byKey(const ValueKey('sf-pick')));
  await tester.pumpAndSettle();
  return repo;
}

/// A line going in, as the table shows it: the stock now, the change, after.
void _expectRow(WidgetTester tester, String jan, String before, String change, String after) {
  String text(String key) => tester.widget<Text>(find.byKey(ValueKey('$key-$jan'))).data!;
  expect([text('sf-before'), text('sf-change'), text('sf-calc')], [before, change, after]);
}

void main() {
  group('reading a stock sheet', () {

  test('headings the app does not know are filled from what the server judged (0163)', () {
    final rows = [
      ['JANコード', '商品名称', 'メーカー品番', '数量', '規格'],
      [_jan1, 'テストペン 黒', 'TP-1', '3', '0.5mm'],
    ];
    final first = parseStockRows(rows);
    expect(first.unplaced, [1, 2, 4]);
    expect(first.lines.single.name, isNull);
    expect(first.samplesFrom(rows), [rows[1]]);
    final again = parseStockRows(rows, meanings: const [
      HeadingMeaning(index: 1, header: '商品名称', field: 'product_name'),
      HeadingMeaning(index: 2, header: 'メーカー品番', field: 'product_code', source: 'partner'),
      HeadingMeaning(index: 4, header: '規格', field: 'spec'),
      // Never over a column the app already placed.
      HeadingMeaning(index: 3, header: '数量', field: 'product_name'),
    ]);
    final l = again.lines.single;
    expect((l.name, l.code, l.quantity), ('テストペン 黒', 'TP-1', 3));
    expect(again.usedMeanings.map((m) => m.header), ['商品名称', 'メーカー品番', '数量']);
    expect(again.unusedMeanings.map((m) => m.header), ['規格']);
    expect(again.unplaced, [4]);
  });

  testWidgets('unknown headings are asked about once, and what they were taken for is shown', (tester) async {
    final reader = FakeMasterImportRepository()
      ..meanings = const [
        HeadingMeaning(index: 1, header: '商品名称', field: 'product_name'),
        HeadingMeaning(index: 3, header: '規格', field: 'spec'),
      ];
    await _pumpCsv(tester, 'JANコード,商品名称,数量,規格\n$_jan1,テストペン 黒,3,0.5mm\n',
        products: {_jan1: 'テストペン'}, reader: reader);
    expect(reader.askedHeadings, [
      ['JANコード', '商品名称', '数量', '規格'],
    ]);
    expect(reader.reads, 0); // the sheet itself is still read here, not by the AI
    expect(find.byKey(const ValueKey('sf-headings')), findsOneWidget);
    expect(find.text('「商品名称」→ 商品名（AIが判定）'), findsOneWidget);
    expect(find.text('「規格」→ 規格（AIが判定）　在庫の読み込みでは使いません'), findsOneWidget);
  });

  testWidgets('a sheet whose headings are all known asks nothing', (tester) async {
    final reader = FakeMasterImportRepository();
    await _pumpCsv(tester, 'JANコード,商品名,数量\n$_jan1,テストペン 黒,3\n', products: {_jan1: 'テストペン'}, reader: reader);
    expect(reader.askedHeadings, isEmpty);
    expect(find.byKey(const ValueKey('sf-headings')), findsNothing);
  });

  testWidgets('without an answer about the headings, the sheet stands as read', (tester) async {
    final reader = FakeMasterImportRepository()..meaningsFail = true;
    await _pumpCsv(tester, 'JANコード,商品名称,数量\n$_jan1,テストペン 黒,3\n', products: {_jan1: 'テストペン'}, reader: reader);
    expect(reader.askedHeadings, hasLength(1));
    expect(find.byKey(const ValueKey('sf-headings')), findsNothing);
    expect(find.textContaining('1商品・合計3個'), findsOneWidget);
  });
    test('finds the JAN and quantity columns under a title, and adds up the same JAN', () {
      final s = parseStockRows([
        ['在庫表 10月'],
        ['No', 'JANコード', '商品名', '在庫数'],
        ['1', _jan1, 'テストペン', '10'],
        ['2', '４９０９９９９００００２１', 'テストノート', '1,200'],
        ['3', _jan1, 'テストペン', '5'],
        ['', '', '', ''],
        ['4', 'なし', 'メモ', '3'],
        ['5', _jan3, 'テスト消しゴム', '-2'],
      ]);
      expect(s.header, isTrue);
      expect(s.lines, [
        const StockFileLine(lineNo: 3, janCode: _jan1, quantity: 15, name: 'テストペン', merged: 2),
        const StockFileLine(lineNo: 4, janCode: _jan2, quantity: 1200, name: 'テストノート'),
      ]);
      expect(s.problems, [
        const StockFileProblem(7, 'no_jan', value: 'なし'),
        const StockFileProblem(8, 'bad_quantity', value: '-2'),
      ]);
    });

    test('a sheet without the two headings is said to be one', () {
      expect(parseStockRows([
        ['品番', '数'],
        ['A-1', '3'],
      ]).header, isFalse);
    });

    test('reads Excel, and CSV with quotes and a BOM', () {
      final xlsx = buildXlsx(sheetName: 's', headers: const ['JAN', '数量'], rows: const [
        [_jan1, 4],
      ]);
      expect(parseStockRows(readStockFile('a.xlsx', xlsx)).lines.single.quantity, 4);
      final csv = Uint8List.fromList(utf8.encode('﻿JANコード,商品名,数量\r\n$_jan2,"ノート, A罫",7\r\n'));
      final s = parseStockRows(readStockFile('a.csv', csv));
      expect(s.lines.single, const StockFileLine(lineNo: 2, janCode: _jan2, quantity: 7, name: 'ノート, A罫'));
      expect(() => readStockFile('a.pdf', csv), throwsFormatException);
    });
  });

  testWidgets('added stock waits for inspection, filed under the date the sheet prints, with payment and a memo', (tester) async {
    final repo = await _pumpCsv(
      tester,
      '入金依頼書\n発行日,2026/08/19\nJANコード,数量\n$_jan1,500\n$_jan2,100\n',
      products: {_jan1: 'テストペン 青', _jan2: 'テストノート'},
    );
    // Said before anything goes in: added stock waits for the inspector.
    expect(find.byKey(const ValueKey('sf-inspection-hint')), findsOneWidget);
    expect(find.text('書類の日付: 2026/08/19（ファイルに書かれた日付）'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('sf-paid')));
    await tester.tap(find.byKey(const ValueKey('sf-paid')));
    await tester.enterText(find.byKey(const ValueKey('sf-note')), '8/21 振込予定');
    await tester.pumpAndSettle();
    await _tick(tester);
    expect(find.text('検品待ちとして登録（2商品）'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sf-apply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sf-confirm-stage')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sf-confirm')));
    await tester.pumpAndSettle();

    expect(repo.staged, [12]);
    final (id, date, paid, note) = repo.notesSet.single;
    expect(id, 12);
    expect(date, DocumentDate(DateTime(2026, 8, 19), DocumentDateSource.content));
    expect(paid, isTrue);
    expect(note, '8/21 振込予定');
    expect(find.text('取込 #12: 2商品を検品待ちにしました（合計 600個）。検品が済むと在庫に入ります。'), findsOneWidget);
    expect(find.byKey(const ValueKey('sf-go-inspect')), findsOneWidget);
  });

  testWidgets('without a date in the file, the import is filed under the upload day; setting the stock is not staged',
      (tester) async {
    final repo = await _pumpCsv(tester, 'JANコード,数量\n$_jan1,5\n', products: {_jan1: 'テストペン 青'});
    final today = DateTime.now();
    expect(find.textContaining('（アップロード日）'), findsOneWidget);
    await tester.tap(find.text('在庫をこの数にする'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sf-inspection-hint')), findsOneWidget);
    await _tick(tester);
    await tester.tap(find.byKey(const ValueKey('sf-apply')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sf-confirm')));
    await tester.pumpAndSettle();
    expect(repo.staged, isEmpty);
    expect(repo.applied.single.$2, StockFileMode.set);
    final (_, date, paid, note) = repo.notesSet.single;
    expect(date, DocumentDate(DateTime(today.year, today.month, today.day), DocumentDateSource.uploaded));
    expect(paid, isNull);
    expect(note, isNull);
  });

  testWidgets('a file is read, a JAN not in the library is left out, and the rest go into the warehouse', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _FakeStock({_jan1: 'テストペン 青', _jan2: 'テストノート'}, stock: {_jan1: 4});
    final csv = Uint8List.fromList(utf8.encode('JANコード,数量\n$_jan1,10\n$_jan2,3\n$_jan3,8\nx,1\n'));
    await pumpApp(tester, const StockFileImportScreen(), overrides: [
      _signedIn(['inventory.adjust']),
      stockImportRepositoryProvider.overrideWithValue(repo),
      stockFilePickerProvider.overrideWithValue(() async => (name: '在庫.csv', bytes: csv)),
      warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(const WarehouseOverview(
        warehouses: [Warehouse(id: 1, code: 'WH-01', name: '本社倉庫'), Warehouse(id: 2, code: 'WH-02', name: '第二倉庫')],
        totals: WarehouseTotals(),
      ))),
    ]);

    await tester.tap(find.byKey(const ValueKey('sf-mode')).last);
    await tester.tap(find.text('在庫をこの数にする'));
    await tester.tap(find.byKey(const ValueKey('sf-pick')));
    await tester.pumpAndSettle();

    expect(find.text('在庫.csv: 3商品・合計21個'), findsOneWidget);
    // Every row that will not go in is listed, with why.
    expect(find.byKey(const ValueKey('sf-problem-5')), findsOneWidget);
    expect(find.byKey(const ValueKey('sf-out-$_jan3')), findsOneWidget);
    expect(find.byKey(const ValueKey('sf-unknown')), findsOneWidget);
    expect(find.text('テストペン 青'), findsOneWidget);
    expect(find.byKey(const ValueKey('sf-line-$_jan3')), findsNothing);
    // Set: said plainly, with what each becomes.
    expect(find.byKey(const ValueKey('sf-set-warning')), findsOneWidget);
    _expectRow(tester, _jan1, '4', '+6', '10');

    await _tick(tester);
    await tester.tap(find.byKey(const ValueKey('sf-apply')));
    await tester.pumpAndSettle();
    expect(find.text('本社倉庫の在庫に反映しますか？'), findsOneWidget);
    expect(find.text('在庫の合計: 4 → 13'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sf-confirm')));
    await tester.pumpAndSettle();

    final (wh, mode, lines) = repo.applied.single;
    expect(wh, 1);
    expect(mode, StockFileMode.set);
    expect(lines.map((l) => l.janCode), [_jan1, _jan2]);
    expect(repo.kept.single, (12, '在庫.csv'));
    expect(find.byKey(const ValueKey('sf-done')), findsOneWidget);
  });

  testWidgets('a file adds to the stock there is; its own name for a product does not matter, the JAN does', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _FakeStock({_jan1: 'テストペン 青'}, stock: {_jan1: 40});
    // The supplier calls it something else, twice.
    final csv = Uint8List.fromList(utf8.encode('JANコード,商品名,数量\n$_jan1,ﾃｽﾄﾍﾟﾝ ｱｵ,10\n$_jan1,テストペン(青),5\n'));
    await pumpApp(tester, const StockFileImportScreen(), overrides: [
      _signedIn(['inventory.adjust']),
      stockImportRepositoryProvider.overrideWithValue(repo),
      stockFilePickerProvider.overrideWithValue(() async => (name: '入荷.csv', bytes: csv)),
      warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(const WarehouseOverview(
        warehouses: [Warehouse(id: 1, code: 'WH-01', name: '本社倉庫')],
        totals: WarehouseTotals(),
      ))),
    ]);
    await tester.tap(find.byKey(const ValueKey('sf-pick')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sf-set-warning')), findsNothing);
    expect(find.text('テストペン 青'), findsOneWidget);
    expect(find.textContaining('ファイルでの表記: ﾃｽﾄﾍﾟﾝ ｱｵ'), findsOneWidget);
    expect(find.textContaining('同じJANの2行を合計'), findsOneWidget);
    _expectRow(tester, _jan1, '40', '+15', '55');

    await _tick(tester);
    await tester.tap(find.byKey(const ValueKey('sf-apply')));
    await tester.pumpAndSettle();
    expect(find.text('在庫の合計: 40 → 55'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sf-confirm')));
    await tester.pumpAndSettle();
    final (_, mode, lines) = repo.applied.single;
    expect(mode, StockFileMode.add);
    expect(lines.single.quantity, 15);
  });

  testWidgets('the whole file lands: products the library lacks are registered, then their stock goes in', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final book = FakePriceBookRepository(items: const [PriceBookItem(id: 7, name: 'テストノート A罫', janCode: _jan2)]);
    final repo = _FakeStock({_jan1: 'テストペン 青'}, stock: {_jan1: 4}, book: {_jan2: (7, 'テストノート A罫')}, priceBook: book);
    // jan1 is in the library, jan2 only in the price book, jan3 nowhere but named.
    final csv = Uint8List.fromList(utf8.encode('JAN,品名,メーカー,数量\n$_jan1,ペン,テスト文具,10\n$_jan2,ノート,,6\n$_jan3,テスト消しゴム,テスト文具,2\n'));
    await pumpApp(tester, const StockFileImportScreen(), overrides: [
      _signedIn(['inventory.adjust', 'product.manage']),
      stockImportRepositoryProvider.overrideWithValue(repo),
      priceBookRepositoryProvider.overrideWithValue(book),
      stockFilePickerProvider.overrideWithValue(() async => (name: 'a.csv', bytes: csv)),
      warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(const WarehouseOverview(
        warehouses: [Warehouse(id: 1, code: 'WH-01', name: '本社倉庫')],
        totals: WarehouseTotals(),
      ))),
    ]);
    await tester.tap(find.byKey(const ValueKey('sf-pick')));
    await tester.pumpAndSettle();

    expect(find.text('商品ライブラリーにない商品 2件'), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('sf-register-new'))).value, isTrue);
    expect(find.text('検品待ちとして登録（3商品）'), findsOneWidget);

    await _tick(tester);
    await tester.tap(find.byKey(const ValueKey('sf-apply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sf-confirm-register')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sf-confirm')));
    await tester.pumpAndSettle();

    // The new one went into the price book under the file's name and maker…
    expect(book.imports.single.lines.single, {'jan_code': _jan3, 'product_name': 'テスト消しゴム', 'maker': 'テスト文具'});
    // …and both into the library: the price book's item, and the new one.
    expect(book.toMaster.single.toSet(), {7, 1000});
    final (_, _, lines) = repo.applied.single;
    expect(lines.map((l) => (l.janCode, l.quantity)).toSet(), {(_jan1, 10), (_jan2, 6), (_jan3, 2)});
    // What the file was read as is kept with the import.
    expect(repo.notes.single.$2.map((r) => r.name), ['ペン', 'ノート', 'テスト消しゴム']);
    expect(repo.notes.single.$3, isFalse);
    expect(find.byKey(const ValueKey('iv-open-12')), findsOneWidget);
  });

  testWidgets('unticked, only what the library has goes in', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final book = FakePriceBookRepository();
    final repo = _FakeStock({_jan1: 'テストペン 青'}, priceBook: book);
    final csv = Uint8List.fromList(utf8.encode('JAN,品名,数量\n$_jan1,ペン,10\n$_jan3,消しゴム,2\n'));
    await pumpApp(tester, const StockFileImportScreen(), overrides: [
      _signedIn(['inventory.adjust', 'product.manage']),
      stockImportRepositoryProvider.overrideWithValue(repo),
      priceBookRepositoryProvider.overrideWithValue(book),
      stockFilePickerProvider.overrideWithValue(() async => (name: 'a.csv', bytes: csv)),
      warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(const WarehouseOverview(
        warehouses: [Warehouse(id: 1, code: 'WH-01', name: '本社倉庫')],
        totals: WarehouseTotals(),
      ))),
    ]);
    await tester.tap(find.byKey(const ValueKey('sf-pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sf-register-new')));
    await tester.pumpAndSettle();
    await _tick(tester);
    await tester.tap(find.byKey(const ValueKey('sf-apply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sf-confirm-register')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('sf-confirm')));
    await tester.pumpAndSettle();
    expect(book.imports, isEmpty);
    expect(repo.applied.single.$3.map((l) => l.janCode), [_jan1]);
  });

  test('what the AI read becomes a stock sheet: JANs checked, the same JAN summed, doubts kept', () {
    final s = stockSheetFromRead(const [
      ReadRow(lineNo: 1, jan: _jan1, name: 'テストペン', quantity: '10'),
      ReadRow(lineNo: 2, jan: _jan1, name: 'ﾃｽﾄﾍﾟﾝ', quantity: '2', flags: ['ai_disagree']),
      ReadRow(lineNo: 3, name: 'メモ帳', quantity: '4'),
      ReadRow(lineNo: 4, jan: _jan2, name: 'テストノート', flags: ['no_maker']),
    ]);
    expect(s.byAi, isTrue);
    expect(s.lines.single, const StockFileLine(lineNo: 1, janCode: _jan1, quantity: 12, name: 'テストペン', merged: 2, doubtful: true));
    expect(s.problems.map((p) => p.code), ['no_jan', 'bad_quantity']);
    // Every row is kept as read, for the viewer.
    expect(s.read.length, 4);
    expect(readsLocally('a.PDF'), isFalse);
    expect(readsLocally('a.xlsx'), isTrue);
  });

  testWidgets('a PDF is read by the AI; its lines are checked in a table beside the original, then counted', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _FakeStock({_jan1: 'テストペン 青', _jan2: 'テストノート'}, stock: {_jan1: 40});
    final reader = FakeMasterImportRepository(
      readResult: const MasterRead(lines: [
        MasterLine(
          lineNo: 1, janCode: _jan1, supplierName: 'ﾃｽﾄﾍﾟﾝ ｱｵ', quantity: '100', flags: ['ai_disagree:planned_quantity'],
          ledger: {'unit_price': 88, 'amount': 880},
        ),
        MasterLine(lineNo: 2, janCode: _jan2, supplierName: 'ノート', quantity: '30'),
      ]),
    );
    await pumpApp(tester, const StockFileImportScreen(), overrides: [
      _signedIn(['inventory.adjust']),
      stockImportRepositoryProvider.overrideWithValue(repo),
      masterImportRepositoryProvider.overrideWithValue(reader),
      stockFilePickerProvider.overrideWithValue(() async => (name: '納品書.pdf', bytes: Uint8List.fromList([37, 80, 68, 70]))),
      warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(const WarehouseOverview(
        warehouses: [Warehouse(id: 1, code: 'WH-01', name: '本社倉庫')],
        totals: WarehouseTotals(),
      ))),
    ]);
    await tester.tap(find.byKey(const ValueKey('sf-pick')));
    await tester.pumpAndSettle();

    expect(reader.reads, 1);
    // Row by row, so a ledger keeps each 注番 (0150).
    expect(reader.readKeptRows, isTrue);
    // First the table: every row, its doubt marked, 数量 × 単価 against 金額.
    expect(find.text('読み取り結果の確認'), findsOneWidget);
    expect(find.byKey(const ValueKey('rc-doubt-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('rc-mismatch')), findsOneWidget);
    expect(find.text('2行・数量合計 130・金額合計 880'), findsOneWidget);
    // The doubtful one was 10, not 100: now it adds up.
    await tester.enterText(find.byKey(const ValueKey('rc-1-quantity')), '10');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rc-mismatch')), findsNothing);
    // The other is left out.
    await tester.tap(find.byKey(const ValueKey('rc-remove-2')));
    await tester.pumpAndSettle();
    expect(find.text('1行・数量合計 10・金額合計 880'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rc-ok')));
    await tester.pumpAndSettle();

    // Then the stock: what the person left, checked, no longer in doubt.
    expect(find.byKey(const ValueKey('sf-table-checked')), findsOneWidget);
    expect(find.text('元のファイルと照合済み（直した行 1・外した行 1）'), findsOneWidget);
    _expectRow(tester, _jan1, '40', '+10', '50');
    expect(find.byKey(const ValueKey('sf-doubt-$_jan1')), findsNothing);
    expect(find.byKey(const ValueKey('sf-line-$_jan2')), findsNothing);

    await _tick(tester);
    await tester.tap(find.byKey(const ValueKey('sf-apply')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sf-confirm')));
    await tester.pumpAndSettle();
    final (_, mode, lines) = repo.applied.single;
    expect(mode, StockFileMode.add);
    expect(lines.map((l) => (l.janCode, l.quantity)), [(_jan1, 10)]);
    expect(repo.kept.single.$2, '納品書.pdf');
    // The reading is kept as the person left it: what the AI had beside it.
    final read = repo.notes.single.$2;
    expect(read.first.quantity, '10');
    expect(read.first.aiQuantity, '100');
    expect(read.first.flags, containsAll(['human_checked', 'human_corrected']));
    expect(read.last.humanRemoved, isTrue);
  });

  testWidgets('read by the AI, nothing is counted until the table is checked; it can be opened again', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reader = FakeMasterImportRepository(
      readResult: const MasterRead(lines: [MasterLine(lineNo: 1, janCode: _jan1, supplierName: 'ペン', quantity: '5')]),
    );
    await pumpApp(tester, const StockFileImportScreen(), overrides: [
      _signedIn(['inventory.adjust']),
      stockImportRepositoryProvider.overrideWithValue(_FakeStock({_jan1: 'テストペン 青'})),
      masterImportRepositoryProvider.overrideWithValue(reader),
      stockFilePickerProvider.overrideWithValue(() async => (name: 'scan.jpg', bytes: Uint8List.fromList([1, 2, 3]))),
      warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(const WarehouseOverview(
        warehouses: [Warehouse(id: 1, code: 'WH-01', name: '本社倉庫')],
        totals: WarehouseTotals(),
      ))),
    ]);
    await tester.tap(find.byKey(const ValueKey('sf-pick')));
    await tester.pumpAndSettle();
    // Gone back without it: the stock is not worked out, and the table waits.
    Navigator.of(tester.element(find.byType(ReadingCheckScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sf-table-needed')), findsOneWidget);
    expect(find.byKey(const ValueKey('sf-apply')), findsNothing);
    expect(find.byKey(const ValueKey('sf-line-$_jan1')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('sf-open-table')));
    await tester.pumpAndSettle();
    // A row the AI missed, added by hand.
    await tester.tap(find.byKey(const ValueKey('rc-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('rc-2-jan')), _jan2);
    await tester.enterText(find.byKey(const ValueKey('rc-2-quantity')), '3');
    await tester.tap(find.byKey(const ValueKey('rc-ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sf-table-needed')), findsNothing);
    expect(find.byKey(const ValueKey('sf-line-$_jan1')), findsOneWidget);
    expect(find.byKey(const ValueKey('sf-apply')), findsOneWidget);
    expect(find.textContaining(_jan2), findsWidgets);
  });

  testWidgets('when the AI cannot be used, it says why', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester, const StockFileImportScreen(), overrides: [
      _signedIn(['inventory.adjust']),
      stockImportRepositoryProvider.overrideWithValue(_FakeStock({})),
      masterImportRepositoryProvider.overrideWithValue(
          FakeMasterImportRepository(readResult: const MasterRead(lines: [], aiFailure: 'quota'))),
      stockFilePickerProvider.overrideWithValue(() async => (name: 'scan.jpg', bytes: Uint8List.fromList([1, 2, 3]))),
      warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(const WarehouseOverview(
        warehouses: [Warehouse(id: 1, code: 'WH-01', name: '本社倉庫')],
        totals: WarehouseTotals(),
      ))),
    ]);
    await tester.tap(find.byKey(const ValueKey('sf-pick')));
    await tester.pumpAndSettle();
    expect(find.textContaining('AIの利用残高'), findsOneWidget);
  });

  testWidgets('nothing goes in until the reading is checked', (tester) async {
    await _pumpCsv(tester, 'JAN,数量\n$_jan1,10\n', products: {_jan1: 'テストペン 青'});
    ButtonStyleButton apply() => tester.widget<ButtonStyleButton>(find.byKey(const ValueKey('sf-apply')));
    expect(apply().onPressed, isNull);
    await _tick(tester);
    expect(apply().onPressed, isNotNull);
    // A change to a line asks for the look again.
    await tester.tap(find.byKey(const ValueKey('sf-line-$_jan1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('sf-edit-qty')), '12');
    await tester.tap(find.byKey(const ValueKey('sf-edit-ok')));
    await tester.pumpAndSettle();
    expect(apply().onPressed, isNull);
  });

  testWidgets('the same lines already in: asked first, and nothing goes in on cancel', (tester) async {
    final repo = await _pumpCsv(tester, 'JAN,数量\n$_jan1,10\n', products: {_jan1: 'テストペン 青'});
    repo.dupes = [DuplicateImport(importId: 9, at: DateTime(2026, 10, 22, 14), fileName: '在庫.csv', lines: 1, change: 10)];
    await _tick(tester);
    await tester.tap(find.byKey(const ValueKey('sf-apply')));
    await tester.pumpAndSettle();
    expect(find.text('同じ内容がすでに反映されています'), findsOneWidget);
    expect(find.byKey(const ValueKey('sf-dup-9')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sf-dup-cancel')));
    await tester.pumpAndSettle();
    expect(repo.applied, isEmpty);

    await tester.tap(find.byKey(const ValueKey('sf-apply')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sf-dup-go')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sf-confirm')));
    await tester.pumpAndSettle();
    expect(repo.applied, hasLength(1));
    // Fingerprinted, so the next time is caught too.
    final (id, file, lines) = repo.fingerprints.single;
    expect(id, 12);
    expect(file, startsWith('f:'));
    expect(lines, linesFingerprint(const [StockFileLine(lineNo: 2, janCode: _jan1, quantity: 10)]));
  });

  testWidgets('every row is shown; rows that are not products are counted apart; a huge quantity is asked about', (tester) async {
    await _pumpCsv(
      tester,
      'JAN,商品名,数量\n$_jan1,ペン,4909999000014\n,船場支店,\n,,\n$_jan2,ノート,3\n',
      products: {_jan1: 'テストペン 青', _jan2: 'テストノート'},
    );
    expect(find.byKey(const ValueKey('sf-line-$_jan1')), findsOneWidget);
    expect(find.byKey(const ValueKey('sf-line-$_jan2')), findsOneWidget);
    expect(find.byKey(const ValueKey('sf-doubt-$_jan1')), findsOneWidget);
    expect(find.textContaining('数量が大きすぎます'), findsWidgets);
    // 船場支店 and the blank row are not products, and not errors either.
    expect(find.textContaining('商品ではない行 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('sf-left-out')), findsNothing);
  });

  testWidgets('the 確認用Excel has every row; corrected and chosen again, the corrections are known', (tester) async {
    final saved = <(String, Uint8List)>[];
    final reader = FakeMasterImportRepository(
      readResult: const MasterRead(lines: [
        MasterLine(lineNo: 1, janCode: _jan1, supplierName: 'ﾃｽﾄﾍﾟﾝ', quantity: '100', flags: ['ai_disagree']),
        MasterLine(lineNo: 2, janCode: '', supplierName: 'ノート', quantity: '3'),
      ]),
    );
    await _pumpCsv(tester, '%PDF', products: {_jan1: 'テストペン 青'}, saved: saved, reader: reader, name: '納品書.pdf');
    // The table opens first; the 確認用Excel is there too, behind it.
    Navigator.of(tester.element(find.byType(ReadingCheckScreen))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sf-review-xlsx')));
    await tester.pumpAndSettle();
    expect(saved.single.$1, '在庫登録_確認用_納品書.xlsx');
    final rows = readXlsx(saved.single.$2);
    final head = rows.indexWhere((r) => r.contains('JANコード'));
    expect(rows[head].take(6), ['元の行', 'JANコード', '商品名', 'メーカー', '品番', '数量']);
    expect(rows[head + 1][6], '反映できる・要確認');
    expect(rows[head + 2][6], 'JANが読めない（直してください）');

    // A person corrects it: 100 → 10, and fills in the missing JAN.
    final fixed = [for (final r in rows) [...r]];
    fixed[head + 1][5] = '10';
    fixed[head + 2][1] = _jan2;
    final again = parseStockRows(fixed);
    expect(again.lines.map((l) => (l.janCode, l.quantity)), [(_jan1, 10), (_jan2, 3)]);
    expect(again.read.where((r) => r.corrected).length, 2);
    expect(again.read.first.flags, ['human_corrected']);
  });

  testWidgets('the lines going in are a table on a PC, field by field, and a list on a phone', (tester) async {
    await _pumpCsv(tester, 'JAN,商品名,数量\n$_jan1,ペン,4\n', products: {_jan1: 'テストペン 青'});
    expect(find.byKey(const ValueKey('sf-going-table')), findsOneWidget);
    expect(find.text('反映後'), findsOneWidget);
    _expectRow(tester, _jan1, '0', '+4', '4');

    await tester.binding.setSurfaceSize(const Size(600, 1600));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sf-going-table')), findsNothing);
    expect(find.text('現在庫 0 ＋ 4 ＝ 4'), findsOneWidget);
  });

  testWidgets('the file chosen can be looked at; the 確認用Excel is beside it', (tester) async {
    await _pumpCsv(tester, 'JAN,商品名,数量\n$_jan1,ペン,4\n', products: {_jan1: 'テストペン 青'});
    expect(find.byKey(const ValueKey('sf-review-xlsx')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sf-view-original')));
    await tester.pumpAndSettle();
    // The sheet's own cells, as they are.
    expect(find.byKey(const ValueKey('iv-sheet')), findsOneWidget);
    expect(find.text('ペン'), findsOneWidget);
  });

  testWidgets('a PDF too long for the AI says what to do instead', (tester) async {
    await _pumpCsv(tester, '%PDF',
        reader: FakeMasterImportRepository(readFailure: 'Request idle timeout limit (150s) reached'), name: 'long.pdf');
    expect(find.textContaining('時間内に終わりませんでした'), findsOneWidget);
  });

  testWidgets('without the stock permission the file is read but not put in', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _FakeStock({_jan1: 'テストペン 青'});
    final csv = Uint8List.fromList(utf8.encode('JAN,数量\n$_jan1,10\n'));
    await pumpApp(tester, const StockFileImportScreen(), overrides: [
      _signedIn(['inventory.view']),
      stockImportRepositoryProvider.overrideWithValue(repo),
      stockFilePickerProvider.overrideWithValue(() async => (name: 'a.csv', bytes: csv)),
      warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(const WarehouseOverview(
        warehouses: [Warehouse(id: 1, code: 'WH-01', name: '本社倉庫')],
        totals: WarehouseTotals(),
      ))),
    ]);
    await tester.tap(find.byKey(const ValueKey('sf-pick')));
    await tester.pumpAndSettle();
    expect(tester.widget<ButtonStyleButton>(find.byKey(const ValueKey('sf-apply'))).onPressed, isNull);
    expect(find.text('在庫を反映するには「在庫調整」の権限が必要です。'), findsOneWidget);
  });
}
