// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/auth/application/auth_controller.dart';
import 'package:wms_mobile/features/auth/domain/auth_user.dart';
import 'package:wms_mobile/features/master_import/data/master_import_repository.dart';
import 'package:wms_mobile/features/master_import/domain/master_import.dart';
import 'package:wms_mobile/features/stock_import/data/stock_import_repository.dart';
import 'package:wms_mobile/features/stock_import/domain/stock_ledger.dart';
import 'package:wms_mobile/features/stock_import/presentation/stock_import_calendar_screen.dart';
import 'package:wms_mobile/features/qc/presentation/inspection_list_screen.dart';
import 'package:wms_mobile/features/stock_import/presentation/stock_inspection_screen.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';

import '../../support/harness.dart';

const _jan1 = '4909999000014';
const _jan2 = '4909999000021';

MasterImport _awaiting({bool firstDone = false}) => MasterImport.fromJson({
      'id': 21,
      'status': 'awaiting_inspection',
      'source': 'stock_file',
      'original_name': '請求書.pdf',
      'original_path': 'imports/21/original-a.pdf',
      'warehouse_name': '本社倉庫',
      'lines': [
        {
          'line_no': 2, 'jan_code': _jan1, 'name': 'テストペン 青', 'quantity': 500,
          if (firstDone) ...{'inspected_at': '2026-10-23T02:00:00Z', 'inspected_quantity': 498, 'inspected_by_name': '検品担当', 'added': 498},
        },
        {'line_no': 3, 'jan_code': _jan2, 'name': 'テストノート', 'quantity': 100},
      ],
    });

class _Reader implements MasterImportRepository {
  _Reader(this.import);
  MasterImport import;

