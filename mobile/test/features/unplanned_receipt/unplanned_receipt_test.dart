import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/auth/application/auth_controller.dart';
import 'package:wms_mobile/features/auth/domain/auth_user.dart';
import 'package:wms_mobile/features/delivery_note/delivery_note.dart';
import 'package:wms_mobile/features/home/domain/feature_catalog.dart';
import 'package:wms_mobile/features/master_import/data/master_import_repository.dart';
import 'package:wms_mobile/features/master_import/domain/master_import.dart';
import 'package:wms_mobile/features/stock_import/data/stock_import_repository.dart';
import 'package:wms_mobile/features/stock_import/domain/stock_file.dart';
import 'package:wms_mobile/features/stock_import/domain/stock_ledger.dart';
import 'package:wms_mobile/features/stock_import/presentation/stock_inspection_screen.dart';
import 'package:wms_mobile/features/unplanned_receipt/unplanned_receipt_screen.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';
import 'package:wms_mobile/features/warehouse_context/domain/warehouse.dart';

import '../../support/harness.dart';

const _pen = '4909999000014';
const _note = '4909999000021';
const _stranger = '4909999000038';

MasterImport _staged({List<int> done = const [], List<int> closed = const []}) => MasterImport.fromJson({
      'id': 31, 'status': 'awaiting_inspection', 'source': 'stock_file', 'kind': 'unplanned',
      'original_name': '納品書_1102.jpg', 'supplier_name': 'テスト商事株式会社',
      'lines': [
        for (final (no, jan, qty) in [(1, _pen, 20), (2, _note, 10), (3, _stranger, 5)])
          {
            'line_no': no, 'jan_code': jan, 'name': 'テスト$no', 'quantity': qty,
            if (done.contains(no)) ...{'inspected_at': '2026-11-02T03:00:00Z', 'inspected_quantity': qty, 'added': qty},
            if (closed.contains(no))
              ...{'inspected_at': '2026-11-02T03:00:00Z', 'inspected_quantity': 0, 'added': 0, 'not_delivered': true},
          },
      ],
    });

class _Reader implements MasterImportRepository {
  _Reader(this.note);
  final MasterRead note;
  String? purpose;
  MasterImport import = _staged();

  @override
  Future<ApiResult<MasterRead>> read(String fileName, Uint8List bytes,
      {bool keepRows = false, String purpose = 'library'}) async {
    this.purpose = purpose;
    return ApiSuccess(note);
  }

