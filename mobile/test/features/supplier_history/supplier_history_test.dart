// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/inbound/presentation/supplier_product_names_screen.dart';
import 'package:wms_mobile/features/partners/domain/trading_partner.dart';
import 'package:wms_mobile/features/purchase_request/data/purchase_request_repository.dart';
import 'package:wms_mobile/features/purchase_request/domain/purchase_request.dart';
import 'package:wms_mobile/features/purchase_request/presentation/purchase_request_screen.dart';
import 'package:wms_mobile/features/supplier_history/data/supplier_history_repository.dart';
import 'package:wms_mobile/features/supplier_history/domain/supplier_history.dart';
import 'package:wms_mobile/features/supplier_history/presentation/supplier_detail_screen.dart';

import '../../support/harness.dart';

final _historyJson = {
  'supplier': {'id': 41, 'name': 'アケボノ商事', 'code': 'S00002', 'phone': '03-0000-0000'},
  'totals': {'purchases': 3, 'units': 1300, 'amount': 52000, 'first_at': '2026-08-01', 'last_at': '2026-10-01'},
  'products': [
    {
      'product_id': 1, 'jan_code': '4902778322239', 'name': 'ZENTO リフィル 黒', 'sku': 'UBRZ05.24', 'unit': '本',
      'their_name': 'uniball ZENTO リフィル 黒', 'their_code': 'UBRZ05.24',
      'times': 3, 'total': 1200, 'avg_qty': 400, 'last_qty': 500, 'last_price': 40,
      'first_at': '2026-08-01', 'last_at': '2026-10-01', 'interval_days': 30, 'next_due': '2026-10-31', 'on_hand': 120,
    },
    {
      'product_id': 2, 'jan_code': '4902778319512', 'name': 'ジェットストリーム 0.7',
      'times': 1, 'total': 100, 'avg_qty': 100, 'last_qty': 100,
      'first_at': '2026-09-15', 'last_at': '2026-09-15', 'on_hand': 0,
    },
    {'product_id': 3, 'jan_code': '4902778767269', 'name': 'パワータンク', 'their_name': 'パワータンク 黒', 'times': 0, 'total': 0, 'on_hand': 7},
  ],
  'events': [
    {'source': 'import', 'ref_id': 3, 'ref_no': '請求書.pdf', 'at': '2026-10-01', 'lines': 1, 'units': 500, 'amount': 20000},
    {'source': 'delivery', 'ref_id': 9, 'ref_no': 'D-9', 'at': '2026-09-15', 'lines': 2, 'units': 500},
    {'source': 'po', 'ref_id': 4, 'ref_no': 'PO-000004', 'at': '2026-08-01', 'lines': 1, 'units': 300},
  ],
};

class _FakeHistory implements SupplierHistoryRepository {
  _FakeHistory({this.json});

  final Map<String, dynamic>? json;
  final List<int?> asked = [];

  @override
  Future<ApiResult<List<SupplierCard>>> cards({String? search}) async => ApiSuccess([
        SupplierCard.fromJson({
          'id': 41, 'name': 'アケボノ商事', 'code': 'S00002', 'products': 3, 'purchases': 3, 'units': 1300,
          'last_at': '2026-10-01', 'top': ['ZENTO リフィル 黒', 'ジェットストリーム 0.7'],
        }),
        SupplierCard.fromJson({'id': 42, 'name': 'ウエダ商事', 'code': 'S00003'}),
      ]);

  @override
  Future<ApiResult<SupplierHistory>> history(int supplierId, {int? warehouseId}) async {
    asked.add(warehouseId);
    return ApiSuccess(SupplierHistory.fromJson(json ?? _historyJson));
  }
}

class _FakeRequests implements PurchaseRequestRepository {
  final List<Map<String, dynamic>> saves = [];

  @override
  Future<ApiResult<List<RequestCandidate>>> candidates({int? warehouseId, int? supplierId}) async => const ApiSuccess([]);

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
    saves.add({'supplier': supplierId, 'title': title, 'lines': lines});
    return ApiSuccess(RequestSaved(id: 5, number: 'REQ-000005', lines: lines.length, units: lines.fold(0, (s, l) => s + l.quantity)));
  }

  @override
  Future<ApiResult<List<PurchaseRequest>>> list() async => const ApiSuccess([]);

  @override
  Future<ApiResult<PurchaseRequest>> get(int id) async =>
      ApiSuccess(PurchaseRequest(id: id, number: 'REQ-000005', supplierId: 41, supplierName: 'アケボノ商事'));

  @override
  Future<ApiResult<bool>> remove(int id) async => const ApiSuccess(true);
}

