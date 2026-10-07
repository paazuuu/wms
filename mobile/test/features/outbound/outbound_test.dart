// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/core/export/xlsx.dart';
import 'package:wms_mobile/features/outbound/data/outbound_excel.dart';
import 'package:wms_mobile/features/outbound/data/outbound_repository.dart';
import 'package:wms_mobile/features/outbound/domain/outbound.dart';
import 'package:wms_mobile/features/outbound/domain/pricing.dart';
import 'package:wms_mobile/features/outbound/presentation/outbound_downloads.dart';
import 'package:wms_mobile/features/outbound/presentation/outbound_proposal_screen.dart';
import 'package:wms_mobile/features/outbound/presentation/ship_destinations_screen.dart';
import 'package:wms_mobile/features/shipment/domain/sender_profile.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';

import '../../support/harness.dart';

const _janA = '4909999000014';
const _janB = '4909999000021';

class _FakeOutboundRepository implements OutboundRepository {
  _FakeOutboundRepository({List<ShipDestination>? destinations, List<OutboundStockItem>? stock})
      : dests = destinations ?? [],
        stockItems = stock ?? [];

  List<ShipDestination> dests;
  List<OutboundStockItem> stockItems;
  final List<ShipDestination> saved = [];
  final List<int> retired = [];
  final List<Map<String, dynamic>> created = [];
  int exports = 0;

  @override
  Future<ApiResult<List<ShipDestination>>> destinations({String? search}) async => ApiSuccess(dests);

  @override
  Future<ApiResult<int>> saveDestination(ShipDestination d) async {
    saved.add(d);
    final id = d.id ?? 100 + saved.length;
    dests = [
      ...dests.where((x) => x.id != id),
      ShipDestination(id: id, name: d.name, department: d.department, address1: d.address1, phone: d.phone),
    ];
    return ApiSuccess(id);
  }

