// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/exceptions/application/exception_providers.dart';
import 'package:wms_mobile/features/exceptions/domain/warehouse_exception.dart';
import 'package:wms_mobile/features/exceptions/presentation/exception_list_screen.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';

import '../../support/harness.dart';

/// The lot-tracked product that arrived with no lot recorded: the blocker from
/// 0071's own test, and the one that must sort to the top.
WarehouseException _lotMissing() => WarehouseException(
      id: 1,
      exceptionType: 'LOT_MISSING',
      exceptionName: 'ロット未記録',
      category: 'RECEIVING',
      severity: ExceptionSeverity.blocker,
      status: ExceptionStatus.open,
      quantity: 10,
      janCode: '4901234567890',
      productName: 'ボールペン',
      note: 'LOT 管理の商品にロットが記録されていない',
      deliveryNumber: 'DN-1',
      supplierName: '文具商事',
      referenceNo: 'SUP-00001',
      createdAt: DateTime(2026, 9, 20, 10, 30),
    );

WarehouseException _shortfall() => WarehouseException(
      id: 2,
      exceptionType: 'SHORTFALL',
      exceptionName: '数量不足',
      category: 'RECEIVING',
      severity: ExceptionSeverity.warning,
      status: ExceptionStatus.acknowledged,
      quantity: 10,
      janCode: '4901234567890',
      productName: 'ボールペン',
      note: '予定 40 に対して 30',
      createdAt: DateTime(2026, 9, 20, 10, 31),
      acknowledgedAt: DateTime(2026, 9, 20, 11, 0),
    );

WarehouseException _qcFail() => WarehouseException(
      id: 3,
      exceptionType: 'QC_FAIL',
      exceptionName: '検品不合格',
      category: 'QC',
      severity: ExceptionSeverity.blocker,
      status: ExceptionStatus.open,
      quantity: 4,
      productName: '検品対象品',
      lotCode: 'QC-L1',
      expiryDate: DateTime(2027, 1, 19),
      inspectionId: 5,
      createdAt: DateTime(2026, 9, 20, 12, 0),
    );

WarehouseException _resolved() => WarehouseException(
      id: 4,
      exceptionType: 'SHORTFALL',
      exceptionName: '数量不足',
      category: 'RECEIVING',
      severity: ExceptionSeverity.warning,
      status: ExceptionStatus.resolved,
      resolution: ExceptionResolution.accepted,
      resolutionNote: '発注残として処理',
      quantity: 5,
      createdAt: DateTime(2026, 9, 19, 9, 0),
      resolvedAt: DateTime(2026, 9, 19, 9, 30),
    );

