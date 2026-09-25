import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/exception_repository.dart';
import '../domain/warehouse_exception.dart';

final exceptionRepositoryProvider = Provider<ExceptionRepository>((ref) {
  return ExceptionRepositoryImpl(ref.watch(restDioProvider));
});

/// Which stage's exceptions to show; null is all of them, which is the default
/// because a supervisor working the queue does not care which step produced a
/// blocker.
final exceptionCategoryProvider = StateProvider<String?>((_) => null);

/// Whether resolved and cancelled ones are shown. Off by default: this is a work
/// queue, and a queue that keeps finished work is a list nobody reaches the
/// bottom of.
final showClosedExceptionsProvider = StateProvider<bool>((_) => false);

/// The queue for the active warehouse, blockers first — the server's order, not
/// a local sort, so the two agree when the list is paged.
final openExceptionsProvider =
    FutureProvider.autoDispose<List<WarehouseException>>((ref) async {
  final warehouseId = ref.watch(activeWarehouseIdProvider);
  final category = ref.watch(exceptionCategoryProvider);
  final includeClosed = ref.watch(showClosedExceptionsProvider);
  final result = await ref.watch(exceptionRepositoryProvider).open(
        warehouseId: warehouseId,
        category: category,
        includeClosed: includeClosed,
      );
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// The vocabulary a "raise an exception" form picks from — the server's own
/// order, names and severities, not a list guessed client-side.
final exceptionTypesProvider =
    FutureProvider.autoDispose<List<ExceptionType>>((ref) async {
  final result = await ref.watch(exceptionRepositoryProvider).listTypes();
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// The counts behind the tile. Kept separate from the list so a dashboard can
/// show "4 blockers" without loading every row.
final exceptionSummaryProvider =
    FutureProvider.autoDispose<ExceptionSummary>((ref) async {
  final warehouseId = ref.watch(activeWarehouseIdProvider);
  final result =
      await ref.watch(exceptionRepositoryProvider).summary(warehouseId: warehouseId);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});
