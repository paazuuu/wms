import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/auth/application/auth_controller.dart';
import 'package:wms_mobile/features/auth/data/auth_repository.dart';
import 'package:wms_mobile/features/auth/domain/auth_user.dart';
import 'package:wms_mobile/features/home/application/role_dashboard_providers.dart';
import 'package:wms_mobile/features/home/domain/role_dashboards.dart';
import 'package:wms_mobile/features/home/presentation/dashboard_overview_screen.dart';
import 'package:wms_mobile/features/home/presentation/manual_inbound_list_screen.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';

import '../../../support/harness.dart';

class _Auth implements AuthRepository {
  const _Auth(this.roles, this.permissions);

  final List<String> roles;
  final List<String> permissions;

  AuthUser get _user =>
      AuthUser(id: '1', name: 'Tester', email: 't@test.com', roles: roles, permissions: permissions);

  @override
  Future<ApiResult<AuthUser>> currentUser() async => ApiSuccess(_user);

  @override
  Future<ApiResult<AuthUser>> login(String email, String password) async => ApiSuccess(_user);

  @override
  Future<void> logout() async {}
}

const _floor = ['receiving.view', 'receiving.confirm', 'inspection.view', 'inspection.confirm'];
const _buyer = ['inventory.view', 'purchase_order.view', 'purchase_order.manage'];
const _sales = ['sales_order.view', 'sales_order.manage'];

final _schedule = InboundSchedule.fromJson(const {
  'today': '2026-09-27',
  'plans': [
    {
      'id': 1, 'delivery_number': 'DP-1', 'supplier_name': '東京商事', 'po_number': 'PO-000010',
      'expected_on': '2026-09-27', 'manual': false, 'line_count': 4, 'outstanding_units': 120,
      'preview': [
        {'jan_code': '4900000000011', 'product_name': 'お茶 500ml', 'outstanding': 100},
      ],
    },
    {
      'id': 2, 'delivery_number': 'MN-000002', 'supplier_name': '大阪物産',
      'expected_on': '2026-09-28', 'manual': true, 'line_count': 1, 'outstanding_units': 30,
      'preview': [],
    },
    {'id': 3, 'delivery_number': 'DP-3', 'expected_on': null, 'line_count': 1, 'outstanding_units': 5},
  ],
  'unplanned_orders': [
    {'id': 29, 'po_number': 'PO-000029', 'supplier_name': '名古屋', 'expected_date': '2026-10-02',
     'outstanding_units': 15, 'line_count': 1},
  ],
  'awaiting_inspection': {'inspections': 2, 'lines': 3, 'units': 80},
});

final _stock = StockOverview.fromJson(const {
  'country_code': 'JP',
  'products': [
    {'product_id': 7, 'jan_code': '4900000000011', 'product_name': 'お茶 500ml', 'usable': 40,
     'qc_pending': 100, 'held': 5, 'reserved': 10, 'available': 30, 'incoming': 15,
     'next_expected': '2026-10-02', 'backordered': 20, 'shortfall': 5},
  ],
  'totals': {'usable': 40, 'qc_pending': 100, 'held': 5, 'incoming': 15, 'products': 1},
});

final _cycle = SalesCycle.fromJson(const {
  'country_code': 'CN',
  'months': [
    {'month': '2026-08', 'orders': 2, 'units': 30, 'prev_units': 0},
    {'month': '2026-09', 'orders': 1, 'units': 20, 'prev_units': 10},
  ],
  'total_units': 50, 'prev_total_units': 10, 'total_orders': 3,
  'top_products': [{'product_name': 'お茶 500ml', 'jan_code': '4900000000011', 'units': 50, 'orders': 3}],
  'to_purchase': [
    {'product_name': 'お茶 500ml', 'jan_code': '4900000000011', 'backordered': 20, 'incoming': 15,
     'shortfall': 5},
  ],
});

