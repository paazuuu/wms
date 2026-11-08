// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/core/export/xlsx.dart';
import 'package:wms_mobile/features/outbound/presentation/outbound_downloads.dart';
import 'package:wms_mobile/features/outbound_file/domain/outbound_sheet.dart';
import 'package:wms_mobile/features/outbound_file/presentation/outbound_file_screen.dart' show outboundFilePickerProvider;
import 'package:wms_mobile/features/partners/domain/trading_partner.dart';
import 'package:wms_mobile/features/purchase_request/data/purchase_request_excel.dart';
import 'package:wms_mobile/features/purchase_request/data/purchase_request_repository.dart';
import 'package:wms_mobile/features/purchase_request/domain/purchase_request.dart';
import 'package:wms_mobile/features/purchase_request/domain/wish_file.dart';
import 'package:wms_mobile/features/purchase_request/presentation/purchase_request_screen.dart';
import 'package:wms_mobile/features/purchase_request/presentation/purchase_requests_screen.dart';

import 'package:wms_mobile/features/record_notes/data/record_notes_repository.dart';

import '../../support/fake_overseas_and_notes.dart';
import '../../support/harness.dart';

class _FakeRepo implements PurchaseRequestRepository {
  _FakeRepo({this.saved});

  PurchaseRequest? saved;
  final List<(int?, int?)> asked = [];
  final List<Map<String, dynamic>> saves = [];
  final List<int> removed = [];
  List<PurchaseRequest> listed = [];

  @override
  Future<ApiResult<List<RequestCandidate>>> candidates({int? warehouseId, int? supplierId}) async {
    asked.add((warehouseId, supplierId));
    return ApiSuccess([
      RequestCandidate(productId: 1, name: 'ボルト', janCode: '4909999000014', onHand: 10, maxStock: 30),
      RequestCandidate(productId: 2, name: 'ナット', janCode: '4909999000021', onHand: 0),
      RequestCandidate(
        productId: 3,
        name: 'ワッシャー',
        sku: 'WS-3',
        onHand: 5,
        fromSupplier: supplierId != null,
        supplierCode: supplierId == null ? null : 'W-01',
        supplierProductName: supplierId == null ? null : '平ワッシャー',
      ),
    ]);
  }

  @override
  Future<ApiResult<RequestSaved>> save({
    int? id,
    int? supplierId,
    int? warehouseId,
    String? title,
    String? note,
    DateTime? replyBy,
    required List<RequestRow> lines,
    Map<String, dynamic>? settings,
    String? customerName,
    int? destinationId,
    DateTime? wantedBy,
  }) async {
    saves.add({'id': id, 'supplier': supplierId, 'title': title, 'lines': lines, 'customer': customerName, 'destination': destinationId, 'wanted': wantedBy});
    return ApiSuccess(RequestSaved(id: 5, number: 'REQ-000005', lines: lines.length, units: lines.fold(0, (s, l) => s + l.quantity)));
  }

  final List<(int, String)> statuses = [];
  List<WishSummary> summaryRows = const [];

