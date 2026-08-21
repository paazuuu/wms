import 'package:flutter/material.dart';
import 'package:wms_mobile/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/warehouses/application/warehouse_providers.dart';
import 'package:wms_mobile/features/warehouses/data/warehouse_repository.dart';
import 'package:wms_mobile/features/warehouses/domain/warehouse.dart';
import 'package:wms_mobile/features/warehouses/presentation/warehouse_list_screen.dart';

/// In-memory fake so the list renders without a network. `list` filters by a
/// case-insensitive name/code/city substring, mirroring the search parameter.
class _FakeWarehouseRepository implements WarehouseRepository {
  _FakeWarehouseRepository(this._all);

  final List<Warehouse> _all;

  @override
  Future<ApiResult<List<Warehouse>>> list({String? search}) async {
    final q = search?.trim().toLowerCase() ?? '';
    if (q.isEmpty) return ApiSuccess(_all);
    final filtered = _all
        .where((w) =>
            w.name.toLowerCase().contains(q) ||
            (w.code?.toLowerCase().contains(q) ?? false) ||
            (w.city?.toLowerCase().contains(q) ?? false))
        .toList();
    return ApiSuccess(filtered);
  }

  @override
  Future<ApiResult<Warehouse>> show(int id) async =>
      ApiSuccess(_all.firstWhere((w) => w.id == id));
}

Warehouse _wh({
  required int id,
  required String name,
  String? code,
  String? city,
  bool isDefault = false,
  int? locationsCount,
}) =>
    Warehouse(
      id: id,
      name: name,
      code: code,
      city: city,
      isDefault: isDefault,
      locationsCount: locationsCount,
    );

Widget _wrap(WarehouseRepository repo) => ProviderScope(
      overrides: [
        warehouseRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WarehouseListScreen(),
      ),
    );

void main() {
  testWidgets('lists warehouses with city, default badge and bin count',
      (tester) async {
    final repo = _FakeWarehouseRepository([
      _wh(
        id: 1,
        name: 'Central DC',
        code: 'CDC',
        city: 'Toronto',
        isDefault: true,
        locationsCount: 12,
      ),
      _wh(id: 2, name: 'West Hub', code: 'WST', city: 'Calgary',
          locationsCount: 1),
    ]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Central DC'), findsOneWidget);
    expect(find.text('Toronto'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
    expect(find.text('12 bins'), findsOneWidget);
    expect(find.text('1 bin'), findsOneWidget);
  });

  testWidgets('filters results when a query is submitted', (tester) async {
    final repo = _FakeWarehouseRepository([
      _wh(id: 1, name: 'Central DC', code: 'CDC', city: 'Toronto'),
      _wh(id: 2, name: 'West Hub', code: 'WST', city: 'Calgary'),
    ]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'calgary');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('West Hub'), findsOneWidget);
    expect(find.text('Central DC'), findsNothing);
  });

  testWidgets('shows an empty state when there are no warehouses',
      (tester) async {
    await tester.pumpWidget(_wrap(_FakeWarehouseRepository([])));
    await tester.pumpAndSettle();

    expect(find.textContaining('No warehouses yet'), findsOneWidget);
  });
}
