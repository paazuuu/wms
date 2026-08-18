import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/sales_order_repository.dart';
import '../domain/sales_order.dart';

final salesOrderRepositoryProvider = Provider<SalesOrderRepository>((ref) {
  return SalesOrderRepositoryImpl(ref.watch(dioProvider));
});

/// Sales orders matching a search query. Empty query lists recent orders.
final salesOrderSearchProvider = FutureProvider.autoDispose
    .family<List<SalesOrder>, String>((ref, query) async {
  final repository = ref.watch(salesOrderRepositoryProvider);
  final result = await repository.list(search: query);
  return result.when(
    success: (data) => data,
    failure: (failure) => throw Exception(failure.message),
  );
});

/// A single sales order with its line items.
final salesOrderDetailProvider =
    FutureProvider.autoDispose.family<SalesOrder, int>((ref, id) async {
  final repository = ref.watch(salesOrderRepositoryProvider);
  final result = await repository.show(id);
  return result.when(
    success: (data) => data,
    failure: (failure) => throw Exception(failure.message),
  );
});
