import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../data/report_repository.dart';
import '../domain/report.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepositoryImpl(ref.watch(restDioProvider));
});

/// 識別コード in use and the memos of uploads (0218), for the pick lists of
/// 入出庫履歴's conditions; empty when they cannot be had.
final reportClassCodesProvider = FutureProvider.autoDispose<List<String>>((ref) async =>
    (await ref.watch(reportRepositoryProvider).classCodes()).when(success: (d) => d, failure: (_) => const []));
final reportImportNotesProvider = FutureProvider.autoDispose<List<String>>((ref) async =>
    (await ref.watch(reportRepositoryProvider).importNotes()).when(success: (d) => d, failure: (_) => const []));

/// Saved report definitions, for the "load a saved report" list.
final savedReportListProvider =
    FutureProvider.autoDispose<List<ReportDefinition>>((ref) async {
  final result = await ref.watch(reportRepositoryProvider).listSaved();
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});
