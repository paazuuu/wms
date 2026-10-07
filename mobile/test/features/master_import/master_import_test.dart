// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/core/export/xlsx.dart';
import 'package:wms_mobile/features/auth/application/auth_controller.dart';
import 'package:wms_mobile/features/auth/domain/auth_user.dart';
import 'package:wms_mobile/features/master_import/data/master_import_repository.dart';
import 'package:wms_mobile/features/master_import/domain/master_import.dart';
import 'package:wms_mobile/features/master_import/presentation/master_import_screen.dart';
import 'package:wms_mobile/features/master_import/presentation/master_imports_screen.dart';
import 'package:wms_mobile/features/product_library/data/english_name_suggester.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';

import '../../support/harness.dart';

// Synthetic JANs with a correct check digit.
const _jan1 = '4909999000014';
const _jan2 = '4909999000021';

Override _signedIn(List<String> permissions) => authControllerProvider.overrideWith((ref) =>
    fakeAuthControllerFor(AuthUser(id: 'u1', email: 'a@b.test', name: '倉庫', permissions: permissions)));

class _FakeSuggester implements EnglishNameSuggester {
  int calls = 0;

  @override
  Future<ApiResult<Map<int, String>>> suggest(List<NameRequest> items) async {
    calls++;
    return ApiSuccess({for (final i in items) i.index: 'EN ${i.supplierName}'});
  }
}

Map<String, dynamic> _readLine(String jan, String name, num qty) =>
    {'jan_code': jan, 'product_name': name, 'planned_quantity': qty, 'maker': 'テスト工業'};

PlatformFile _file(String name, [Uint8List? bytes]) =>
    PlatformFile(name: name, size: bytes?.length ?? 3, bytes: bytes ?? Uint8List.fromList([1, 2, 3]));

