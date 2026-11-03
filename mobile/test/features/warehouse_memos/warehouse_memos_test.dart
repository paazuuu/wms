import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/core/ui/open_window.dart';
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
  final saved = <(int?, MemoKind, int, String, DateTime?)>[];
  final removed = <int>[];
  final added = <(int, String)>[];
  final removedFiles = <int>[];
  final asked = <({MemoKind kind, int? warehouseId, DateTime? from, DateTime? to, String? query})>[];

  @override
  Future<ApiResult<List<WarehouseMemo>>> list(MemoKind kind,
      {int? warehouseId, DateTime? from, DateTime? to, String? query}) async {
    asked.add((kind: kind, warehouseId: warehouseId, from: from, to: to, query: query));
    final q = query?.trim() ?? '';
    final out = [
      for (final m in memos)
        if (m.kind == kind &&
            (warehouseId == null || m.warehouseId == warehouseId) &&
            (from == null || !m.day.isBefore(from)) &&
            (to == null || !m.day.isAfter(to)) &&
            (q.isEmpty || m.body.toLowerCase().contains(q.toLowerCase()) || m.files.any((f) => f.name.contains(q))))
          m,
    ];
    out.sort((a, b) => kind == MemoKind.calendar ? a.day.compareTo(b.day) : b.id.compareTo(a.id));
    return ApiSuccess(out);
  }

  @override
  Future<ApiResult<int>> save(
      {int? id, required MemoKind kind, required int warehouseId, required String body, DateTime? date}) async {
    saved.add((id, kind, warehouseId, body, date));
    final now = DateTime.now();
    final day = date ?? DateTime(now.year, now.month, now.day);
    if (id == null) {
      memos = [...memos, WarehouseMemo(id: 99, kind: kind, warehouseId: warehouseId, body: body, day: day, createdAt: now)];
      return const ApiSuccess(99);
    }
    memos = [
      for (final m in memos)
        m.id == id ? WarehouseMemo(id: id, kind: m.kind, warehouseId: warehouseId, body: body, day: date ?? m.day) : m
    ];
    return ApiSuccess(id);
  }

  @override
  Future<ApiResult<bool>> remove(int id) async {
    removed.add(id);
    memos = [for (final m in memos) if (m.id != id) m];
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<bool>> addFile(int memoId, String fileName, Uint8List bytes) async {
    added.add((memoId, fileName));
    memos = [
      for (final m in memos)
        m.id == memoId
            ? WarehouseMemo(
                id: m.id, kind: m.kind, warehouseId: m.warehouseId, body: m.body, day: m.day,
                files: [...m.files, MemoFile(id: 500 + added.length, path: '$memoId/x', name: fileName, size: bytes.length)])
            : m
    ];
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<bool>> removeFile(int fileId) async {
    removedFiles.add(fileId);
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<Uint8List>> fileBytes(MemoFile file) async => ApiSuccess(Uint8List.fromList([1, 2, 3]));
}

class _Tab implements HtmlTab {
  final shown = <(int, String)>[];

  @override
  void show(String html) {}

  @override
  void close() {}

  @override
  void showBytes(List<int> bytes, String contentType) => shown.add((bytes.length, contentType));
}

void main() {
  final now = DateTime.now();
  final d5 = DateTime(now.year, now.month, 5);
  final d20 = DateTime(now.year, now.month, 20);
  WarehouseMemo cal(int id, int wh, String body, DateTime day) => WarehouseMemo(
      id: id, kind: MemoKind.calendar, warehouseId: wh, body: body, day: day, warehouseName: wh == 1 ? 'メイン倉庫' : '東京');
  WarehouseMemo board(int id, String body, {List<MemoFile> files = const []}) => WarehouseMemo(
      id: id, kind: MemoKind.board, warehouseId: 1, body: body, day: DateTime(now.year, now.month, 1),
      createdAt: DateTime(now.year, now.month, 1, 9, 30), files: files);

  Future<(_Memos, _Tab)> pump(WidgetTester tester, {List<WarehouseMemo>? memos, int tab = 0}) async {
    await tester.binding.setSurfaceSize(const Size(1300, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _Memos(memos ??
        [
          cal(1, 1, 'アルバイト3人', d20),
          cal(2, 21, '〇〇商事 入荷予定（10ケース）', d5),
          cal(3, 1, '棚卸し', d5),
          board(4, '休憩室の鍵は事務所の棚', files: const [MemoFile(id: 7, path: '4/1-map.pdf', name: '地図.pdf', type: 'application/pdf', size: 2048)]),
        ]);
    final browser = _Tab();
    final saved = <String>[];
    await pumpApp(tester, WarehouseMemosScreen(initialTab: tab), overrides: [
      authControllerProvider.overrideWith((ref) => fakeAuthControllerFor(
          const AuthUser(id: 'u1', email: 'a@b.test', name: '倉庫', permissions: ['inventory.view']))),
      warehouseMemosRepositoryProvider.overrideWithValue(repo),
      memoTabOpenerProvider.overrideWithValue(() => browser),
      memoFileSaverProvider.overrideWithValue((n, b) async => saved.add(n)),
      memoFilePickerProvider.overrideWithValue(() async => [(name: '入荷予定.xlsx', bytes: Uint8List.fromList([1, 2]))]),
      warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(const WarehouseOverview(
        warehouses: [Warehouse(id: 1, code: 'WH-01', name: 'メイン倉庫'), Warehouse(id: 21, code: 'WH-21', name: '東京')],
        totals: WarehouseTotals(),
      ))),
    ]);
    await tester.pumpAndSettle();
    return (repo, browser);
  }

  testWidgets('カレンダー: the month listed at once by day, no day to pick first; a day narrows it (0185)', (tester) async {
    final (repo, _) = await pump(tester);
    final asked = repo.asked.lastWhere((a) => a.kind == MemoKind.calendar);
    expect((asked.from, asked.to), (DateTime(now.year, now.month), DateTime(now.year, now.month + 1, 0)));
    expect(find.text('この月のメモ 3件（日付順）'), findsOneWidget);
    // Listed without a tap, the earliest day first, under its date.
    expect(tester.getTopLeft(find.byKey(const ValueKey('wm-memo-2'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('wm-memo-1'))).dy));
    expect(find.byKey(const ValueKey('wm-day-head-5')), findsOneWidget);
    expect(find.byKey(const ValueKey('wm-memo-4')), findsNothing); // the board's
    await tester.tap(find.byKey(const ValueKey('wm-day-20')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wm-memo-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('wm-memo-2')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('wm-show-month')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wm-memo-2')), findsOneWidget);
    // Months to come too.
    expect(tester.widget<IconButton>(find.byKey(const ValueKey('wm-next'))).onPressed, isNotNull);
  });

  testWidgets('a calendar note is written on a day chosen, and edited', (tester) async {
    final (repo, _) = await pump(tester, memos: const []);
    await tester.tap(find.byKey(const ValueKey('wm-new')));
    await tester.pumpAndSettle();
    expect(find.text('カレンダーにメモを書く'), findsWidgets);
    expect(find.byKey(const ValueKey('wm-date')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('wm-body')), 'アルバイト4人');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wm-save')));
    await tester.pumpAndSettle();
    final (id, kind, wh, body, date) = repo.saved.single;
    expect((id, kind, wh, body), (null, MemoKind.calendar, 1, 'アルバイト4人'));
    expect(date, DateTime(now.year, now.month, now.day));
    // Edited: 編集する.
    await tester.tap(find.byKey(const ValueKey('wm-more-99')));
    await tester.pumpAndSettle();
    expect(find.text('メモを編集する'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wm-edit-99')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('wm-body')), 'アルバイト5人');
    await tester.tap(find.byKey(const ValueKey('wm-save')));
    await tester.pumpAndSettle();
    expect(repo.saved.last.$1, 99);
    expect(repo.saved.last.$4, 'アルバイト5人');
  });

  testWidgets('掲示板: tied to no day, the newest first, written with a file', (tester) async {
    final (repo, _) = await pump(tester, tab: 1);
    final asked = repo.asked.lastWhere((a) => a.kind == MemoKind.board);
    expect((asked.from, asked.to), (null, null));
    expect(find.text('掲示板のメモ 1件（新しい順）'), findsOneWidget);
    expect(find.byKey(const ValueKey('wm-month')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('wm-new')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wm-date')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('wm-body')), '明日は午後から停電');
    await tester.tap(find.byKey(const ValueKey('wm-dialog-files')));
    await tester.pumpAndSettle();
    expect(find.text('入荷予定.xlsx'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wm-save')));
    await tester.pumpAndSettle();
    expect(repo.saved.single.$2, MemoKind.board);
    expect(repo.saved.single.$5, isNull);
    expect(repo.added, [(99, '入荷予定.xlsx')]);
  });

  testWidgets('a file is seen in the browser as it is, saved again, and taken away (0186)', (tester) async {
    final (repo, browser) = await pump(tester, tab: 1);
    await tester.tap(find.byKey(const ValueKey('wm-file-view-7')));
    await tester.pumpAndSettle();
    expect(browser.shown, [(3, 'application/pdf')]);
    await tester.tap(find.byKey(const ValueKey('wm-file-dl-7')));
    await tester.pumpAndSettle();
    expect(find.text('地図.pdf を保存しました'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wm-add-files-4')));
    await tester.pumpAndSettle();
    expect(repo.added, [(4, '入荷予定.xlsx')]);
    await tester.tap(find.byKey(const ValueKey('wm-file-remove-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wm-file-remove-go')));
    await tester.pumpAndSettle();
    expect(repo.removedFiles, [7]);
  });

  testWidgets('search finds the notes of the tab by their words, whatever the day', (tester) async {
    final (repo, _) = await pump(tester);
    await tester.enterText(find.byKey(const ValueKey('wm-search')), '入荷');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    final asked = repo.asked.lastWhere((a) => a.kind == MemoKind.calendar);
    expect(asked.query, '入荷');
    expect((asked.from, asked.to), (null, null));
    expect(find.text('「入荷」を含むメモ 1件'), findsOneWidget);
    expect(find.byKey(const ValueKey('wm-memo-2')), findsOneWidget);
  });

  test('メモ is in the menu where 棚入れ was, for whoever works in a warehouse; 棚入れ keeps its address only', () {
    final entries = buildFeatureCatalog().expand((g) => g.entries).toList();
    final memo = entries.firstWhere((e) => e.id == 'warehouse_memos');
    expect(memo.visibleFor(const ['putaway.confirm']), isTrue);
    expect(memo.visibleFor(const ['inventory.view']), isTrue);
    expect(memo.visibleFor(const []), isFalse);
    expect(entries.firstWhere((e) => e.id == 'putaway').inMenu, isFalse);
  });
}
