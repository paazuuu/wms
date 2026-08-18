import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/stock_audit_repository.dart';
import '../domain/stock_audit.dart';

final stockAuditRepositoryProvider = Provider<StockAuditRepository>((ref) {
  return StockAuditRepositoryImpl(ref.watch(dioProvider));
});

/// Stock counts, optionally filtered by status. Empty status lists all.
final stockAuditListProvider =
    FutureProvider.autoDispose.family<List<StockAudit>, String>(
  (ref, status) async {
    final repository = ref.watch(stockAuditRepositoryProvider);
    final result = await repository.list(status: status);
    return result.when(
      success: (data) => data,
      failure: (failure) => throw Exception(failure.message),
    );
  },
);

/// A single stock count with its full detail (items loaded).
final stockAuditDetailProvider =
    FutureProvider.autoDispose.family<StockAudit, int>((ref, id) async {
  final repository = ref.watch(stockAuditRepositoryProvider);
  final result = await repository.show(id);
  return result.when(
    success: (data) => data,
    failure: (failure) => throw Exception(failure.message),
  );
});