Future<ProviderContainer> _pump(
  WidgetTester tester,
  FakeExceptionRepository repo, {
  int? warehouseId = 1,
}) async {
  final container = ProviderContainer(overrides: [
    exceptionRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  if (warehouseId != null) {
    container.read(activeWarehouseIdProvider.notifier).state = warehouseId;
  }
  await pumpAppWith(tester, container, const ExceptionListScreen());
  return container;
}

void main() {
  testWidgets('shows what went wrong, how much, and off whose delivery',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeExceptionRepository(exceptions: [_lotMissing(), _shortfall()]);
    await _pump(tester, repo);

    expect(find.text('ロット未記録'), findsOneWidget);
    expect(find.text('数量 10'), findsNWidgets(2));
    // The next question after "what went wrong" is always "on whose delivery".
    expect(find.textContaining('DN-1'), findsOneWidget);
    expect(find.textContaining('文具商事'), findsOneWidget);
    // The server's own note explains the finding; the client does not restate it.
    expect(find.textContaining('LOT 管理の商品に'), findsOneWidget);
    expect(find.textContaining('予定 40 に対して 30'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a blocker is marked as one, and the count leads with blockers',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeExceptionRepository(
      exceptions: [_lotMissing(), _qcFail(), _shortfall()],
    );
    await _pump(tester, repo);

    // Two blockers of three open — the number a supervisor acts on.
    expect(find.text('要対応 2 件（未処理 3 件）'), findsOneWidget);
    expect(find.text('要対応'), findsNWidgets(2));
    expect(find.text('注意'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a QC failure carries its lot and expiry', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeExceptionRepository(exceptions: [_qcFail()]);
    await _pump(tester, repo);

    expect(find.text('検品不合格'), findsOneWidget);
    expect(find.text('ロット QC-L1 / 期限 2027-01-19'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('acknowledging is offered once, then the state shows instead',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeExceptionRepository(exceptions: [_lotMissing(), _shortfall()]);
    await _pump(tester, repo);

    // One OPEN row offers it; the ACKNOWLEDGED one shows its state instead,
    // because acknowledging twice is not a thing.
    expect(find.text('確認した'), findsOneWidget);
    expect(find.text('確認済み'), findsOneWidget);

    await tester.tap(find.text('確認した'));
    await tester.pumpAndSettle();
    expect(repo.acknowledgedId, 1);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('recording a decision sends the decision and says it moves no stock',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeExceptionRepository(exceptions: [_shortfall()]);
    await _pump(tester, repo);

    await tester.tap(find.text('対応を記録'));
    await tester.pumpAndSettle();

    // The sheet says so up front, because an operator choosing 廃棄した will
    // otherwise assume the write-off happened here.
    expect(find.textContaining('在庫を動かす場合は在庫調整から'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.lastResolution?.id, 2);
    expect(repo.lastResolution?.resolution, ExceptionResolution.accepted);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a decision that needs a note is stopped before the server sees it',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeExceptionRepository(exceptions: [_shortfall()]);
    await _pump(tester, repo);

    await tester.tap(find.text('対応を記録'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<ExceptionResolution>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('廃棄した').last);
    await tester.pumpAndSettle();

    // The label changes to say the note is now required.
    expect(find.widgetWithText(TextField, 'メモ（必須）'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    // Caught locally: the operator fixes a form instead of reading a 400.
    expect(find.text('この対応にはメモが必要です'), findsOneWidget);
    expect(repo.lastResolution, isNull);

    await tester.enterText(
        find.widgetWithText(TextField, 'メモ（必須）'), '破損のため廃棄');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.lastResolution?.resolution, ExceptionResolution.scrapped);
    expect(repo.lastResolution?.note, '破損のため廃棄');

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a refused resolve keeps the sheet open with the reason',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeExceptionRepository(exceptions: [_shortfall()])
      ..failResolveWith = 'exception 2 is already RESOLVED';
    await _pump(tester, repo);

    await tester.tap(find.text('対応を記録'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.textContaining('already RESOLVED'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '保存'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('finished work is hidden until asked for', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeExceptionRepository(exceptions: [_shortfall(), _resolved()]);
    final container = await _pump(tester, repo);

    expect(repo.lastIncludeClosed, isFalse);
    expect(find.text('対応済み'), findsNothing);

    container.read(showClosedExceptionsProvider.notifier).state = true;
    await tester.pumpAndSettle();

    // Asking for it is a different question to the server, not a local filter:
    // the work queue and the history are different lists.
    expect(repo.lastIncludeClosed, isTrue);
    // A resolved row shows what was decided, not just that it was.
    expect(find.text('受入（このまま確定）'), findsOneWidget);
    expect(find.text('発注残として処理'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('filtering by stage asks the server for that stage', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeExceptionRepository(exceptions: [_lotMissing(), _qcFail()]);
    final container = await _pump(tester, repo);

    container.read(exceptionCategoryProvider.notifier).state = 'QC';
    await tester.pumpAndSettle();

    expect(repo.lastCategory, 'QC');
    expect(find.text('検品不合格'), findsOneWidget);
    expect(find.text('ロット未記録'), findsNothing);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('nothing open reads as good news, not as an empty screen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeExceptionRepository();
    await _pump(tester, repo);

    expect(find.text('未処理の例外はありません'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('with no active warehouse it says to pick one', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final repo = FakeExceptionRepository(exceptions: [_lotMissing()]);
    await _pump(tester, repo, warehouseId: null);

    expect(find.text('倉庫を選ぶと表示できます'), findsOneWidget);
    expect(repo.lastWarehouseId, isNull);

    await tester.binding.setSurfaceSize(null);
  });
}
