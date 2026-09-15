import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/auth/application/auth_controller.dart';
import 'package:wms_mobile/features/auth/data/auth_repository.dart';
import 'package:wms_mobile/features/auth/domain/auth_user.dart';
import 'package:wms_mobile/features/home/presentation/coming_soon_screen.dart';
import 'package:wms_mobile/features/home/presentation/home_screen.dart';
import 'package:wms_mobile/features/picking_ops/application/picking_ops_providers.dart';
import 'package:wms_mobile/features/picking_ops/domain/pick_list.dart';
import 'package:wms_mobile/features/picking_ops/presentation/pick_list_index_screen.dart';
import 'package:wms_mobile/features/shipment/application/shipment_providers.dart';
import 'package:wms_mobile/l10n/app_localizations.dart';

import '../../../support/harness.dart';

/// Offline fake so the auth controller lands "authenticated" without a network.
/// Every permission the catalog gates on, so this fixture exercises the whole
/// menu — a limited user is covered separately below.
const _allPermissions = [
  'ai.review', 'audit.view', 'connector.manage', 'count.approve',
  'count.perform', 'inspection.confirm', 'inspection.view', 'inventory.adjust',
  'pack.complete', 'partner.manage', 'partner.view', 'pick.confirm',
  'product.manage', 'product.view', 'purchase_order.approve',
  'purchase_order.manage', 'purchase_order.view', 'putaway.confirm',
  'receiving.confirm', 'receiving.view', 'report.manage', 'report.view',
  'sales_order.approve', 'sales_order.manage', 'sales_order.view',
  'ship.complete', 'transfer.approve', 'transfer.create', 'transfer.receive',
  'user.manage', 'work_order.manage', 'work_order.view',
];

class _FakeAuthRepository implements AuthRepository {
  const _FakeAuthRepository({this.permissions = _allPermissions});

  final List<String> permissions;

  AuthUser get _user => AuthUser(
      id: '1',
      name: 'Test Operator',
      email: 'e2e@test.com',
      permissions: permissions);

  @override
  Future<ApiResult<AuthUser>> currentUser() async => ApiSuccess(_user);

  @override
  Future<ApiResult<AuthUser>> login(String email, String password) async =>
      ApiSuccess(_user);

  @override
  Future<void> logout() async {}
}

Widget _wrap({List<String> permissions = _allPermissions}) => ProviderScope(
      overrides: [
        authRepositoryProvider
            .overrideWithValue(_FakeAuthRepository(permissions: permissions)),
        // Empty fakes so navigating into the live Picking screen renders
        // without a network.
        shipmentRepositoryProvider.overrideWithValue(FakeShipmentRepository([])),
        pickingRepositoryProvider.overrideWithValue(
          FakePickingRepository(
            list: const PickList(id: 0, shipmentPlanId: 0),
            started: false,
          ),
        ),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(),
      ),
    );

void main() {
  testWidgets('renders greeting and grouped feature menu', (tester) async {
    // The dashboard grew a §30 notifications section on top of the feature
    // grid; a tall surface keeps everything in the initial layout instead of
    // needing a manual scroll for every assertion below the fold.
    await tester.binding.setSurfaceSize(const Size(900, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Test Operator'), findsOneWidget);
    expect(find.text('Field Operations'), findsOneWidget);
    expect(find.text('Inspection'), findsOneWidget);
    expect(find.text('Shipping'), findsOneWidget);
    // Every catalog feature is now built, so no "Soon" badges remain.
    expect(find.text('Soon'), findsNothing);
  });

  testWidgets('tapping a ready feature opens its live screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    // The Picking card can sit below the fold on the small test viewport;
    // scroll it into view before tapping.
    await tester.ensureVisible(find.text('Picking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Picking'));
    await tester.pumpAndSettle();

    expect(find.byType(PickListIndexScreen), findsOneWidget);
    expect(find.byType(ComingSoonScreen), findsNothing);
    expect(find.text('Nothing to pick.'), findsOneWidget);
  });

  testWidgets('hides menu entries and whole groups the user cannot open (§37)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // Picking only — everything in "management" and the rest of "field
    // operations" is gated on something else.
    await tester.pumpWidget(_wrap(permissions: const ['pick.confirm']));
    await tester.pumpAndSettle();

    expect(find.text('Picking'), findsOneWidget);
    expect(find.text('Inspection'), findsNothing);
    expect(find.text('Shipping'), findsNothing);
    // The whole "management" group has nothing this user may open.
    expect(find.text('Management'), findsNothing);
    expect(find.text('Reports'), findsNothing);
  });

  testWidgets('a user with no role at all is told why the menu is empty (§37)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // Reachable by design: only the first sign-in self-assigns a role
    // (bootstrap_first_admin), so every later account lands here until an
    // admin assigns one. Gating alone would leave an app with no menu and no
    // explanation.
    await tester.pumpWidget(_wrap(permissions: const []));
    await tester.pumpAndSettle();

    expect(find.text('No role assigned yet'), findsOneWidget);
    expect(find.textContaining('Ask an administrator'), findsOneWidget);
  });
}
