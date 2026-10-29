// ignore_for_file: prefer_const_literals_to_create_immutables
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/core/export/xlsx.dart';
import 'package:wms_mobile/features/auth/application/auth_controller.dart';
import 'package:wms_mobile/features/auth/domain/auth_user.dart';
import 'package:wms_mobile/features/master_import/data/master_import_repository.dart';
import 'package:wms_mobile/features/stock_import/data/stock_import_repository.dart';
import 'package:wms_mobile/features/master_import/domain/master_import.dart';
import 'package:wms_mobile/features/stock_import/domain/stock_ledger.dart';
import 'package:wms_mobile/features/stock_import/presentation/import_view_screen.dart';
import 'package:wms_mobile/features/stock_import/presentation/stock_file_import_screen.dart' show stockTemplateSaverProvider;

import '../../support/harness.dart';

// Synthetic JANs with a correct check digit.
const _jan1 = '4909999000014';
const _jan2 = '4909999000021';
const _jan3 = '4909999000038';

const _csv = 'JANコード,商品名,数量\n$_jan1,ﾃｽﾄﾍﾟﾝ ｱｵ,100\n$_jan2,ノート,3\nなし,メモ,1\n$_jan3,消しゴム,2\n$_jan1,テストペン,5\n';

/// An import as 0146 keeps it: the reading, the lines that went in, the
/// file.
final _importJson = <String, dynamic>{
  'id': 12,
  'status': 'stock_done',
  'source': 'stock_file',
  'warehouse_name': '本社倉庫',
  'original_name': '在庫.csv',
  'original_path': 'imports/12/original-a.csv',
  'read_by': 'ai',
  'read_lines': [
    {'line_no': 2, 'jan': _jan1, 'name': 'ﾃｽﾄﾍﾟﾝ ｱｵ', 'quantity': '100', 'flags': ['ai_disagree']},
    {'line_no': 3, 'jan': _jan2, 'name': 'ノート', 'quantity': '3'},
    {'line_no': 4, 'jan': 'なし', 'name': 'メモ', 'quantity': '1'},
    {'line_no': 5, 'jan': _jan3, 'name': '消しゴム', 'quantity': '2'},
    {'line_no': 6, 'jan': _jan1, 'name': 'テストペン', 'quantity': '5', 'ai_jan': _jan1, 'ai_quantity': '50', 'flags': ['human_corrected']},
  ],
  'issues': [
    {'code': 'unknown_jan', 'lines': [{'line_no': 5, 'jan_code': _jan3}]},
  ],
  'lines': [
    // The doubtful 100 was corrected to 10 (+5 from row 6) before it went in.
    {'line_no': 2, 'jan_code': _jan1, 'name': 'テストペン 青', 'quantity': 15, 'on_hand_before': 40, 'added': 15, 'on_hand_after': 55},
  ],
};
final _import = MasterImport.fromJson(_importJson);

class _Undo implements StockImportRepository {
  final undone = <int>[];

