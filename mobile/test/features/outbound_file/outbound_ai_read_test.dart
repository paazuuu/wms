import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/export/xlsx.dart';
import 'package:wms_mobile/features/master_import/data/master_import_repository.dart';
import 'package:wms_mobile/features/master_import/domain/master_import.dart';
import 'package:wms_mobile/features/outbound_file/data/outbound_file_repository.dart';
import 'package:wms_mobile/features/outbound_file/presentation/outbound_file_detail_screen.dart';
import 'package:wms_mobile/features/outbound_file/presentation/outbound_file_screen.dart';
import 'package:wms_mobile/features/stock_import/domain/ai_read_sheet.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';
import 'package:wms_mobile/features/warehouse_context/domain/warehouse.dart';

import '../../support/fake_outbound_file_repository.dart';
import '../../support/harness.dart';

OutboundMatch _match(Map<String, String?> r) => r['jan'] == '4909999000014'
    ? const OutboundMatch(matchedBy: OutboundMatchedBy.jan, productId: 1, jan: '4909999000014', name: 'テストペン', onHand: 100)
    : OutboundMatch.none;

void main() {
  test('what the AI read becomes a sheet read as an Excel is', () {
    final s = aiReadAsSheet(const [
      MasterLine(lineNo: 1, janCode: '4909999000014', name: 'テストペン', quantity: '5', ledger: {'unit_price': 120}),
      MasterLine(lineNo: 2, supplierCode: 'S-1', name: 'テスト品', quantity: '2'),
    ]);
    expect(s.rows.first, aiReadHeadings);
    expect(s.rows[1].take(5), ['4909999000014', '', 'テストペン', '', '5']);
    expect(s.rows[1][6], '120');
    expect(s.rows[2][1], 'S-1');
    expect(readsAsSheet('a.CSV'), isTrue);
    expect(readsAsSheet('a.jpeg'), isFalse);
  });

  testWidgets('a PDF shipping list: read by the AI, matched, registered; the reading kept as Excel', (tester) async {
    // Narrow: the PDF is not drawn beside the table in a test.
    await tester.binding.setSurfaceSize(const Size(1000, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeOutboundFileRepository(matcher: _match);
    final ai = FakeMasterImportRepository(
      readResult: const MasterRead(lines: [
        MasterLine(lineNo: 1, janCode: '4909999000014', name: 'テストペン', quantity: '5'),
      ]),
    );
    await pumpApp(tester, const OutboundFileScreen(), overrides: [
      outboundFileRepositoryProvider.overrideWithValue(repo),
      masterImportRepositoryProvider.overrideWithValue(ai),
      outboundFilePickerProvider.overrideWithValue(() async => (name: '明細.pdf', bytes: Uint8List.fromList([37, 80, 68, 70]))),
      writeWarehouseIdProvider.overrideWithValue(1),
      warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(const WarehouseOverview(
        warehouses: [Warehouse(id: 1, code: 'WH-01', name: '本倉庫')],
        totals: WarehouseTotals(),
      ))),
      activeWarehouseIdProvider.overrideWith((ref) => null),
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('of-pick')));
    await tester.pumpAndSettle();
    expect(ai.reads, 1);
    expect(find.byKey(const ValueKey('of-read-by-ai')), findsOneWidget);
    expect(find.byKey(const ValueKey('of-row-2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('of-post')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('of-post-ok')));
    await tester.pumpAndSettle();
    expect([for (final u in repo.uploaded) u.name], ['明細.pdf', '明細_読み取り結果.xlsx']);
    expect(repo.posted.single.path, '1/1-明細.pdf');
    expect([for (final l in repo.posted.single.lines) (l.productId, l.quantity)], [(1, 5)]);
    expect(repo.readPaths.values.single, '1/1-明細_読み取り結果.xlsx');
  });

  testWidgets('the detail offers the reading (Excel) beside the file', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final saved = <(String, Uint8List)>[];
    final f = OutboundFileSummary(
      id: 5, warehouseId: 1, shippedOn: DateTime(2026, 11, 20), fileName: '明細.pdf', status: 'planned',
      storagePath: '1/1-明細.pdf', readPath: '1/1-明細_読み取り結果.xlsx', lineCount: 1, quantityTotal: 5,
    );
    final repo = FakeOutboundFileRepository(detailOf: (_) => OutboundFileDetail(file: f, lines: const []))
      ..bytes = Uint8List.fromList(buildXlsxBook([const XlsxSheet(name: 'x', headers: ['a'], rows: [])]));
    await pumpApp(tester, const OutboundFileDetailScreen(fileId: 5), overrides: [
      outboundFileRepositoryProvider.overrideWithValue(repo),
      outboundFileSaverProvider.overrideWithValue((n, b) async => saved.add((n, b))),
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('of-download-read')));
    await tester.pumpAndSettle();
    expect(saved.single.$1, '明細_読み取り結果.xlsx');
  });
}
