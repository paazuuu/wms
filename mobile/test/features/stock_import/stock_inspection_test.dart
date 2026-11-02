import 'dart:typed_data';

// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/delivery_note/delivery_note.dart';
import 'package:wms_mobile/features/home/domain/feature_catalog.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/auth/application/auth_controller.dart';
import 'package:wms_mobile/features/auth/domain/auth_user.dart';
import 'package:wms_mobile/features/evidence/domain/import_document.dart';
import 'package:wms_mobile/features/master_import/data/master_import_repository.dart';
import 'package:wms_mobile/features/master_import/domain/master_import.dart';
import 'package:wms_mobile/features/stock_import/data/stock_import_repository.dart';
import 'package:wms_mobile/features/stock_import/domain/stock_ledger.dart';
import 'package:wms_mobile/features/stock_import/presentation/inspection_calendar_screen.dart';
import 'package:wms_mobile/features/stock_import/presentation/stock_import_calendar_screen.dart';
import 'package:wms_mobile/features/qc/presentation/inspection_list_screen.dart';
import 'package:wms_mobile/features/stock_import/presentation/stock_inspection_screen.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';

import 'package:wms_mobile/features/product/application/product_providers.dart';
import 'package:wms_mobile/features/product/domain/product.dart';
import 'package:wms_mobile/features/product_library/application/product_library_providers.dart';
import 'package:wms_mobile/features/shelf_notes/data/shelf_notes_repository.dart';

import '../../support/fake_marks_and_notes.dart';
import '../../support/harness.dart';

const _jan1 = '4909999000014';
const _jan2 = '4909999000021';

MasterImport _awaiting({bool firstDone = false, String doneAt = '2026-10-23T02:00:00Z', String? secondDoneAt}) =>
    MasterImport.fromJson({
      'id': 21,
      'status': 'awaiting_inspection',
      'source': 'stock_file',
      'original_name': '請求書.pdf',
      'original_path': 'imports/21/original-a.pdf',
      'warehouse_name': '本社倉庫',
      'lines': [
        {
          'line_no': 2, 'jan_code': _jan1, 'name': 'テストペン 青', 'quantity': 500,
          if (firstDone) ...{'inspected_at': doneAt, 'inspected_quantity': 498, 'inspected_by_name': '検品担当', 'added': 498},
        },
        {
          'line_no': 3, 'jan_code': _jan2, 'name': 'テストノート', 'quantity': 100,
          if (secondDoneAt != null) ...{'inspected_at': secondDoneAt, 'inspected_quantity': 100, 'inspected_by_name': '検品担当', 'added': 100},
        },
      ],
    });

class _Reader implements MasterImportRepository {
  _Reader(this.import, {this.note});
  MasterImport import;

  /// A delivery note as the AI reads it (0178).
  MasterRead? note;
  String? notePurpose;

  @override
  Future<ApiResult<MasterRead>> read(String fileName, Uint8List bytes,
      {bool keepRows = false, String purpose = 'library'}) async {
    notePurpose = purpose;
    return ApiSuccess(note ?? const MasterRead(lines: []));
  }

