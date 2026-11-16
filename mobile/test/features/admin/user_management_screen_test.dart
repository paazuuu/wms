import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/admin/application/admin_providers.dart';
import 'package:wms_mobile/features/admin/domain/app_user_summary.dart';
import 'package:wms_mobile/features/admin/presentation/user_management_screen.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';
import 'package:wms_mobile/features/warehouse_context/domain/warehouse.dart';

import '../../support/harness.dart';

void main() {
  const roleCatalog = [
    RoleOption(code: 'system_admin', name: 'System Admin'),
    RoleOption(code: 'picker', name: 'Picker'),
  ];

  testWidgets('lists users with their 区分 and what it allows', (tester) async {
    final repo = FakeAdminRepository(
      [
        AppUserSummary(
          id: 'u1',
          name: 'Yamada',
          email: 'yamada@example.com',
          status: 'active',
          createdAt: DateTime(2026, 1, 1),
          roles: const [UserRoleTag(code: 'floor_staff', name: 'Floor Staff')],
        ),
      ],
      roles: roleCatalog,
    );

    await pumpApp(
      tester,
      const UserManagementScreen(),
      overrides: [adminRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.text('Yamada'), findsOneWidget);
    expect(find.text('yamada@example.com'), findsOneWidget);
    expect(find.text('通常'), findsOneWidget);
    expect(find.textContaining('現場スタッフ'), findsOneWidget);
    // No role is taken off by a cross any more.
    expect(find.byIcon(Icons.add_moderator_outlined), findsNothing);
  });

  testWidgets('a user with no roles says so rather than showing nothing',
      (tester) async {
    final repo = FakeAdminRepository(
      [
        AppUserSummary(
          id: 'u1',
          name: 'Suzuki',
          email: 'suzuki@example.com',
          status: 'active',
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
      roles: roleCatalog,
    );

    await pumpApp(
      tester,
      const UserManagementScreen(),
      overrides: [adminRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.text('ロール未割り当て'), findsOneWidget);
  });

  testWidgets('an empty roster explains itself rather than showing nothing',
      (tester) async {
    final repo = FakeAdminRepository(const [], roles: roleCatalog);

    await pumpApp(
      tester,
      const UserManagementScreen(),
      overrides: [adminRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.text('ユーザーがまだいません'), findsOneWidget);
  });

  testWidgets(
      'a non-admin sees a friendly permission error, not raw RPC text (§34)',
      (tester) async {
    final repo = FakeAdminRepository(const [], roles: roleCatalog)
      ..failListUsersWith = 'not permitted: user.manage required';

    await pumpApp(
      tester,
      const UserManagementScreen(),
      overrides: [adminRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.text('この操作を行う権限がありません。'), findsOneWidget);
    expect(find.textContaining('user.manage'), findsNothing);
  });

  testWidgets('区分: 通常 to 管理者 after a confirm; cancelled, nothing changes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeAdminRepository(
      [
        AppUserSummary(
          id: 'u1',
          name: 'Yamada',
          email: 'yamada@example.com',
          status: 'active',
          createdAt: DateTime(2026, 1, 1),
          roles: const [UserRoleTag(code: 'floor_staff', name: 'Floor Staff')],
        ),
      ],
      roles: roleCatalog,
    );
    await pumpApp(tester, const UserManagementScreen(), overrides: [adminRepositoryProvider.overrideWithValue(repo)]);

    // Cancelled: still 通常.
    await tester.tap(find.byKey(const ValueKey('um-tier-u1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('um-tier-u1-manager')));
    await tester.pumpAndSettle();
    expect(find.textContaining('「通常」から「管理者」'), findsOneWidget);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(repo.tiers, isEmpty);
    expect(find.text('通常'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('um-tier-u1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('um-tier-u1-manager')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('um-tier-ok-u1')));
    await tester.pumpAndSettle();
    expect(repo.tiers, [('u1', 'manager')]);
    expect(find.text('管理者'), findsOneWidget);
    expect(find.textContaining('倉庫責任者'), findsOneWidget);
  });

  const warehouseCatalog = [
    Warehouse(id: 1, code: 'MAIN', name: '神戸倉庫'),
    Warehouse(id: 2, code: 'SUB', name: '大阪倉庫'),
  ];

  testWidgets('shows the warehouses a user is scoped to by name', (tester) async {
    final repo = FakeAdminRepository(
      [
        AppUserSummary(
          id: 'u1',
          name: 'Yamada',
          email: 'yamada@example.com',
          status: 'active',
          createdAt: DateTime(2026, 1, 1),
          warehouseIds: const [1],
        ),
      ],
      roles: roleCatalog,
    );

    await pumpApp(
      tester,
      const UserManagementScreen(),
      overrides: [
        adminRepositoryProvider.overrideWithValue(repo),
        warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(
          const WarehouseOverview(
            warehouses: warehouseCatalog,
            totals: WarehouseTotals(),
          ),
        )),
      ],
    );

    expect(find.text('神戸倉庫'), findsOneWidget);
    expect(find.text('大阪倉庫'), findsNothing);
  });

  testWidgets('a user with no warehouse says so rather than showing nothing',
      (tester) async {
    final repo = FakeAdminRepository(
      [
        AppUserSummary(
          id: 'u1',
          name: 'Yamada',
          email: 'yamada@example.com',
          status: 'active',
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
      roles: roleCatalog,
    );

    await pumpApp(
      tester,
      const UserManagementScreen(),
      overrides: [
        adminRepositoryProvider.overrideWithValue(repo),
        warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(
          const WarehouseOverview(
            warehouses: warehouseCatalog,
            totals: WarehouseTotals(),
          ),
        )),
      ],
    );

    expect(find.textContaining('倉庫が割り当てられていません'), findsOneWidget);
  });

  testWidgets('adding a warehouse from the picker attaches it to the user',
      (tester) async {
    final repo = FakeAdminRepository(
      [
        AppUserSummary(
          id: 'u1',
          name: 'Yamada',
          email: 'yamada@example.com',
          status: 'active',
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
      roles: roleCatalog,
    );

    await pumpApp(
      tester,
      const UserManagementScreen(),
      overrides: [
        adminRepositoryProvider.overrideWithValue(repo),
        warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(
          const WarehouseOverview(
            warehouses: warehouseCatalog,
            totals: WarehouseTotals(),
          ),
        )),
      ],
    );

    await tester.tap(find.byIcon(Icons.add_business_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('神戸倉庫'));
    await tester.pumpAndSettle();

    expect(find.text('神戸倉庫'), findsOneWidget);
  });

  testWidgets('removing a warehouse detaches it after confirming', (tester) async {
    final repo = FakeAdminRepository(
      [
        AppUserSummary(
          id: 'u1',
          name: 'Yamada',
          email: 'yamada@example.com',
          status: 'active',
          createdAt: DateTime(2026, 1, 1),
          warehouseIds: const [1],
        ),
      ],
      roles: roleCatalog,
    );

    await pumpApp(
      tester,
      const UserManagementScreen(),
      overrides: [
        adminRepositoryProvider.overrideWithValue(repo),
        warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(
          const WarehouseOverview(
            warehouses: warehouseCatalog,
            totals: WarehouseTotals(),
          ),
        )),
      ],
    );

    expect(find.text('神戸倉庫'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();

    expect(find.textContaining('倉庫が割り当てられていません'), findsOneWidget);
  });
}
