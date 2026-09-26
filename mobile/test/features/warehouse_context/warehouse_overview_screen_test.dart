// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';
import 'package:wms_mobile/features/warehouse_context/domain/warehouse.dart';
import 'package:wms_mobile/features/warehouse_context/domain/warehouse_role.dart';
import 'package:wms_mobile/features/warehouse_context/presentation/warehouse_overview_screen.dart';

import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/auth/application/auth_controller.dart';
import 'package:wms_mobile/features/auth/data/auth_repository.dart';
import 'package:wms_mobile/features/auth/domain/auth_user.dart';

import '../../support/harness.dart';

/// Signed in, holds a role, but assigned no warehouse — the state migration
/// 0044 made reachable, where the server filters the warehouse list to the
/// caller's own and so returns nothing.
class _ScopedOutAuthRepository implements AuthRepository {
  const _ScopedOutAuthRepository();

  AuthUser get _user => const AuthUser(
        id: '1',
        email: 'picker@test.com',
        name: 'Picker',
        roles: ['picker'],
        permissions: ['inventory.view'],
        warehouseIds: [],
      );

  @override
  Future<ApiResult<AuthUser>> currentUser() async => ApiSuccess(_user);

  @override
  Future<ApiResult<AuthUser>> login(String email, String password) async =>
      ApiSuccess(_user);

  @override
  Future<void> logout() async {}
}

void main() {
  testWidgets('lists every warehouse with its figures, totals and bins',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final warehouses = [
      Warehouse(
          id: 1,
          code: 'KOBE',
          name: '神戸倉庫',
          isDefault: true,
          skuCount: 120,
          onHand: 12430,
          inboundOpen: 12),
      Warehouse(
          id: 2,
          code: 'OSAKA',
          name: '大阪倉庫',
          skuCount: 80,
          onHand: 8210,
          outboundOpen: 9),
    ];
    final container = ProviderContainer(overrides: [
      warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(
        WarehouseOverview(
          warehouses: warehouses,
          totals: WarehouseTotals(
              warehouseCount: 2, skuCount: 200, onHand: 20640, inboundOpen: 12),
        ),
        binsByWarehouse: {
          1: [
            Bin(id: 1, code: 'STAGE-01', binType: 'STAGING'),
            Bin(id: 2, code: 'QC-01', binType: 'QC_HOLD'),
          ],
        },
      )),
    
      warehouseRoleRepositoryProvider.overrideWithValue(FakeWarehouseRoleRepository()),
    ]);
    addTearDown(container.dispose);

    await pumpAppWith(tester, container, const WarehouseOverviewScreen());

    // Both warehouses and their codes.
    expect(find.text('神戸倉庫'), findsOneWidget);
    expect(find.text('大阪倉庫'), findsOneWidget);
    expect(find.text('KOBE'), findsOneWidget);

    // Company totals row.
    expect(find.text('合計'), findsOneWidget);
    expect(find.text('20,640'), findsOneWidget);

    // Per-warehouse figures.
    expect(find.text('12,430'), findsOneWidget);
    expect(find.text('8,210'), findsOneWidget);

    // Bins of the first warehouse render as pills.
    expect(find.text('STAGE-01'), findsOneWidget);
    expect(find.text('QC-01'), findsOneWidget);

    // Tapping a warehouse makes it the active context.
    await tester.tap(find.text('大阪倉庫'));
    await tester.pumpAndSettle();
    expect(container.read(activeWarehouseIdProvider), 2);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'a user with no assigned warehouse is told to ask an admin, not to add one (§37)',
      (tester) async {
    final container = ProviderContainer(overrides: [
      // The server returns an empty list for a scoped-out user, exactly as it
      // would for a company with no warehouses at all — so the screen has to
      // tell the two apart from the signed-in user's own scope.
      warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(
        WarehouseOverview(warehouses: const [], totals: WarehouseTotals()),
      )),
      authRepositoryProvider.overrideWithValue(_ScopedOutAuthRepository()),
      warehouseRoleRepositoryProvider.overrideWithValue(FakeWarehouseRoleRepository()),
    ]);
    addTearDown(container.dispose);

    await pumpAppWith(tester, container, const WarehouseOverviewScreen());
    await tester.pumpAndSettle();

    expect(find.text('倉庫が割り当てられていません'), findsOneWidget);
    // Not the "add your first warehouse" advice, which this user cannot act on.
    expect(find.text('倉庫がまだありません'), findsNothing);
  });

  testWidgets(
      'a warehouse shows its country, and a China warehouse can be set to receive cross-border stock (0087)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    final roles = FakeWarehouseRoleRepository([
      WarehouseRole(id: 1, code: 'KOBE', name: '神戸倉庫', countryCode: 'JP'),
      WarehouseRole(id: 2, code: 'SH', name: '上海倉庫', countryCode: 'CN'),
    ]);
    final container = ProviderContainer(overrides: [
      warehouseRepositoryProvider.overrideWithValue(FakeWarehouseRepository(
        WarehouseOverview(
          warehouses: [
            Warehouse(id: 1, code: 'KOBE', name: '神戸倉庫'),
            Warehouse(id: 2, code: 'SH', name: '上海倉庫'),
          ],
          totals: WarehouseTotals(warehouseCount: 2),
        ),
      )),
      warehouseRoleRepositoryProvider.overrideWithValue(roles),
    ]);
    addTearDown(container.dispose);

    await pumpAppWith(tester, container, const WarehouseOverviewScreen());
    await tester.pumpAndSettle();

    expect(find.text('日本'), findsOneWidget);
    expect(find.text('中国'), findsOneWidget);

    await tester.tap(find.byTooltip('国・役割').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(roles.lastSet, (id: 2, country: 'CN', receives: true));

    await tester.binding.setSurfaceSize(null);
  });
}
