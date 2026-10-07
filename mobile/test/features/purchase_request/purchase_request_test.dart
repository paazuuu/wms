// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/core/export/xlsx.dart';
import 'package:wms_mobile/features/outbound/presentation/outbound_downloads.dart';
import 'package:wms_mobile/features/partners/domain/trading_partner.dart';
import 'package:wms_mobile/features/purchase_request/data/purchase_request_excel.dart';
import 'package:wms_mobile/features/purchase_request/data/purchase_request_repository.dart';
import 'package:wms_mobile/features/purchase_request/domain/purchase_request.dart';
import 'package:wms_mobile/features/purchase_request/presentation/purchase_request_screen.dart';
import 'package:wms_mobile/features/purchase_request/presentation/purchase_requests_screen.dart';

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
  }) async {
    saves.add({'id': id, 'supplier': supplierId, 'title': title, 'lines': lines});
    return ApiSuccess(RequestSaved(id: 5, number: 'REQ-000005', lines: lines.length, units: lines.fold(0, (s, l) => s + l.quantity)));
  }

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
}

Future<(_FakeRepo, List<(String, Uint8List)>)> _pump(WidgetTester tester, {_FakeRepo? repo, int? requestId}) async {
  await tester.binding.setSurfaceSize(const Size(1200, 2600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final r = repo ?? _FakeRepo();
  final saved = <(String, Uint8List)>[];
  await pumpApp(tester, PurchaseRequestScreen(requestId: requestId), overrides: [
    purchaseRequestRepositoryProvider.overrideWithValue(r),
    requestSuppliersProvider.overrideWith((ref) async => [TradingPartner(id: 42, name: 'ウエダ商事')]),
    saveFileProvider.overrideWithValue((n, b) async => saved.add((n, b))),
  ]);
  await tester.pumpAndSettle();
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

    await tester.tap(find.byKey(const ValueKey('pr-excel')));
    await tester.pumpAndSettle();
    expect(saved.single.$1, startsWith('入荷希望_REQ-000005_'));
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
    expect(find.text('品名と1以上の数量を入れてください'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('pm-name')), '新しいボルト');
    await tester.enterText(find.byKey(const ValueKey('pm-qty')), '6');
    await tester.tap(find.byKey(const ValueKey('pm-ok')));
    await tester.pumpAndSettle();
    expect(find.text('新しいボルト'), findsOneWidget);
    expect(find.text('4品目・合計 15個'), findsOneWidget);
  });

  testWidgets('a supplier is optional; chosen, its names show and its products can be kept to', (tester) async {
    final (repo, _) = await _pump(tester);
    expect(repo.asked.last, (null, null));
    await tester.tap(find.byWidgetPredicate((w) => w is DropdownButtonFormField<int?>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ウエダ商事').last);
    await tester.pumpAndSettle();
    expect(repo.asked.last.$2, 42);
    expect(find.textContaining('仕入先: W-01 平ワッシャー'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pr-only-supplier')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pr-row-p1')), findsNothing);
    expect(find.byKey(const ValueKey('pr-row-p3')), findsOneWidget);
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

  testWidgets('the saved lists, and one removed', (tester) async {
    final repo = _FakeRepo()
      ..listed = [PurchaseRequest(id: 5, number: 'REQ-000005', supplierName: 'ウエダ商事', lineCount: 2, units: 9)];
    await pumpApp(tester, const PurchaseRequestsScreen(), overrides: [purchaseRequestRepositoryProvider.overrideWithValue(repo)]);
    expect(find.text('REQ-000005'), findsOneWidget);
    expect(find.textContaining('ウエダ商事 · 2品目・合計 9個'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pr-remove-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pr-remove-ok')));
    await tester.pumpAndSettle();
    expect(repo.removed, [5]);
    expect(find.text('保存したリストはまだありません'), findsOneWidget);
  });
}
