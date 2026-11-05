import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/admin/application/admin_providers.dart';
import 'package:wms_mobile/features/admin/data/user_provisioning_repository.dart';
import 'package:wms_mobile/features/admin/domain/app_user_summary.dart';
import 'package:wms_mobile/features/admin/domain/user_tier.dart';
import 'package:wms_mobile/features/admin/presentation/add_users_dialog.dart';
import 'package:wms_mobile/features/admin/presentation/user_management_screen.dart';

import '../../support/harness.dart';

class _Provision implements UserProvisioningRepository {
  final created = <List<NewUser>>[];
  final reset = <String>[];
  final changed = <String>[];

  @override
  Future<ApiResult<List<ProvisionResult>>> create(List<NewUser> users) async {
    created.add(users);
    return ApiSuccess([
      for (final (i, u) in users.indexed)
        i == 0
            ? ProvisionResult(email: u.email, tier: u.tier, status: 'existing')
            : ProvisionResult(email: u.email, tier: u.tier, status: 'created', password: 'Pw${i}abcdefgh'),
    ]);
  }

  @override
  Future<ApiResult<String>> resetPassword(String userId) async {
    reset.add(userId);
    return const ApiSuccess('NewPass2345x');
  }

  @override
  Future<ApiResult<bool>> changeOwnPassword(String password) async {
    changed.add(password);
    return const ApiSuccess(true);
  }
}

void main() {
  test('people pasted from a sheet: email and kind a line, headings passed over', () {
    final users = parseNewUsers('メールアドレス\t役割\n'
        'info@example.com\t普通\n'
        'adam@example.com\t管理\n'
        'Ganki.Rin@Example.com\tシステムADMIN\n'
        'jeff@example.com\n'
        'jeff@example.com\t管理\n'
        'yamada@example.com, 山田, 管理者\n');
    expect(users.map((u) => (u.email, u.tier)), [
      ('info@example.com', UserTier.user),
      ('adam@example.com', UserTier.manager),
      ('ganki.rin@example.com', UserTier.admin),
      ('jeff@example.com', UserTier.user),
      ('yamada@example.com', UserTier.manager),
    ]);
    expect(users.last.name, '山田');
  });

  testWidgets('ADMIN adds users by pasting, sees the temporary passwords once and copies them', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? clip;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clip = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final p = _Provision();
    await pumpApp(tester, const UserManagementScreen(), overrides: [
      adminRepositoryProvider.overrideWithValue(FakeAdminRepository([
        AppUserSummary(id: 'u1', name: 'ganki', email: 'ganki@example.com', status: 'active', createdAt: DateTime(2026),
            roles: const [UserRoleTag(code: 'system_admin', name: 'System Admin')]),
      ])),
      userProvisioningRepositoryProvider.overrideWithValue(p),
    ]);
    expect(find.text('区分: ADMIN'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('um-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('um-add-text')), 'ganki@example.com\tシステムADMIN\nnew@example.com\t普通');
    await tester.pump();
    expect(find.byKey(const ValueKey('um-add-row-1')), findsOneWidget);
    // The second made a manager by hand.
    await tester.tap(find.byKey(const ValueKey('um-add-tier-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('管理者').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('um-add-ok')));
    await tester.pumpAndSettle();

    expect(p.created.single.map((u) => (u.email, u.tier)), [
      ('ganki@example.com', UserTier.admin),
      ('new@example.com', UserTier.manager),
    ]);
    expect(find.byKey(const ValueKey('um-results')), findsOneWidget);
    expect(find.text('既存（役割を追加）'), findsOneWidget);
    expect(find.text('Pw1abcdefgh'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('um-copy')));
    await tester.pumpAndSettle();
    expect(clip, 'new@example.com\t管理者\tPw1abcdefgh');
  });

  testWidgets('a password is reissued for one person', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final p = _Provision();
    await pumpApp(tester, const UserManagementScreen(), overrides: [
      adminRepositoryProvider.overrideWithValue(FakeAdminRepository([
        AppUserSummary(id: 'u9', name: 'jeff', email: 'jeff@example.com', status: 'active', createdAt: DateTime(2026),
            roles: const [UserRoleTag(code: 'picker', name: 'Picker')]),
      ])),
      userProvisioningRepositoryProvider.overrideWithValue(p),
    ]);
    expect(find.text('区分: 通常'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('um-reset-u9')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('um-reset-ok')));
    await tester.pumpAndSettle();
    expect(p.reset, ['u9']);
    expect(find.text('NewPass2345x'), findsOneWidget);
  });

  testWidgets('one changes one\'s own password: 8 or more, typed twice', (tester) async {
    final p = _Provision();
    await pumpApp(tester, const Scaffold(body: ChangePasswordDialog()), overrides: [
      userProvisioningRepositoryProvider.overrideWithValue(p),
    ]);
    await tester.enterText(find.byKey(const ValueKey('pw-new')), 'short');
    await tester.enterText(find.byKey(const ValueKey('pw-again')), 'short');
    await tester.tap(find.byKey(const ValueKey('pw-save')));
    await tester.pump();
    expect(find.text('8文字以上にしてください'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('pw-new')), 'longenough1');
    await tester.enterText(find.byKey(const ValueKey('pw-again')), 'longenough2');
    await tester.tap(find.byKey(const ValueKey('pw-save')));
    await tester.pump();
    expect(find.text('2つのパスワードが違います'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('pw-again')), 'longenough1');
    await tester.tap(find.byKey(const ValueKey('pw-save')));
    await tester.pump();
    expect(p.changed, ['longenough1']);
  });
}