  @override
  Future<ApiResult<MasterImport>> detail(int importId, {int? warehouseId}) async => ApiSuccess(import);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Stock implements StockImportRepository {
  _Stock(this.library, this.reader);
  final Map<String, String> library;
  final _Reader reader;
  final registered = <List<String>>[];
  final staged = <({int warehouseId, List<StockFileLine> lines, String? supplier, int? documentId, DateTime? date})>[];
  final inspected = <List<int>>[];
  final closed = <List<int>>[];
  final noted = <int>[];

  @override
  Future<ApiResult<Map<String, String>>> known(List<String> jans) async =>
      ApiSuccess({for (final j in jans) if (library[j] case final n?) j: n});

  @override
  Future<ApiResult<List<String>>> registerProducts(List<StockFileLine> lines) async {
    registered.add([for (final l in lines) l.janCode]);
    return ApiSuccess([for (final l in lines) l.janCode]);
  }

  @override
  Future<ApiResult<StockFileResult>> unplannedStage(int warehouseId, List<StockFileLine> lines,
      {String? fileName, String? fileType, String? supplier, int? documentId, DateTime? documentDate}) async {
    staged.add((warehouseId: warehouseId, lines: lines, supplier: supplier, documentId: documentId, date: documentDate));
    return ApiSuccess(StockFileResult.fromJson({'import_id': 31, 'lines': lines.length, 'change': 0}));
  }

  @override
  Future<ApiResult<bool>> note(int importId, List<ReadRow> read, {required bool byAi, int? documentId}) async {
    noted.add(importId);
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<bool>> keepFile(int importId, String fileName, Uint8List bytes, String contentType) async =>
      const ApiSuccess(true);

  @override
  Future<ApiResult<InspectionResult>> inspect(int importId, List<InspectedLine> lines) async {
    inspected.add([for (final l in lines) l.lineNo]);
    reader.import = _staged(done: [for (final l in lines) l.lineNo]);
    return ApiSuccess(InspectionResult(lines: lines.length, change: 0, difference: 0, left: 3 - lines.length));
  }

  @override
  Future<ApiResult<int>> closeLines(int importId, List<int> lineNos) async {
    closed.add(lineNos);
    reader.import = _staged(done: [for (final l in inspected.last) l], closed: lineNos);
    return ApiSuccess(lineNos.length);
  }

  @override
  Future<ApiResult<PendingInspection>> pendingInspection({int? warehouseId}) async => const ApiSuccess(PendingInspection());

  @override
  Future<ApiResult<List<AwaitingImport>>> awaiting({int? warehouseId}) async => const ApiSuccess([]);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Override _signedIn(List<String> p) => authControllerProvider
    .overrideWith((ref) => fakeAuthControllerFor(AuthUser(id: 'u1', email: 'a@b.test', name: '倉庫', permissions: p)));

Future<_Stock> _pump(WidgetTester tester, {List<String> perms = const ['inventory.adjust'], bool readNote = true}) async {
  await tester.binding.setSurfaceSize(const Size(1000, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final reader = _Reader(const MasterRead(
    documentId: 77,
    supplierName: 'テスト商事株式会社',
    docDate: '2026/11/02',
    lines: [
      MasterLine(lineNo: 1, janCode: _pen, supplierName: 'ﾃｽﾄﾍﾟﾝ ｱｵ', quantity: '20'),
      MasterLine(lineNo: 2, janCode: _note, supplierName: 'ﾉｰﾄ', quantity: '10'),
      MasterLine(lineNo: 3, janCode: _stranger, supplierName: '新しい消しゴム', quantity: '5', maker: 'テスト', productCode: 'KE-1'),
    ],
  ));
  final stock = _Stock({_pen: 'テストペン 青', _note: 'テストノート'}, reader);
  await pumpApp(tester, const UnplannedReceiptScreen(), overrides: [
    _signedIn(perms),
    stockImportRepositoryProvider.overrideWithValue(stock),
    masterImportRepositoryProvider.overrideWithValue(reader),
    deliveryNotePickerProvider.overrideWithValue(({required camera}) async =>
        (name: '納品書_1102.pdf', bytes: Uint8List.fromList([37, 80, 68, 70]))),
    warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(const WarehouseOverview(
      warehouses: [Warehouse(id: 1, code: 'WH-01', name: '本社倉庫')],
      totals: WarehouseTotals(),
    ))),
  ]);
  if (readNote) {
    expect(find.text('今: アップロード'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ur-note')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dn-pick-file')));
    await tester.pumpAndSettle();
    expect(reader.purpose, 'ocr');
    // First what the AI read, beside the note, as 発注 does.
    expect(find.text('読み取り結果の確認'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rc-ok')));
    await tester.pumpAndSettle();
  }
  return stock;
}

void main() {
  testWidgets('予定外の入荷 goes as 発注: the note read, checked in the table, new products registered, then 検品 with all ticked (0182)',
      (tester) async {
    final stock = await _pump(tester);
    expect(find.text('今: 商品登録'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('ur-supplier'))).controller!.text, 'テスト商事株式会社');
    expect(find.text('3行・35個を検品に回します'), findsOneWidget);
    // Field by field across, as 発注 lists them.
    expect(find.byKey(const ValueKey('ur-table-going')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('ur-qty-2'))).data, '10');
    expect(find.text('未登録（登録します）'), findsOneWidget);
    // An ordinary stock role registers the one the library lacks.
    expect(find.byKey(const ValueKey('ur-will-register')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ur-next')));
    await tester.pumpAndSettle();
    expect(stock.registered, [
      [_stranger],
    ]);
    final s = stock.staged.single;
    expect([for (final l in s.lines) (l.janCode, l.quantity)], [(_pen, 20), (_note, 10), (_stranger, 5)]);
    expect((s.warehouseId, s.supplier, s.documentId, s.date), (1, 'テスト商事株式会社', 77, DateTime(2026, 11, 2)));
    expect(stock.noted, [31]);
    // The ordinary 検品 screen, every line ticked.
    expect(find.byType(StockInspectionDetailScreen), findsOneWidget);
    expect(find.text('今: 検品・在庫'), findsOneWidget);
    for (final n in [1, 2, 3]) {
      expect(tester.widget<Checkbox>(find.byKey(ValueKey('si-tick-$n'))).value, isTrue);
    }
    // The notebook did not come: unticked; the rest checked in, it is closed.
    await tester.tap(find.byKey(const ValueKey('si-tick-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('si-check-in')));
    await tester.pumpAndSettle();
    expect(find.text('チェックしていない 1行は「届いていない」として閉じる'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('si-confirm')));
    await tester.pumpAndSettle();
    expect(stock.inspected.single, [1, 3]);
    expect(stock.closed.single, [2]);
    expect(tester.widget<Text>(find.byKey(const ValueKey('si-inspected-2'))).data, '届いていない（閉じました・在庫は増やしていません）');
  });

  testWidgets('left open on asking, the unticked line keeps waiting', (tester) async {
    final stock = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('ur-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('si-tick-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('si-check-in')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('si-close-left')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('si-confirm')));
    await tester.pumpAndSettle();
    expect(stock.inspected.single, [1, 2]);
    expect(stock.closed, isEmpty);
  });

  testWidgets('with no note, the goods are scanned and go to 検品 the same way', (tester) async {
    final stock = await _pump(tester, readNote: false);
    for (final j in [_pen, _pen, _note]) {
      await tester.enterText(find.byKey(const ValueKey('ur-scan')), j);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }
    expect(find.text('2行・3個を検品に回します'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ur-next')));
    await tester.pumpAndSettle();
    expect([for (final l in stock.staged.single.lines) (l.janCode, l.quantity)], [(_pen, 2), (_note, 1)]);
    expect(stock.registered, isEmpty);
    expect(stock.noted, isEmpty);
  });

  test('予定外の入荷 is in the menu for those who adjust stock; 納品照合 is not', () {
    final entries = buildFeatureCatalog().expand((g) => g.entries);
    final e = entries.firstWhere((e) => e.id == 'unplanned_receipt');
    expect(e.visibleFor(['inventory.adjust']), isTrue);
    expect(e.visibleFor(['inspection.view']), isFalse);
    expect(entries.firstWhere((e) => e.id == 'delivery').inMenu, isFalse);
  });

  test('an invoice line matches the oldest unplanned line of its JAN, one each', () {
    UnplannedLine u(int id, String jan) => UnplannedLine.fromJson({'import_id': id, 'line_no': 1, 'jan_code': jan, 'quantity': 5});
    final m = matchUnplanned([(1, _pen, 5), (2, _pen, 5), (3, _pen, 5), (4, _note, 1)], [u(3, _pen), u(4, _pen)]);
    expect([for (final x in m) (x.$1, x.$4.importId)], [(1, 3), (2, 4)]);
  });
}