  @override
  Future<ApiResult<int>> undo(int importId) async {
    undone.add(importId);
    return const ApiSuccess(1);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The stock side of the viewer: what the notes were changed to.
class _Notes implements StockImportRepository {
  final notes = <(int, DocumentDate?, bool?, String?)>[];

  @override
  Future<ApiResult<bool>> updateNotes(int importId, {DocumentDate? date, bool? paid, String? note}) async {
    notes.add((importId, date, paid, note));
    return const ApiSuccess(true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repo extends FakeMasterImportRepository {
  _Repo([MasterImport? import]) : _one = import ?? _import;
  final MasterImport _one;

  @override
  Future<ApiResult<MasterImport>> detail(int importId, {int? warehouseId}) async => ApiSuccess(_one);

  @override
  Future<ApiResult<Uint8List>> download(String path) async => ApiSuccess(Uint8List.fromList(utf8.encode(_csv)));
}

void main() {
  test('each row as read, beside what became of it', () {
    final o = readOutcomes(_import);
    expect(o.map((x) => x.fate), [
      ReadFate.inStock,
      ReadFate.removed,
      ReadFate.noJan,
      ReadFate.notInLibrary,
      ReadFate.merged,
    ]);
    // The file gave 105 for the pen; 15 went in.
    expect(o.first.fileQuantity, 105);
    // Row 6 was corrected on the 確認用Excel (50 → 5) — not a doubt of the AI's.
    expect(o.last.row.corrected, isTrue);
    expect(o.last.doubtful, isFalse);
    expect(o.first.doubtful, isTrue);
  });

  testWidgets('the original and the reading side by side, row by row', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester, const ImportViewScreen(importId: 12), overrides: [
      masterImportRepositoryProvider.overrideWithValue(_Repo()),
    ]);

    // The original's cells, with their row numbers.
    expect(find.byKey(const ValueKey('iv-sheet')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('iv-sheet')), matching: find.text('ﾃｽﾄﾍﾟﾝ ｱｵ')), findsOneWidget);
    // The reading.
    expect(find.text('AIで読み取り · 本社倉庫'), findsOneWidget);
    expect(find.text('5行'), findsOneWidget);
    expect(find.text('反映 1'), findsOneWidget);
    expect(find.text('入れていない 3'), findsOneWidget);
    expect(find.text('要確認 1'), findsOneWidget);
    expect(find.text('ファイル: JAN $_jan1 ・「ﾃｽﾄﾍﾟﾝ ｱｵ」・ 数量 100'), findsOneWidget);
    expect(find.byKey(const ValueKey('iv-edited-2')), findsOneWidget);
    expect(find.text('→ テストペン 青: 在庫 40 → 55（+15）'), findsOneWidget);
    expect(find.text('→ 入れていません: 商品ライブラリーにない商品'), findsOneWidget);
    expect(find.text('→ 入れていません: JANコードが読めません'), findsOneWidget);
    expect(find.text('→ 入れていません: 反映前に外しました'), findsOneWidget);
    expect(find.text('→ 同じJANの上の行と合計して反映'), findsOneWidget);
    expect(find.text('確認用Excelで直した: JAN $_jan1 → $_jan1 ・ 数量 50 → 5'), findsOneWidget);

    // Looked back at as a table, beside the original, nothing to change.
    await tester.tap(find.byKey(const ValueKey('iv-table-12')));
    await tester.pumpAndSettle();
    expect(find.text('読み取り結果（表）'), findsOneWidget);
    expect(find.byKey(const ValueKey('rc-table')), findsOneWidget);
    expect(find.byKey(const ValueKey('rc-ok')), findsNothing);
    expect(find.byKey(const ValueKey('iv-sheet')), findsOneWidget);
  });

  testWidgets('読み取り結果を見る opens the same table as when it was checked, with what became of each row (0165)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester, const Scaffold(body: ImportViewButtons(importId: 12)), overrides: [
      masterImportRepositoryProvider.overrideWithValue(_Repo()),
    ]);
    await tester.tap(find.byKey(const ValueKey('iv-open-12')));
    await tester.pumpAndSettle();
    expect(find.text('読み取り結果（表）'), findsOneWidget);
    expect(find.byKey(const ValueKey('rc-table')), findsOneWidget);
    expect(find.byKey(const ValueKey('rc-ok')), findsNothing);
    expect(find.text('反映'), findsWidgets);
    expect(tester.widget<Text>(find.byKey(const ValueKey('rc-2-result'))).data, '→ テストペン 青: 在庫 40 → 55（+15）');
    // The import's details (memo, undo) from there.
    await tester.tap(find.byKey(const ValueKey('iv-details-12')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('iv-read')), findsOneWidget);
  });

  testWidgets('a stock file can be taken back, after asking', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final stock = _Undo();
    await pumpApp(tester, const ImportViewScreen(importId: 12), overrides: [
      masterImportRepositoryProvider.overrideWithValue(_Repo()),
      stockImportRepositoryProvider.overrideWithValue(stock),
      authControllerProvider.overrideWith((ref) =>
          fakeAuthControllerFor(const AuthUser(id: 'u1', email: 'a@b.test', name: '倉庫', permissions: ['inventory.adjust']))),
    ]);
    await tester.tap(find.byKey(const ValueKey('iv-undo')));
    await tester.pumpAndSettle();
    expect(find.text('取込 #12 を取り消しますか？'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('iv-undo-ok')));
    await tester.pumpAndSettle();
    expect(stock.undone, [12]);
    expect(find.text('取込 #12 を取り消しました'), findsOneWidget);
  });

  testWidgets('on a narrow screen the two are tabs', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester, const ImportViewScreen(importId: 12), overrides: [
      masterImportRepositoryProvider.overrideWithValue(_Repo()),
    ]);
    expect(find.byKey(const ValueKey('iv-tab-original')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('iv-tab-read')));
    await tester.pumpAndSettle();
    expect(find.text('反映 1'), findsOneWidget);
  });

  testWidgets('waiting for inspection: said so row by row; date, payment and memo kept; the reading as Excel', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final waiting = MasterImport.fromJson({
      ..._importJson,
      'status': 'awaiting_inspection',
      'document_date': '2026-08-19',
      'document_date_source': 'content',
      'paid': false,
      'lines': [
        {'line_no': 2, 'jan_code': _jan1, 'name': 'テストペン 青', 'quantity': 15},
      ],
    });
    final stock = _Notes();
    final saved = <(String, Uint8List)>[];
    await pumpApp(tester, const ImportViewScreen(importId: 12), overrides: [
      masterImportRepositoryProvider.overrideWithValue(_Repo(waiting)),
      stockImportRepositoryProvider.overrideWithValue(stock),
      stockTemplateSaverProvider.overrideWithValue((n, b) async => saved.add((n, b))),
      authControllerProvider.overrideWith((ref) =>
          fakeAuthControllerFor(const AuthUser(id: 'u1', email: 'a@b.test', name: '倉庫', permissions: ['inventory.adjust']))),
    ]);
    expect(find.byKey(const ValueKey('iv-awaiting')), findsOneWidget);
    expect(find.text('→ テストペン 青: 検品待ち（ファイル 15個）'), findsOneWidget);
    expect(find.text('検品待ち 1'), findsOneWidget);
    expect(find.text('書類の日付: 2026/08/19（ファイルに書かれた日付）'), findsOneWidget);
    expect(find.text('2033/08/18まで保存（7年）'), findsOneWidget);
    // Taking back a waiting file is allowed: nothing of it is in stock yet.
    expect(find.byKey(const ValueKey('iv-undo')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('iv-paid')));
    await tester.pumpAndSettle();
    expect(stock.notes.last, (12, null, true, null));
    await tester.enterText(find.byKey(const ValueKey('iv-note')), '8/21 振込済み');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('iv-note-save')));
    await tester.pumpAndSettle();
    expect(stock.notes.last, (12, null, null, '8/21 振込済み'));

    // The reading as an Excel workbook: every row, what became of it.
    await tester.tap(find.byKey(const ValueKey('iv-xlsx-12')));
    await tester.pumpAndSettle();
    final (name, bytes) = saved.single;
    expect(name, '読み取り結果_12_在庫.xlsx');
    final rows = readXlsx(bytes);
    expect(rows.any((r) => r.length > 1 && r[0] == '書類の日付' && r[1].startsWith('2026/08/19')), isTrue);
    final header = rows.indexWhere((r) => r.isNotEmpty && r[0] == '行');
    // A purchase ledger's (明細) columns first, in its order (0150).
    expect(rows[header].take(16), [
      '行', '発注日', '入荷日', '番号', '仕入先', 'メーカー', '品番', 'JANコード', '商品名', '数量', '単位',
      '定価（税抜）', '単価（税抜）', '単価（税込）', '金額', '注番',
    ]);
    expect(rows.length - header - 1, 5);
    expect(rows[header + 1][7], _jan1);
    expect(rows[header + 1][18], '→ テストペン 青: 検品待ち（ファイル 15個）');
    expect(rows[header + 1][23], '検品待ち');
  });
}