Future<(FakeMasterImportRepository, _FakeSuggester, List<(String, Uint8List)>)> _pump(
  WidgetTester tester, {
  required FakeMasterImportRepository repo,
  required List<PlatformFile> files,
  List<String> permissions = const ['product.manage', 'inventory.adjust'],
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final suggester = _FakeSuggester();
  final saved = <(String, Uint8List)>[];
  final queue = [...files];
  await pumpApp(
    tester,
    MasterImportScreen(
      pickFile: () async => queue.isEmpty ? null : queue.removeAt(0),
      saveFile: (name, bytes) async => saved.add((name, bytes)),
    ),
    overrides: [
      masterImportRepositoryProvider.overrideWithValue(repo),
      englishNameSuggesterProvider.overrideWithValue(suggester),
      writeWarehouseIdProvider.overrideWithValue(1),
      _signedIn(permissions),
    ],
  );
  return (repo, suggester, saved);
}

void main() {
  group('xlsx', () {
    test('a sheet written is read back as written, JAN as text', () {
      final bytes = buildXlsx(
        sheetName: '商品と数量',
        headers: ['JANコード', '商品名', '数量'],
        rows: [
          ['0490999900001', 'ボルト <M8> & "ナット"', 12],
          ['4909999000021', null, 3.5],
        ],
        flagged: {(0, 1)},
      );
      final table = readXlsx(bytes);
      expect(table, [
        ['JANコード', '商品名', '数量'],
        ['0490999900001', 'ボルト <M8> & "ナット"', '12'],
        ['4909999000021', '', '3.5'],
      ]);
      expect(columnLetters(0), 'A');
      expect(columnLetters(26), 'AA');
      expect(() => readXlsx(Uint8List.fromList([1, 2, 3])), throwsFormatException);
    });
  });

  group('checks', () {
    test('a JAN check digit is checked', () {
      expect(janCheckOk(_jan1), isTrue);
      expect(janCheckOk('4909999000015'), isFalse);
      expect(janCheckOk('49123456'), isTrue);
      expect(janCheckOk('49123457'), isFalse);
      expect(janCheckOk('12345'), isFalse);
    });

    test('what stops a file and what is only shown', () {
      final lines = [
        MasterLine(lineNo: 1, janCode: _jan1, supplierName: 'A', quantity: '3', nameEn: 'A'),
        MasterLine(lineNo: 2, janCode: '4909999000015', supplierName: 'B', quantity: '2個'),
        MasterLine(lineNo: 3, janCode: _jan1, supplierName: '', quantity: ''),
        MasterLine(lineNo: 4, janCode: '', supplierName: 'D', quantity: '1', flags: ['ai_disagree']),
      ];
      final p = checkMasterLines(lines, verified: false, totalsOk: false);
      final codes = [for (final x in p) '${x.lineNo}:${x.code}'];
      expect(codes, containsAll([
        '0:unverified', '0:totals_mismatch', '2:jan_invalid', '2:qty_invalid', '3:jan_duplicate', '3:name_missing',
        '3:qty_missing', '4:jan_missing', '4:ai_disagree', '2:name_en_missing',
      ]));
      expect(p.firstWhere((x) => x.code == 'qty_missing').blocking, isFalse);
      expect(p.firstWhere((x) => x.code == 'name_en_missing').blocking, isFalse);
      // Once a person has checked the lines, the reader's doubts are gone.
      final checked = checkMasterLines(lines, checked: true, verified: false, totalsOk: false);
      expect(checked.any((x) => x.code == 'unverified' || x.code == 'ai_disagree' || x.code == 'totals_mismatch'), isFalse);
      expect(checkMasterLines(const []).single.code, 'no_lines');
    });

    test('a sheet is matched by its headings, in any order and any wording', () {
      final lines = MasterSheet.parse([
        ['在庫一覧'],
        ['数量', '品名', 'JAN', '英語名', 'メーカー'],
        ['10', 'ボルト', _jan1, 'Bolt', 'テスト'],
        ['', '', '', '', ''],
        ['4', 'ナット', _jan2, '', ''],
      ]);
      expect(lines.length, 2);
      expect([lines[0].janCode, lines[0].supplierName, lines[0].nameEn, lines[0].maker, lines[0].quantity],
          [_jan1, 'ボルト', 'Bolt', 'テスト', '10']);
      expect(lines[1].lineNo, 2);
      expect(() => MasterSheet.parse([['名前', '数']]), throwsFormatException);
    });

    test('the converted sheet reads back into the same lines', () {
      final lines = [
        MasterLine(lineNo: 1, janCode: _jan1, supplierName: 'ボルト', nameEn: 'Bolt', quantity: '10', maker: 'M'),
        MasterLine(lineNo: 2, janCode: 'x', supplierName: 'ナット', quantity: '4'),
      ];
      final problems = checkMasterLines(lines);
      final (rows, flagged) = MasterSheet.rows(lines, problems, (p) => p.code);
      expect(flagged, contains((1, 1)));
      final back = MasterSheet.parse(readXlsx(buildXlsx(sheetName: 's', headers: MasterSheet.headers, rows: rows)));
      expect([for (final l in back) l.janCode], [_jan1, 'x']);
      expect(back[0].nameEn, 'Bolt');
      expect(back[0].quantity, '10');
    });
  });

  testWidgets('a clean file goes into the master, then onto the stock with what was there kept', (tester) async {
    final repo = FakeMasterImportRepository(
      readResult: MasterRead(lines: [
        MasterLine.fromRead(_readLine(_jan1, 'ステンレス六角ボルト M8', 10), 1),
        MasterLine.fromRead(_readLine(_jan2, 'ナット M8', 4), 2),
      ], supplierId: 42),
      onHandByJan: {_jan1: 5},
    );
    final (_, suggester, _) = await _pump(tester, repo: repo, files: [_file('在庫一覧.pdf')]);
    await tester.tap(find.byKey(const ValueKey('mi-pick')));
    await tester.pumpAndSettle();

    // One choice: read, English names proposed, into the master.
    expect(repo.reads, 1);
    expect(repo.kept.single.$1, 'original');
    expect(suggester.calls, 1);
    expect(repo.commits.single.map((l) => l.nameEn), ['EN ステンレス六角ボルト M8', 'EN ナット M8']);
    expect(find.byKey(const ValueKey('mi-master-done')), findsOneWidget);

    // The stock there now, a correction by hand, and the total.
    expect(find.text('今の在庫: 5'), findsOneWidget);
    expect(find.text('合計: 15'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('mi-fix-2')), '2');
    await tester.pumpAndSettle();
    expect(find.text('合計: 6'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mi-apply-stock')));
    await tester.pumpAndSettle();
    expect(repo.stockApplied.single, [
      {'line_no': 1, 'quantity': 10},
      {'line_no': 2, 'quantity': 4, 'on_hand_set': 2},
    ]);
    expect(find.byKey(const ValueKey('mi-stock-done')), findsOneWidget);
    expect(find.text('元の在庫 5 ＋ 追加 10 ＝ 15'), findsOneWidget);
    expect(find.text('元の在庫 0 → 手で直して 2 ＋ 追加 4 ＝ 6'), findsOneWidget);
    expect(find.byKey(const ValueKey('mi-download-original')), findsOneWidget);
  });

  testWidgets('a doubtful file stops untouched and is put right by hand', (tester) async {
    final repo = FakeMasterImportRepository(
      readResult: MasterRead(lines: [
        MasterLine.fromRead(_readLine('4909999000015', 'ボルト', 10), 1),
        MasterLine.fromRead(_readLine(_jan2, 'ナット', 4), 2),
      ], verified: false),
    );
    await _pump(tester, repo: repo, files: [_file('scan.pdf')]);
    await tester.tap(find.byKey(const ValueKey('mi-pick')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mi-stopped')), findsOneWidget);
    expect(repo.commits, isEmpty);
    expect(repo.stops.single.map((p) => p.code), containsAll(['unverified', 'jan_invalid']));
    expect(find.textContaining('1行目: JANコードが正しくありません（4909999000015）'), findsOneWidget);
    expect(find.byKey(const ValueKey('mi-way-manual')), findsOneWidget);
    expect(find.byKey(const ValueKey('mi-way-excel')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mi-way-manual')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('mi-jan-1')), _jan1);
    await tester.enterText(find.byKey(const ValueKey('mi-en-1')), 'Hex Bolt');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mi-register-checked')));
    await tester.pumpAndSettle();

    expect(repo.commits.single.map((l) => l.jan), [_jan1, _jan2]);
    expect(repo.commits.single.first.nameEn, 'Hex Bolt');
    expect(find.byKey(const ValueKey('mi-apply-stock')), findsOneWidget);
  });

  testWidgets('a doubtful file becomes an Excel sheet, kept, and the checked sheet goes in', (tester) async {
    final repo = FakeMasterImportRepository(
      readResult: MasterRead(lines: [
        MasterLine.fromRead(_readLine(_jan1, 'ボルト', 10), 1),
        MasterLine.fromRead(_readLine('', 'ナット', 4), 2),
      ]),
    );
    // What the person sends back: the sheet with the JAN filled in.
    final corrected = buildXlsx(sheetName: 's', headers: MasterSheet.headers, rows: [
      [1, _jan1, 'ボルト', '', 'Bolt', '', '', '', '', '', '', 10, ''],
      [2, _jan2, 'ナット', '', 'Nut', '', '', '', '', '', '', 4, ''],
    ]);
    final (_, _, saved) = await _pump(tester, repo: repo, files: [_file('scan.pdf'), _file('checked.xlsx', corrected)]);
    await tester.tap(find.byKey(const ValueKey('mi-pick')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mi-stopped')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mi-way-excel')));
    await tester.pumpAndSettle();
    expect(saved.single.$1, 'scan_確認用.xlsx');
    final sheet = MasterSheet.parse(readXlsx(saved.single.$2));
    expect(sheet.map((l) => l.supplierName), ['ボルト', 'ナット']);
    expect(repo.kept.map((k) => k.$1), ['original', 'converted']);
    expect(find.byKey(const ValueKey('mi-download-converted')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mi-pick-corrected')));
    await tester.pumpAndSettle();
    expect(repo.kept.map((k) => k.$1), ['original', 'converted', 'corrected']);
    expect(repo.commits.single.map((l) => l.jan), [_jan1, _jan2]);
    expect(repo.commits.single.map((l) => l.nameEn), ['Bolt', 'Nut']);
  });

  testWidgets('a file that cannot be read offers a sheet to fill in and a second try', (tester) async {
    final repo = FakeMasterImportRepository(readFailure: 'Gemini error 402: prepaid credits depleted');
    final (_, _, saved) = await _pump(tester, repo: repo, files: [_file('photo.jpg')]);
    await tester.tap(find.byKey(const ValueKey('mi-pick')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mi-stopped')), findsOneWidget);
    expect(find.text('記入用のExcelをダウンロード'), findsOneWidget);
    expect(find.byKey(const ValueKey('mi-retry')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mi-way-excel')));
    await tester.pumpAndSettle();
    expect(saved.single.$1, 'photo_記入用.xlsx');
    expect(readXlsx(saved.single.$2).single, MasterSheet.headers);
  });

  testWidgets('our own sheet is read as it is, without the AI', (tester) async {
    final sheet = buildXlsx(sheetName: 's', headers: MasterSheet.headers, rows: [
      [1, _jan1, 'ボルト', '', 'Bolt', '', '', '', '', '', '', 3, ''],
    ]);
    final repo = FakeMasterImportRepository();
    await _pump(tester, repo: repo, files: [_file('ours.xlsx', sheet)]);
    await tester.tap(find.byKey(const ValueKey('mi-pick')));
    await tester.pumpAndSettle();
    expect(repo.reads, 0);
    expect(repo.commits.single.single.quantity, '3');
  });

  testWidgets('without stock adjustment the stock stage says so', (tester) async {
    final repo = FakeMasterImportRepository(
      readResult: MasterRead(lines: [MasterLine.fromRead(_readLine(_jan1, 'ボルト', 1), 1)]),
    );
    await _pump(tester, repo: repo, files: [_file('a.pdf')], permissions: const ['product.manage']);
    await tester.tap(find.byKey(const ValueKey('mi-pick')));
    await tester.pumpAndSettle();
    expect(find.text('在庫に反映するには「在庫調整」の権限が必要です'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('mi-apply-stock'))).onPressed, isNull);
  });

  testWidgets('the history shows where each import got to and its files', (tester) async {
    final repo = FakeMasterImportRepository(imports: [
      MasterImport.fromJson({
        'id': 3,
        'status': 'stopped',
        'original_name': 'scan.pdf',
        'original_path': 'imports/3/original-scan.pdf',
        'converted_name': 'scan_確認用.xlsx',
        'converted_path': 'imports/3/converted-scan.xlsx',
        'line_count': 2,
        'issues': [
          {'line_no': 1, 'code': 'jan_invalid', 'value': '123'},
        ],
      }),
      MasterImport.fromJson({
        'id': 2,
        'status': 'master_done',
        'original_name': 'ok.xlsx',
        'original_path': 'imports/2/original-ok.xlsx',
        'line_count': 5,
        'master_created': 4,
        'master_updated': 1,
      }),
    ]);
    final saved = <String>[];
    await pumpApp(tester, MasterImportsScreen(saveFile: (n, _) async => saved.add(n)), overrides: [
      masterImportRepositoryProvider.overrideWithValue(repo),
      _signedIn(const ['product.manage', 'inventory.adjust']),
    ]);
    expect(find.text('停止（未登録）'), findsOneWidget);
    expect(find.textContaining('1行目 JANコードが正しくありません（123）'), findsOneWidget);
    expect(find.text('商品マスタ: 新規 4・更新 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('mi-row-2-stock')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mi-row-3-converted')));
    await tester.pumpAndSettle();
    expect(saved, ['scan_確認用.xlsx']);
  });

  testWidgets('a product stock is set by hand', (tester) async {
    final repo = FakeMasterImportRepository(onHandByJan: {_jan1: 5});
    await pumpApp(
      tester,
      Scaffold(body: ProductOnHandRow(warehouseId: 1, janCode: _jan1, name: 'ボルト')),
      overrides: [
        masterImportRepositoryProvider.overrideWithValue(repo),
        _signedIn(const ['inventory.adjust']),
      ],
    );
    expect(find.text('今の在庫: 5'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('soh-open')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('soh-qty')), '8');
    await tester.tap(find.byKey(const ValueKey('soh-save')));
    await tester.pumpAndSettle();
    expect(repo.setOnHands, [(_jan1, 8)]);
    expect(find.text('今の在庫: 8'), findsOneWidget);
    expect(find.text('在庫数を 5 → 8 に変更しました'), findsOneWidget);
  });

  testWidgets('without the permission the stock cannot be changed by hand', (tester) async {
    await pumpApp(
      tester,
      Scaffold(body: ProductOnHandRow(warehouseId: 1, janCode: _jan1, name: 'ボルト')),
      overrides: [_signedIn(const ['product.view'])],
    );
    expect(find.byKey(const ValueKey('soh-open')), findsNothing);
  });
}
