import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/outbound/domain/outbound.dart';
import 'package:wms_mobile/features/outbound_file/data/outbound_file_repository.dart';
import 'package:wms_mobile/features/outbound_file/presentation/outbound_file_detail_screen.dart';
import 'package:wms_mobile/features/outbound_file/presentation/outbound_file_screen.dart';
import 'package:wms_mobile/features/outbound_file/presentation/outbound_hub_screen.dart';
import 'package:wms_mobile/features/packing/data/packing_repository.dart';
import 'package:wms_mobile/features/packing/domain/packing.dart';
import 'package:wms_mobile/features/packing/presentation/packing_screen.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';
import 'package:wms_mobile/features/warehouse_context/domain/warehouse.dart';

import '../../support/fake_outbound_file_repository.dart';
import '../../support/fake_packing_repository.dart';
import '../../support/harness.dart';

OutboundFileSummary _file({
  int id = 5,
  int warehouseId = 1,
  String warehouseName = '東京',
  String kind = 'stock',
  String status = 'planned',
  bool undecided = true,
  int? cartons,
  double? cartonKg,
  double? materialKg,
}) =>
    OutboundFileSummary(
      id: id,
      warehouseId: warehouseId,
      warehouseName: warehouseName,
      shippedOn: DateTime(2026, 11, 6),
      fileName: 'list-$id.xlsx',
      kind: kind,
      status: status,
      dateUndecided: undecided,
      lineCount: 3,
      quantityTotal: 44,
      packCartonCount: cartons,
      packCartonKg: cartonKg,
      packMaterialKg: materialKg,
      shipTo: const ShipDestination(id: 31, name: 'テスト貿易', nameEn: 'Test Trading'),
    );

OutboundFileDetail _detail(OutboundFileSummary f) => OutboundFileDetail(file: f, lines: const [
      OutboundFileLine(id: 1, rowNo: 2, action: 'ship', productId: 1, jan: '4909999000014', productName: 'テストペン', quantity: 30, unitWeightG: 100),
      OutboundFileLine(id: 2, rowNo: 3, action: 'ship', productId: 2, jan: '4909999000021', productName: 'テストノート', quantity: 5, unitWeightG: 200),
      // No product, no weight: counted apart.
      OutboundFileLine(id: 3, rowNo: 4, action: 'record', jan: '4909999000038', productName: '重さ不明', quantity: 9),
    ]);

const _warehouses = WarehouseOverview(
  warehouses: [
    Warehouse(id: 1, code: 'TKY', name: '東京'),
    Warehouse(id: 2, code: 'KOB', name: '神戸'),
  ],
  totals: WarehouseTotals(warehouseCount: 2),
);

