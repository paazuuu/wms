// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/auth/application/auth_controller.dart';
import 'package:wms_mobile/features/auth/domain/auth_user.dart';
import 'package:wms_mobile/features/delivery/application/delivery_providers.dart';
import 'package:wms_mobile/features/delivery/data/delivery_repository.dart';
import 'package:wms_mobile/features/delivery/domain/delivery_plan.dart';
import 'package:wms_mobile/features/delivery/domain/delivery_plan_line.dart';
import 'package:wms_mobile/features/delivery/presentation/delivery_plan_list_screen.dart';
import 'package:wms_mobile/features/delivery/presentation/plan_import_screen.dart';
import 'package:wms_mobile/features/delivery/presentation/reconciliation_screen.dart';
import 'package:wms_mobile/features/inbound/application/inbound_providers.dart';
import 'package:wms_mobile/features/inbound/domain/inbound.dart';
import 'package:wms_mobile/features/inbound/presentation/expected_receipt_screen.dart';
import 'package:wms_mobile/features/inbound/presentation/inbound_today_card.dart';
import 'package:wms_mobile/features/inbound/presentation/product_inbound_card.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';

import '../../support/harness.dart';

Override _signedIn(List<String> permissions) => authControllerProvider.overrideWith((ref) =>
    fakeAuthControllerFor(AuthUser(id: 'u1', email: 'a@b.test', name: '倉庫', permissions: permissions)));

DeliveryPlan _plan() => const DeliveryPlan(
      id: 1,
      deliveryNumber: 'DN-1',
      supplierName: 'ABC商事',
      lines: [
        DeliveryPlanLine(id: 11, janCode: '4902505632037', productName: 'ボルト', plannedQuantity: 5),
      ],
    );

ExpectedReceipt _receipt() => ExpectedReceipt.fromJson({
      'plan': {
        'id': 1,
        'delivery_number': 'DN-1',
        'supplier_name': 'ABC商事',
        'expected_arrival_date': '2026-10-10',
        'scheduled_inspection_date': null,
        'document_type': 'delivery_schedule',
        'receipt_state': 'PARTIALLY_RECEIVED',
        'today': '2026-10-06',
      },
      'lines': [
        {
          'id': 11, 'jan_code': '4902505632037', 'product_name': 'M8ボルト', 'supplier_product_name': '六角ボルト M8',
          'planned': 100, 'received': 60, 'remaining': 40, 'over': 0, 'state': 'PARTIALLY_RECEIVED',
        },
      ],
      'receipts': [
        {
          'id': 47, 'seq': 1, 'status': 'partial', 'arrived_on': '2026-10-04', 'units': 60,
          'lines': [{'jan_code': '4902505632037', 'product_name': 'M8ボルト', 'quantity': 60}],
          'inspection': {'id': 23, 'status': 'PENDING', 'scheduled_date': '2026-10-04'},
        },
      ],
      'documents': [
        {'id': 9, 'file_name': '納品予定表.pdf', 'storage_path': '2026/10/x.pdf', 'document_type': 'delivery_schedule',
         'uploaded_at': '2026-10-01T01:00:00Z'},
      ],
      'history': [
        {'at': '2026-10-01T01:00:00Z', 'event': 'inbound.expected_created', 'details': {'expected_arrival_date': null}},
        {'at': '2026-10-05T01:00:00Z', 'event': 'inbound.expected_date_changed',
         'details': {'field': 'expected_arrival_date', 'from': null, 'to': '2026-10-10'}},
      ],
    });

