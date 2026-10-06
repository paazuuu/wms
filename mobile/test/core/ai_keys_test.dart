// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/ai/ai_confidence.dart';
import 'package:wms_mobile/core/ai/ai_health.dart';
import 'package:wms_mobile/core/ai/ai_keys.dart';
import 'package:wms_mobile/core/ai/ai_settings_screen.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/auth/application/auth_controller.dart';
import 'package:wms_mobile/features/auth/domain/auth_user.dart';

import '../support/harness.dart';

Override _signedIn(List<String> permissions) => authControllerProvider.overrideWith((ref) =>
    fakeAuthControllerFor(AuthUser(id: 'u1', email: 'a@b.test', name: '管理者', permissions: permissions)));

/// In-memory stand-in for the 0137 key functions.
class _FakeAiKeyRepository implements AiKeyRepository {
  _FakeAiKeyRepository(this.keys);

  List<AiApiKey> keys;
  final List<int?> activated = [];
  final List<int?> tested = [];
  final List<int> retired = [];
  final List<Map<String, Object?>> added = [];
  AiPingResult ping = const AiPingResult(ok: true, model: 'gemini-x', latencyMs: 500);

  AiApiKey _with(AiApiKey k, {required bool active}) => AiApiKey(
        id: k.id,
        label: k.label,
        keyHint: k.keyHint,
        tier: k.tier,
        model: k.model,
        isActive: active,
        lastOk: k.lastOk,
        lastErrorKind: k.lastErrorKind,
        calls24h: k.calls24h,
        failed24h: k.failed24h,
      );

  @override
  Future<ApiResult<AiKeys>> list() async =>
      ApiSuccess(AiKeys(keys: keys, usingServerKey: !keys.any((k) => k.isActive)));

  @override
  Future<ApiResult<int>> add({
    required String label,
    required String key,
    AiKeyTier tier = AiKeyTier.unknown,
    String? model,
    bool activate = false,
    String? note,
  }) async {
    added.add({'label': label, 'key': key, 'tier': tier, 'model': model, 'activate': activate});
    final id = 100 + added.length;
    keys = [
      for (final k in keys) activate ? _with(k, active: false) : k,
      AiApiKey(id: id, label: label, keyHint: '…${key.substring(key.length - 4)}', tier: tier, isActive: activate),
    ];
    return ApiSuccess(id);
  }

