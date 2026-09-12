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

  testWidgets('lists users with their current roles', (tester) async {
    final repo = FakeAdminRepository(
      [
        AppUserSummary(
          id: 'u1',
          name: 'Yamada',
          email: 'yamada@example.com',
          status: 'active',
          createdAt: DateTime(2026, 1, 1),
          roles: const [UserRoleTag(code: 'picker', name: 'Picker')],
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
    expect(find.text('Picker'), findsOneWidget);
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

  testWidgets('a non-admin sees the permission error, not an empty screen',
      (tester) async {
    final repo = FakeAdminRepository(const [], roles: roleCatalog)
      ..failListUsersWith = 'not permitted: user.manage required';

    await pumpApp(
      tester,
      const UserManagementScreen(),
      overrides: [adminRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.textContaining('user.manage'), findsOneWidget);
  });

  testWidgets('adding a role from the picker attaches it to the user',
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
      overrides: [adminRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.tap(find.byIcon(Icons.add_moderator_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Picker'));
    await tester.pumpAndSettle();

    expect(find.text('Picker'), findsOneWidget);
  });

  testWidgets('removing a role detaches it after confirming', (tester) async {
    final repo = FakeAdminRepository(
      [
        AppUserSummary(
          id: 'u1',
          name: 'Yamada',
          email: 'yamada@example.com',
          status: 'active',
          createdAt: DateTime(2026, 1, 1),
          roles: const [UserRoleTag(code: 'picker', name: 'Picker')],
        ),
      ],
      roles: roleCatalog,
    );

    await pumpApp(
      tester,
      const UserManagementScreen(),
      overrides: [adminRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.text('Picker'), findsOneWidget);

    // Material 3's default chip delete affordance is Icons.clear, not the
    // Icons.cancel used pre-M3 — confirmed by dumping the rendered icons.
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();

    expect(find.text('ロール未割り当て'), findsOneWidget);
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
