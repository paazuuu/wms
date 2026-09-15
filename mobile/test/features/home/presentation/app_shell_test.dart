import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/auth/application/auth_controller.dart';
import 'package:wms_mobile/features/auth/data/auth_repository.dart';
import 'package:wms_mobile/features/auth/domain/auth_user.dart';
import 'package:go_router/go_router.dart';
import 'package:wms_mobile/core/router/app_router.dart';
import 'package:wms_mobile/features/home/domain/feature_catalog.dart';
import 'package:wms_mobile/features/home/presentation/app_shell.dart';
import 'package:wms_mobile/features/home/presentation/coming_soon_screen.dart';
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

/// Builds the app the way `WmsApp` does — through the real [goRouterProvider]
/// rather than pumping the shell directly — so these tests exercise the
/// redirect chain and the URL, not just the widget tree. Returns the router so
/// a test can assert on the current location.
({Widget widget, GoRouter router, ProviderContainer container}) _wrap({
  List<String> permissions = _allPermissions,
}) {
  final container = ProviderContainer(
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
  );
  addTearDown(container.dispose);
  final router = container.read(goRouterProvider);

  return (
    router: router,
    container: container,
    widget: UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

void main() {
  testWidgets('renders greeting and grouped feature menu', (tester) async {
    // The dashboard grew a §30 notifications section on top of the feature
    // grid; a tall surface keeps everything in the initial layout instead of
    // needing a manual scroll for every assertion below the fold.
    await tester.binding.setSurfaceSize(const Size(900, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_wrap().widget);
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
    await tester.pumpWidget(_wrap().widget);
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
    await tester.pumpWidget(_wrap(permissions: const ['pick.confirm']).widget);
    await tester.pumpAndSettle();

    expect(find.text('Picking'), findsOneWidget);
    expect(find.text('Inspection'), findsNothing);
    expect(find.text('Shipping'), findsNothing);
    // The whole "management" group has nothing this user may open.
    expect(find.text('Management'), findsNothing);
    // 'Report builder' is the actual label; the earlier 'Reports' spelling
    // here matched nothing either way, so this assertion passed vacuously and
    // proved nothing about group hiding.
    expect(find.text('Report builder'), findsNothing);
  });

  testWidgets('a user with no role at all is told why the menu is empty (§37)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // Reachable by design: only the first sign-in self-assigns a role
    // (bootstrap_first_admin), so every later account lands here until an
    // admin assigns one. Gating alone would leave an app with no menu and no
    // explanation.
    await tester.pumpWidget(_wrap(permissions: const []).widget);
    await tester.pumpAndSettle();

    expect(find.text('No role assigned yet'), findsOneWidget);
    expect(find.textContaining('Ask an administrator'), findsOneWidget);
  });

  group('routing', () {
    testWidgets('opening a feature puts it in the URL', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final app = _wrap();
      await tester.pumpWidget(app.widget);
      await tester.pumpAndSettle();

      // Signed in and settled: the dashboard is the location, not the splash
      // or login page the redirect chain passes through.
      expect(_location(app.router), '/');

      await tester.ensureVisible(find.text('Picking'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Picking'));
      await tester.pumpAndSettle();

      // This is the whole point of the change: the screen and the address
      // agree, so the browser has something to put in its history and the
      // operator has something to bookmark.
      expect(_location(app.router), '/picking');
    });

    testWidgets('a URL resolves straight to its screen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final app = _wrap();
      await tester.pumpWidget(app.widget);
      await tester.pumpAndSettle();

      // What a reload or a pasted link does: hand the router a location and
      // get that screen, without passing through the dashboard first.
      app.router.go('/picking');
      await tester.pumpAndSettle();

      expect(find.byType(PickListIndexScreen), findsOneWidget);
      expect(_location(app.router), '/picking');
    });

    testWidgets('every catalog feature has a reachable route', (tester) async {
      // Guards the derived-path scheme: adding a catalog entry whose id does
      // not map onto a declared route would silently 404 that menu item.
      // Checked against the router's own configuration rather than by
      // navigating to all eighteen screens, which would need every
      // repository faked.
      final app = _wrap();
      final declared = <String>{};
      void collect(List<RouteBase> routes) {
        for (final r in routes) {
          if (r is GoRoute) declared.add(r.path);
          collect(r.routes);
        }
      }

      collect(app.router.configuration.routes);

      for (final group in buildFeatureCatalog()) {
        for (final entry in group.entries) {
          expect(declared, contains(entry.path), reason: entry.id);
        }
      }
    });

    testWidgets('signing out redirects to the login page', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final app = _wrap();
      await tester.pumpWidget(app.widget);
      await tester.pumpAndSettle();
      expect(_location(app.router), '/');

      // Ends the session at the controller rather than through the sidebar
      // button, because the redirect — not the button — is what is under test.
      // Driving it this way covers every way a session can end, including a
      // token that simply expires while nobody is clicking anything.
      await app.container.read(authControllerProvider.notifier).logout();
      await tester.pumpAndSettle();

      expect(_location(app.router), '/login');
      expect(find.byType(PickListIndexScreen), findsNothing);
    });

    testWidgets('the sidebar collapses to an icon rail and back',
        (tester) async {
      // The earlier tests run at a logical width below the 900px breakpoint,
      // so they exercise the drawer layout. Collapsing is wide-layout only,
      // which needs a view genuinely wider than the breakpoint.
      tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = const Size(1400, 1200);
      addTearDown(tester.view.reset);

      final app = _wrap();
      await tester.pumpWidget(app.widget);
      await tester.pumpAndSettle();

      // Scoped to the sidebar throughout: the dashboard's own feature grid
      // renders the same section headings and feature names, so an unscoped
      // finder would match either and prove nothing.
      Finder inSidebar(String text) => find.descendant(
            of: find.byKey(sidebarKey),
            matching: find.text(text),
          );
      double sidebarWidth() =>
          tester.getSize(find.byKey(sidebarKey)).width;

      // Expanded by default. The sidebar uppercases its section headings,
      // which is also what distinguishes them from the dashboard's.
      expect(inSidebar('FIELD OPERATIONS'), findsOneWidget);
      expect(inSidebar('Picking'), findsOneWidget);
      expect(find.byTooltip('Collapse menu'), findsOneWidget);
      expect(sidebarWidth(), 268);

      await tester.tap(find.byTooltip('Collapse menu'));
      await tester.pumpAndSettle();

      // Labels give way to icons, and the section heading to a rule.
      expect(inSidebar('FIELD OPERATIONS'), findsNothing);
      expect(inSidebar('Picking'), findsNothing);
      expect(sidebarWidth(), 76);
      // But nothing is unreachable: the label is one hover away.
      expect(find.byTooltip('Picking'), findsOneWidget);
      expect(find.byTooltip('Expand menu'), findsOneWidget);

      await tester.tap(find.byTooltip('Expand menu'));
      await tester.pumpAndSettle();

      expect(inSidebar('FIELD OPERATIONS'), findsOneWidget);
      expect(sidebarWidth(), 268);
      expect(find.byTooltip('Collapse menu'), findsOneWidget);
    });

    testWidgets('a collapsed rail still navigates', (tester) async {
      tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = const Size(1400, 1200);
      addTearDown(tester.view.reset);

      final app = _wrap();
      await tester.pumpWidget(app.widget);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Collapse menu'));
      await tester.pumpAndSettle();

      // Collapsing trades labels for content width; it must not cost the
      // operator access to a feature.
      await tester.tap(find.byTooltip('Picking'));
      await tester.pumpAndSettle();

      expect(_location(app.router), '/picking');
    });

    testWidgets('the menu filter narrows entries and whole groups',
        (tester) async {
      tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = const Size(1400, 1200);
      addTearDown(tester.view.reset);

      final app = _wrap();
      await tester.pumpWidget(app.widget);
      await tester.pumpAndSettle();

      Finder inSidebar(String text) => find.descendant(
            of: find.byKey(sidebarKey),
            matching: find.text(text),
          );

      expect(inSidebar('Inspection'), findsOneWidget);
      expect(inSidebar('FIELD OPERATIONS'), findsOneWidget);
      expect(inSidebar('MANAGEMENT'), findsOneWidget);

      await tester.enterText(find.byKey(menuFilterKey), 'inspection');
      await tester.pumpAndSettle();

      expect(inSidebar('Inspection'), findsOneWidget);
      expect(inSidebar('Picking'), findsNothing);
      // A group with no surviving entry disappears with them, rather than
      // leaving a heading over nothing.
      expect(inSidebar('MANAGEMENT'), findsNothing);
      expect(inSidebar('FIELD OPERATIONS'), findsOneWidget);
      // The dashboard entry is filtered too, so this narrows the whole menu
      // and not everything-but-the-first-item.
      expect(inSidebar('Dashboard'), findsNothing);
    });

    testWidgets('matching descriptions costs some precision, by choice',
        (tester) async {
      tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = const Size(1400, 1200);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap().widget);
      await tester.pumpAndSettle();

      Finder inSidebar(String text) => find.descendant(
            of: find.byKey(sidebarKey),
            matching: find.text(text),
          );

      await tester.enterText(find.byKey(menuFilterKey), 'pick');
      await tester.pumpAndSettle();

      expect(inSidebar('Picking'), findsOneWidget);
      // Report builder's description opens "Pick a data source...", so it
      // survives a filter for 'pick'. Documented rather than tuned away: the
      // same rule is what makes 'approve' find the order screens, and a
      // near-miss that stays visible is cheaper for an operator than a
      // relevant entry that vanishes.
      expect(inSidebar('Report builder'), findsOneWidget);
    });

    testWidgets('the filter matches descriptions, not just labels',
        (tester) async {
      tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = const Size(1400, 1200);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap().widget);
      await tester.pumpAndSettle();

      // 'approve' appears in no label at all — it is the word an operator
      // hunting for approvals would actually type, and it lives in the
      // purchase/sales/work order descriptions.
      await tester.enterText(find.byKey(menuFilterKey), 'approve');
      await tester.pumpAndSettle();

      Finder inSidebar(String text) => find.descendant(
            of: find.byKey(sidebarKey),
            matching: find.text(text),
          );
      expect(inSidebar('Purchase orders'), findsOneWidget);
      expect(inSidebar('Sales orders'), findsOneWidget);
      expect(inSidebar('Putaway'), findsNothing);
    });

    testWidgets('a filter matching nothing says so', (tester) async {
      tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = const Size(1400, 1200);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap().widget);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(menuFilterKey), 'zzzzz');
      await tester.pumpAndSettle();

      // An empty sidebar with no explanation reads as a broken menu.
      expect(find.text('No matching menu item'), findsOneWidget);
    });

    testWidgets('collapsing clears an active filter', (tester) async {
      tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = const Size(1400, 1200);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap().widget);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(menuFilterKey), 'pick');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Collapse menu'));
      await tester.pumpAndSettle();

      // Otherwise the rail shows a mysteriously short list, and expanding
      // restores a filter the operator has forgotten about.
      expect(find.byTooltip('Inspection'), findsOneWidget);

      await tester.tap(find.byTooltip('Expand menu'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
            of: find.byKey(sidebarKey), matching: find.text('Inspection')),
        findsOneWidget,
      );
    });

    test('a scanned code is carried in the URL, escaped', () {
      expect(AppRoutes.stock('4901234567894'), '/stock/4901234567894');
      // A code containing a slash must not invent a path segment.
      expect(AppRoutes.stock('AB/12'), '/stock/AB%2F12');
    });
  });
}
