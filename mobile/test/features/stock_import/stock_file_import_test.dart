import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/core/export/xlsx.dart';
import 'package:wms_mobile/features/auth/application/auth_controller.dart';
import 'package:wms_mobile/features/auth/domain/auth_user.dart';
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
  _FakeStock(this.products);

  final Map<String, String> products;
  final applied = <(int, StockFileMode, List<StockFileLine>)>[];
  final kept = <(int, String)>[];

  @override
  Future<ApiResult<Map<String, String>>> known(List<String> jans) async =>
      ApiSuccess({for (final j in jans) if (products.containsKey(j)) j: products[j]!});

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
    final repo = _FakeStock({_jan1: 'テストペン 青', _jan2: 'テストノート'});
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

    await tester.tap(find.byKey(const ValueKey('sf-apply')));
    await tester.pumpAndSettle();
    expect(find.text('本社倉庫の在庫に反映しますか？'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sf-confirm')));
    await tester.pumpAndSettle();

    final (wh, mode, lines) = repo.applied.single;
    expect(wh, 1);
    expect(mode, StockFileMode.set);
    expect(lines.map((l) => l.janCode), [_jan1, _jan2]);
    expect(repo.kept.single, (12, '在庫.csv'));
    expect(find.byKey(const ValueKey('sf-done')), findsOneWidget);
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
