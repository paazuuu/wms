import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/work_order_repository.dart';
import '../domain/work_order.dart';

final workOrderRepositoryProvider = Provider<WorkOrderRepository>((ref) {
  return WorkOrderRepositoryImpl(ref.watch(dioProvider));
});

/// Work orders matching a search query. Empty query lists all (recent) orders.
final workOrderSearchProvider =
    FutureProvider.autoDispose.family<List<WorkOrder>, String>(
  (ref, query) async {
    final repository = ref.watch(workOrderRepositoryProvider);
    final result = await repository.list(search: query);
    return result.when(
      success: (data) => data,
      failure: (failure) => throw Exception(failure.message),
    );
  },
);

/// A single work order with its components loaded.
final workOrderDetailProvider =
    FutureProvider.autoDispose.family<WorkOrder, int>((ref, id) async {
  final repository = ref.watch(workOrderRepositoryProvider);
  final result = await repository.show(id);
  return result.when(
    success: (data) => data,
    failure: (failure) => throw Exception(failure.message),
  );
});
