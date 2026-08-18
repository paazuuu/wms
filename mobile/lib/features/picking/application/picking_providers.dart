import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sales_orders/application/sales_order_providers.dart';
import '../../sales_orders/domain/sales_order.dart';

/// Sales-order statuses that still need warehouse fulfilment (picking).
const _openStatuses = {
  SalesOrderStatus.pending,
  SalesOrderStatus.processing,
};

/// Open sales orders presented as pick lists. Reuses the sales-order API and
/// filters client-side to orders still awaiting fulfilment. Read-only: there is
/// no backend picking endpoint, so line check-off stays local to the device.
final pickListsProvider =
    FutureProvider.autoDispose<List<SalesOrder>>((ref) async {
  final repository = ref.watch(salesOrderRepositoryProvider);
  final result = await repository.list();
  final orders = result.when(
    success: (data) => data,
    failure: (failure) => throw Exception(failure.message),
  );
  return orders.where((o) => _openStatuses.contains(o.status)).toList();
});
