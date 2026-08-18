import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/reports/application/report_providers.dart';
import 'package:wms_mobile/features/reports/data/report_repository.dart';
import 'package:wms_mobile/features/reports/domain/report_result.dart';
import 'package:wms_mobile/features/reports/domain/saved_report.dart';
import 'package:wms_mobile/features/reports/presentation/report_list_screen.dart';

/// In-memory fake so the browse list renders without a network.
class _FakeReportRepository implements ReportRepository {
  _FakeReportRepository(this._all);

  final List<SavedReport> _all;

  @override
  Future<ApiResult<List<SavedReport>>> list() async => ApiSuccess(_all);

  @override
  Future<ApiResult<ReportResult>> run(int id) async => ApiSuccess(
        ReportResult(id: id, name: _all.firstWhere((r) => r.id == id).name),
      );
}

Widget _wrap(ReportRepository repo) => ProviderScope(
      overrides: [
        reportRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: ReportListScreen()),
    );

void main() {
  testWidgets('lists saved reports with column counts and sharing',
      (tester) async {
    final repo = _FakeReportRepository(const [
      SavedReport(
          id: 1, name: 'Low stock', columnsCount: 4, isShared: true),
      SavedReport(id: 2, name: 'Sales by month', columnsCount: 3),
    ]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Low stock'), findsOneWidget);
    expect(find.text('Sales by month'), findsOneWidget);
    expect(find.text('4 columns'), findsOneWidget);
    expect(find.text('Shared'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no reports', (tester) async {
    await tester.pumpWidget(_wrap(_FakeReportRepository(const [])));
    await tester.pumpAndSettle();

    expect(find.textContaining('No saved reports yet'), findsOneWidget);
  });
}
