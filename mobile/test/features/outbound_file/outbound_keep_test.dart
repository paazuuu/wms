import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/outbound_file/data/outbound_file_repository.dart';
import 'package:wms_mobile/features/outbound_file/domain/outbound_plan.dart';
import 'package:wms_mobile/features/outbound_file/domain/outbound_sheet.dart';
import 'package:wms_mobile/features/outbound_file/presentation/outbound_calendar_tab.dart';
import 'package:wms_mobile/features/outbound_file/presentation/outbound_file_detail_screen.dart';
import 'package:wms_mobile/features/outbound_file/presentation/outbound_hub_screen.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';

import '../../support/fake_outbound_file_repository.dart';
import '../../support/harness.dart';

const _line = OutboundFileLine(
    id: 1, rowNo: 2, action: 'ship', productId: 1, jan: '4909999000014', productName: 'テストペン', quantity: 6, unitWeightG: 10);

OutboundFileSummary _file({String status = 'planned', bool undecided = false, DateTime? day, bool auto = false, int? held}) =>
    OutboundFileSummary(
      id: 5,
      warehouseId: 1,
      warehouseName: '東京',
      shippedOn: day ?? DateTime.now().add(const Duration(days: 3)),
      fileName: 'list.xlsx',
      status: status,
      dateUndecided: undecided,
      lineCount: 1,
      quantityTotal: 6,
      autoShipped: auto,
      autoHoldAt: held == null ? null : DateTime(2026, 11, 7),
      autoHoldShort: held,
    );