void main() {
  test('an OVER_RECEIPT refusal is read back into its lines', () {
    final lines = parseOverReceipt(
        'OVER_RECEIPT [{"over": 10, "planned": 100, "arriving": 50, "jan_code": "4902505451447", "received": 60, "remaining": 40, "product_name": "A"}]');
    expect(lines, isNotNull);
    expect(lines!.single.over, 10);
    expect(lines.single.remaining, 40);
    expect(parseOverReceipt('not permitted: receiving.confirm required'), isNull);
  });

  test('a file name says what kind of document it is', () {
    expect(DocumentType.guess('ウエダ商事_請求書_202610.pdf'), DocumentType.invoice);
    expect(DocumentType.guess('納品予定表.xlsx'), DocumentType.deliverySchedule);
    expect(DocumentType.guess('注文請書.pdf'), DocumentType.purchaseConfirmation);
    expect(DocumentType.guess('納品書0901.pdf'), DocumentType.deliveryNote);
    expect(DocumentType.guess('scan.jpg'), isNull);
  });

  test('how a line was tied says how sure it is', () {
    expect(matchPercent('jan'), 99);
    expect(matchPercent('manual'), 100);
    expect(matchPercent('name'), lessThan(kConfidentMatch));
    expect(matchPercent(null), isNull);
  });

  testWidgets('more than expected asks what to do, and sends the choice with the arrival date', (tester) async {
    final inbound = FakeInboundRepository()
      ..receiveFailures.add(
          'OVER_RECEIPT [{"over": 2, "planned": 5, "arriving": 7, "jan_code": "4902505632037", "received": 0, "remaining": 5, "product_name": "ボルト"}]');
    await pumpApp(
      tester,
      const ReconciliationScreen(planId: 1),
      overrides: [
        deliveryRepositoryProvider.overrideWithValue(FakeDeliveryRepository([_plan()])),
        inboundRepositoryProvider.overrideWithValue(inbound),
        _signedIn(const ['receiving.confirm']),
      ],
    );
    for (var i = 0; i < 7; i++) {
      await tester.enterText(find.byType(TextField), '4902505632037');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('recon-arrived-on')), findsOneWidget);
    await tester.tap(find.text('照合を完了'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完了'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('over-receipt-dialog')), findsOneWidget);
    expect(find.text('予定 5・入荷済 0・今回 7・超過 2'), findsOneWidget);
    // Accepting everything needs receiving.over_accept, which this user lacks.
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('over-accept'))).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('over-hold')));
    await tester.pumpAndSettle();

    expect(inbound.received, hasLength(2));
    expect(inbound.received.first.over, isNull);
    expect(inbound.received.last.over, OverReceiptChoice.hold);
    expect(inbound.received.last.arrivedOn, DateUtils.dateOnly(DateTime.now()));
  });

  testWidgets('the expected receipt shows what is left, each delivery with its inspection, files and history',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final inbound = FakeInboundRepository(receipt: _receipt());
    await pumpApp(
      tester,
      const ExpectedReceiptScreen(planId: 1),
      overrides: [inboundRepositoryProvider.overrideWithValue(inbound), _signedIn(const ['receiving.confirm'])],
    );

    expect(find.text('予定 100・入荷済 60・残 40'), findsWidgets);
    expect(find.text('2026/10/10'), findsOneWidget);
    expect(find.text('未定'), findsWidgets);
    expect(find.text('第1回入荷'), findsOneWidget);
    expect(find.text('検品予定 2026/10/04'), findsOneWidget);
    expect(find.text('納品予定表.pdf'), findsOneWidget);
    expect(find.text('予定入荷日: 未定 → 2026/10/10'), findsOneWidget);
    expect(find.byKey(const ValueKey('er-receive')), findsOneWidget);

    // The supplier gave no date after all: 未定 is a real answer.
    await tester.tap(find.byKey(const ValueKey('er-expected_arrival_date')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('planned-day-clear')));
    await tester.pumpAndSettle();
    expect(inbound.expectedSet.single.changes, {'expected_arrival_date': null});
  });

  testWidgets('a document already registered offers to open or update the plan it became', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final inbound = FakeInboundRepository(duplicatesFound: const [
      InboundDuplicate(planId: 7, deliveryNumber: 'DN-7', supplierName: 'ABC商事', reasons: ['same_file']),
    ]);
    final repo = FakeDeliveryRepository(
      [],
      preview: const ImportPreview(
        source: 'xlsx', lineCount: 1, totalQuantity: 3, documentId: 55, deliveryNumber: 'DN-7',
        lines: [{'jan_code': '4901234567894', 'product_name': 'ボールペン', 'planned_quantity': 3}],
      ),
    );
    await pumpApp(
      tester,
      PlanImportScreen(
          pickFile: () async => PlatformFile(name: '納品予定表.xlsx', size: 3, bytes: Uint8List.fromList([1, 2, 3]))),
      overrides: [deliveryRepositoryProvider.overrideWithValue(repo), inboundRepositoryProvider.overrideWithValue(inbound)],
    );
    await tester.tap(find.text('ファイルを選ぶ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('読み取る'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('import-duplicates')), findsOneWidget);
    expect(find.textContaining('同じファイル'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dup-update-7')));
    await tester.pumpAndSettle();
    expect(inbound.expectedSet.single.planId, 7);
    expect(inbound.expectedSet.single.documentId, 55);
    expect(inbound.expectedSet.single.changes['document_type'], 'delivery_schedule');
    expect(repo.lastCommit, isNull, reason: 'no second plan is made');
  });

  testWidgets('a line nobody placed shows candidates, and the dates go with the new plan', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final inbound = FakeInboundRepository(candidates: const {
      0: [MatchCandidate(productId: 5, name: 'M8ボルト', janCode: '4900000000005', score: 0.68, reasons: ['name'])],
    });
    final repo = FakeDeliveryRepository(
      [],
      preview: const ImportPreview(
        source: 'xlsx', lineCount: 1, totalQuantity: 3, documentId: 56, deliveryNumber: 'DN-8',
        lines: [{'jan_code': '', 'product_name': 'ABC ボルト M8 100本', 'planned_quantity': 3}],
      ),
    );
    await pumpApp(
      tester,
      PlanImportScreen(pickFile: () async => PlatformFile(name: '請求書.pdf', size: 3, bytes: Uint8List.fromList([1]))),
      overrides: [deliveryRepositoryProvider.overrideWithValue(repo), inboundRepositoryProvider.overrideWithValue(inbound)],
    );
    await tester.tap(find.text('ファイルを選ぶ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('読み取る'));
    await tester.pumpAndSettle();

    // An invoice is never goods received.
    expect(find.byKey(const ValueKey('import-invoice-note')), findsOneWidget);
    expect(find.text('M8ボルト  68%'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('import-candidate-0-0')));
    await tester.pumpAndSettle();
    expect(find.text('一致度 100%'), findsOneWidget);

    await tester.tap(find.text('登録する'));
    await tester.pumpAndSettle();
    expect(repo.lastCommit!.lines.single['product_id'], 5);
    expect(inbound.expectedSet.single.changes, {'document_type': 'invoice'});
    expect(inbound.expectedSet.single.documentId, 56);
  });

  testWidgets('a plan card says how much is expected, received and left, and when', (tester) async {
    final plan = DeliveryPlan.fromJson({
      'id': 3, 'delivery_number': 'DN-3', 'supplier_name': 'XYZ', 'status': 'partial',
      'receipt_state': 'PARTIALLY_RECEIVED', 'planned_units': 160, 'received_units': 60, 'remaining_units': 100,
    });
    await pumpApp(tester, const DeliveryPlanListScreen(), overrides: [
      deliveryRepositoryProvider.overrideWithValue(FakeDeliveryRepository([plan])),
    ]);
    expect(find.text('予定 160・入荷済 60・残 100'), findsOneWidget);
    expect(find.text('予定日 未定'), findsOneWidget);
    expect(find.text('一部入荷'), findsWidgets);
  });

  testWidgets('today\'s inbound counts what is due, waiting for inspection and for put-away', (tester) async {
    final inbound = FakeInboundRepository(todayCounts: const InboundToday(dueToday: 3, overdue: 1, awaitingInspection: 5, putawayWaiting: 7));
    await pumpApp(tester, const Scaffold(body: InboundTodayCard()), overrides: [
      inboundRepositoryProvider.overrideWithValue(inbound),
      activeWarehouseIdProvider.overrideWith((ref) => 1),
    ]);
    expect(find.text('今日の入荷'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('遅れ 1'), findsOneWidget);
  });

  testWidgets('a product shows what each supplier calls it and what came in', (tester) async {
    final inbound = FakeInboundRepository(history: ProductInboundHistory.fromJson({
      'supplier_names': [
        {'supplier_display_name': 'ABC商事', 'supplier_name': 'M8 六角ボルト 50本', 'supplier_code': 'AB-M8-50'},
      ],
      'receipts': [
        {'plan_id': 1, 'arrived_on': '2026-10-04', 'supplier_name': 'ABC商事', 'quantity': 60,
         'inspection': {'status': 'COMPLETED', 'passed': 58, 'failed': 2}},
      ],
    }));
    await pumpApp(tester, const Scaffold(body: SingleChildScrollView(child: ProductInboundCard(productId: 216))),
        overrides: [inboundRepositoryProvider.overrideWithValue(inbound)]);
    expect(find.text('ABC商事「M8 六角ボルト 50本」 · AB-M8-50'), findsOneWidget);
    expect(find.text('合格 58・不合格 2'), findsOneWidget);
  });
}
