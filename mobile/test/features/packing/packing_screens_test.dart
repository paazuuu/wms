import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/export/xlsx.dart';
import 'package:wms_mobile/core/ui/open_window.dart';
import 'package:wms_mobile/features/outbound/domain/outbound.dart';
import 'package:wms_mobile/features/outbound_file/data/outbound_file_repository.dart';
import 'package:wms_mobile/features/outbound_file/presentation/outbound_file_detail_screen.dart';
import 'package:wms_mobile/features/outbound_file/presentation/outbound_file_screen.dart';
import 'package:wms_mobile/features/outbound_file/presentation/outbound_hub_screen.dart';
import 'package:wms_mobile/features/packing/data/packing_repository.dart';
import 'package:wms_mobile/features/packing/domain/packing.dart';
import 'package:wms_mobile/features/packing/domain/packing_list_reader.dart';
import 'package:wms_mobile/features/packing/presentation/packing_lists_screen.dart';
import 'package:wms_mobile/features/packing/presentation/packing_screen.dart';
import 'package:wms_mobile/features/packing/presentation/packing_settings_screen.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';

import '../../support/fake_outbound_file_repository.dart';
import '../../support/fake_packing_repository.dart';
import '../../support/harness.dart';

class _Tab implements HtmlTab {
  final pages = <String>[];

  @override
  void show(String html) => pages.add(html);

  @override
  void close() {}

  @override
  void showBytes(List<int> bytes, String contentType) {}
}

final _plan = OutboundFileSummary(
  id: 5,
  warehouseId: 1,
  shippedOn: DateTime(2026, 11, 20),
  plannedOn: DateTime(2026, 11, 20),
  fileName: '到货明细.xlsx',
  status: 'planned',
  lineCount: 2,
  quantityTotal: 35,
  shipTo: const ShipDestination(id: 31, name: 'テスト貿易', nameEn: 'Test Trading', port: 'Shanghai'),
);

final _detail = OutboundFileDetail(file: _plan, lines: const [
  OutboundFileLine(id: 1, rowNo: 2, action: 'ship', productId: 1, jan: '4909999000014', productName: 'テストペン', quantity: 30, unitWeightG: 100),
  OutboundFileLine(id: 2, rowNo: 3, action: 'ship', productId: 2, jan: '4909999000021', productName: 'テストノート', quantity: 5, unitWeightG: 200),
  OutboundFileLine(id: 3, rowNo: 4, action: 'skip', productId: 3, jan: '4909999000038', productName: '外す行', quantity: 9),
]);

