import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/jan_catalog/data/jan_catalog_repository.dart';
import 'package:wms_mobile/features/jan_catalog/presentation/jan_catalog_screen.dart';

import '../../support/fake_jan_catalog_repository.dart';
import '../../support/harness.dart';

const _url =
    'https://dcs.mediapress-net.com/iportal/CatalogViewInterfaceStartUpAction.do?method=startUp&mode=PAGE&volumeID=TST12001&catalogId=1234500000&designID=TSTD001';

void main() {
  test('a catalog and a JAN as the server gives them', () {
    final c = JanCatalog.fromJson(const {
      'id': 1,
      'url': _url,
      'maker': 'テスト株式会社',
      'name': 'テスト総合カタログ',
      'page_count': 304,
      'pages_read': 306,
      'entry_count': 3066,
      'synced_at': '2026-10-27T15:56:41.808+00:00',
      'sync_error': null,
    });
    expect([c.entryCount, c.pagesRead, c.syncedAt!.isUtc], [3066, 306, false]);
    final h = JanCatalogHit.fromJson(const {'jan': '4909999000021', 'found': false, 'covered': true});
    expect(h.missing, isTrue);
    expect(JanCatalogHit.fromJson(const {'jan': '4909999000021', 'found': false, 'covered': false}).missing, isFalse);
  });

  test('looked up quietly: a failure is nothing to say', () async {
    final failing = _FailingRepo();
    expect(await lookupJans(failing, ['4909999000014']), isEmpty);
  });

  testWidgets('a catalog read by its URL, listed with what it came to; read again, deleted', (tester) async {
    final repo = FakeJanCatalogRepository();
    await pumpApp(tester, const JanCatalogScreen(), overrides: [janCatalogRepositoryProvider.overrideWithValue(repo)]);
    expect(find.byKey(const ValueKey('jc-empty')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('jc-url')), _url);
    await tester.tap(find.byKey(const ValueKey('jc-add')));
    await tester.pumpAndSettle();
    expect(repo.synced, [_url]);
    expect(find.text('テスト総合カタログ'), findsOneWidget);
    expect(find.text('JAN 3件・2ページ'), findsOneWidget);
    expect(find.text('JAN 3件を読み込みました'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('jc-resync-1')));
    await tester.pumpAndSettle();
    expect(repo.synced, [_url, _url]);

    await tester.tap(find.byKey(const ValueKey('jc-delete-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('jc-delete-confirm')));
    await tester.pumpAndSettle();
    expect(repo.catalogs, isEmpty);
    expect(find.byKey(const ValueKey('jc-empty')), findsOneWidget);
  });

  testWidgets('a URL that is not a catalog: said so', (tester) async {
    final repo = FakeJanCatalogRepository()
      ..syncResult = const ApiFailure(message: 'jan_catalog_bad_url', statusCode: 400);
    await pumpApp(tester, const JanCatalogScreen(), overrides: [janCatalogRepositoryProvider.overrideWithValue(repo)]);
    await tester.enterText(find.byKey(const ValueKey('jc-url')), 'https://example.com/');
    await tester.tap(find.byKey(const ValueKey('jc-add')));
    await tester.pumpAndSettle();
    expect(find.text('mediapress（iCata）のカタログURLではありません'), findsOneWidget);
  });

  testWidgets('without product.manage: only the list', (tester) async {
    final repo =
        FakeJanCatalogRepository(catalogs: [const JanCatalog(id: 1, url: _url, name: 'テスト総合カタログ', entryCount: 3)]);
    await pumpApp(tester, const JanCatalogScreen(canManage: false),
        overrides: [janCatalogRepositoryProvider.overrideWithValue(repo)]);
    expect(find.text('テスト総合カタログ'), findsOneWidget);
    expect(find.byKey(const ValueKey('jc-url')), findsNothing);
    expect(find.byKey(const ValueKey('jc-resync-1')), findsNothing);
    expect(find.byKey(const ValueKey('jc-open-1')), findsOneWidget);
  });
}

class _FailingRepo extends FakeJanCatalogRepository {
  @override
  Future<ApiResult<Map<String, JanCatalogHit>>> lookup(Iterable<String> jans) async =>
      const ApiFailure(message: 'offline');
}