Future<FakeRoleDashboardRepository> _pump(
  WidgetTester tester, {
  required List<String> roles,
  required List<String> permissions,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final repo = FakeRoleDashboardRepository(schedule: _schedule, stock: _stock, sales: _cycle);
  await pumpApp(tester, const Scaffold(body: DashboardOverviewScreen()), overrides: [
    authRepositoryProvider.overrideWithValue(_Auth(roles, permissions)),
    roleDashboardRepositoryProvider.overrideWithValue(repo),
  ]);
  return repo;
}

void main() {
  group('DashboardView', () {
    test('each job opens on its own view', () {
      expect(DashboardView.defaultFor(['inspector']), DashboardView.inspection);
      expect(DashboardView.defaultFor(['receiving']), DashboardView.inspection);
      expect(DashboardView.defaultFor(['purchasing']), DashboardView.purchasing);
      expect(DashboardView.defaultFor(['sales']), DashboardView.sales);
      expect(DashboardView.defaultFor(['warehouse_manager', 'inspector']), DashboardView.overview);
      expect(DashboardView.defaultFor(const []), DashboardView.overview);
    });

    test('a view is offered only to who may read it', () {
      expect(DashboardView.sales.visibleFor(_floor), isFalse);
      expect(DashboardView.inspection.visibleFor(_floor), isTrue);
      expect(DashboardView.purchasing.visibleFor(_buyer), isTrue);
      expect(DashboardView.sales.visibleFor(_sales), isTrue);
      expect(DashboardView.overview.visibleFor(const []), isTrue);
    });

    test('the sales change compares with the year before', () {
      expect(_cycle.change, closeTo(4.0, 1e-9));
      expect(const SalesCycle(totalUnits: 5).change, isNull);
    });
  });

  testWidgets('an inspector opens on what is coming in, by day', (tester) async {
    await _pump(tester, roles: const ['inspector'], permissions: _floor);

    expect(find.byKey(const ValueKey('dash-tab-inspection')), findsOneWidget);
    expect(find.byKey(const ValueKey('dash-tab-sales')), findsNothing);
    expect(find.text('2件・3行・80個'), findsOneWidget);
    expect(find.byKey(const ValueKey('dash-day-today')), findsOneWidget);
    expect(find.byKey(const ValueKey('dash-day-tomorrow')), findsOneWidget);
    expect(find.byKey(const ValueKey('dash-day-none')), findsOneWidget);
    expect(find.text('東京商事'), findsOneWidget);
    expect(find.text('ほか3品目'), findsOneWidget);
    // The hand-written list is marked as such.
    expect(find.descendant(of: find.byKey(const ValueKey('dash-plan-2')), matching: find.text('手動')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('dash-unplanned-29')), findsOneWidget);
    expect(find.byKey(const ValueKey('dash-create-manual-list')), findsOneWidget);
  });

  testWidgets('switching tabs by hand is remembered', (tester) async {
    await _pump(tester,
        roles: const ['inspector'], permissions: const [..._floor, ..._buyer, ..._sales]);

    await tester.tap(find.byKey(const ValueKey('dash-tab-purchasing')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stock-row-7')), findsOneWidget);
    expect(find.text('不足 5'), findsOneWidget);
    expect(find.text('次回 2026-10-02'), findsOneWidget);

    final element = tester.element(find.byType(DashboardOverviewScreen));
    expect(ProviderScope.containerOf(element).read(dashboardViewProvider), DashboardView.purchasing);
  });

  testWidgets('the purchasing view narrows by country and search', (tester) async {
    final repo = await _pump(tester, roles: const ['purchasing'], permissions: _buyer);

    expect(find.text('100'), findsWidgets); // awaiting inspection counts as stock
    await tester.tap(find.byKey(const ValueKey('stock-country-CN')));
    await tester.pumpAndSettle();
    expect(repo.lastStockCountry, 'CN');

    await tester.enterText(find.byKey(const ValueKey('stock-search')), 'お茶');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(repo.lastStockSearch, 'お茶');
  });

  testWidgets('the sales view shows the year against the last, and what to buy', (tester) async {
    final repo = await _pump(tester, roles: const ['sales'], permissions: _sales);

    expect(repo.lastSalesCountry, 'CN');
    expect(find.text('前年比 +400%'), findsOneWidget);
    expect(find.byKey(const ValueKey('sales-purchase-4900000000011')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sales-country-all')));
    await tester.pumpAndSettle();
    expect(repo.lastSalesCountry, isNull);
  });

  testWidgets('a list is written by hand: scans add up, the date is optional', (tester) async {
    final repo = FakeRoleDashboardRepository();
    await pumpApp(tester, const ManualInboundListScreen(), overrides: [
      roleDashboardRepositoryProvider.overrideWithValue(repo),
      activeWarehouseIdProvider.overrideWith((_) => 3),
    ]);

    Future<void> scan(String code) async {
      await tester.enterText(find.byKey(const ValueKey('manual-list-scan')), code);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }

    await scan('4900000000011');
    await scan('4900000000011');
    await scan('123');
    expect(find.text('JANは数字8桁または13桁です'), findsOneWidget);
    await scan('49000028');
    await tester.enterText(find.byKey(const ValueKey('manual-qty-49000028')), '300');
    await tester.enterText(find.byKey(const ValueKey('manual-list-supplier')), '上海貿易');

    await tester.tap(find.byKey(const ValueKey('manual-list-save')));
    await tester.pumpAndSettle();

    final sent = repo.lastManual!;
    expect(sent.warehouseId, 3);
    expect(sent.supplierName, '上海貿易');
    expect(sent.expectedOn, isNull);
    expect(sent.lines, [
      (janCode: '4900000000011', quantity: 2),
      (janCode: '49000028', quantity: 300),
    ]);
  });
}