  @override
  Future<ApiResult<MasterImport>> detail(int importId, {int? warehouseId}) async => ApiSuccess(import);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Stock implements StockImportRepository {
  _Stock({this.waiting = const [], this.month = const []});
  final List<AwaitingImport> waiting;
  final List<CalendarImport> month;
  final inspected = <(int, List<InspectedLine>)>[];
  final asked = <(DateTime, DateTime)>[];
  _Reader? reader;

  @override
  Future<ApiResult<List<AwaitingImport>>> awaiting({int? warehouseId}) async => ApiSuccess(waiting);

  @override
  Future<ApiResult<InspectionResult>> inspect(int importId, List<InspectedLine> lines) async {
    inspected.add((importId, lines));
    reader?.import = _awaiting(firstDone: true);
    return const ApiSuccess(InspectionResult(lines: 1, change: 498, difference: -2, left: 1));
  }

  @override
  Future<ApiResult<PendingInspection>> pendingInspection({int? warehouseId}) async => const ApiSuccess(PendingInspection());

  @override
  Future<ApiResult<List<CalendarImport>>> calendar(DateTime from, DateTime to) async {
    asked.add((from, to));
    return ApiSuccess(month);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Override _signedIn(List<String> p) => authControllerProvider
    .overrideWith((ref) => fakeAuthControllerFor(AuthUser(id: 'u1', email: 'a@b.test', name: '検品担当', permissions: p)));

void main() {
  testWidgets('files waiting for inspection are listed with what is left of each', (tester) async {
    final stock = _Stock(waiting: [
      AwaitingImport.fromJson({
        'id': 21, 'original_name': '請求書.pdf', 'warehouse_name': '本社倉庫', 'lines': 9, 'left': 9, 'quantity_left': 4100,
        'created_at': '2026-10-23T02:00:00Z', 'created_by_name': 'ganki',
      }),
    ]);
    await pumpApp(tester, const StockInspectionScreen(), overrides: [
      _signedIn(['inspection.confirm']),
      stockImportRepositoryProvider.overrideWithValue(stock),
    ]);
    expect(find.text('取込 #21 · 請求書.pdf'), findsOneWidget);
    expect(find.textContaining('未検品 9/9行・4100個'), findsOneWidget);
  });

  testWidgets('an inspector ticks a line, enters what was counted, and checks it in', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reader = _Reader(_awaiting());
    final stock = _Stock()..reader = reader;
    await pumpApp(tester, const StockInspectionScreen(openImportId: 21), overrides: [
      _signedIn(['inspection.confirm']),
      stockImportRepositoryProvider.overrideWithValue(stock),
      masterImportRepositoryProvider.overrideWithValue(reader),
    ]);
    expect(find.text('未検品 2行（全2行）'), findsOneWidget);
    // Nothing chosen, nothing to check in.
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('si-check-in'))).onPressed, isNull);

    // A scanned JAN ticks its line; the count found differs from the file.
    await tester.enterText(find.byKey(const ValueKey('si-scan')), _jan1);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byKey(const ValueKey('si-tick-2'))).value, isTrue);
    await tester.enterText(find.byKey(const ValueKey('si-count-2')), '498');
    await tester.pumpAndSettle();
    expect(find.textContaining('差 -2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('si-check-in')));
    await tester.pumpAndSettle();
    expect(find.text('1行・498個を在庫に入れます。ファイルとの差は -2個です。'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('si-confirm')));
    await tester.pumpAndSettle();

    final (id, lines) = stock.inspected.single;
    expect(id, 21);
    expect([for (final l in lines) (l.lineNo, l.quantity)], [(2, 498)]);
    // The line is checked in, by whom and how many; the other still waits.
    expect(find.byKey(const ValueKey('si-done-2')), findsOneWidget);
    expect(find.textContaining('検品済み 498個（検品担当）'), findsOneWidget);
    expect(find.text('未検品 1行（全2行）'), findsOneWidget);
  });

  testWidgets('a JAN not among the lines is said so', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester, const StockInspectionScreen(openImportId: 21), overrides: [
      _signedIn(['inspection.confirm']),
      stockImportRepositoryProvider.overrideWithValue(_Stock()),
      masterImportRepositoryProvider.overrideWithValue(_Reader(_awaiting())),
    ]);
    await tester.enterText(find.byKey(const ValueKey('si-scan')), '4909999000038');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('4909999000038 はこのファイルの未検品の行にありません'), findsOneWidget);
  });

  testWidgets('without the permission nothing can be checked in', (tester) async {
    await pumpApp(tester, const StockInspectionScreen(openImportId: 21), overrides: [
      _signedIn(['inventory.view']),
      stockImportRepositoryProvider.overrideWithValue(_Stock()),
      masterImportRepositoryProvider.overrideWithValue(_Reader(_awaiting())),
    ]);
    expect(find.byKey(const ValueKey('si-check-in')), findsNothing);
    expect(find.textContaining('権限が要ります'), findsOneWidget);
  });

  testWidgets('the calendar shows a month’s files on their days, paid or not, and a day opens its files', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final stock = _Stock(month: [
      CalendarImport.fromJson({
        'id': 13, 'day': '2026-08-19', 'document_date_source': 'content', 'original_name': '請求書.pdf',
        'warehouse_name': 'メイン倉庫', 'status': 'stock_done', 'stock_lines': 9, 'stock_added': 4100, 'paid': true,
        'note': '8/21 振込',
      }),
      CalendarImport.fromJson({
        'id': 14, 'day': '2026-08-19', 'original_name': '納品書.pdf', 'status': 'awaiting_inspection', 'line_count': 2,
      }),
      CalendarImport.fromJson({'id': 15, 'day': '2026-08-03', 'original_name': '在庫.csv', 'status': 'stock_done'}),
    ]);
    await pumpApp(tester, StockImportCalendarScreen(initialMonth: DateTime(2026, 8)), overrides: [
      _signedIn(['inventory.adjust']),
      stockImportRepositoryProvider.overrideWithValue(stock),
    ]);
    expect(stock.asked.single, (DateTime(2026, 8), DateTime(2026, 8, 31)));
    expect(find.text('8月'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('cal-count-19'))).data, '2件');
    expect(find.text('この月の取込 3件'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cal-day-19')));
    await tester.pumpAndSettle();
    expect(find.text('2026/08/19 の取込 2件'), findsOneWidget);
    expect(find.byKey(const ValueKey('cal-item-15')), findsNothing);
    expect(find.descendant(of: find.byKey(const ValueKey('cal-paid-13')), matching: find.text('振込済')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('cal-paid-14')), matching: find.text('未払い')), findsOneWidget);
    expect(find.textContaining('検品待ち'), findsWidgets);
    expect(find.text('8/21 振込'), findsOneWidget);

    // A day with none says so.
    await tester.tap(find.byKey(const ValueKey('cal-day-20')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cal-none')), findsOneWidget);
  });

  testWidgets('a file registered for inspection is listed on 検品 too, for its warehouse', (tester) async {
    AwaitingImport waiting(int id, int wh) => AwaitingImport.fromJson({
          'id': id, 'original_name': '請求書$id.pdf', 'warehouse_id': wh, 'warehouse_name': '倉庫$wh', 'lines': 9, 'left': 9,
          'quantity_left': 4100,
        });
    final stock = _Stock(waiting: [waiting(21, 1), waiting(22, 2)]);
    await pumpApp(tester, const QcInspectionListScreen(), overrides: [
      _signedIn(['inspection.confirm']),
      stockImportRepositoryProvider.overrideWithValue(stock),
      activeWarehouseIdProvider.overrideWith((ref) => 1),
    ]);
    expect(find.text('ファイル取込の検品待ち 1件'), findsOneWidget);
    expect(find.byKey(const ValueKey('qc-file-21')), findsOneWidget);
    expect(find.byKey(const ValueKey('qc-file-22')), findsNothing);
    expect(find.textContaining('未検品 9/9行'), findsOneWidget);
  });

  testWidgets('the calendar is small enough to be seen whole, its files beside it on a wide screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final stock = _Stock(month: [
      CalendarImport.fromJson({'id': 13, 'day': '2026-08-19', 'original_name': '請求書.pdf', 'status': 'stock_done'}),
    ]);
    await pumpApp(tester, StockImportCalendarScreen(initialMonth: DateTime(2026, 8)), overrides: [
      _signedIn(['inventory.adjust']),
      stockImportRepositoryProvider.overrideWithValue(stock),
    ]);
    final cal = tester.getRect(find.byKey(const ValueKey('cal-calendar')));
    expect(cal.width, lessThanOrEqualTo(calendarMaxWidth));
    // August 2026 runs to the 31st on the sixth row: still on screen.
    expect(tester.getRect(find.byKey(const ValueKey('cal-day-31'))).bottom, lessThan(800));
    expect(tester.getRect(find.byKey(const ValueKey('cal-list-title'))).left, greaterThan(cal.right));

    // A phone: the list under the calendar.
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpAndSettle();
    final small = tester.getRect(find.byKey(const ValueKey('cal-calendar')));
    expect(tester.getRect(find.byKey(const ValueKey('cal-list-title'))).top, greaterThan(small.bottom));
  });
}
