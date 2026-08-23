import 'package:flutter/material.dart';
import 'package:wms_mobile/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/locations/application/location_providers.dart';
import 'package:wms_mobile/features/locations/data/location_repository.dart';
import 'package:wms_mobile/features/locations/domain/location.dart';
import 'package:wms_mobile/features/locations/presentation/location_list_screen.dart';

/// In-memory fake so the list renders without a network. `list` filters by a
/// case-insensitive name/code substring, mirroring the real search parameter.
class _FakeLocationRepository implements LocationRepository {
  _FakeLocationRepository(this._all);

  final List<Location> _all;

  @override
  Future<ApiResult<List<Location>>> list({String? search}) async {
    final q = search?.trim().toLowerCase() ?? '';
    if (q.isEmpty) return ApiSuccess(_all);
    final filtered = _all
        .where((l) =>
            l.name.toLowerCase().contains(q) ||
            (l.code?.toLowerCase().contains(q) ?? false))
        .toList();
    return ApiSuccess(filtered);
  }

  @override
  Future<ApiResult<Location>> show(int id) async =>
      ApiSuccess(_all.firstWhere((l) => l.id == id));
}

Location _loc({
  required int id,
  required String name,
  String? code,
  String? fullLocation,
  bool isActive = true,
  int? productsCount,
}) =>
    Location(
      id: id,
      name: name,
      code: code,
      fullLocation: fullLocation,
      isActive: isActive,
      productsCount: productsCount,
    );

Widget _wrap(LocationRepository repo) => ProviderScope(
      overrides: [
        locationRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LocationListScreen(),
      ),
    );

void main() {
  testWidgets('lists locations with their code and item count',
      (tester) async {
    final repo = _FakeLocationRepository([
      _loc(
        id: 1,
        name: 'Receiving Bay A',
        code: 'RB-A',
        fullLocation: 'A-12-3',
        productsCount: 5,
      ),
      _loc(id: 2, name: 'Zone B', code: 'ZN-B', productsCount: 1),
    ]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Receiving Bay A'), findsOneWidget);
    expect(find.text('A-12-3'), findsOneWidget);
    expect(find.text('5 items'), findsOneWidget);
    expect(find.text('1 item'), findsOneWidget);
  });

  testWidgets('filters results when a query is submitted', (tester) async {
    final repo = _FakeLocationRepository([
      _loc(id: 1, name: 'Receiving Bay A', code: 'RB-A'),
      _loc(id: 2, name: 'Zone B', code: 'ZN-B'),
    ]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zone');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Zone B'), findsOneWidget);
    expect(find.text('Receiving Bay A'), findsNothing);
  });

  testWidgets('shows an empty state when there are no matches',
      (tester) async {
    await tester.pumpWidget(_wrap(_FakeLocationRepository([])));
    await tester.pumpAndSettle();

    expect(find.textContaining('No locations yet'), findsOneWidget);
  });
}
