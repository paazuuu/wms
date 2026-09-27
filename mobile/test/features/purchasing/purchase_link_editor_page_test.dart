// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/purchasing/application/purchase_order_providers.dart';
import 'package:wms_mobile/features/purchasing/domain/purchase_order.dart';
import 'package:wms_mobile/features/purchasing/presentation/purchase_link_editor_page.dart';

import '../../support/harness.dart';

const _line = PurchaseOrderLine(
    id: 7, janCode: '4988601001053', productName: 'ノート', quantity: 6, received: 6, linked: 6);

FakePurchaseOrderRepository _repo() => FakePurchaseOrderRepository()
  ..linkCandidateList = const [
    PurchaseLinkCandidate(
        salesOrderLineId: 11, salesOrderId: 1, soNumber: 'SO-A', customerName: 'A商事',
        ordered: 4, promised: 4, linked: 4, filled: 4),
    PurchaseLinkCandidate(
        salesOrderLineId: 12, salesOrderId: 2, soNumber: 'SO-B', customerName: 'B物産',
        ordered: 5, promised: 2, backordered: 3, linked: 2, filled: 2),
  ];

Future<void> _pump(WidgetTester tester, FakePurchaseOrderRepository repo) async {
  await pumpApp(tester, const PurchaseLinkEditorPage(line: _line),
      overrides: [purchaseOrderRepositoryProvider.overrideWithValue(repo)]);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('cutting a link below what arrived warns and asks before saving',
      (tester) async {
    final repo = _repo();
    await _pump(tester, repo);

    // Move 3 of A's arrived goods to B.
    await tester.enterText(find.byKey(const ValueKey('po-link-edit-11')), '1');
    await tester.enterText(find.byKey(const ValueKey('po-link-edit-12')), '5');
    await tester.pump();
    expect(find.text('保存すると、この注文に引当済みの 3 個が解除されます'), findsOneWidget);
    expect(find.byKey(const ValueKey('po-link-releasing-12')), findsNothing);

    // Cancelling the dialog saves nothing.
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('引当を解除しますか？'), findsOneWidget);
    expect(find.text('SO-A · A商事：3 個を解除'), findsOneWidget);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(repo.lastSetDemands, isNull);

    // Confirming saves the new links.
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('po-link-release-confirm')));
    await tester.pumpAndSettle();
    expect(repo.lastSetDemands?.lineId, 7);
    expect(repo.lastSetDemands?.demands, [
      (salesOrderLineId: 11, quantity: 1),
      (salesOrderLineId: 12, quantity: 5),
    ]);
  });

  testWidgets('a change that keeps every reservation saves without asking',
      (tester) async {
    final repo = _repo()
      ..linkCandidateList = const [
        PurchaseLinkCandidate(
            salesOrderLineId: 11, salesOrderId: 1, soNumber: 'SO-A', customerName: 'A商事',
            ordered: 4, promised: 2, linked: 4, filled: 2),
      ];
    await _pump(tester, repo);

    await tester.enterText(find.byKey(const ValueKey('po-link-edit-11')), '3');
    await tester.pump();
    expect(find.byKey(const ValueKey('po-link-releasing-11')), findsNothing);

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('引当を解除しますか？'), findsNothing);
    expect(repo.lastSetDemands?.demands, [(salesOrderLineId: 11, quantity: 3)]);
  });
}