  @override
  Future<ApiResult<bool>> setStatus(int id, String status) async {
    statuses.add((id, status));
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<List<WishSummary>>> summary({int? warehouseId}) async => ApiSuccess(summaryRows);

  @override
  Future<ApiResult<List<PurchaseRequest>>> list() async => ApiSuccess(listed);

  @override
  Future<ApiResult<PurchaseRequest>> get(int id) async => ApiSuccess(saved!);

  @override
  Future<ApiResult<bool>> remove(int id) async {
    removed.add(id);
    listed = listed.where((r) => r.id != id).toList();
    return const ApiSuccess(true);
  }

  final List<(String, int)> uploads = [];
  final List<(int, Map<String, dynamic>)> files = [];
  Uint8List kept = Uint8List(0);

  @override
  Future<ApiResult<String>> upload(String fileName, Uint8List bytes) async {
    uploads.add((fileName, bytes.length));
    return ApiSuccess('wish/1-$fileName');
  }

  @override
  Future<ApiResult<bool>> setFile(int id, Map<String, dynamic> file) async {
    files.add((id, file));
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<Uint8List>> fileBytes(String storagePath) async => ApiSuccess(kept);
}

Future<(_FakeRepo, List<(String, Uint8List)>)> _pump(WidgetTester tester,
    {_FakeRepo? repo, int? requestId, bool library = true, ({String name, Uint8List bytes})? file, FakeRecordNotesRepository? notes}) async {
  await tester.binding.setSurfaceSize(const Size(1200, 2600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final r = repo ?? _FakeRepo();
  final saved = <(String, Uint8List)>[];
  await pumpApp(tester, PurchaseRequestScreen(requestId: requestId), overrides: [
    purchaseRequestRepositoryProvider.overrideWithValue(r),
    requestSuppliersProvider.overrideWith((ref) async => [TradingPartner(id: 42, name: 'ウエダ商事')]),
    saveFileProvider.overrideWithValue((n, b) async => saved.add((n, b))),
    outboundFilePickerProvider.overrideWithValue(() async => file),
    recordNotesRepositoryProvider.overrideWithValue(notes ?? FakeRecordNotesRepository()),
  ]);
  await tester.pumpAndSettle();
  // A new list opens on the file tab; these choose from the library.
  if (requestId == null && library) {
    await tester.tap(find.byKey(const ValueKey('wl-tab-library')));
    await tester.pumpAndSettle();
  }
  return (r, saved);
}

String _qty(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(ValueKey('pr-qty-$key'))).controller!.text;

void main() {
  group('bulk', () {
    const a = RequestRow(key: 'p1', name: 'A', onHand: 10, maxStock: 30, reorderPoint: 12);
    const b = RequestRow(key: 'p2', name: 'B', onHand: 5, reorderPoint: 8);
    const c = RequestRow(key: 'p3', name: 'C', onHand: 0);

    test('a share of stock, the same number, or up to the maximum', () {
      expect(bulkQuantity(a, BulkMode.percentOfStock, 25), 3); // 2.5 rounded up
      expect(bulkQuantity(a, BulkMode.percentOfStock, 25, rounding: BulkRounding.down), 2);
      expect(bulkQuantity(b, BulkMode.percentOfStock, 50, rounding: BulkRounding.nearest), 3);
      expect(bulkQuantity(c, BulkMode.percentOfStock, 50), 0);
      expect(bulkQuantity(c, BulkMode.fixed, 4), 4);
      expect(bulkQuantity(a, BulkMode.upToMax, 0), 20);
      expect(bulkQuantity(b, BulkMode.upToMax, 0), 3); // up to the reorder point
      expect(bulkQuantity(c, BulkMode.upToMax, 0), 0);
    });

    test('a range is everything between, whichever way round', () {
      const order = ['a', 'b', 'c', 'd', 'e'];
      expect(keysBetween(order, 'b', 'd'), ['b', 'c', 'd']);
      expect(keysBetween(order, 'e', 'c'), ['c', 'd', 'e']);
      expect(keysBetween(order, 'x', 'c'), ['c']);
    });

    test('the sheet for the supplier has their columns to fill in', () {
      final bytes = buildPurchaseRequestXlsx(
        lines: [
          RequestRow(key: 'p1', name: 'ボルト', janCode: '4909999000014', quantity: 5, onHand: 10, supplierCode: 'B-1'),
          RequestRow(key: 'm1', name: '新商品', quantity: 2, manual: true),
        ],
        number: 'REQ-000005',
        supplierName: 'ウエダ商事',
        replyBy: DateTime(2026, 10, 20),
      );
      final t = readXlsx(bytes);
      final flat = t.expand((r) => r).toList();
      expect(flat, containsAll(['REQ-000005', 'ウエダ商事 御中', '2026/10/20']));
      final h = t.indexWhere((r) => r.isNotEmpty && r.first == 'No.');
      expect(t[h], contains('在庫の有無 / Available'));
      expect(t[h], isNot(contains('当社在庫 / Our stock')));
      expect(t[h + 1].sublist(0, 9), ['1', '4909999000014', 'ボルト', '', '', '', 'B-1', '', '5']);
      expect(t.last[8], '7');
      final withStock = readXlsx(buildPurchaseRequestXlsx(lines: [RequestRow(key: 'p1', name: 'A', quantity: 1, onHand: 9)], withStock: true));
      final h2 = withStock.indexWhere((r) => r.isNotEmpty && r.first == 'No.');
      expect(withStock[h2], contains('当社在庫 / Our stock'));
      expect(purchaseRequestFileName('REQ-000005', 'ウエダ 商事', now: DateTime(2026, 10, 10)), '入荷希望_REQ-000005_ウエダ_商事_20261010.xlsx');
    });
  });

  testWidgets('bulk by share of stock, a range chosen, taken out and set again, then saved and downloaded', (tester) async {
    final (repo, saved) = await _pump(tester);
    expect(find.byKey(const ValueKey('pr-row-p1')), findsOneWidget);
    expect(find.text('在庫 10 ・ 最大 30'), findsOneWidget);

    // 50% of the stock for everything shown: 5, 0 (no stock), 3.
    await tester.tap(find.byKey(const ValueKey('pr-apply-visible')));
    await tester.pumpAndSettle();
    expect([_qty(tester, 'p1'), _qty(tester, 'p2'), _qty(tester, 'p3')], ['5', '', '3']);
    expect(find.text('2品目・合計 8個'), findsOneWidget);

    // A range: the first, then (range on) the last.
    await tester.tap(find.byKey(const ValueKey('pr-range')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pr-select-p1')));
    await tester.tap(find.byKey(const ValueKey('pr-select-p3')));
    await tester.pumpAndSettle();
    expect(find.text('3件選択中'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pr-exclude')));
    await tester.pumpAndSettle();
    expect(find.text('0品目・合計 0個'), findsOneWidget);

    // The same number for the chosen ones.
    await tester.tap(find.text('一律◯個'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('pr-bulk-value')), '4');
    await tester.tap(find.byKey(const ValueKey('pr-apply-selected')));
    await tester.pumpAndSettle();
    expect(find.text('3品目・合計 12個'), findsOneWidget);

    // One by hand, and one product out again.
    await tester.enterText(find.byKey(const ValueKey('pr-qty-p2')), '9');
    await tester.tap(find.byKey(const ValueKey('pr-toggle-p3')));
    await tester.pumpAndSettle();
    expect(find.text('2品目・合計 13個'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pr-save')));
    await tester.pumpAndSettle();
    final lines = repo.saves.single['lines'] as List<RequestRow>;
    expect([for (final l in lines) '${l.key}:${l.quantity}'], ['p1:4', 'p2:9']);
    expect(find.text('REQ-000005 を保存しました（2品目・13個）'), findsOneWidget);
    // Downstream wishes: no supplier sheet here (wishes to suppliers are kept elsewhere).
    expect(find.byKey(const ValueKey('pr-excel')), findsNothing);
    expect(saved, isEmpty);
  });

  testWidgets('shift-click chooses everything between; a product is added by hand', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('pr-select-p1')));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.byKey(const ValueKey('pr-select-p3')));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(find.text('3件選択中'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pr-include')));
    await tester.pumpAndSettle();
    // A product without stock still goes in, with one.
    expect([_qty(tester, 'p1'), _qty(tester, 'p2'), _qty(tester, 'p3')], ['5', '1', '3']);

    await tester.tap(find.byKey(const ValueKey('pr-add-manual')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pm-ok')));
    await tester.pumpAndSettle();
    expect(find.text('商品名と1以上の数量を入れてください'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('pm-name')), '新しいボルト');
    await tester.enterText(find.byKey(const ValueKey('pm-qty')), '6');
    await tester.tap(find.byKey(const ValueKey('pm-ok')));
    await tester.pumpAndSettle();
    expect(find.text('新しいボルト'), findsOneWidget);
    expect(find.text('4品目・合計 15個'), findsOneWidget);
  });

  testWidgets('whose wishes and by when: 依頼元 typed, 希望時期 chosen, saved with the list; 完了', (tester) async {
    final (repo, _) = await _pump(tester);
    expect(repo.asked.last, (null, null));
    expect(find.byKey(const ValueKey('pr-supplier-1-null')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('pr-customer')), 'テスト商店');
    await tester.tap(find.byKey(const ValueKey('pr-wanted-by')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.textContaining('希望時期 '), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('pr-qty-p1')), '3');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pr-save')));
    await tester.pumpAndSettle();
    expect(repo.saves.single['customer'], 'テスト商店');
    expect(repo.saves.single['wanted'], isNotNull);

    // Saved: it can be closed (out of the summary).
    await tester.tap(find.byKey(const ValueKey('pr-close')));
    await tester.pumpAndSettle();
    expect(repo.statuses, [(5, 'closed')]);
    expect(find.text('進行中に戻す'), findsOneWidget);
  });

  testWidgets('a saved list opens with its quantities, its hand-typed lines and the rest of the master', (tester) async {
    final repo = _FakeRepo(
      saved: PurchaseRequest.fromJson({
        'id': 5,
        'request_number': 'REQ-000005',
        'title': '秋の補充',
        'lines': [
          {'product_id': 1, 'name': 'ボルト', 'quantity': 7},
          {'name': '手書き品', 'quantity': 2},
        ],
      }),
    );
    await _pump(tester, repo: repo, requestId: 5);
    expect(find.text('入荷希望リスト REQ-000005'), findsOneWidget);
    expect(_qty(tester, 'p1'), '7');
    expect(find.text('手書き品'), findsOneWidget);
    expect(find.byKey(const ValueKey('pr-row-p2')), findsOneWidget);
    expect(find.text('2品目・合計 9個'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pr-save')));
    await tester.pumpAndSettle();
    expect(repo.saves.single['id'], 5);
  });

  testWidgets('the saved lists, by customer and when; a closed one hidden until asked; one removed', (tester) async {
    final repo = _FakeRepo()
      ..listed = [
        PurchaseRequest(id: 5, number: 'REQ-000005', customerName: 'テスト商店', wantedBy: DateTime(2026, 12, 1), lineCount: 2, units: 9),
        PurchaseRequest(id: 6, number: 'REQ-000006', customerName: '済み商会', status: 'closed', lineCount: 1, units: 1),
      ];
    await pumpApp(tester, const PurchaseRequestsScreen(), overrides: [purchaseRequestRepositoryProvider.overrideWithValue(repo)]);
    await tester.pumpAndSettle();
    expect(find.text('テスト商店'), findsOneWidget);
    expect(find.textContaining('REQ-000005 · 希望時期 2026/12/01 · 2品目・合計 9個'), findsOneWidget);
    expect(find.text('済み商会'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('wl-show-closed')));
    await tester.pumpAndSettle();
    expect(find.text('済み商会'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wl-show-closed')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pr-remove-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pr-remove-ok')));
    await tester.pumpAndSettle();
    expect(repo.removed, [5]);
    expect(find.text('保存したリストはまだありません'), findsOneWidget);
  });

  testWidgets('まとめ: the open lists by product, who wished how many by when, against the stock', (tester) async {
    final repo = _FakeRepo()
      ..summaryRows = [
        WishSummary(
          productId: 1,
          jan: '4909999000014',
          name: 'ボルト',
          wanted: 25,
          onHand: 20,
          kept: 0,
          free: 20,
          short: 5,
          firstWantedBy: DateTime(2026, 11, 20),
          wishes: [
            WishOf(requestId: 6, number: 'REQ-000006', customer: 'B商会', wantedBy: DateTime(2026, 11, 20), quantity: 10),
            WishOf(requestId: 5, number: 'REQ-000005', customer: 'A商店', wantedBy: DateTime(2026, 12, 1), quantity: 15),
          ],
        ),
        const WishSummary(productId: 2, name: 'ナット', wanted: 3, onHand: 10, free: 10),
      ];
    await pumpApp(tester, const PurchaseRequestsScreen(), overrides: [purchaseRequestRepositoryProvider.overrideWithValue(repo)]);
    await tester.tap(find.byKey(const ValueKey('wl-tab-summary')));
    await tester.pumpAndSettle();
    expect(find.text('2品目・希望 合計 28個・足りない 1品目'), findsOneWidget);
    expect(find.text('足りない 5'), findsOneWidget);
    expect(find.text('在庫で足りる'), findsOneWidget);
    await tester.tap(find.text('ボルト'));
    await tester.pumpAndSettle();
    expect(find.text('B商会'), findsOneWidget);
    expect(find.text('× 15'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wl-short-only')));
    await tester.pumpAndSettle();
    expect(find.text('ナット'), findsNothing);
  });

  group('file', () {
    const library = [
      RequestRow(key: 'p1', name: 'ボルト', productId: 1, janCode: '4909999000014', sku: 'B-1', maker: 'テスト金物'),
      RequestRow(key: 'p2', name: 'ナット', productId: 2, janCode: '4909999000021', sku: 'N-1', maker: 'テスト金物'),
      RequestRow(key: 'p3', name: 'ナット（別）', productId: 3, sku: 'N-1', maker: 'ほか工業'),
    ];

    test('by JAN, else 品番 (narrowed by maker); not in the library goes in typed in', () {
      final lines = matchWishRows([
        const OutboundRow(rowNo: 2, jan: '4909999000014', quantity: 5),
        const OutboundRow(rowNo: 3, code: 'n-1', maker: 'ほか工業', quantity: 2),
        const OutboundRow(rowNo: 4, code: 'N-1', quantity: 1),
        const OutboundRow(rowNo: 5, jan: '4909999000069', name: '新商品X', quantity: 4),
        const OutboundRow(rowNo: 6, jan: '4909999000014', quantity: 3),
        const OutboundRow(rowNo: 7, jan: '4909999000021'),
      ], library);
      expect([for (final l in lines) l.key], ['p1', 'p3', null, null, 'p1', 'p2']);
      expect([for (final l in lines) l.status], [
        WishRowStatus.found,
        WishRowStatus.found,
        WishRowStatus.several,
        WishRowStatus.notInLibrary,
        WishRowStatus.found,
        WishRowStatus.noQuantity,
      ]);
      expect(lines[1].by, WishMatchedBy.code);

      final a = applyWishFile(lines, {6});
      expect(a.quantities, {'p1': 5, 'p3': 2, 'p2': 0});
      expect([for (final m in a.manual) '${m.key}:${m.name}:${m.quantity}:${m.janCode}'],
          ['f4:N-1:1:null', 'f5:新商品X:4:4909999000069']);
      expect(a.rows, 4);
      expect(a.units, 12);

      final picked = matchWishRows([const OutboundRow(rowNo: 4, code: 'N-1', quantity: 1)], library, picked: {4: 'p2'});
      expect(picked.single.key, 'p2');
      expect(picked.single.by, WishMatchedBy.picked);
    });
  });

  testWidgets('ファイルから読み込む: read, matched, ticked into the list, saved with the file', (tester) async {
    final book = buildXlsxBook([
      const XlsxSheet(name: '希望', headers: ['JANコード', '品番', '商品名', '数量'], rows: [
        ['4909999000014', '', 'ボルト', 5],
        ['', 'WS-3', 'ワッシャー', 2],
        ['4909999000069', '', '新商品X', 4],
        ['4909999000021', '', 'ナット', ''],
      ]),
    ]);
    final (repo, _) = await _pump(tester, library: false, file: (name: '希望.xlsx', bytes: Uint8List.fromList(book)));
    expect(find.text('ファイルを選ぶ'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wl-file-pick')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('wl-file-name')), findsOneWidget);
    expect(find.text('4行を読み込み · リストに入る 3品目・11個（うち未登録 1品目）'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('wl-status-2'))).data, 'ライブラリーにあり');
    expect(find.text('品番で照合'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('wl-status-4'))).data, '未登録（手入力で入る）');
    expect(tester.widget<Text>(find.byKey(const ValueKey('wl-status-5'))).data, '数量なし');
    expect(find.text('3品目・合計 11個'), findsOneWidget);

    // Unticked: out of the list.
    await tester.tap(find.byKey(const ValueKey('wl-include-3')));
    await tester.pumpAndSettle();
    expect(find.text('2品目・合計 9個'), findsOneWidget);

    // The row not in the library is one of ours after all.
    await tester.tap(find.byKey(const ValueKey('wl-pick-4')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('wl-pick-search')), 'ナット');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wl-pick-p2')));
    await tester.pumpAndSettle();
    expect(find.text('選んだ商品'), findsOneWidget);
    expect(find.text('4行を読み込み · リストに入る 2品目・9個（うち未登録 0品目）'), findsOneWidget);

    // The columns can be chosen again.
    await tester.tap(find.byKey(const ValueKey('wl-columns')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wl-columns-panel')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('pr-customer')), 'テスト商店');
    await tester.tap(find.byKey(const ValueKey('pr-save')));
    await tester.pumpAndSettle();
    final lines = repo.saves.single['lines'] as List<RequestRow>;
    expect([for (final l in lines) '${l.key}:${l.quantity}'], ['p1:5', 'p2:4']);
    expect(repo.saves.single['customer'], 'テスト商店');
    expect([for (final u in repo.uploads) u.$1], ['希望.xlsx', '希望_読み取り結果.xlsx']);
    expect(repo.files.single.$2['read_path'], 'wish/1-希望_読み取り結果.xlsx');
    final (id, f) = repo.files.single;
    expect(id, 5);
    expect(f['file_name'], '希望.xlsx');
    expect(f['storage_path'], 'wish/1-希望.xlsx');
    expect(f['sheet_name'], '希望');
    expect((f['columns'] as Map).keys, containsAll(['jan', 'quantity', 'code', 'name']));

    // Saved again without a new file: the file is not sent twice.
    await tester.tap(find.byKey(const ValueKey('pr-save')));
    await tester.pumpAndSettle();
    expect(repo.uploads, hasLength(2));

    // The same rows on the library tab.
    await tester.tap(find.byKey(const ValueKey('wl-tab-library')));
    await tester.pumpAndSettle();
    expect(_qty(tester, 'p1'), '5');
    expect(_qty(tester, 'p2'), '4');
  });

  testWidgets('a list read from a file keeps it: looked at again, and named in the lists', (tester) async {
    final repo = _FakeRepo(
      saved: PurchaseRequest.fromJson({
        'id': 5,
        'request_number': 'REQ-000005',
        'file_name': '希望.csv',
        'storage_path': 'wish/1-a.csv',
        'sheet_name': '希望',
        'lines': [
          {'product_id': 1, 'name': 'ボルト', 'quantity': 7},
        ],
      }),
    )..kept = Uint8List.fromList(utf8.encode('JAN,数量\n4909999000014,7\n'));
    await _pump(tester, repo: repo, requestId: 5);
    await tester.tap(find.byKey(const ValueKey('wl-tab-file')));
    await tester.pumpAndSettle();
    expect(find.text('読み込んだファイル: 希望.csv'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wl-saved-view')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wl-saved-original')), findsOneWidget);
    expect(find.text('4909999000014'), findsOneWidget);
  });

  testWidgets('メモ: not before the list is saved', (tester) async {
    await _pump(tester, library: false);
    await tester.tap(find.byKey(const ValueKey('wl-tab-notes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wl-notes-unsaved')), findsOneWidget);
  });

  testWidgets('メモ on a saved list', (tester) async {
    final notes = FakeRecordNotesRepository();
    final repo = _FakeRepo(saved: PurchaseRequest.fromJson({'id': 5, 'request_number': 'REQ-000005', 'lines': []}));
    await _pump(tester, repo: repo, requestId: 5, notes: notes);
    await tester.tap(find.byKey(const ValueKey('wl-tab-notes')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('rn-body')), '12月に追加の可能性あり');
    await tester.tap(find.byKey(const ValueKey('rn-add')));
    await tester.pumpAndSettle();
    expect(notes.notes[(NoteSubject.wishList, 5)]!.single.body, '12月に追加の可能性あり');
    expect(find.text('12月に追加の可能性あり'), findsOneWidget);
  });

  testWidgets('a list with a file says so in the lists', (tester) async {
    final lists = _FakeRepo()
      ..listed = [
        PurchaseRequest(id: 5, number: 'REQ-000005', customerName: 'テスト商店', fileName: '希望.csv', noteCount: 2, lineCount: 1, units: 7),
      ];
    await pumpApp(tester, const PurchaseRequestsScreen(), overrides: [purchaseRequestRepositoryProvider.overrideWithValue(lists)]);
    await tester.pumpAndSettle();
    expect(find.textContaining('ファイル: 希望.csv'), findsOneWidget);
    expect(find.textContaining('メモ 2'), findsOneWidget);
  });
}