void main() {
  test('a supplier history reads, and the next order takes the last or the average quantity', () {
    final h = SupplierHistory.fromJson(_historyJson);
    expect(h.name, 'アケボノ商事');
    expect(h.purchases, 3);
    expect(h.products, hasLength(3));
    final zento = h.products.first;
    expect(zento.theirName, 'uniball ZENTO リフィル 黒');
    expect(zento.nextDue, DateTime(2026, 10, 31));
    expect(zento.dueBy(DateTime(2026, 11, 2)), isTrue);
    expect(zento.dueBy(DateTime(2026, 10, 20)), isFalse);
    expect(nextOrderQuantity(zento, NextOrderQty.last), 500);
    expect(nextOrderQuantity(zento, NextOrderQty.average), 400);
    expect(nextOrderQuantity(zento, NextOrderQty.none), 0);
    expect(nextOrderQuantity(h.products.last, NextOrderQty.last), 0);
    expect(h.events.map((e) => e.source), [PurchaseSource.import, PurchaseSource.delivery, PurchaseSource.po]);
  });

  testWidgets('suppliers are cards; one opens their products and history', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final history = _FakeHistory();
    await pumpApp(tester, const SupplierProductNamesScreen(), overrides: [
      supplierHistoryRepositoryProvider.overrideWithValue(history),
      purchaseRequestRepositoryProvider.overrideWithValue(_FakeRequests()),
    ]);

    expect(find.byKey(const ValueKey('sup-card-41')), findsOneWidget);
    expect(find.byKey(const ValueKey('sup-card-42')), findsOneWidget);
    expect(find.text('取扱 3品目 · 仕入 3回 · 合計 1300個'), findsOneWidget);
    expect(find.text('よく仕入れる: ZENTO リフィル 黒、ジェットストリーム 0.7'), findsOneWidget);

    // Searching narrows the cards, by what is bought too.
    await tester.enterText(find.byKey(const ValueKey('spn-search')), 'ジェット');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sup-card-42')), findsNothing);
    expect(find.byKey(const ValueKey('sup-card-41')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sup-card-41')));
    await tester.pumpAndSettle();
    expect(find.byType(SupplierDetailScreen), findsOneWidget);
    expect(find.text('仕入 3回 · 合計 1,300個 · 最終仕入 2026/10/01 · ¥52,000'), findsOneWidget);
    expect(find.textContaining('仕入 3回 · 合計 1,200個 · 前回 500個（2026/10/01） · 平均 400個'), findsOneWidget);
    expect(find.text('まだ仕入れていません（商品名の対応のみ）'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sup-tab-history')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sup-event-po-4')), findsOneWidget);
    expect(find.textContaining('ファイル取込 · 2026/10/01 · 1品目 · 500個 · ¥20,000'), findsOneWidget);
  });

  testWidgets('the next order: bought ones ticked with last quantities, adjusted, made into a request', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final requests = _FakeRequests();
    await pumpApp(tester, SupplierDetailScreen(supplierId: 41, today: DateTime(2026, 11, 2)), overrides: [
      supplierHistoryRepositoryProvider.overrideWithValue(_FakeHistory()),
      purchaseRequestRepositoryProvider.overrideWithValue(requests),
      requestSuppliersProvider.overrideWith((ref) async => [TradingPartner(id: 41, name: 'アケボノ商事')]),
    ]);

    bool ticked(String key) => tester.widget<Checkbox>(find.byKey(ValueKey('sup-check-$key'))).value!;
    String qty(String key) => tester.widget<TextField>(find.byKey(ValueKey('sup-qty-$key'))).controller!.text;

    expect(ticked('p1'), isTrue);
    expect(ticked('p2'), isTrue);
    expect(ticked('p3'), isFalse);
    expect(qty('p1'), '500');
    expect(qty('p2'), '100');
    expect(find.text('2品目 · 合計 600個'), findsOneWidget);
    // The one due is said so.
    expect(find.textContaining('約30日ごと · 次回目安 2026/10/31 · 目安を過ぎています'), findsOneWidget);

    // Averages instead.
    await tester.tap(find.byKey(const ValueKey('sup-qty-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('数量: 平均').last);
    await tester.pumpAndSettle();
    expect(qty('p1'), '400');

    // Only what is due, then one more by hand.
    await tester.tap(find.byKey(const ValueKey('sup-select-due')));
    await tester.pumpAndSettle();
    expect(ticked('p1'), isTrue);
    expect(ticked('p2'), isFalse);
    await tester.tap(find.byKey(const ValueKey('sup-check-p3')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('sup-qty-p3')), '50');
    await tester.pumpAndSettle();
    expect(find.text('2品目 · 合計 450個'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sup-make-request')));
    await tester.pumpAndSettle();
    final made = requests.saves.single;
    expect(made['supplier'], 41);
    expect(made['title'], 'アケボノ商事 次回注文（2026/11/02）');
    final lines = made['lines'] as List<RequestRow>;
    expect([for (final l in lines) (l.productId, l.quantity)], [(1, 400), (3, 50)]);
    expect(lines.first.supplierProductName, 'uniball ZENTO リフィル 黒');
    expect(lines.first.supplierCode, 'UBRZ05.24');
    // And it opens, ready to adjust and send.
    expect(find.byType(PurchaseRequestScreen), findsOneWidget);
  });

  testWidgets('a supplier with nothing yet says how products get there', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester, const SupplierDetailScreen(supplierId: 42), overrides: [
      supplierHistoryRepositoryProvider.overrideWithValue(_FakeHistory(json: {
        'supplier': {'id': 42, 'name': 'ウエダ商事'},
        'totals': {'purchases': 0, 'units': 0},
        'products': [],
        'events': [],
      })),
      purchaseRequestRepositoryProvider.overrideWithValue(_FakeRequests()),
    ]);
    expect(find.text('この仕入先の商品はまだありません'), findsOneWidget);
    expect(find.text('まだ仕入れの記録はありません'), findsOneWidget);
    expect(find.byKey(const ValueKey('sup-make-request')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
