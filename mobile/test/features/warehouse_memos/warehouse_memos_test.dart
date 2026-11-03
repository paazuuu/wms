import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/auth/application/auth_controller.dart';
import 'package:wms_mobile/features/auth/domain/auth_user.dart';
import 'package:wms_mobile/features/home/domain/feature_catalog.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';
import 'package:wms_mobile/features/warehouse_context/domain/warehouse.dart';
import 'package:wms_mobile/features/warehouse_memos/warehouse_memos_repository.dart';
import 'package:wms_mobile/features/warehouse_memos/warehouse_memos_screen.dart';

import '../../support/harness.dart';

/// Notes in memory, filtered as the server does.
class _Memos implements WarehouseMemosRepository {
  _Memos(this.memos);
  List<WarehouseMemo> memos;
  final saved = <(int?, int, String)>[];
  final removed = <int>[];
  final asked = <({int? warehouseId, DateTime? from, DateTime? to, String? query})>[];

  @override
  Future<ApiResult<List<WarehouseMemo>>> list({int? warehouseId, DateTime? from, DateTime? to, String? query}) async {
    asked.add((warehouseId: warehouseId, from: from, to: to, query: query));
    return ApiSuccess([
      for (final m in memos)
        if ((warehouseId == null || m.warehouseId == warehouseId) &&
            (from == null || !m.day.isBefore(from)) &&
            (to == null || !m.day.isAfter(to)) &&
            (query == null || m.body.toLowerCase().contains(query.toLowerCase())))
          m,
    ]);
  }

  @override
  Future<ApiResult<int>> save({int? id, required int warehouseId, required String body}) async {
    saved.add((id, warehouseId, body));
    final now = DateTime.now();
    if (id == null) {
      memos = [
        WarehouseMemo(
            id: 99, warehouseId: warehouseId, body: body, day: DateTime(now.year, now.month, now.day),
            warehouseName: warehouseId == 1 ? 'メイン倉庫' : '東京', createdAt: now, createdByName: 'ganki.rin'),
        ...memos,
      ];
    } else {
      memos = [for (final m in memos) m.id == id ? WarehouseMemo(id: id, warehouseId: warehouseId, body: body, day: m.day) : m];
    }
    return ApiSuccess(id ?? 99);
  }

  @override
  Future<ApiResult<bool>> remove(int id) async {
    removed.add(id);
    memos = [for (final m in memos) if (m.id != id) m];
    return const ApiSuccess(true);
  }
}

void main() {
  final now = DateTime.now();
  final d1 = DateTime(now.year, now.month, 1);
  final d2 = DateTime(now.year, now.month, 2);
  WarehouseMemo memo(int id, int wh, String body, DateTime day) => WarehouseMemo(
      id: id, warehouseId: wh, body: body, day: day, warehouseName: wh == 1 ? 'メイン倉庫' : '東京',
      createdAt: day.add(const Duration(hours: 9)), createdByName: 'ganki.rin');

  Future<_Memos> pump(WidgetTester tester, {List<WarehouseMemo>? memos}) async {
    await tester.binding.setSurfaceSize(const Size(1300, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _Memos(memos ??
        [
          memo(1, 1, '午後から棚Bを整理する', d1),
          memo(2, 21, '東京の冷房が壊れている。業者は木曜', d2),
          memo(3, 1, '〇〇商事の入荷あり。棚Cを空ける', d2),
        ]);
    await pumpApp(tester, const WarehouseMemosScreen(), overrides: [
      authControllerProvider.overrideWith((ref) => fakeAuthControllerFor(
          const AuthUser(id: 'u1', email: 'a@b.test', name: '倉庫', permissions: ['inventory.view']))),
      warehouseMemosRepositoryProvider.overrideWithValue(repo),
      warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(const WarehouseOverview(
        warehouses: [Warehouse(id: 1, code: 'WH-01', name: 'メイン倉庫'), Warehouse(id: 21, code: 'WH-21', name: '東京')],
        totals: WarehouseTotals(),
      ))),
    ]);
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('メモ: the month on a calendar, a day opens its notes, and a warehouse narrows them (0184)', (tester) async {
    final repo = await pump(tester);
    // This month asked for, whole.
    expect(repo.asked.last.from, DateTime(now.year, now.month));
    expect(repo.asked.last.to, DateTime(now.year, now.month + 1, 0));
    expect(find.text('この月のメモ 3件'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('wm-count-2'))).data, '2');
    await tester.tap(find.byKey(const ValueKey('wm-day-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wm-memo-1')), findsNothing);
    expect(find.byKey(const ValueKey('wm-memo-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('wm-memo-3')), findsOneWidget);
    // Only 東京's.
    await tester.tap(find.byKey(const ValueKey('wm-wh-21')));
    await tester.pumpAndSettle();
    expect(repo.asked.last.warehouseId, 21);
    expect(find.byKey(const ValueKey('wm-memo-3')), findsNothing);
    expect(find.byKey(const ValueKey('wm-memo-2')), findsOneWidget);
  });

  testWidgets('search finds notes by their words, whatever the day', (tester) async {
    final repo = await pump(tester);
    await tester.enterText(find.byKey(const ValueKey('wm-search')), '棚');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(repo.asked.last.query, '棚');
    expect((repo.asked.last.from, repo.asked.last.to), (null, null));
    expect(find.text('「棚」を含むメモ 2件'), findsOneWidget);
    expect(find.byKey(const ValueKey('wm-memo-2')), findsNothing);
  });

  testWidgets('a note is written for a warehouse, changed, and taken away', (tester) async {
    final repo = await pump(tester, memos: const []);
    await tester.tap(find.byKey(const ValueKey('wm-new')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('wm-save'))).onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey('wm-body')), '明日の午前に入荷あり');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wm-save')));
    await tester.pumpAndSettle();
    expect(repo.saved.single, (null, 1, '明日の午前に入荷あり'));
    expect(find.byKey(const ValueKey('wm-memo-99')), findsOneWidget);
    // Changed.
    await tester.tap(find.byKey(const ValueKey('wm-more-99')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wm-edit-99')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('wm-body')), '明日の午前に入荷あり（棚B）');
    await tester.tap(find.byKey(const ValueKey('wm-save')));
    await tester.pumpAndSettle();
    expect(repo.saved.last, (99, 1, '明日の午前に入荷あり（棚B）'));
    // Taken away, asked first.
    await tester.tap(find.byKey(const ValueKey('wm-more-99')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wm-remove-99')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wm-remove-go')));
    await tester.pumpAndSettle();
    expect(repo.removed, [99]);
    expect(find.byKey(const ValueKey('wm-memo-99')), findsNothing);
  });

  test('メモ is in the menu where 棚入れ was, for whoever works in a warehouse; 棚入れ keeps its address only', () {
    final entries = buildFeatureCatalog().expand((g) => g.entries).toList();
    final memo = entries.firstWhere((e) => e.id == 'warehouse_memos');
    expect(memo.visibleFor(const ['putaway.confirm']), isTrue);
    expect(memo.visibleFor(const ['inventory.view']), isTrue);
    expect(memo.visibleFor(const []), isFalse);
    expect(entries.firstWhere((e) => e.id == 'putaway').inMenu, isFalse);
    final ids = [for (final e in entries) e.id];
    expect(ids.indexOf('warehouse_memos'), ids.indexOf('putaway') - 1);
  });
}
