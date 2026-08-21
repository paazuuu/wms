import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/auth/application/auth_controller.dart';
import 'package:wms_mobile/features/auth/data/auth_repository.dart';
import 'package:wms_mobile/features/auth/domain/auth_user.dart';
import 'package:wms_mobile/features/home/presentation/coming_soon_screen.dart';
import 'package:wms_mobile/features/home/presentation/home_screen.dart';
import 'package:wms_mobile/features/picking/presentation/picking_list_screen.dart';
import 'package:wms_mobile/features/sales_orders/application/sales_order_providers.dart';
import 'package:wms_mobile/features/sales_orders/data/sales_order_repository.dart';
import 'package:wms_mobile/features/sales_orders/domain/sales_order.dart';
import 'package:wms_mobile/l10n/app_localizations.dart';

/// Offline fake so the auth controller lands "authenticated" without a network.
class _FakeAuthRepository implements AuthRepository {
  static const _user =
      AuthUser(id: 1, name: 'Test Operator', email: 'e2e@test.com');

  @override
  Future<ApiResult<AuthUser>> currentUser() async => const ApiSuccess(_user);

  @override
  Future<ApiResult<AuthUser>> login(String email, String password) async =>
      const ApiSuccess(_user);

  @override
  Future<void> logout() async {}
}

/// Empty fake so navigating into the live Picking screen renders without a
/// network (it reuses the sales-order repository).
class _EmptySalesOrderRepository implements SalesOrderRepository {
  @override
  Future<ApiResult<List<SalesOrder>>> list({String? search, String? status}) async =>
      const ApiSuccess([]);

  @override
  Future<ApiResult<SalesOrder>> show(int id) async =>
      const ApiFailure(message: 'unused');
}

Widget _wrap() => ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        salesOrderRepositoryProvider
            .overrideWithValue(_EmptySalesOrderRepository()),
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
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Test Operator'), findsOneWidget);
    expect(find.text('Field Operations'), findsOneWidget);
    expect(find.text('Inspection'), findsOneWidget);
    expect(find.text('Receiving'), findsOneWidget);
    // Every catalog feature is now built, so no "Soon" badges remain.
    expect(find.text('Soon'), findsNothing);
  });

  testWidgets('tapping a ready feature opens its live screen', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    // The Picking card can sit below the fold on the small test viewport;
    // scroll it into view before tapping.
    await tester.ensureVisible(find.text('Picking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Picking'));
    await tester.pumpAndSettle();

    expect(find.byType(PickingListScreen), findsOneWidget);
    expect(find.byType(ComingSoonScreen), findsNothing);
    expect(find.text('Nothing to pick.'), findsOneWidget);
  });
}
