import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../data/report_repository.dart';
import '../domain/report.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepositoryImpl(ref.watch(restDioProvider));
});

/// Saved report definitions, for the "load a saved report" list.
final savedReportListProvider =
    FutureProvider.autoDispose<List<ReportDefinition>>((ref) async {
  final result = await ref.watch(reportRepositoryProvider).listSaved();
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});