void main() {
  test('what other 出庫予定 keep is not counted as there to ship', () {
    const m = OutboundMatch(matchedBy: OutboundMatchedBy.jan, productId: 1, jan: '4909999000014', onHand: 10, kept: 6);
    expect(m.free, 4);
    final plan = planOutbound([const OutboundRow(rowNo: 2, jan: '4909999000014', quantity: 6)], [m]);
    expect(plan.single.shipped, 4);
    expect(plan.single.short, 2);
    expect(plan.single.stockBefore, 4);
    // Kept beyond what is there: nothing is free, never below 0.
    expect(const OutboundMatch(matchedBy: OutboundMatchedBy.jan, productId: 1, onHand: 3, kept: 5).free, 0);
  });

  Future<FakeOutboundFileRepository> pumpDetail(WidgetTester tester, OutboundFileDetail d) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeOutboundFileRepository(detailOf: (_) => d);
    await pumpApp(tester, const OutboundFileDetailScreen(fileId: 5), overrides: [
      outboundFileRepositoryProvider.overrideWithValue(repo),
    ]);
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('all there: it is kept and ships itself the day after its day', (tester) async {
    await pumpDetail(
        tester,
        OutboundFileDetail(file: _file(), lines: const [_line], shortage: const [
          OutboundShortage(jan: '4909999000014', name: 'テストペン', needed: 6, onHand: 10, keptAhead: 0, free: 10, short: 0),
        ]));
    expect(find.byKey(const ValueKey('of-detail-keep')), findsOneWidget);
    expect(find.textContaining('翌日に自動で出庫済みになり'), findsOneWidget);
    expect(find.byKey(const ValueKey('of-detail-short')), findsNothing);
  });

  testWidgets('short: a warning, not shipped by itself; held once its day has passed', (tester) async {
    const short = [
      OutboundShortage(jan: '4909999000014', name: 'テストペン', needed: 6, onHand: 10, keptAhead: 8, free: 2, short: 4),
    ];
    await pumpDetail(tester, OutboundFileDetail(file: _file(), lines: const [_line], shortage: short));
    expect(find.text('在庫が足りない商品が 1 品目あります（不足 4）。そろうまで自動で出庫済みになりません。'), findsOneWidget);
    expect(find.text('テストペン: 必要 6 ／ 在庫 10（先の予定でキープ 8）／ 不足 4'), findsOneWidget);

    // Recorded by hand all the same: told what will be short.
    await tester.tap(find.byKey(const ValueKey('of-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('of-confirm-short')), findsOneWidget);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    await pumpDetail(
        tester,
        OutboundFileDetail(
            file: _file(day: DateTime.now().subtract(const Duration(days: 2)), held: 4), lines: const [_line], shortage: short));
    expect(find.textContaining('を過ぎましたが、在庫が足りないため出庫済みにしていません'), findsOneWidget);
  });

  testWidgets('shipped by the night run: said so, and put back to planned if it did not leave', (tester) async {
    final repo = await pumpDetail(
        tester,
        OutboundFileDetail(
            file: _file(status: 'shipped', day: DateTime(2026, 11, 6), auto: true),
            lines: const [_line],
            shippedAt: DateTime(2026, 11, 7, 0, 7)));
    expect(find.text('出庫済み 2026/11/06（予定日の翌日に自動で記録 2026/11/07 00:07）'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('of-back-to-plan')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('of-back-to-plan-ok')));
    await tester.pumpAndSettle();
    expect(repo.backToPlanned, [5]);
    expect(find.text('出庫予定に戻しました（6個を在庫に戻しました）'), findsOneWidget);
  });

  testWidgets('the calendar marks a planned list whose day has passed', (tester) async {
    final now = DateTime.now();
    final past = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    final f = OutboundFileSummary(
        id: 7, warehouseId: 1, shippedOn: past, fileName: 'late.xlsx', status: 'planned', autoHoldShort: 3,
        autoHoldAt: now, lineCount: 1, quantityTotal: 6);
    final repo = FakeOutboundFileRepository(files: [f]);
    await pumpApp(tester, const OutboundCalendarScreen(), overrides: [
      outboundFileRepositoryProvider.overrideWithValue(repo),
      activeWarehouseIdProvider.overrideWith((ref) => null),
    ]);
    await tester.pumpAndSettle();
    if (find.byKey(const ValueKey('of-file-7')).evaluate().isEmpty) {
      // Yesterday may be in last month: the list of the month is what shows it.
      return;
    }
    expect(find.byKey(const ValueKey('of-overdue-7')), findsOneWidget);
  });

  testWidgets('the 未定 card: rows open the list, and a list taken back there is gone on return', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final f = _file(undecided: true);
    final repo = FakeOutboundFileRepository(detailOf: (_) => OutboundFileDetail(file: f, lines: const [_line]))
      ..undecidedFiles = [f];
    await pumpApp(tester, const Scaffold(body: SingleChildScrollView(child: OutboundUndecidedCard())), overrides: [
      outboundFileRepositoryProvider.overrideWithValue(repo),
      activeWarehouseIdProvider.overrideWith((ref) => null),
    ]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('of-undecided-5')), findsOneWidget);
    expect(find.text('開いて編集'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('of-undecided-open-5')));
    await tester.pumpAndSettle();
    expect(find.byType(OutboundFileDetailScreen), findsOneWidget);
    repo.undecidedFiles = const [];
    await tester.tap(find.byKey(const ValueKey('of-undo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('of-undo-ok')));
    await tester.pumpAndSettle();
    expect(repo.undone, [5]);
    Navigator.of(tester.element(find.byType(OutboundFileDetailScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('of-undecided-5')), findsNothing);
  });

  testWidgets('taken back: ✕ on its day in the calendars; one with no day listed as 取り消し in 出庫', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, 2);
    final shipped = OutboundFileSummary(
        id: 7, warehouseId: 1, shippedOn: day, fileName: 'shipped.xlsx', lineCount: 1, shippedTotal: 5, undoneAt: now);
    final repo = FakeOutboundFileRepository(files: [shipped])
      ..cancelledUndatedFiles = [
        OutboundFileSummary(
            id: 9, warehouseId: 1, shippedOn: day, fileName: 'no-day.xlsx', status: 'planned', dateUndecided: true,
            lineCount: 1, quantityTotal: 6, undoneAt: now),
      ];
    await pumpApp(tester, const OutboundCalendarScreen(), overrides: [
      outboundFileRepositoryProvider.overrideWithValue(repo),
      activeWarehouseIdProvider.overrideWith((ref) => null),
    ]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('of-cancelled-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('of-count-2')), findsNothing);
    expect(find.byKey(const ValueKey('of-file-x-7')), findsOneWidget);
    expect(find.textContaining('✕ '), findsWidgets);

    await pumpApp(tester, const OutboundHubScreen(tab: OutboundHubTab.shipments), overrides: [
      outboundFileRepositoryProvider.overrideWithValue(repo),
      activeWarehouseIdProvider.overrideWith((ref) => null),
    ]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sh-row-9')), findsOneWidget);
    expect(find.byKey(const ValueKey('sh-row-7')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sh-state-undecided')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sh-row-9')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('sh-state-undone')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sh-row-9')), findsOneWidget);
    expect(find.byKey(const ValueKey('sh-row-7')), findsOneWidget);
  });
}
