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
import 'package:wms_mobile/features/price_book/application/price_book_providers.dart';
import 'package:wms_mobile/features/product_library/application/product_library_providers.dart';
import 'package:wms_mobile/features/stock_import/data/stock_import_repository.dart';
import 'package:wms_mobile/features/stock_import/domain/stock_file.dart';
import 'package:wms_mobile/features/stock_import/domain/stock_ledger.dart';
import 'package:wms_mobile/features/unplanned_receipt/unplanned_receipt_screen.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';
import 'package:wms_mobile/features/warehouse_context/domain/warehouse.dart';

import '../../support/harness.dart';

const _pen = '4909999000014';
const _note = '4909999000021';
const _stranger = '4909999000038';

class _Reader implements MasterImportRepository {
  _Reader(this.note);
  final MasterRead note;
  String? purpose;

  @override
  Future<ApiResult<MasterRead>> read(String fileName, Uint8List bytes,
      {bool keepRows = false, String purpose = 'library'}) async {
    this.purpose = purpose;
    return ApiSuccess(note);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Stock implements StockImportRepository {
  _Stock(this.library);
  final Map<String, String> library;
  final received = <({int warehouseId, List<StockFileLine> lines, String? supplier, int? documentId, DateTime? date})>[];

  @override
  Future<ApiResult<Map<String, String>>> known(List<String> jans) async =>
      ApiSuccess({for (final j in jans) if (library[j] case final n?) j: n});

  @override
  Future<ApiResult<Map<String, (int, String)>>> inPriceBook(List<String> jans) async => const ApiSuccess({});

  @override
  Future<ApiResult<PendingInspection>> pendingInspection({int? warehouseId}) async => const ApiSuccess(PendingInspection());

  @override
  Future<ApiResult<StockFileResult>> unplannedReceipt(int warehouseId, List<StockFileLine> lines,
      {String? fileName, String? fileType, String? supplier, int? documentId, DateTime? documentDate}) async {
    received.add((warehouseId: warehouseId, lines: lines, supplier: supplier, documentId: documentId, date: documentDate));
    return ApiSuccess(StockFileResult.fromJson({'import_id': 31, 'lines': lines.length, 'change': 0}));
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Override _signedIn(List<String> p) => authControllerProvider
    .overrideWith((ref) => fakeAuthControllerFor(AuthUser(id: 'u1', email: 'a@b.test', name: '倉庫', permissions: p)));

Future<_Stock> _pump(WidgetTester tester,
    {required List<String> perms, Map<String, String>? library, bool canRegister = false}) async {
  await tester.binding.setSurfaceSize(const Size(600, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final stock = _Stock(library ?? {_pen: 'テストペン 青', _note: 'テストノート'});
  await pumpApp(tester, const UnplannedReceiptScreen(), overrides: [
    _signedIn(perms),
    productLibraryCanManageProvider.overrideWithValue(canRegister),
    stockImportRepositoryProvider.overrideWithValue(stock),
    masterImportRepositoryProvider.overrideWithValue(_Reader(const MasterRead(
      documentId: 77,
      supplierName: 'テスト商事株式会社',
      docDate: '2026/11/02',
      lines: [
        MasterLine(lineNo: 1, janCode: _pen, supplierName: 'ﾃｽﾄﾍﾟﾝ ｱｵ', quantity: '20'),
        MasterLine(lineNo: 2, janCode: _note, supplierName: 'ﾉｰﾄ', quantity: '10'),
        MasterLine(lineNo: 3, janCode: _stranger, supplierName: '新しい消しゴム', quantity: '5', maker: 'テスト', productCode: 'KE-1'),
      ],
    ))),
    deliveryNotePickerProvider.overrideWithValue(({required camera}) async =>
        (name: '納品書_1102.jpg', bytes: Uint8List.fromList([1]))),
    priceBookRepositoryProvider.overrideWithValue(FakePriceBookRepository()),
    warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(const WarehouseOverview(
      warehouses: [Warehouse(id: 1, code: 'WH-01', name: '本社倉庫')],
      totals: WarehouseTotals(),
    ))),
  ]);
  await tester.tap(find.byKey(const ValueKey('ur-note')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('dn-pick-camera')));
  await tester.pumpAndSettle();
  return stock;
}

void main() {
  testWidgets('予定外の入荷: the note read ticks every good with its count; what did not come is unticked, then in stock (0181)',
      (tester) async {
    final stock = await _pump(tester, perms: ['inventory.adjust']);
    // Who it is from, read from the note; every line ticked with its count.
    expect(tester.widget<TextField>(find.byKey(const ValueKey('ur-supplier'))).controller!.text, 'テスト商事株式会社');
    expect(tester.widget<Checkbox>(find.byKey(const ValueKey('ur-tick-1'))).value, isTrue);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('ur-count-1'))).controller!.text, '20');
    expect(find.byKey(const ValueKey('ur-new-3')), findsOneWidget);
    expect(find.text('3行（入庫する 3行・35個）'), findsOneWidget);
    // One more pen scanned; the notebook did not come.
    await tester.enterText(find.byKey(const ValueKey('ur-scan')), _pen);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const ValueKey('ur-count-1'))).controller!.text, '21');
    await tester.tap(find.byKey(const ValueKey('ur-tick-2')));
    await tester.pumpAndSettle();
    expect(find.text('検品完了（2行・26個を入庫）'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ur-complete')));
    await tester.pumpAndSettle();
    // Not allowed to register products: the new one is left out, and said so.
    expect(find.text('商品ライブラリーにない 1件は登録する権限がないため入庫しません。'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ur-confirm')));
    await tester.pumpAndSettle();
    final r = stock.received.single;
    expect([for (final l in r.lines) (l.janCode, l.quantity)], [(_pen, 21)]);
    expect((r.warehouseId, r.supplier, r.documentId, r.date), (1, 'テスト商事株式会社', 77, DateTime(2026, 11, 2)));
    expect(find.text('取込 #31 として 1行・21個を入庫しました'), findsOneWidget);
    expect(find.byKey(const ValueKey('ur-line-1')), findsNothing);
  });

  testWidgets('one who may register products has the new one registered first, then it goes in too', (tester) async {
    final stock = await _pump(tester, perms: ['inventory.adjust', 'product.manage'], canRegister: true);
    await tester.tap(find.byKey(const ValueKey('ur-complete')));
    await tester.pumpAndSettle();
    expect(find.text('商品ライブラリーにない 1件は、納品書の名前で登録してから入庫します。'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ur-confirm')));
    await tester.pumpAndSettle();
    expect([for (final l in stock.received.single.lines) l.janCode], [_pen, _note, _stranger]);
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
