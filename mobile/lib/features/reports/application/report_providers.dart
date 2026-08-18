import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/report_repository.dart';
import '../domain/report_result.dart';
import '../domain/saved_report.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepositoryImpl(ref.watch(dioProvider));
});

/// The saved reports the current user can access (own + shared).
final reportListProvider =
    FutureProvider.autoDispose<List<SavedReport>>((ref) async {
  final repository = ref.watch(reportRepositoryProvider);
  final result = await repository.list();
  return result.when(
    success: (data) => data,
    failure: (failure) => throw Exception(failure.message),
  );
});

/// The executed output of a single saved report.
final reportResultProvider =
    FutureProvider.autoDispose.family<ReportResult, int>((ref, id) async {
  final repository = ref.watch(reportRepositoryProvider);
  final result = await repository.run(id);
  return result.when(
    success: (data) => data,
    failure: (failure) => throw Exception(failure.message),
  );
});
