import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/admin/data/menu_visibility_repository.dart';
import 'package:wms_mobile/features/admin/domain/user_tier.dart';
import 'package:wms_mobile/features/admin/presentation/menu_visibility_screen.dart';
import 'package:wms_mobile/features/auth/application/auth_controller.dart';
import 'package:wms_mobile/features/auth/domain/auth_user.dart';
import 'package:wms_mobile/features/home/domain/feature_catalog.dart';
import 'package:wms_mobile/features/product/presentation/purchase_price_card.dart';

import '../../support/harness.dart';

const _all = [
  'inspection.view', 'inspection.confirm', 'inventory.view', 'inventory.adjust', 'ship.complete', 'pack.complete',
  'sales_order.view', 'purchase_order.view', 'report.view', 'user.manage', 'product.view',
];

Future<Set<String>> _hiddenFor(List<String> roles, {Map<String, bool> settings = const {}}) async {
  final c = ProviderContainer(overrides: [
    authControllerProvider.overrideWith(
        (ref) => fakeAuthControllerFor(AuthUser(id: 'u', email: 'u@test', roles: roles, permissions: _all))),
    menuVisibilityRepositoryProvider.overrideWithValue(FakeMenuVisibilityRepository(Map.of(settings))),
  ]);
  addTearDown(c.dispose);
  c.read(authControllerProvider);
  await c.read(menuVisibilitySettingsProvider.future);
  return c.read(hiddenFeaturesProvider);
}

void main() {
  test('the tier comes from the roles held', () {
    expect(UserTier.of(['system_admin']), UserTier.admin);
    expect(UserTier.of(['company_admin', 'picker']), UserTier.admin);
    expect(UserTier.of(['warehouse_manager']), UserTier.manager);
    expect(UserTier.of(['sales', 'picker']), UserTier.manager);
    expect(UserTier.of(['picker', 'packer']), UserTier.user);
    expect(UserTier.of(const []), isNull);
  });

  test('by default a user sees the floor only, a manager more, ADMIN everything', () async {
    final groupOf = {for (final g in buildFeatureCatalog()) for (final e in g.entries) e.id: g.id};
    final user = await _hiddenFor(['picker']);
    expect(user, isNot(contains('inspection')));
    expect(user, isNot(contains('outbound_calendar')));
    expect(user, containsAll(['outbound', 'payments', 'products', 'user_management', 'menu_visibility', contentPrices]));
    expect([for (final id in user) if (groupOf[id] == 'field_operations') id], isEmpty);

    final manager = await _hiddenFor(['warehouse_manager']);
    expect(manager, isNot(contains('outbound')));
    expect(manager, isNot(contains('products')));
    expect(manager, isNot(contains('reports')));
    expect(manager, isNot(contains(contentPrices)));
    expect(manager, containsAll(['payments', 'user_management', 'menu_visibility']));

    expect(await _hiddenFor(['system_admin']), isEmpty);
    expect(await _hiddenFor(const []), isEmpty, reason: 'no role: no permission to show anything anyway');
  });

  test('what ADMIN set wins over the default', () async {
    final hidden = await _hiddenFor(['picker'], settings: {
      visibilityKey('outbound', UserTier.user): true,
      visibilityKey('stock_adjustment', UserTier.user): false,
    });
    expect(hidden, isNot(contains('outbound')));
    expect(hidden, contains('stock_adjustment'));
  });

  testWidgets('表示設定: ticked per tier, saved, back to the defaults', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 6000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeMenuVisibilityRepository();
    await pumpApp(tester, const MenuVisibilityScreen(), overrides: [
      menuVisibilityRepositoryProvider.overrideWithValue(repo),
    ]);
    bool box(String key) => tester.widget<Checkbox>(find.byKey(ValueKey(key))).value!;
    expect(box('mv-outbound-user'), isFalse);
    expect(box('mv-outbound-manager'), isTrue);
    expect(box('mv-inspection-user'), isTrue);
    expect(box('mv-content.prices-user'), isFalse);

    await tester.tap(find.byKey(const ValueKey('mv-outbound-user')));
    await tester.tap(find.byKey(const ValueKey('mv-inspection-user')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('mv-save')));
    await tester.pumpAndSettle();
    expect(repo.saved.single[visibilityKey('outbound', UserTier.user)], isTrue);
    expect(repo.saved.single[visibilityKey('inspection', UserTier.user)], isFalse);
    expect(find.text('表示設定を保存しました'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mv-defaults')));
    await tester.pump();
    expect(box('mv-outbound-user'), isFalse);
    expect(box('mv-inspection-user'), isTrue);
  });

  testWidgets('prices hidden from a tier: the purchase price card is not shown', (tester) async {
    await pumpApp(tester, const PurchasePriceCard(productId: 1), overrides: [
      showPricesProvider.overrideWithValue(false),
    ]);
    expect(find.byKey(const ValueKey('pp-card')), findsNothing);
  });
}
