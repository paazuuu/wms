import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/jan_catalog/data/reference_repository.dart';
import 'package:wms_mobile/features/jan_catalog/presentation/jan_catalog_screen.dart';
import 'package:wms_mobile/features/jan_catalog/presentation/reference_tab.dart';

import '../../support/fake_reference_repository.dart';
import '../../support/harness.dart';

ReferenceSnapshot _copy(int id, String at, {List<ReferenceFile> files = const [], int? jans, int? weights}) =>
    ReferenceSnapshot(
      id: id,
      takenAt: DateTime.parse(at),
      fiscalYear: fiscalYearOf(DateTime.parse(at)),
      edition: '2026年1月1日',
      entryCount: jans,
      weightCount: weights,
      files: files,
    );

void main() {
  test('年度 is April to March, in Japan', () {
    expect(fiscalYearOf(DateTime.parse('2026-03-31T14:59:59Z')), 2025);
    expect(fiscalYearOf(DateTime.parse('2026-03-31T15:00:00Z')), 2026);
    expect(fiscalYearOf(DateTime.parse('2026-10-28T06:00:00Z')), 2026);
  });

  test('a source and its copies as the server gives them, newest first', () {
    final s = ReferenceSource.fromJson(const {
      'id': 3,
      'kind': 'catalog',
      'url': 'https://example.invalid/c',
      'jan_catalog_id': 9,
      'title': 'テスト総合カタログ',
      'reference_snapshots': [
        {'id': 1, 'taken_at': '2025-06-01T00:00:00Z', 'fiscal_year': 2025, 'files': []},
        {
          'id': 2,
          'taken_at': '2026-06-01T00:00:00Z',
          'fiscal_year': 2026,
          'entry_count': 3,
          'files': [
            {'kind': 'entries', 'path': 'source-3/x/entries.json', 'bytes': 10}
          ],
        },
      ],
    });
    expect(s.snapshots.map((c) => c.id), [2, 1]);
    expect(s.snapshots.first.file('entries')!.path, 'source-3/x/entries.json');
    expect(s.snapshots.first.file('pdf'), isNull);
  });

  test("a catalog copy's JAN list as a table", () {
    final t = entriesTable(const {
      'catalog': {'name': 'テスト総合カタログ'},
      'rows': [
        ['4909999000014', 'TP-F', 11.5, '●重量：11.5g／パック', 'pack', '30', 'TP-F | 49-09999-000014'],
      ],
    });
    expect(t.headers.first, 'JANコード');
    expect(t.rows.single[2], 11.5);
    expect(t.catalog['name'], 'テスト総合カタログ');
  });

  testWidgets('kept by 年度: the newest shown, an older one a chip away; a catalog’s copy as a table or Excel',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeReferenceRepository(sources: [
      ReferenceSource(
          id: 1,
          kind: 'catalog',
          url: 'https://example.invalid/c',
          janCatalogId: 9,
          title: 'テスト総合カタログ',
          snapshots: [
            _copy(12, '2026-06-01T00:00:00Z',
                jans: 3066,
                weights: 961,
                files: const [ReferenceFile(kind: 'entries', path: 'source-1/b/entries.json')]),
            _copy(11, '2025-06-01T00:00:00Z',
                jans: 3000,
                weights: 900,
                files: const [ReferenceFile(kind: 'entries', path: 'source-1/a/entries.json')]),
          ]),
      ReferenceSource(id: 2, kind: 'site', url: 'https://example.invalid/page', title: 'テストのページ', snapshots: [
        _copy(21, '2026-07-01T00:00:00Z', files: const [
          ReferenceFile(kind: 'html', path: 'source-2/c/page.html'),
          ReferenceFile(kind: 'text', path: 'source-2/c/text.txt'),
        ]),
      ]),
    ]);
    await pumpApp(
      tester,
      Scaffold(body: ReferenceTab(now: DateTime.parse('2026-10-28T06:00:00Z'))),
      overrides: [referenceRepositoryProvider.overrideWithValue(repo)],
    );
    expect(find.byKey(const ValueKey('ref-year-2026')), findsOneWidget);
    expect(find.byKey(const ValueKey('ref-year-2025')), findsOneWidget);
    expect(find.byKey(const ValueKey('ref-copy-12')), findsOneWidget);
    expect(find.byKey(const ValueKey('ref-copy-11')), findsNothing);
    expect(find.textContaining('JAN 3,066件（重量 961件）'), findsOneWidget);
    expect(find.byKey(const ValueKey('ref-table-12')), findsOneWidget);
    expect(find.byKey(const ValueKey('ref-xlsx-12')), findsOneWidget);
    // A site: its page and its text.
    expect(find.byKey(const ValueKey('ref-html-21')), findsOneWidget);
    expect(find.byKey(const ValueKey('ref-text-21')), findsOneWidget);
    expect(find.byKey(const ValueKey('ref-delete-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('ref-delete-1')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('ref-year-2025')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ref-copy-11')), findsOneWidget);
    expect(find.byKey(const ValueKey('ref-copy-12')), findsNothing);
    expect(find.byKey(const ValueKey('ref-2')), findsNothing);
  });

  testWidgets('a site added by its URL, saved at once; saved again later', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeReferenceRepository();
    await pumpApp(tester, const Scaffold(body: ReferenceTab()),
        overrides: [referenceRepositoryProvider.overrideWithValue(repo)]);
    expect(find.byKey(const ValueKey('ref-empty')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('ref-url')), 'https://example.invalid/new');
    await tester.enterText(find.byKey(const ValueKey('ref-title')), 'テスト価格表');
    await tester.tap(find.byKey(const ValueKey('ref-add')));
    await tester.pumpAndSettle();
    expect(repo.added, ['https://example.invalid/new']);
    expect(find.text('保存しました'), findsOneWidget);
    expect(find.text('テスト価格表'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ref-save-100')));
    await tester.pumpAndSettle();
    expect(repo.savedAgain, [100]);
  });

  testWidgets('without product.manage: only to look at', (tester) async {
    await pumpApp(tester, const Scaffold(body: ReferenceTab(canManage: false)));
    expect(find.byKey(const ValueKey('ref-url')), findsNothing);
  });

  testWidgets('the catalog screen has the 参照資料 tab', (tester) async {
    await pumpApp(tester, const JanCatalogScreen());
    await tester.tap(find.byKey(const ValueKey('jc-tab-reference')));
    await tester.pumpAndSettle();
    expect(find.byType(ReferenceTab), findsOneWidget);
  });
}
