import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/auth/application/auth_controller.dart';
import 'package:wms_mobile/features/auth/domain/auth_user.dart';
import 'package:wms_mobile/features/home/domain/feature_catalog.dart';
import 'package:wms_mobile/features/system_reset/data/system_reset_repository.dart';
import 'package:wms_mobile/features/system_reset/presentation/system_reset_screen.dart';

import '../../support/harness.dart';

class _Repo implements SystemResetRepository {
  final calls = <(String, Map<String, dynamic>)>[];

  @override
  Future<ApiResult<ResetCounts>> preview() async => const ApiSuccess({
        'imports': 7, 'documents': 6, 'proofs': 1, 'deliveries': 0, 'inspections': 0, 'orders': 1,
        'stock_levels': 51, 'movements': 154, 'files': 14, 'products': 51, 'price_book': 56,
        'suppliers': 3, 'learned': 17, 'lookups': 72, 'audit': 654, 'ai_calls': 129,
      });

  @override
  Future<ApiResult<ResetResult>> reset(String confirm, ResetOptions options) async {
    calls.add((confirm, options.toJson()));
    return ApiSuccess(ResetResult.fromJson({
      'before': {'imports': 7, 'products': 51, 'files': {'a': 3, 'b': 11}},
      'after': {'imports': 0, 'products': 0},
      'files': {'import-documents': {'removed': 3, 'failed': 0}, 'master-import-files': {'removed': 7, 'failed': 0}},
    }));
  }
}

const _admin = AuthUser(id: 'u1', email: 'a@b.test', name: '管理者', permissions: ['system.reset']);

void main() {
  test('システムの初期化 is in 管理, for system.reset only', () {
    final e = buildFeatureCatalog().firstWhere((g) => g.id == 'management').entries.firstWhere((e) => e.id == 'system_reset');
    expect(e.requiredAnyOf, ['system.reset']);
    expect(e.visibleFor(['user.manage', 'inventory.adjust']), isFalse);
    expect(e.visibleFor(['system.reset']), isTrue);
  });

  test('a reset result counts the files removed and those that could not be', () {
    final r = ResetResult.fromJson({
      'before': {'imports': 7, 'files': {'x': 2, 'y': 3}},
      'after': {},
      'files': {'a': {'removed': 5, 'failed': 1}, 'b': {'error': 'gone'}},
    });
    expect(r.before['files'], 5);
    expect((r.filesRemoved, r.filesFailed), (5, 2));
  });

  testWidgets('what goes is counted first; nothing runs until 「初期化」 is typed and confirmed', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _Repo();
    await pumpApp(tester, const SystemResetScreen(), overrides: [
      authControllerProvider.overrideWith((ref) => fakeAuthControllerFor(_admin)),
      systemResetRepositoryProvider.overrideWithValue(repo),
    ]);
    expect(find.textContaining('取込 7件'), findsOneWidget);
    expect(find.textContaining('商品 51件・価格台帳 56件'), findsOneWidget);
    // Products and logs by default; suppliers and lookups kept.
    bool ticked(String key) => tester.widget<CheckboxListTile>(find.descendant(
        of: find.byKey(ValueKey(key)), matching: find.byType(CheckboxListTile))).value!;
    expect([ticked('sr-products'), ticked('sr-suppliers'), ticked('sr-lookups'), ticked('sr-logs')], [true, false, false, true]);

    FilledButton run() => tester.widget<FilledButton>(find.ancestor(of: find.text('初期化する'), matching: find.byType(FilledButton)).first);
    expect(run().onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey('sr-word')), 'しょきか');
    await tester.pump();
    expect(run().onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey('sr-word')), '初期化');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sr-lookups')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sr-run')));
    await tester.pumpAndSettle();
    // Asked once more; cancelled, nothing done.
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);
    await tester.tap(find.byKey(const ValueKey('sr-run')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sr-confirm')));
    await tester.pumpAndSettle();
    final (word, options) = repo.calls.single;
    expect(word, '初期化');
    expect(options, {'products': true, 'suppliers': false, 'lookups': true, 'logs': true});
    expect(find.byKey(const ValueKey('sr-done')), findsOneWidget);
    expect(find.textContaining('ファイル 10件を消しました'), findsOneWidget);
  });

  testWidgets('without system.reset it says so and offers nothing', (tester) async {
    await pumpApp(tester, const SystemResetScreen(), overrides: [
      authControllerProvider.overrideWith((ref) => fakeAuthControllerFor(
          const AuthUser(id: 'u2', email: 'c@d.test', name: '倉庫', permissions: ['user.manage']))),
      systemResetRepositoryProvider.overrideWithValue(_Repo()),
    ]);
    expect(find.byKey(const ValueKey('sr-no-permission')), findsOneWidget);
    expect(find.byKey(const ValueKey('sr-run')), findsNothing);
  });
}