  @override
  Future<ApiResult<MasterImport>> detail(int importId, {int? warehouseId}) async => ApiSuccess(import);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Stock implements StockImportRepository {
  _Stock({this.waiting = const [], this.month = const []});
  final List<AwaitingImport> waiting;
  final List<CalendarImport> month;
  final inspected = <(int, List<InspectedLine>)>[];
  final asked = <(DateTime, DateTime)>[];
  _Reader? reader;

  /// 0179: lines taken back, notes kept, and the inspection days.
  final uninspected = <(int, int)>[];
  final linked = <(int, int)>[];
  List<ImportDocument> docs = const [];
  List<InspectionDay> days = const [];
  String? uninspectError;

  @override
  Future<ApiResult<bool>> uninspect(int importId, int lineNo) async {
    if (uninspectError case final e?) return ApiFailure(message: e);
    uninspected.add((importId, lineNo));
    reader?.import = _awaiting();
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<bool>> linkInspectionDocument(int importId, int documentId) async {
    linked.add((importId, documentId));
    docs = [
      ImportDocument(
        id: documentId, purpose: EvidencePurpose.ocr, fileName: '納品書_検品済み.pdf', storagePath: 'ocr/x.pdf',
        uploadedAt: DateTime(2026, 10, 23, 11, 5), contentType: 'application/pdf', uploadedByName: '検品担当',
      ),
    ];
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<List<ImportDocument>>> inspectionDocuments(int importId) async => ApiSuccess(docs);

  @override
  Future<ApiResult<List<InspectionDay>>> inspectionCalendar(DateTime from, DateTime to) async {
    asked.add((from, to));
    return ApiSuccess(days);
  }

  @override
  Future<ApiResult<List<AwaitingImport>>> awaiting({int? warehouseId}) async => ApiSuccess(waiting);

  @override
  Future<ApiResult<InspectionResult>> inspect(int importId, List<InspectedLine> lines) async {
    inspected.add((importId, lines));
    reader?.import = _awaiting(firstDone: true);
    return const ApiSuccess(InspectionResult(lines: 1, change: 498, difference: -2, left: 1));
  }

  @override
  Future<ApiResult<PendingInspection>> pendingInspection({int? warehouseId}) async => const ApiSuccess(PendingInspection());

  @override
  Future<ApiResult<List<CalendarImport>>> calendar(DateTime from, DateTime to) async {
    asked.add((from, to));
    return ApiSuccess(month);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Override _signedIn(List<String> p) => authControllerProvider
    .overrideWith((ref) => fakeAuthControllerFor(AuthUser(id: 'u1', email: 'a@b.test', name: '検品担当', permissions: p)));

void main() {
  testWidgets('files waiting for inspection are listed with what is left of each', (tester) async {
    final stock = _Stock(waiting: [
      AwaitingImport.fromJson({
        'id': 21, 'original_name': '請求書.pdf', 'warehouse_name': '本社倉庫', 'lines': 9, 'left': 9, 'quantity_left': 4100,
        'created_at': '2026-10-23T02:00:00Z', 'created_by_name': 'ganki',
      }),
    ]);
    await pumpApp(tester, const StockInspectionScreen(), overrides: [
      _signedIn(['inspection.confirm']),
      stockImportRepositoryProvider.overrideWithValue(stock),
    ]);
    expect(find.text('取込 #21 · 請求書.pdf'), findsOneWidget);
    expect(find.textContaining('未検品 9/9行・4100個'), findsOneWidget);
  });

  testWidgets('an inspector ticks a line, enters what was counted, and checks it in', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reader = _Reader(_awaiting());
    final stock = _Stock()..reader = reader;
    await pumpApp(tester, const StockInspectionScreen(openImportId: 21), overrides: [
      _signedIn(['inspection.confirm']),
      stockImportRepositoryProvider.overrideWithValue(stock),
      masterImportRepositoryProvider.overrideWithValue(reader),
      // A scan only ticks here (the switch off), to count first.
      scanChecksInProvider.overrideWith((ref) => false),
    ]);
    expect(find.text('未検品 2行（全2行）'), findsOneWidget);
    // Nothing chosen, nothing to check in.
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('si-check-in'))).onPressed, isNull);

    // A scanned JAN ticks its line; the count found differs from the file.
    await tester.enterText(find.byKey(const ValueKey('si-scan')), _jan1);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byKey(const ValueKey('si-tick-2'))).value, isTrue);
    await tester.enterText(find.byKey(const ValueKey('si-count-2')), '498');
    await tester.pumpAndSettle();
    expect(find.textContaining('差 -2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('si-check-in')));
    await tester.pumpAndSettle();
    expect(find.text('1行・498個を在庫に入れます。ファイルとの差は -2個です。'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('si-confirm')));
    await tester.pumpAndSettle();

    final (id, lines) = stock.inspected.single;
    expect(id, 21);
    expect([for (final l in lines) (l.lineNo, l.quantity)], [(2, 498)]);
    // The line is checked in, by whom and how many; the other still waits.
    expect(find.byKey(const ValueKey('si-done-2')), findsOneWidget);
    expect(find.textContaining('検品済み 498個（検品担当）'), findsOneWidget);
    expect(find.text('未検品 1行（全2行）'), findsOneWidget);
  });

  testWidgets('a scanned JAN is checked in at once with its count; the camera does the same, line after line (0177)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reader = _Reader(_awaiting());
    final stock = _Stock()..reader = reader;
    final asked = <String?>[];
    await pumpApp(tester, const StockInspectionScreen(openImportId: 21), overrides: [
      _signedIn(['inspection.confirm']),
      stockImportRepositoryProvider.overrideWithValue(stock),
      masterImportRepositoryProvider.overrideWithValue(reader),
      inspectionCameraProvider.overrideWithValue((context, {required validate, required onScan, required title}) async {
        // The camera reads the second line's JAN, then an unknown one.
        for (final code in [_jan2, '4909999000038']) {
          final reason = validate(code);
          asked.add(reason);
          if (reason == null) onScan(code);
        }
      }),
    ]);
    // On by default.
    expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('si-scan-checkin'))).value, isTrue);

    // Typed or from a hand scanner: in at once, no confirmation, the file's count.
    await tester.enterText(find.byKey(const ValueKey('si-scan')), _jan1);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect([for (final l in stock.inspected.single.$2) (l.lineNo, l.quantity)], [(2, 500)]);
    expect(find.byKey(const ValueKey('si-scanned-in')), findsOneWidget);
    expect(find.byKey(const ValueKey('si-done-2')), findsOneWidget);

    // The camera: the next line in, the stranger said so.
    await tester.tap(find.byKey(const ValueKey('si-camera')));
    await tester.pumpAndSettle();
    expect(asked, [null, '4909999000038 はこのファイルの未検品の行にありません']);
    expect(stock.inspected.length, 2);
    expect(stock.inspected.last.$2.single.lineNo, 3);
  });

  testWidgets('the checked note read back ticks its lines with its counts; one not sent is unticked, then checked in (0178)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reader = _Reader(_awaiting(), note: const MasterRead(documentId: 55, lines: [
      MasterLine(lineNo: 1, janCode: _jan1, supplierName: 'ﾃｽﾄﾍﾟﾝ', quantity: '480'),
      MasterLine(lineNo: 2, janCode: _jan2, supplierName: 'ﾉｰﾄ', quantity: '100'),
      MasterLine(lineNo: 3, janCode: '4909999000038', supplierName: '別の品', quantity: '5'),
    ]));
    final stock = _Stock()..reader = reader;
    await pumpApp(tester, const StockInspectionScreen(openImportId: 21), overrides: [
      _signedIn(['inspection.confirm']),
      stockImportRepositoryProvider.overrideWithValue(stock),
      masterImportRepositoryProvider.overrideWithValue(reader),
      deliveryNotePickerProvider.overrideWithValue(({required camera}) async =>
          (name: '納品書_検品済み.pdf', bytes: Uint8List.fromList([1]))),
    ]);
    await tester.tap(find.byKey(const ValueKey('si-note')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dn-pick-file')));
    await tester.pumpAndSettle();
    expect(reader.notePurpose, 'ocr');
    // The note kept with this inspection, to look back at (0179).
    expect(stock.linked, [(21, 55)]);
    expect(find.text('検品時のファイル（1件）'), findsOneWidget);
    expect(find.byKey(const ValueKey('si-file-open-55')), findsOneWidget);
    expect(find.byKey(const ValueKey('si-file-dl-55')), findsOneWidget);
    // Every JAN on the note ticked, with the note's count; a stranger said so.
    expect(tester.widget<Checkbox>(find.byKey(const ValueKey('si-tick-2'))).value, isTrue);
    expect(tester.widget<Checkbox>(find.byKey(const ValueKey('si-tick-3'))).value, isTrue);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('si-count-2'))).controller!.text, '480');
    expect(find.text('納品書_検品済み.pdf から 2行にチェックを入れました'), findsOneWidget);
    expect(find.byKey(const ValueKey('si-note-stranger-3')), findsOneWidget);
    // The notebook did not come (未発送): unticked by hand.
    await tester.tap(find.byKey(const ValueKey('si-tick-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('si-check-in')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('si-confirm')));
    await tester.pumpAndSettle();
    expect([for (final l in stock.inspected.single.$2) (l.lineNo, l.quantity)], [(2, 480)]);
  });

  testWidgets('a line checked in by mistake is taken back by one who inspects (0179)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reader = _Reader(_awaiting(firstDone: true));
    final stock = _Stock()..reader = reader;
    await pumpApp(tester, const StockInspectionScreen(openImportId: 21), overrides: [
      // An ordinary stock role, not a manager.
      _signedIn(['inventory.adjust']),
      stockImportRepositoryProvider.overrideWithValue(stock),
      masterImportRepositoryProvider.overrideWithValue(reader),
    ]);
    expect(find.byKey(const ValueKey('si-done-2')), findsOneWidget);
    // Behind ⋯, never pressed by mistake.
    await tester.tap(find.byKey(const ValueKey('si-more-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('si-undo-2')));
    await tester.pumpAndSettle();
    expect(find.textContaining('入庫した 498個 を在庫から戻し'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('si-undo-confirm')));
    await tester.pumpAndSettle();
    expect(stock.uninspected, [(21, 2)]);
    // Waiting again, to be checked in once more.
    expect(find.byKey(const ValueKey('si-line-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('si-more-2')), findsNothing);
  });

  testWidgets('taking back what already went out is refused in words (0179)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reader = _Reader(_awaiting(firstDone: true));
    final stock = _Stock()
      ..reader = reader
      ..uninspectError = 'uninspect_below_zero: 4909999000014 now 10, the line added 498';
    await pumpApp(tester, const StockInspectionScreen(openImportId: 21), overrides: [
      _signedIn(['inspection.confirm']),
      stockImportRepositoryProvider.overrideWithValue(stock),
      masterImportRepositoryProvider.overrideWithValue(reader),
    ]);
    // Behind ⋯, never pressed by mistake.
    await tester.tap(find.byKey(const ValueKey('si-more-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('si-undo-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('si-undo-confirm')));
    await tester.pumpAndSettle();
    expect(find.textContaining('在庫がマイナスになります'), findsOneWidget);
    expect(find.byKey(const ValueKey('si-done-2')), findsOneWidget);
  });

  testWidgets('without the right to inspect, a checked line cannot be taken back', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reader = _Reader(_awaiting(firstDone: true));
    await pumpApp(tester, const StockInspectionScreen(openImportId: 21), overrides: [
      _signedIn(['inventory.view']),
      stockImportRepositoryProvider.overrideWithValue(_Stock()..reader = reader),
      masterImportRepositoryProvider.overrideWithValue(reader),
    ]);
    expect(find.byKey(const ValueKey('si-done-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('si-more-2')), findsNothing);
  });

  testWidgets('検品履歴カレンダー: the days lines were checked in, stamped, and the inspection opened from a day (0179)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, 1);
    // Checked in over two days: line 2 on the 1st, line 3 on the 2nd (Japan time).
    String jst(int d, int h) => DateTime.utc(day.year, day.month, d, h - 9).toIso8601String();
    final reader = _Reader(_awaiting(firstDone: true, doneAt: jst(1, 10), secondDoneAt: jst(2, 15)));
    final stock = _Stock()
      ..reader = reader
      ..days = [
        InspectionDay.fromJson({
          'import_id': 21, 'day': '${day.year}-${day.month.toString().padLeft(2, '0')}-01', 'lines': 1, 'units': 498,
          'first_at': DateTime(day.year, day.month, 1, 10, 5).toUtc().toIso8601String(),
          'last_at': DateTime(day.year, day.month, 1, 10, 40).toUtc().toIso8601String(),
          'by': '検品担当', 'original_name': '請求書.pdf', 'warehouse_name': '本社倉庫', 'status': 'awaiting_inspection',
          'line_count': 2, 'documents': 1,
        }),
      ];
    await pumpApp(tester, const InspectionCalendarScreen(), overrides: [
      _signedIn(['inspection.confirm']),
      stockImportRepositoryProvider.overrideWithValue(stock),
      masterImportRepositoryProvider.overrideWithValue(reader),
    ]);
    // This month asked for, whole.
    expect(stock.asked.single, (DateTime(now.year, now.month), DateTime(now.year, now.month + 1, 0)));
    expect(tester.widget<Text>(find.byKey(const ValueKey('ic-count-1'))).data, '1行');
    final dd = '${day.year}/${day.month.toString().padLeft(2, '0')}/01';
    expect(tester.widget<Text>(find.byKey(const ValueKey('ic-when-21'))).data, '検品日時 $dd 10:05〜10:40');
    expect(tester.widget<Text>(find.byKey(const ValueKey('ic-what-21'))).data, 'この日に 1行・498個を検品（全2行中） · 検品担当 · 本社倉庫');
    expect(find.byKey(const ValueKey('ic-notes-21')), findsOneWidget);
    // A day chosen: only its inspections.
    await tester.tap(find.byKey(const ValueKey('ic-day-1')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('ic-list-title'))).data, '$dd の検品 1件');
    await tester.tap(find.textContaining('取込 #21'));
    await tester.pumpAndSettle();
    // Only what was checked in that day — not the next day's line.
    expect(tester.widget<Text>(find.byKey(const ValueKey('si-day-text'))).data, '$dd に検品した行だけを表示しています（1行・498個）');
    expect(find.byKey(const ValueKey('si-done-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('si-done-3')), findsNothing);
    expect(find.byKey(const ValueKey('si-check-in')), findsNothing);
    // Every line again, on asking.
    await tester.tap(find.byKey(const ValueKey('si-day-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('si-day')), findsNothing);
    expect(find.byKey(const ValueKey('si-done-3')), findsOneWidget);
  });

  test('the inspection calendar is in the menu for those who inspect, and for stock and product viewers', () {
    final e = buildFeatureCatalog().expand((g) => g.entries).firstWhere((e) => e.id == 'inspection_calendar');
    expect(e.visibleFor(['inventory.adjust']), isTrue);
    expect(e.visibleFor(['inspection.confirm']), isTrue);
    expect(e.visibleFor(['product.view']), isTrue);
    expect(e.visibleFor(['shipment.view']), isFalse);
  });

  // 0167: each line with what its product tells of it, and narrowing.
  const pen = Product(
    id: 7, janCode: _jan1, name: 'テストペン タイプA 0.5 青', baseName: 'テストペン タイプA 0.5 青', maker: 'テスト文具',
    sku: 'TP-05L', unitWeightG: 9.5, marks: {'warning'}, markNote: '黒と間違えやすい',
    attributes: [ProductPart(key: 'color', name: '色', value: '青')],
  );
  const note = Product(id: 8, janCode: _jan2, name: 'TN-1', sku: 'TN-1', maker: '別メーカー');

  testWidgets('a line shows its picture, 商品名, maker, 品番, attributes, weight, warning and shelf note; narrowed by words (0167)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final products = FakeProductRepository(products: const [pen, note]);
    await pumpApp(tester, const StockInspectionScreen(openImportId: 21), overrides: [
      _signedIn(['inspection.confirm', 'product.manage', 'putaway.confirm']),
      stockImportRepositoryProvider.overrideWithValue(_Stock()),
      masterImportRepositoryProvider.overrideWithValue(_Reader(_awaiting())),
      productRepositoryProvider.overrideWithValue(products),
      productLibraryCanManageProvider.overrideWithValue(true),
      shelfNotesRepositoryProvider.overrideWithValue(
          FakeShelfNotesRepository([const ShelfNote(id: 1, productId: 7, location: 'A棚 上段', body: '・青だけ奥')])),
    ]);
    // On a phone: a card with every field.
    expect(tester.widget<Text>(find.byKey(const ValueKey('si-name-2'))).data, 'テストペン タイプA 0.5 青');
    expect(find.text('テスト文具 · TP-05L'), findsOneWidget);
    expect(find.text('色: 青'), findsOneWidget);
    expect(find.text('重量: 9.5 g'), findsOneWidget);
    expect(find.text('⚠ 黒と間違えやすい'), findsOneWidget);
    expect(find.text('📍A棚 上段 ・青だけ奥'), findsOneWidget);
    // Only its 品番 for a name: 未登録, not the 品番 again.
    expect(tester.widget<Text>(find.byKey(const ValueKey('si-name-3'))).data, 'テストノート'); // the file's, not TN-1

    // Narrowed by a word, then by ⚠.
    await tester.enterText(find.byKey(const ValueKey('si-filter')), 'TN-1');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('si-line-2')), findsNothing);
    expect(find.byKey(const ValueKey('si-line-3')), findsOneWidget);
    expect(find.text('1 / 2行を表示'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('si-filter')), '');
    await tester.tap(find.byKey(const ValueKey('si-mark-warning')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('si-line-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('si-line-3')), findsNothing);
    // 表示中の1件をすべて選ぶ ticks only what is shown.
    await tester.tap(find.byKey(const ValueKey('si-all')));
    await tester.pumpAndSettle();
    expect(find.text('選んだ1行を検品完了にする'), findsOneWidget);

    // The weight, put in as the goods are in hand.
    await tester.tap(find.byKey(const ValueKey('si-weigh-2')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('si-weight-field')), '10.2');
    await tester.tap(find.byKey(const ValueKey('si-weight-save')));
    await tester.pumpAndSettle();
    expect(products.setWeights.single.productId, 7);
    expect(products.setWeights.single.unitWeightG, 10.2);
    expect(products.setWeights.single.source, 'measured');
  });

  testWidgets('on a PC every line is one row under a heading (0167)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester, const StockInspectionScreen(openImportId: 21), overrides: [
      _signedIn(['inspection.confirm']),
      stockImportRepositoryProvider.overrideWithValue(_Stock()),
      masterImportRepositoryProvider.overrideWithValue(_Reader(_awaiting())),
      productRepositoryProvider.overrideWithValue(FakeProductRepository(products: const [pen, note])),
    ]);
    expect(find.byKey(const ValueKey('si-heading')), findsOneWidget);
    final y = tester.getCenter(find.byKey(const ValueKey('si-name-2'))).dy;
    expect(tester.getCenter(find.byKey(const ValueKey('si-weight-2'))).dy, closeTo(y, 12));
    expect(tester.getCenter(find.byKey(const ValueKey('si-count-2'))).dy, closeTo(y, 12));
  });

  testWidgets('a JAN not among the lines is said so', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester, const StockInspectionScreen(openImportId: 21), overrides: [
      _signedIn(['inspection.confirm']),
      stockImportRepositoryProvider.overrideWithValue(_Stock()),
      masterImportRepositoryProvider.overrideWithValue(_Reader(_awaiting())),
    ]);
    await tester.enterText(find.byKey(const ValueKey('si-scan')), '4909999000038');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('4909999000038 はこのファイルの未検品の行にありません'), findsOneWidget);
  });

  testWidgets('without the permission nothing can be checked in', (tester) async {
    await pumpApp(tester, const StockInspectionScreen(openImportId: 21), overrides: [
      _signedIn(['inventory.view']),
      stockImportRepositoryProvider.overrideWithValue(_Stock()),
      masterImportRepositoryProvider.overrideWithValue(_Reader(_awaiting())),
    ]);
    expect(find.byKey(const ValueKey('si-check-in')), findsNothing);
    expect(find.textContaining('権限が要ります'), findsOneWidget);
  });

  testWidgets('the calendar shows a month’s files on their days, paid or not, and a day opens its files', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final stock = _Stock(month: [
      CalendarImport.fromJson({
        'id': 13, 'day': '2026-08-19', 'document_date_source': 'content', 'original_name': '請求書.pdf',
        'warehouse_name': 'メイン倉庫', 'status': 'stock_done', 'stock_lines': 9, 'stock_added': 4100, 'paid': true,
        'note': '8/21 振込', 'proof_count': 1,
      }),
      CalendarImport.fromJson({
        'id': 14, 'day': '2026-08-19', 'original_name': '納品書.pdf', 'status': 'awaiting_inspection', 'line_count': 2,
      }),
      CalendarImport.fromJson({'id': 15, 'day': '2026-08-03', 'original_name': '在庫.csv', 'status': 'stock_done'}),
    ]);
    await pumpApp(tester, StockImportCalendarScreen(initialMonth: DateTime(2026, 8)), overrides: [
      _signedIn(['inventory.adjust']),
      stockImportRepositoryProvider.overrideWithValue(stock),
    ]);
    expect(stock.asked.single, (DateTime(2026, 8), DateTime(2026, 8, 31)));
    expect(find.text('8月'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('cal-count-19'))).data, '2件');
    expect(find.text('この月の取込 3件'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cal-day-19')));
    await tester.pumpAndSettle();
    expect(find.text('2026/08/19 の取込 2件'), findsOneWidget);
    expect(find.byKey(const ValueKey('cal-item-15')), findsNothing);
    expect(find.descendant(of: find.byKey(const ValueKey('cal-paid-13')), matching: find.text('振込済')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('cal-paid-14')), matching: find.text('未払い')), findsOneWidget);
    // And whether the transfer's proof is kept, and the stock inspected (0173).
    expect(find.descendant(of: find.byKey(const ValueKey('cal-proof-13')), matching: find.text('送金記録あり')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('cal-proof-14')), matching: find.text('送金記録なし')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('cal-stock-13')), matching: find.text('検品済（入庫済）')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('cal-stock-14')), matching: find.text('検品待ち')), findsOneWidget);
    expect(find.textContaining('検品待ち'), findsWidgets);
    expect(find.text('8/21 振込'), findsOneWidget);

    // A day with none says so.
    await tester.tap(find.byKey(const ValueKey('cal-day-20')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cal-none')), findsOneWidget);
  });

  testWidgets('a file is on the day it was taken in, as well as on its document date (0165)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Map<String, dynamic> row(String day, String kind) => {
          'id': 18, 'day': day, 'day_kind': kind, 'document_date': '2026-09-01',
          'created_at': '2026-10-29T13:13:00', 'original_name': '請求書.pdf', 'status': 'stock_done',
        };
    final stock = _Stock(month: [CalendarImport.fromJson(row('2026-10-29', 'imported'))]);
    await pumpApp(tester, StockImportCalendarScreen(initialMonth: DateTime(2026, 10)), overrides: [
      _signedIn(['inventory.adjust']),
      stockImportRepositoryProvider.overrideWithValue(stock),
    ]);
    expect(tester.widget<Text>(find.byKey(const ValueKey('cal-count-29'))).data, '1件');
    await tester.tap(find.byKey(const ValueKey('cal-day-29')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('cal-dates-18'))).data, '取込 2026/10/29 13:13 · 書類の日付 2026/09/01');
    expect(CalendarImport.fromJson(row('2026-09-01', 'document')).dayKind, 'document');
  });

  testWidgets('a file registered for inspection is listed on 検品 too, for its warehouse', (tester) async {
    AwaitingImport waiting(int id, int wh) => AwaitingImport.fromJson({
          'id': id, 'original_name': '請求書$id.pdf', 'warehouse_id': wh, 'warehouse_name': '倉庫$wh', 'lines': 9, 'left': 9,
          'quantity_left': 4100,
        });
    final stock = _Stock(waiting: [waiting(21, 1), waiting(22, 2)]);
    await pumpApp(tester, const QcInspectionListScreen(), overrides: [
      _signedIn(['inspection.confirm']),
      stockImportRepositoryProvider.overrideWithValue(stock),
      activeWarehouseIdProvider.overrideWith((ref) => 1),
    ]);
    expect(find.text('ファイル取込の検品待ち 1件'), findsOneWidget);
    expect(find.byKey(const ValueKey('qc-file-21')), findsOneWidget);
    expect(find.byKey(const ValueKey('qc-file-22')), findsNothing);
    expect(find.textContaining('未検品 9/9行'), findsOneWidget);
  });

  testWidgets('one 検品: files waiting first, then what was checked; 受領 with its kinds apart (0174)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    AwaitingImport waiting(int id) => AwaitingImport.fromJson({
          'id': id, 'original_name': '請求書$id.pdf', 'warehouse_id': 1, 'lines': 9, 'left': 9, 'quantity_left': 4100,
        });
    final stock = _Stock(waiting: [waiting(21), waiting(22), waiting(23), waiting(24)]);
    await pumpApp(tester, const QcInspectionListScreen(), overrides: [
      _signedIn(['inspection.confirm', 'inventory.adjust']),
      stockImportRepositoryProvider.overrideWithValue(stock),
      masterImportsProvider.overrideWith((ref) async => [
            MasterImport.fromJson({
              'id': 18, 'status': 'stock_done', 'source': 'stock_file', 'warehouse_id': 1, 'original_name': '請求書18.pdf',
              'original_path': 'x',
            }),
            MasterImport.fromJson({'id': 21, 'status': 'awaiting_inspection', 'source': 'stock_file', 'warehouse_id': 1}),
          ]),
    ]);
    // Every file waiting, not only the first three.
    for (final id in [21, 22, 23, 24]) {
      expect(find.byKey(ValueKey('qc-file-$id')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('qc-file-waiting-all')), findsNothing);
    // Checked below.
    expect(find.text('検品済み 1件'), findsOneWidget);
    expect(find.byKey(const ValueKey('qc-file-done-18')), findsOneWidget);
    // The kinds are 受領's: not shown for all.
    expect(find.text('合格'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('qc-src-receipt')));
    await tester.pumpAndSettle();
    expect(find.text('合格'), findsOneWidget);
    expect(find.byKey(const ValueKey('qc-file-21')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('qc-src-file')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('qc-file-21')), findsOneWidget);
    // 取込の検品 is not a menu of its own any more.
    final entries = buildFeatureCatalog().expand((g) => g.entries);
    expect(entries.firstWhere((e) => e.id == 'stock_inspection').inMenu, isFalse);
    expect(entries.firstWhere((e) => e.id == 'inspection').requiredAnyOf, contains('inventory.adjust'));
  });

  testWidgets('the calendar is small enough to be seen whole, its files beside it on a wide screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final stock = _Stock(month: [
      CalendarImport.fromJson({'id': 13, 'day': '2026-08-19', 'original_name': '請求書.pdf', 'status': 'stock_done'}),
    ]);
    await pumpApp(tester, StockImportCalendarScreen(initialMonth: DateTime(2026, 8)), overrides: [
      _signedIn(['inventory.adjust']),
      stockImportRepositoryProvider.overrideWithValue(stock),
    ]);
    final cal = tester.getRect(find.byKey(const ValueKey('cal-calendar')));
    expect(cal.width, lessThanOrEqualTo(calendarMaxWidth));
    // August 2026 runs to the 31st on the sixth row: still on screen.
    expect(tester.getRect(find.byKey(const ValueKey('cal-day-31'))).bottom, lessThan(800));
    expect(tester.getRect(find.byKey(const ValueKey('cal-list-title'))).left, greaterThan(cal.right));

    // A phone: the list under the calendar.
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpAndSettle();
    final small = tester.getRect(find.byKey(const ValueKey('cal-calendar')));
    expect(tester.getRect(find.byKey(const ValueKey('cal-list-title'))).top, greaterThan(small.bottom));
  });
}