void main() {
  Future<({FakePackingRepository repo, _Tab tab, List<String> saved})> pumpPacking(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakePackingRepository(cases: const [
      CasePack(productId: 1, caseQuantity: 24, lengthCm: 30, widthCm: 20, heightCm: 10, grossKg: 2.6),
    ]);
    final tab = _Tab();
    final saved = <String>[];
    await pumpApp(tester, const PackingScreen(fileId: 5), overrides: [
      packingRepositoryProvider.overrideWithValue(repo),
      outboundFileRepositoryProvider.overrideWithValue(FakeOutboundFileRepository(detailOf: (_) => _detail)),
      outboundTabOpenerProvider.overrideWithValue(() => tab),
      outboundFileSaverProvider.overrideWithValue((n, b) async => saved.add(n)),
      writeWarehouseIdProvider.overrideWithValue(1),
    ]);
    return (repo: repo, tab: tab, saved: saved);
  }

  testWidgets('boxes are worked out: full cases as they are, the rest in the smallest carton that holds it', (tester) async {
    final t = await pumpPacking(tester);
    expect(find.byKey(const ValueKey('pk-box-0')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('pk-plan')));
    await tester.pumpAndSettle();

    final boxes = t.repo.saved[5]!;
    expect(boxes, hasLength(2));
    expect(boxes[0].ownCase, isTrue);
    expect(boxes[0].items.single.quantity, 24);
    expect(boxes[1].cartonType, '80サイズ');
    expect(boxes[1].items.map((i) => i.quantity), [6, 5]);
    expect(boxes[1].estKg, 1.9);
    expect(find.text('2箱 · 数量 35 · 4.5 kg · 0.0235 m³'), findsOneWidget);
    expect(find.text('出荷明細の数量と合っています'), findsOneWidget);
    expect(find.text('確認済み 0 / 2 箱'), findsOneWidget);
  });

  testWidgets('on the floor: a scan ticks the product, counts and weights are written, a box is checked', (tester) async {
    final t = await pumpPacking(tester);
    await tester.tap(find.byKey(const ValueKey('pk-plan')));
    await tester.pumpAndSettle();
    final ids = [for (final b in t.repo.saved[5]!) b.id];

    // The note is in box 2: scanning it there makes box 2 the one packed.
    await tester.enterText(find.byKey(const ValueKey('pk-scan')), '4909999000021');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(t.repo.updates.last.$1, ids[1]);
    expect((t.repo.updates.last.$2['lines'] as List).single['checked'], isTrue);
    expect(find.text('2 の品目です'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('pk-scan')), '4909999999999');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('JAN 4909999999999 はどの箱にもありません'), findsOneWidget);

    // One pen fewer: the list no longer matches, the weight is worked out again.
    await tester.tap(find.byKey(const ValueKey('pk-qty-1-0')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('pk-qty-field')), '5');
    await tester.tap(find.byKey(const ValueKey('pk-qty-ok')));
    await tester.pumpAndSettle();
    expect(t.repo.updates.last.$2['est_kg'], 1.8);
    expect(find.text('出荷明細と合わない品目: 1'), findsOneWidget);
    expect(find.text('テストペン: 明細 30 / 箱 29'), findsOneWidget);

    // Weighed far heavier than worked out.
    await tester.enterText(find.byKey(const ValueKey('pk-gross-1-null')), '3');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(t.repo.updates.last.$2, {'gross_kg': 3.0});
    expect(find.byKey(const ValueKey('pk-off-1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pk-box-check-0')));
    await tester.pumpAndSettle();
    expect(t.repo.updates.last.$1, ids[0]);
    expect(t.repo.updates.last.$2, {'checked': true});
    expect(find.text('確認済み 1 / 2 箱'), findsOneWidget);
  });

  testWidgets('labels are printed and the packing list is made, kept and saved', (tester) async {
    final t = await pumpPacking(tester);
    await tester.tap(find.byKey(const ValueKey('pk-plan')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('pk-labels')));
    await tester.pumpAndSettle();
    expect(t.tab.pages.single, contains('Test Trading'));
    expect(t.tab.pages.single, contains('C/No. 2 / 2'));

    await tester.tap(find.byKey(const ValueKey('pk-make-list')));
    await tester.pumpAndSettle();
    expect(t.saved, ['PackingList_到货明细.xlsx']);
    final rec = t.repo.records.single;
    expect(rec.source, 'generated');
    expect(rec.fileId, 5);
    expect(rec.boxes, 2);
    final back = await readPackingList(t.repo.files[rec.improvedPath]!);
    expect(back.boxes.map((b) => b.quantity), [24, 11]);
    final sheets = readXlsxSheets(t.repo.files[rec.improvedPath]!);
    expect(sheets.first.rows.any((r) => r.any((c) => c.contains('Test Trading'))), isTrue);
    // The 明細 goes with it: the rows shipped (not the one left out), all packed.
    expect(sheets[1].name, '明細');
    expect([for (final r in sheets[1].rows.skip(1)) r.length > 6 ? r[6] : ''], ['30', '5', '35']);
    expect(sheets[4].rows.skip(1).map((r) => r.last), ['0', '0']);
  });

  testWidgets('a packing list uploaded: the AI names its columns, both files are kept, cases learned', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // Headings the words do not tell: the AI is asked.
    final book = buildXlsxBook([
      const XlsxSheet(name: 'PL-HL', headers: ['甲', '乙', '丙', '丁', '戊'], rows: [
        [1, 'TS-100', 24, '30*20*10', 2.6],
        [2, 'TS-100', 24, '30*20*10', 2.6],
        [3, 'TS-200', 3, '35*25*20', 1.1],
        [null, 'TS-300', 2],
      ]),
    ]);
    final repo = FakePackingRepository(ai: const {
      0: PlField.cartonNo, 1: PlField.itemCode, 2: PlField.quantity, 3: PlField.size, 4: PlField.cartonWeight,
    });
    final tab = _Tab();
    final saved = <String>[];
    await pumpApp(tester, const PackingListsScreen(), overrides: [
      packingRepositoryProvider.overrideWithValue(repo),
      packingListPickerProvider.overrideWithValue(() async => (name: 'PL_HL.xlsx', bytes: Uint8List.fromList(book))),
      outboundFileRepositoryProvider.overrideWithValue(FakeOutboundFileRepository(
        matcher: (r) => r['code'] == 'TS-100'
            ? const OutboundMatch(matchedBy: OutboundMatchedBy.code, productId: 1, jan: '4909999000014', name: 'テストペン')
            : OutboundMatch.none,
      )),
      outboundTabOpenerProvider.overrideWithValue(() => tab),
      outboundFileSaverProvider.overrideWithValue((n, b) async => saved.add(n)),
      writeWarehouseIdProvider.overrideWithValue(1),
    ]);
    expect(find.byKey(const ValueKey('pk-lists-empty')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pk-upload')));
    await tester.pumpAndSettle();
    expect(repo.asked, [
      ['甲', '乙', '丙', '丁', '戊'],
    ]);
    expect(find.byKey(const ValueKey('pk-import-ai')), findsOneWidget);
    expect(find.text('3箱 · 数量 53 · 6.3 kg · 0.0295 m³'), findsOneWidget);
    expect(find.text('元箱と入数として覚える（1品目）'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pk-import-ok')));
    await tester.pumpAndSettle();

    expect(repo.files.keys, ['1/pl/1-PL_HL.xlsx', '1/pl/2-PL_HL_改善版.xlsx']);
    final rec = repo.records.single;
    expect(rec.source, 'upload');
    expect(rec.originalPath, '1/pl/1-PL_HL.xlsx');
    expect(rec.note, contains('PL-HL'));
    expect(repo.casesSaved.single.$2, 'packing_list');
    expect(repo.casesSaved.single.$1.single.caseQuantity, 24);
    expect(repo.casesSaved.single.$1.single.productId, 1);
    expect(find.text('パッキングリストを保管し、1品目の入数を覚えました'), findsOneWidget);
    expect(find.byKey(ValueKey('pk-list-${rec.id}')), findsOneWidget);

    // The improved one shown as a page, the JAN the library knows filled in.
    await tester.tap(find.byKey(ValueKey('pk-open-${rec.id}')));
    await tester.pumpAndSettle();
    expect(tab.pages.single, contains('4909999000014'));
    expect(tab.pages.single, contains('TS-300'));

    await tester.tap(find.byKey(ValueKey('pk-dl-original-${rec.id}')));
    await tester.pumpAndSettle();
    expect(saved, ['PL_HL.xlsx']);
  });

  testWidgets('段ボール: only our cartons (the makers’ cases are not set here any more)', (tester) async {
    final repo = FakePackingRepository();
    await pumpApp(tester, const PackingSettingsScreen(), overrides: [packingRepositoryProvider.overrideWithValue(repo)]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pk-settings-mode')), findsNothing);
    expect(find.text('80サイズ'), findsOneWidget);
  });

  testWidgets('the 出庫 hub has the packing lists and boxes; a list opens its packing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester, const OutboundHubScreen(tab: OutboundHubTab.packingLists), overrides: [
      writeWarehouseIdProvider.overrideWithValue(1),
    ]);
    expect(find.byKey(const ValueKey('pk-upload')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ob-hub-boxes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pk-cartons')), findsOneWidget);

    await pumpApp(tester, const OutboundFileDetailScreen(fileId: 5), overrides: [
      outboundFileRepositoryProvider.overrideWithValue(FakeOutboundFileRepository(detailOf: (_) => _detail)),
    ]);
    await tester.tap(find.byKey(const ValueKey('of-packing')));
    await tester.pumpAndSettle();
    expect(find.byType(PackingScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('pk-plan')), findsOneWidget);
  });
}