void main() {
  test('the estimate: products by weight, cartons and material added; a product with no weight counted apart', () {
    final f = _file();
    final e = packEstimateOf(packDemandsOf(_detail(f)), cartonCount: 3, cartonKg: 0.6, materialKg: 1.5);
    expect(e.productKg, 4.0);
    expect(e.unknownRows, 1);
    expect(e.unknownQuantity, 9);
    expect(e.cartonsKg, 1.8);
    expect(e.totalKg, 7.3);
    expect(packEstimateOf(packDemandsOf(_detail(f))).undecided, isTrue);
    expect(packEstimateOf(packDemandsOf(_detail(f))).totalKg, 4.0);
  });

  Future<({FakePackingRepository packing, FakeOutboundFileRepository files})> pumpPacking(WidgetTester tester,
      {OutboundFileSummary? file}) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final packing = FakePackingRepository(cases: const [
      CasePack(productId: 1, caseQuantity: 24, lengthCm: 30, widthCm: 20, heightCm: 10, grossKg: 2.6),
    ]);
    final f = file ?? _file();
    final files = FakeOutboundFileRepository(detailOf: (_) => _detail(f));
    await pumpApp(tester, const PackingScreen(fileId: 5), overrides: [
      packingRepositoryProvider.overrideWithValue(packing),
      outboundFileRepositoryProvider.overrideWithValue(files),
      writeWarehouseIdProvider.overrideWithValue(1),
    ]);
    return (packing: packing, files: files);
  }

  testWidgets('packing starts 未定: no boxes made, the gross weight worked out from what is set and saved', (tester) async {
    final t = await pumpPacking(tester);
    // Nothing is made on its own.
    expect(t.packing.saved, isEmpty);
    expect(find.byKey(const ValueKey('pk-boxes-undecided')), findsOneWidget);
    expect(find.byKey(const ValueKey('pk-box-0')), findsNothing);

    expect(tester.widget<Text>(find.byKey(const ValueKey('pk-est-products'))).data, '4 kg');
    expect(find.byKey(const ValueKey('pk-est-unknown')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('pk-est-cartons'))).data, '未定');
    expect(tester.widget<Text>(find.byKey(const ValueKey('pk-est-total'))).data, '4 kg');

    await tester.enterText(find.byKey(const ValueKey('pk-est-count')), '3');
    await tester.enterText(find.byKey(const ValueKey('pk-est-carton-kg')), '0.6');
    await tester.enterText(find.byKey(const ValueKey('pk-est-material-kg')), '1.5');
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const ValueKey('pk-est-cartons'))).data, '1.8 kg');
    expect(tester.widget<Text>(find.byKey(const ValueKey('pk-est-total'))).data, '7.3 kg');

    await tester.tap(find.byKey(const ValueKey('pk-est-save')));
    await tester.pumpAndSettle();
    expect(t.files.packEstimates.single, (5, 3, 0.6, 1.5));
    expect(find.text('総重量の見積もりを保存しました'), findsOneWidget);
  });

  testWidgets('a carton count is suggested from the cases; the boxes can be put back to 未定', (tester) async {
    final t = await pumpPacking(tester, file: _file(cartons: 2, cartonKg: 0.5));
    expect(tester.widget<Text>(find.byKey(const ValueKey('pk-est-total'))).data, '5 kg');

    await tester.tap(find.byKey(const ValueKey('pk-est-suggest')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pk-est-suggested')), findsOneWidget);
    expect(t.packing.saved, isEmpty, reason: 'a suggestion makes no boxes');

    await tester.tap(find.byKey(const ValueKey('pk-plan')));
    await tester.pumpAndSettle();
    expect(t.packing.saved[5], isNotEmpty);
    await tester.tap(find.byKey(const ValueKey('pk-boxes-clear')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pk-boxes-clear-ok')));
    await tester.pumpAndSettle();
    expect(t.packing.saved[5], isEmpty);
    expect(find.byKey(const ValueKey('pk-boxes-undecided')), findsOneWidget);
  });

  testWidgets('the warehouse a planned list ships from is changed from its detail; a shipped one is not', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final files = FakeOutboundFileRepository(detailOf: (_) => _detail(_file(cartons: 2, cartonKg: 0.5)));
    await pumpApp(tester, const OutboundFileDetailScreen(fileId: 5), overrides: [
      outboundFileRepositoryProvider.overrideWithValue(files),
      warehouseOverviewProvider.overrideWith((ref) async => _warehouses),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('出庫元の倉庫: 東京'), findsOneWidget);
    expect(find.text('総重量の見積もり 5 kg'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('of-warehouse-change')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('of-warehouse-pick-2')));
    await tester.pumpAndSettle();
    expect(files.warehousesSet.single, (5, 2));
    expect(find.text('出庫元の倉庫を「神戸」にしました'), findsOneWidget);

    final shipped = FakeOutboundFileRepository(detailOf: (_) => _detail(_file(status: 'shipped', undecided: false)));
    await pumpApp(tester, const OutboundFileDetailScreen(fileId: 5), overrides: [
      outboundFileRepositoryProvider.overrideWithValue(shipped),
      warehouseOverviewProvider.overrideWith((ref) async => _warehouses),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('出庫元の倉庫: 東京'), findsOneWidget);
    expect(find.byKey(const ValueKey('of-warehouse-change')), findsNothing);
  });

  testWidgets('出荷手配 › 出庫日 未定: every warehouse, filtered by kind and warehouse, a day set, opened', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final files = FakeOutboundFileRepository(detailOf: (id) => _detail(_file(id: id)))
      ..undecidedFiles = [
        _file(id: 5),
        _file(id: 6, warehouseId: 2, warehouseName: '神戸', kind: 'proxy', status: 'shipped'),
      ];
    await pumpApp(tester, const OutboundHubScreen(tab: OutboundHubTab.undecided), overrides: [
      outboundFileRepositoryProvider.overrideWithValue(files),
      warehouseOverviewProvider.overrideWith((ref) async => _warehouses),
      // The one chosen at the top does not narrow this list.
      activeWarehouseIdProvider.overrideWith((ref) => 2),
    ]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ud-row-5')), findsOneWidget);
    expect(find.byKey(const ValueKey('ud-row-6')), findsOneWidget);
    expect(find.text('出庫日がまだ決まっていない出庫 2件'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ud-kind-proxy')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ud-row-5')), findsNothing);
    expect(find.byKey(const ValueKey('ud-row-6')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ud-kind-all')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ud-warehouse')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('東京').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ud-row-5')), findsOneWidget);
    expect(find.byKey(const ValueKey('ud-row-6')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('ud-set-day-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(files.rescheduled.single.$1, 5);

    await tester.tap(find.byKey(const ValueKey('ud-open-5')));
    await tester.pumpAndSettle();
    expect(find.byType(OutboundFileDetailScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('of-warehouse-change')), findsOneWidget);
  });

  test('the undecided tab sits after 在庫外出荷', () {
    expect(OutboundHubTab.values.indexOf(OutboundHubTab.undecided), 2);
    expect(outboundFileSaverProvider, isNotNull);
  });
}
