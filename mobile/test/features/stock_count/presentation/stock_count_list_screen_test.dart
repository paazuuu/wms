import 'package:flutter/material.dart';
import 'package:wms_mobile/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/stock_count/application/stock_audit_providers.dart';
import 'package:wms_mobile/features/stock_count/data/stock_audit_repository.dart';
import 'package:wms_mobile/features/stock_count/domain/stock_audit.dart';
import 'package:wms_mobile/features/stock_count/presentation/stock_count_list_screen.dart';

/// In-memory fake so the browse list renders without a network.
class _FakeStockAuditRepository implements StockAuditRepository {
  _FakeStockAuditRepository(this._all);

  final List<StockAudit> _all;

  @override
  Future<ApiResult<List<StockAudit>>> list({String? status}) async {
    final s = status?.trim() ?? '';
    final filtered = s.isEmpty
        ? _all
        : _all.where((a) => a.status.name == s).toList();
    return ApiSuccess(filtered);
  }

  @override
  Future<ApiResult<StockAudit>> show(int id) async =>
      ApiSuccess(_all.firstWhere((a) => a.id == id));
}

StockAudit _audit({
  required int id,
  required String number,
  required StockAuditStatus status,
  String? name,
  int itemsCount = 1,
}) =>
    StockAudit(
      id: id,
      auditNumber: number,
      status: status,
      name: name,
      itemsCount: itemsCount,
    );

Widget _wrap(StockAuditRepository repo) => ProviderScope(
      overrides: [
        stockAuditRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StockCountListScreen(),
      ),
    );

void main() {
  testWidgets('lists stock counts with their status', (tester) async {
    final repo = _FakeStockAuditRepository([
      _audit(
          id: 2,
          number: 'SC-002',
          status: StockAuditStatus.completed,
          name: 'July full'),
      _audit(
          id: 1,
          number: 'SC-001',
          status: StockAuditStatus.inProgress,
          name: 'August cycle'),
    ]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('SC-002'), findsOneWidget);
    expect(find.text('SC-001'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no stock counts',
      (tester) async {
    await tester.pumpWidget(_wrap(_FakeStockAuditRepository([])));
    await tester.pumpAndSettle();

    expect(find.textContaining('No stock counts yet'), findsOneWidget);
  });
}