  @override
  Future<ApiResult<bool>> retireDestination(int id) async {
    retired.add(id);
    dests = dests.where((d) => d.id != id).toList();
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<List<OutboundStockItem>>> stock(int warehouseId) async => ApiSuccess(stockItems);

  @override
  Future<ApiResult<OutboundCreated>> create({
    required int warehouseId,
    required Map<String, int> lines,
    Map<String, double> prices = const {},
    Map<String, Map<String, double?>> snapshots = const {},
    int? destinationId,
    Map<String, dynamic>? shipTo,
    String? shipDate,
    String? note,
    Map<String, dynamic>? proposal,
  }) async {
    created.add({
      'warehouse': warehouseId,
      'lines': lines,
      'prices': prices,
      'snapshots': snapshots,
      'destination': destinationId,
      'proposal': proposal,
      'note': note,
    });
    return ApiSuccess(OutboundCreated(
        id: 9, shipmentNumber: 'OUT-000009', lines: lines.length, units: lines.values.fold(0, (s, v) => s + v)));
  }

  @override
  Future<ApiResult<OutboundSheet>> sheet(int shipmentId) async => ApiSuccess(OutboundSheet(
        id: shipmentId,
        shipmentNumber: 'OUT-000009',
        shipTo: dests.isEmpty ? null : dests.first,
        lines: [OutboundSheetLine(janCode: _janA, name: 'ボルト', quantity: 5)],
      ));

  @override
  Future<ApiResult<List<StockExportRow>>> stockExport({int? warehouseId}) async {
    exports++;
    return ApiSuccess([
      StockExportRow(warehouseName: '本社倉庫', janCode: _janA, name: 'ボルト', onHand: 10, reserved: 2),
    ]);
  }
}

const _items = [
  OutboundStockItem(janCode: _janA, name: 'ボルト', onHand: 10, reserved: 2, inOpen: 2, free: 6, nameEn: 'Bolt',
      costPrice: 42, listPrice: 100, sellPrice: 80),
  OutboundStockItem(janCode: _janB, name: 'ナット', onHand: 4, free: 4, listPrice: 50),
];

Future<(_FakeOutboundRepository, List<(String, Uint8List)>)> _pump(WidgetTester tester, {
  List<ShipDestination>? destinations,
}) async {
  await tester.binding.setSurfaceSize(const Size(1000, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final repo = _FakeOutboundRepository(
    destinations: destinations ?? [ShipDestination(id: 1, name: 'テスト商事', department: '物流部', address1: '東京都千代田区1-1')],
    stock: [..._items],
  );
  final saved = <(String, Uint8List)>[];
  await pumpApp(tester, const OutboundProposalScreen(), overrides: [
    outboundRepositoryProvider.overrideWithValue(repo),
    writeWarehouseIdProvider.overrideWithValue(1),
    saveFileProvider.overrideWithValue((name, bytes) async => saved.add((name, bytes))),
  ]);
  return (repo, saved);
}

Future<void> _chooseDestination(WidgetTester tester, String name) async {
  await tester.tap(find.byWidgetPredicate((w) => w is DropdownButtonFormField<int>).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

void main() {
  group('proposal', () {
    test('a percentage of the stock, in whole units, never over what is free', () {
      expect(proposeByPercent(_items, 30), {_janA: 3, _janB: 1});
      // 70% of 10 is 7, but only 6 are free.
      expect(proposeByPercent(_items, 70), {_janA: 6, _janB: 2});
      expect(proposeByPercent(_items, 50, base: ProposalBase.free), {_janA: 3, _janB: 2});
      expect(proposeByPercent(_items, 30, rounding: ProposalRounding.up), {_janA: 3, _janB: 2});
      expect(proposeByPercent(_items, 30, rounding: ProposalRounding.nearest), {_janA: 3, _janB: 1});
      expect(proposeByPercent(_items, 100), {_janA: 6, _janB: 4});
      expect(proposeByPercent(_items, 0), {_janA: 0, _janB: 0});
    });

    test('the shipment sheet carries the destination, the sender and the lines with a total', () {
      final bytes = buildShipmentSheetXlsx(
        number: 'OUT-000009',
        to: ShipDestination(name: 'テスト商事', department: '物流部', contactName: '山田', postalCode: '100-0001', address1: '東京都千代田区1-1', phone: '03-0000-0000'),
        lines: [
          OutboundSheetLine(janCode: _janA, name: 'ボルト', quantity: 5, nameEn: 'Bolt'),
          OutboundSheetLine(janCode: _janB, name: 'ナット', quantity: 2),
        ],
        sender: SenderProfile(companyName: '自社株式会社', address: '大阪市', phone: '06-0000-0000'),
        shipDate: '2026-10-10',
      );
      final t = readXlsx(bytes);
      final flat = t.expand((r) => r).toList();
      expect(flat, containsAll(['OUT-000009', 'テスト商事', '物流部', '山田 様', '〒100-0001 東京都千代田区1-1', '03-0000-0000',
        '自社株式会社', '2026-10-10']));
      final header = t.indexWhere((r) => r.isNotEmpty && r.first == 'No.');
      expect(t[header + 1].take(4), ['1', _janA, 'ボルト', 'Bolt']);
      expect(t[header + 1][6], '5');
      expect(t.last[5], '合計 / Total');
      expect(t.last[6], '7');
      expect(shipmentSheetFileName('OUT-000009', 'テスト 商事', now: DateTime(2026, 10, 10)), '出荷明細_OUT-000009_テスト_商事_20261010.xlsx');
    });

    test('the sheet shows the prices chosen, and an amount with its total', () {
      final t = readXlsx(buildShipmentSheetXlsx(
        number: 'OUT-000010',
        to: null,
        lines: [
          OutboundSheetLine(janCode: _janA, name: 'ボルト', quantity: 3, unitPrice: 123.4, costPrice: 42, listPrice: 100),
          OutboundSheetLine(janCode: _janB, name: 'ナット', quantity: 2, unitPrice: 60),
        ],
        priceColumns: [PriceColumn.ship, PriceColumn.cost],
      ));
      final header = t.indexWhere((r) => r.isNotEmpty && r.first == 'No.');
      // Fixed order: 原価 before 単価, whatever order they were ticked in.
      expect(t[header].sublist(8), ['原価 / Cost', '単価 / Unit price', '金額 / Amount']);
      expect(double.parse(t[header + 1][8]), 42);
      expect(double.parse(t[header + 1][9]), 123.4);
      expect(double.parse(t[header + 1][10]), closeTo(370.2, 1e-9));
      expect(t[header + 2].length < 9 || t[header + 2][8].isEmpty, isTrue);
      expect(double.parse(t.last[10]), closeTo(490.2, 1e-9));

      // Only 定価: the amount goes by it.
      final l = readXlsx(buildShipmentSheetXlsx(
        number: 'OUT-000011',
        to: null,
        lines: [OutboundSheetLine(janCode: _janA, name: 'ボルト', quantity: 3, listPrice: 100)],
        priceColumns: [PriceColumn.list],
      ));
      final h = l.indexWhere((r) => r.isNotEmpty && r.first == 'No.');
      expect(l[h].sublist(8), ['定価 / List price', '金額 / Amount']);
      expect(double.parse(l[h + 1][9]), 300);

      // No prices chosen: no price columns at all.
      final n = readXlsx(buildShipmentSheetXlsx(
        number: 'OUT-000012',
        to: null,
        lines: [OutboundSheetLine(janCode: _janA, name: 'ボルト', quantity: 3, unitPrice: 10)],
      ));
      expect(n[n.indexWhere((r) => r.isNotEmpty && r.first == 'No.')].length, 8);
    });

    test('the stock list adds up', () {
      final t = readXlsx(buildStockListXlsx([
        StockExportRow(warehouseName: 'A', janCode: _janA, name: 'ボルト', onHand: 10, reserved: 2),
        StockExportRow(warehouseName: 'A', janCode: _janB, name: 'ナット', onHand: 4),
      ]));
      final header = t.indexWhere((r) => r.isNotEmpty && r.first == '倉庫');
      expect(t[header + 1][2], _janA);
      expect(t[header + 1][10], '8');
      expect(t.last.sublist(8, 11), ['14', '2', '12']);
    });
  });

  testWidgets('a percentage is proposed, capped, corrected and made into a shipment with its sheet', (tester) async {
    final (repo, saved) = await _pump(tester);
    expect(find.text('全在庫 10 ・引当 2 ・出庫予定 2 ・出荷可能 6'), findsOneWidget);

    await _chooseDestination(tester, 'テスト商事 物流部');
    expect(find.byKey(const ValueKey('ob-dest-summary')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('ob-percent')), '50');
    await tester.tap(find.byKey(const ValueKey('ob-propose')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const ValueKey('ob-qty-$_janA'))).controller!.text, '5');
    expect(tester.widget<TextField>(find.byKey(const ValueKey('ob-qty-$_janB'))).controller!.text, '2');
    expect(find.text('2品目・合計 7個'), findsOneWidget);

    // Over what is free: said beside the line, and refused.
    await tester.enterText(find.byKey(const ValueKey('ob-qty-$_janA')), '7');
    await tester.pumpAndSettle();
    expect(find.text('最大 6'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ob-create')));
    await tester.pumpAndSettle();
    expect(repo.created, isEmpty);
    expect(find.text('「ボルト」は出荷可能数（6）を超えています'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('ob-qty-$_janA')), '6');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ob-create')));
    await tester.pumpAndSettle();
    expect(repo.created.single['lines'], {_janA: 6, _janB: 2});
    expect(repo.created.single['destination'], 1);
    expect((repo.created.single['proposal'] as Map)['mode'], 'percent');
    expect(find.byKey(const ValueKey('ob-created')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ob-sheet')));
    await tester.pumpAndSettle();
    expect(saved.single.$1, startsWith('出荷明細_OUT-000009_テスト商事_'));
    expect(readXlsx(saved.single.$2).expand((r) => r), contains('テスト商事'));
  });

  testWidgets('quantities typed by hand; an unticked product stays; a draft sheet before saving', (tester) async {
    final (repo, saved) = await _pump(tester);
    await tester.tap(find.text('数量を直接入力'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('ob-qty-$_janA')), '3');
    await tester.enterText(find.byKey(const ValueKey('ob-qty-$_janB')), '4');
    await tester.tap(find.byKey(const ValueKey('ob-check-$_janB')));
    await tester.pumpAndSettle();
    expect(find.text('1品目・合計 3個'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ob-draft')));
    await tester.pumpAndSettle();
    expect(saved.single.$1, startsWith('出荷明細_下書き_'));
    expect(readXlsx(saved.single.$2).expand((r) => r), contains('（下書き / Draft）'));

    // Without a destination nothing is made.
    await tester.tap(find.byKey(const ValueKey('ob-create')));
    await tester.pumpAndSettle();
    expect(repo.created, isEmpty);
    expect(find.text('出荷先を選ぶか、新しく登録してください'), findsOneWidget);
  });

  testWidgets('a new destination is saved and chosen on the way', (tester) async {
    final (repo, _) = await _pump(tester, destinations: []);
    await tester.tap(find.byKey(const ValueKey('ob-dest-new')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sd-save')));
    await tester.pumpAndSettle();
    expect(find.text('会社名を入れてください'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('sd-name')), '新規商会');
    await tester.enterText(find.byKey(const ValueKey('sd-address1')), '横浜市1-2');
    await tester.enterText(find.byKey(const ValueKey('sd-phone')), '045-000-0000');
    await tester.tap(find.byKey(const ValueKey('sd-save')));
    await tester.pumpAndSettle();
    expect(repo.saved.single.name, '新規商会');
    expect(find.byKey(const ValueKey('ob-dest-summary')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('ob-percent')), '100');
    await tester.tap(find.byKey(const ValueKey('ob-propose')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ob-create')));
    await tester.pumpAndSettle();
    expect(repo.created.single['destination'], 101);
    expect(repo.created.single['lines'], {_janA: 6, _janB: 4});
  });

  testWidgets('prices are set in bulk from a chosen column, by a rate, a percentage or a formula, and go with the shipment',
      (tester) async {
    final (repo, saved) = await _pump(tester);
    expect(find.text('原価 42 · 定価 100 · 販売価格 80'), findsOneWidget);
    expect(find.text('原価 — · 定価 50 · 販売価格 —'), findsOneWidget);
    await _chooseDestination(tester, 'テスト商事 物流部');
    await tester.tap(find.text('数量を直接入力'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('ob-qty-$_janA')), '3');
    await tester.enterText(find.byKey(const ValueKey('ob-qty-$_janB')), '2');
    await tester.pumpAndSettle();

    String price(String jan) => tester.widget<TextField>(find.byKey(ValueKey('ob-price-$jan'))).controller!.text;

    // 原価 × 1.3: the nut has no 原価 and is left alone.
    await tester.tap(find.byKey(const ValueKey('ob-price-apply')));
    await tester.pumpAndSettle();
    expect(price(_janA), '55');
    expect(price(_janB), '');
    expect(find.text('1 件を設定、1 件は基準の値が無いため変えていません'), findsOneWidget);

    // 定価 − 45%, up to the next 10 yen.
    await tester.tap(find.byKey(const ValueKey('ob-price-base')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('定価').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('％').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('ob-price-value')), '-45');
    await tester.tap(find.byKey(const ValueKey('ob-price-step')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10円単位').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ob-price-rounding')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('端数切り上げ').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ob-price-apply')));
    await tester.pumpAndSettle();
    expect(price(_janA), '60');
    expect(price(_janB), '30');
    expect(find.text('2 件の出荷単価を設定しました'), findsOneWidget);
    expect(find.text('出荷金額の合計 ¥240'), findsOneWidget);

    // The price after that, + 10%, as a formula on 基準 (今の出荷単価).
    await tester.tap(find.byKey(const ValueKey('ob-price-base')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('今の出荷単価（掛け率後）').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('式').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('ob-price-formula')), 'ROUNDUP(基準*1.1, -1');
    await tester.tap(find.byKey(const ValueKey('ob-price-apply')));
    await tester.pumpAndSettle();
    expect(find.textContaining('式が読めません'), findsOneWidget);
    expect(price(_janA), '60');
    await tester.enterText(find.byKey(const ValueKey('ob-price-formula')), 'ROUNDUP(基準*1.1, -1)');
    await tester.tap(find.byKey(const ValueKey('ob-price-apply')));
    await tester.pumpAndSettle();
    expect(price(_janA), '70');
    expect(price(_janB), '40');

    // By hand, under 原価: said beside the line.
    await tester.enterText(find.byKey(const ValueKey('ob-price-$_janA')), '40');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ob-loss-$_janA')), findsOneWidget);
    expect(find.byKey(const ValueKey('ob-loss-$_janB')), findsNothing);
    expect(find.text('出荷金額の合計 ¥200'), findsOneWidget);

    // The slip shows 原価 too.
    await tester.tap(find.byKey(const ValueKey('ob-col-cost')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ob-draft')));
    await tester.pumpAndSettle();
    final t = readXlsx(saved.single.$2);
    final header = t.indexWhere((r) => r.isNotEmpty && r.first == 'No.');
    expect(t[header].sublist(8), ['原価 / Cost', '単価 / Unit price', '金額 / Amount']);
    expect(double.parse(t.last[10]), 200);

    await tester.tap(find.byKey(const ValueKey('ob-create')));
    await tester.pumpAndSettle();
    final made = repo.created.single;
    expect(made['prices'], {_janA: 40.0, _janB: 40.0});
    expect(made['snapshots'], {
      _janA: {'cost': 42.0, 'list': 100.0, 'sell': 80.0},
      _janB: {'cost': null, 'list': 50.0, 'sell': null},
    });
    final proposal = made['proposal'] as Map;
    expect(proposal['price_columns'], ['cost', 'ship']);
    expect((proposal['pricing'] as Map)['method'], 'formula');
    expect((proposal['pricing'] as Map)['base'], 'ship');
    expect((proposal['pricing'] as Map)['formula'], 'ROUNDUP(基準*1.1, -1)');
  });

  testWidgets('all stock downloads as Excel', (tester) async {
    final (repo, saved) = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('ob-stock-excel')));
    await tester.pumpAndSettle();
    expect(repo.exports, 1);
    expect(saved.single.$1, startsWith('在庫一覧_'));
    expect(find.text('在庫一覧（1件）をExcelで保存しました'), findsOneWidget);
  });

  testWidgets('saved destinations are listed and can be removed', (tester) async {
    final repo = _FakeOutboundRepository(destinations: [
      ShipDestination(id: 1, name: 'テスト商事', contactName: '山田', address1: '東京都', phone: '03', useCount: 4),
    ]);
    await pumpApp(tester, const ShipDestinationsScreen(), overrides: [outboundRepositoryProvider.overrideWithValue(repo)]);
    expect(find.text('テスト商事'), findsOneWidget);
    expect(find.textContaining('使った回数: 4'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sd-retire-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sd-retire-ok')));
    await tester.pumpAndSettle();
    expect(repo.retired, [1]);
    expect(find.text('保存した出荷先はまだありません'), findsOneWidget);
  });
}
