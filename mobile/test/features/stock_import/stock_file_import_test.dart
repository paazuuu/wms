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
}

Override _signedIn(List<String> permissions) => authControllerProvider.overrideWith((ref) =>
    fakeAuthControllerFor(AuthUser(id: 'u1', email: 'a@b.test', name: '倉庫', permissions: permissions)));

void main() {
  group('reading a stock sheet', () {
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
    expect(find.byKey(const ValueKey('sf-problems')), findsOneWidget);
    expect(find.byKey(const ValueKey('sf-unknown')), findsOneWidget);
    expect(find.text('テストペン 青'), findsOneWidget);
    expect(find.byKey(const ValueKey('sf-line-$_jan3')), findsNothing);
    // Set: said plainly, with what each becomes.
    expect(find.byKey(const ValueKey('sf-set-warning')), findsOneWidget);
    expect(find.text('現在庫 4 → 10（+6）'), findsOneWidget);

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
    expect(find.text('現在庫 40 ＋ 15 ＝ 55'), findsOneWidget);

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
    expect(find.text('在庫に反映（3商品）'), findsOneWidget);

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

  testWidgets('a PDF is read by the AI; its lines are checked, corrected and left out before they go in', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _FakeStock({_jan1: 'テストペン 青', _jan2: 'テストノート'}, stock: {_jan1: 40});
    final reader = FakeMasterImportRepository(
      readResult: const MasterRead(lines: [
        MasterLine(lineNo: 1, janCode: _jan1, supplierName: 'ﾃｽﾄﾍﾟﾝ ｱｵ', quantity: '100', flags: ['ai_disagree']),
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
    expect(find.byKey(const ValueKey('sf-ai')), findsOneWidget);
    expect(find.textContaining('要確認 1行'), findsOneWidget);
    expect(find.byKey(const ValueKey('sf-doubt-$_jan1')), findsOneWidget);
    expect(find.text('現在庫 40 ＋ 100 ＝ 140'), findsOneWidget);

    // The doubtful one was 10, not 100.
    await tester.tap(find.byKey(const ValueKey('sf-line-$_jan1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('sf-edit-qty')), '10');
    await tester.tap(find.byKey(const ValueKey('sf-edit-ok')));
    await tester.pumpAndSettle();
    expect(find.text('現在庫 40 ＋ 10 ＝ 50'), findsOneWidget);
    // The other is left out.
    await tester.tap(find.byKey(const ValueKey('sf-line-$_jan2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sf-edit-remove')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sf-line-$_jan2')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('sf-apply')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sf-confirm')));
    await tester.pumpAndSettle();
    final (_, mode, lines) = repo.applied.single;
    expect(mode, StockFileMode.add);
    expect(lines.map((l) => (l.janCode, l.quantity)), [(_jan1, 10)]);
    expect(repo.kept.single.$2, '納品書.pdf');
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
