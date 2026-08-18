import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/suppliers/application/supplier_providers.dart';
import 'package:wms_mobile/features/suppliers/data/supplier_repository.dart';
import 'package:wms_mobile/features/suppliers/domain/supplier.dart';
import 'package:wms_mobile/features/suppliers/presentation/supplier_list_screen.dart';

/// In-memory fake so the list renders without a network. `list` filters by a
/// case-insensitive name/code substring, mirroring the real search parameter.
class _FakeSupplierRepository implements SupplierRepository {
  _FakeSupplierRepository(this._all);

  final List<Supplier> _all;

  @override
  Future<ApiResult<List<Supplier>>> list({String? search}) async {
    final q = search?.trim().toLowerCase() ?? '';
    if (q.isEmpty) return ApiSuccess(_all);
    final filtered = _all
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            (s.code?.toLowerCase().contains(q) ?? false))
        .toList();
    return ApiSuccess(filtered);
  }

  @override
  Future<ApiResult<Supplier>> show(int id) async =>
      ApiSuccess(_all.firstWhere((s) => s.id == id));
}

Supplier _sup({
  required int id,
  required String name,
  String? code,
  String? contactName,
  int? productsCount,
}) =>
    Supplier(
      id: id,
      name: name,
      code: code,
      contactName: contactName,
      productsCount: productsCount,
    );

Widget _wrap(SupplierRepository repo) => ProviderScope(
      overrides: [
        supplierRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: SupplierListScreen()),
    );

void main() {
  testWidgets('lists suppliers with their contact and product count',
      (tester) async {
    final repo = _FakeSupplierRepository([
      _sup(
        id: 1,
        name: 'Acme Supply Co',
        code: 'ACME',
        contactName: 'Jane Doe',
        productsCount: 8,
      ),
      _sup(id: 2, name: 'Beta Traders', code: 'BETA', productsCount: 1),
    ]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Acme Supply Co'), findsOneWidget);
    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('8 products'), findsOneWidget);
    expect(find.text('1 product'), findsOneWidget);
  });

  testWidgets('filters results when a query is submitted', (tester) async {
    final repo = _FakeSupplierRepository([
      _sup(id: 1, name: 'Acme Supply Co', code: 'ACME'),
      _sup(id: 2, name: 'Beta Traders', code: 'BETA'),
    ]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'beta');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Beta Traders'), findsOneWidget);
    expect(find.text('Acme Supply Co'), findsNothing);
  });

  testWidgets('shows an empty state when there are no suppliers',
      (tester) async {
    await tester.pumpWidget(_wrap(_FakeSupplierRepository([])));
    await tester.pumpAndSettle();

    expect(find.textContaining('No suppliers yet'), findsOneWidget);
  });
}