  @override
  Future<ApiResult<bool>> activate(int? id) async {
    activated.add(id);
    keys = [for (final k in keys) _with(k, active: k.id == id)];
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<bool>> update(int id, {String? label, AiKeyTier? tier, String? model, String? note, String? newKey}) async =>
      const ApiSuccess(true);

  @override
  Future<ApiResult<bool>> retire(int id) async {
    retired.add(id);
    keys = keys.where((k) => k.id != id).toList();
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<AiPingResult>> test(int? id) async {
    tested.add(id);
    return ApiSuccess(ping);
  }
}

Future<_FakeAiKeyRepository> _pump(WidgetTester tester, {List<String> permissions = const ['ai.key_manage']}) async {
  await tester.binding.setSurfaceSize(const Size(900, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final repo = _FakeAiKeyRepository([
    const AiApiKey(
      id: 1,
      label: '有料キー',
      keyHint: '…a1b2',
      tier: AiKeyTier.paid,
      isActive: true,
      lastOk: false,
      lastErrorKind: 'quota',
      calls24h: 12,
      failed24h: 3,
    ),
    const AiApiKey(id: 2, label: '無料キー', keyHint: '…z9y8', tier: AiKeyTier.free, model: 'gemini-flash-lite'),
  ]);
  await pumpApp(tester, const AiSettingsScreen(), overrides: [
    aiThresholdsProvider.overrideWith((ref) async => const AiThresholds()),
    aiKeyRepositoryProvider.overrideWithValue(repo),
    _signedIn(permissions),
  ]);
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  test('the list answer is read without the key itself', () {
    final keys = AiKeys.fromJson({
      'keys': [
        {
          'id': 3,
          'label': 'A',
          'key_hint': '…abcd',
          'tier': 'free',
          'model': '',
          'is_active': true,
          'last_ok': false,
          'last_error_kind': 'quota',
          'calls_24h': 4,
          'failed_24h': 1,
        },
      ],
      'using_server_key': false,
    });
    final k = keys.keys.single;
    expect([k.id, k.label, k.keyHint, k.tier, k.model, k.isActive], [3, 'A', '…abcd', AiKeyTier.free, null, true]);
    expect([k.lastOk, k.lastErrorKind, k.calls24h, k.failed24h], [false, 'quota', 4, 1]);
    expect(keys.usingServerKey, isFalse);
    expect(AiKeys.fromJson(const {}).usingServerKey, isTrue);
    expect(AiKeyTier.fromWire('nope'), AiKeyTier.unknown);
  });

  testWidgets('the keys show their hint, tier, use and last result; one is chosen', (tester) async {
    final repo = await _pump(tester);
    expect(find.byKey(const ValueKey('ai-keys')), findsOneWidget);
    expect(find.text('…a1b2'), findsOneWidget);
    expect(find.text('有料'), findsOneWidget);
    expect(find.text('無料枠'), findsOneWidget);
    expect(find.text('使用中'), findsOneWidget);
    expect(find.text('最後の呼び出し: 回数上限'), findsOneWidget);
    expect(find.text('まだ使われていません'), findsOneWidget);
    expect(find.textContaining('24時間で 12 回（失敗 3）'), findsOneWidget);
    expect(find.textContaining('gemini-flash-lite'), findsOneWidget);

    // Switch to the free key.
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('ak-key-2')), matching: find.byType(Radio<int>)));
    await tester.pumpAndSettle();
    expect(repo.activated, [2]);
    expect(find.text('使うキーを切り替えました。1分以内に反映されます。'), findsOneWidget);
    expect(repo.keys.firstWhere((k) => k.id == 2).isActive, isTrue);

    // And back to the server's own key.
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('ak-server')), matching: find.byType(Radio<int>)));
    await tester.pumpAndSettle();
    expect(repo.activated, [2, null]);
    expect(repo.keys.any((k) => k.isActive), isFalse);
  });

  testWidgets('a key is tried, then retired after confirming', (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('ak-menu-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('接続テスト').last);
    await tester.pumpAndSettle();
    expect(repo.tested, [2]);
    expect(find.text('接続OK（500 ms・gemini-x）'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ak-menu-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除').last);
    await tester.pumpAndSettle();
    expect(find.text('「無料キー」を削除しますか？'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ak-retire-confirm')));
    await tester.pumpAndSettle();
    expect(repo.retired, [2]);
    expect(find.byKey(const ValueKey('ak-key-2')), findsNothing);
    expect(find.text('キーを削除しました'), findsOneWidget);
  });

  testWidgets('a new key needs a name and the key, and can be used at once', (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('ak-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ak-save')));
    await tester.pumpAndSettle();
    expect(repo.added, isEmpty);

    await tester.enterText(find.byKey(const ValueKey('ak-label')), '予備キー');
    await tester.enterText(find.byKey(const ValueKey('ak-key')), 'AIzaSyTESTKEY0000000000000wxyz');
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('ak-tier')), matching: find.text('無料枠')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ak-save')));
    await tester.pumpAndSettle();
    expect(repo.added.single['label'], '予備キー');
    expect(repo.added.single['tier'], AiKeyTier.free);
    expect(repo.added.single['activate'], isTrue);
    expect(find.text('キーを登録しました'), findsOneWidget);
    expect(find.text('…wxyz'), findsOneWidget);
    // The key itself is never shown back.
    expect(find.textContaining('AIzaSyTESTKEY'), findsNothing);
  });

  testWidgets('without the permission the keys are not on the screen', (tester) async {
    await _pump(tester, permissions: const []);
    expect(find.byKey(const ValueKey('ai-keys')), findsNothing);
  });
}
