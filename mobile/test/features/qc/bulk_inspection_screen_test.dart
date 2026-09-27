// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/qc/application/inspection_providers.dart';
import 'package:wms_mobile/features/qc/domain/bulk_inspection.dart';
import 'package:wms_mobile/features/qc/presentation/bulk_inspection_screen.dart';

import '../../support/harness.dart';

/// Two deliveries: yesterday's PO-1 with pens and notebooks, today's PO-2 with
/// more pens.
List<OpenInspectionLine> _lines() => [
      OpenInspectionLine(
          itemId: 1, inspectionId: 10, reconciliationId: 100, arrivedOn: DateTime(2026, 9, 26),
          supplierName: '新東光', purchaseOrderId: 7, poNumber: 'PO-1',
          productId: 4901, janCode: '4901', productName: 'ペン', quantity: 4),
      OpenInspectionLine(
          itemId: 2, inspectionId: 10, reconciliationId: 100, arrivedOn: DateTime(2026, 9, 26),
          supplierName: '新東光', purchaseOrderId: 7, poNumber: 'PO-1',
          productId: 4902, janCode: '4902', productName: 'ノート', quantity: 3),
      OpenInspectionLine(
          itemId: 3, inspectionId: 11, reconciliationId: 101, arrivedOn: DateTime(2026, 9, 27),
          supplierName: '大阪商事', purchaseOrderId: 8, poNumber: 'PO-2',
          productId: 4901, janCode: '4901', productName: 'ペン', quantity: 5),
    ];

Future<FakeInspectionRepository> _pump(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(900, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final repo = FakeInspectionRepository()..openLineList = _lines();
  final container = ProviderContainer(overrides: [
    inspectionRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  await pumpAppWith(tester, container, const BulkInspectionScreen());
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _passAndConfirm(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('bulk-qc-pass')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('bulk-qc-confirm')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('everything waiting starts selected and passes in one go', (tester) async {
    final repo = await _pump(tester);
    expect(find.text('選択 3 行・計 12 点'), findsOneWidget);
    await _passAndConfirm(tester);
    expect(repo.lastPassed, [1, 2, 3]);
    expect(find.text('3 行（12 点）を良品として確定しました'), findsOneWidget);
  });

  testWidgets('by arrival date, leaving one line open', (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('bulk-qc-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026-09-26').last);
    await tester.pumpAndSettle();
    expect(find.text('選択 2 行・計 7 点'), findsOneWidget);

    // The notebooks still want a closer look.
    await tester.tap(find.byKey(const ValueKey('bulk-qc-line-2')));
    await tester.pumpAndSettle();
    expect(find.text('選択 1 行・計 4 点'), findsOneWidget);

    await _passAndConfirm(tester);
    expect(repo.lastPassed, [1]);
  });

  testWidgets('by purchase order', (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('bulk-qc-po')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PO-2 · 大阪商事').last);
    await tester.pumpAndSettle();
    await _passAndConfirm(tester);
    expect(repo.lastPassed, [3]);
  });

  testWidgets('a scanned JAN narrows to that product across deliveries', (tester) async {
    final repo = await _pump(tester);
    await tester.enterText(find.byType(TextField).first, '4901');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('商品：ペン'), findsOneWidget);
    expect(find.text('選択 2 行・計 9 点'), findsOneWidget);
    await _passAndConfirm(tester);
    expect(repo.lastPassed, [1, 3]);
  });

  testWidgets('a JAN with nothing waiting is said so', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField).first, '9999');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('このJANの検品待ちはありません'), findsOneWidget);
    expect(find.text('選択 3 行・計 12 点'), findsOneWidget);
  });

  testWidgets('a whole delivery can be unticked from its header', (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.textContaining('入荷 2026-09-27'));
    await tester.pumpAndSettle();
    expect(find.text('選択 2 行・計 7 点'), findsOneWidget);
    await _passAndConfirm(tester);
    expect(repo.lastPassed, [1, 2]);
  });

  test('OpenInspectionLine reads the server row', () {
    final l = OpenInspectionLine.fromJson({
      'item_id': 5, 'inspection_id': 2, 'reconciliation_id': 9, 'arrived_on': '2026-09-26',
      'purchase_order_id': null, 'jan_code': '4901', 'quantity': 3, 'result': 'PASS',
    });
    expect(l.itemId, 5);
    expect(l.arrivedOn, DateTime(2026, 9, 26));
    expect(l.purchaseOrderId, isNull);
    expect(l.checked, isTrue);
  });
}
