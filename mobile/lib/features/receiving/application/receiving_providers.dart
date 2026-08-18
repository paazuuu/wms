import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/receiving_repository.dart';
import '../domain/purchase_order.dart';

final receivingRepositoryProvider = Provider<ReceivingRepository>((ref) {
  return ReceivingRepositoryImpl(ref.watch(dioProvider));
});

/// Purchase orders open for receiving. The backend has no single "receivable"
/// filter, so we pull `sent` and `partial` and merge them (both can receive).
final receivablePurchaseOrdersProvider =
    FutureProvider.autoDispose<List<PurchaseOrder>>((ref) async {
  final repository = ref.watch(receivingRepositoryProvider);
  final sent = await repository.list(status: 'sent');
  final partial = await repository.list(status: 'partial');

  final orders = <PurchaseOrder>[];
  sent.when(
    success: orders.addAll,
    failure: (f) => throw Exception(f.message),
  );
  partial.when(
    success: orders.addAll,
    failure: (f) => throw Exception(f.message),
  );
  orders.sort((a, b) => b.id.compareTo(a.id));
  return orders;
});

/// A single purchase order with its line items, for the receive screen.
final purchaseOrderDetailProvider =
    FutureProvider.autoDispose.family<PurchaseOrder, int>((ref, id) async {
  final repository = ref.watch(receivingRepositoryProvider);
  final result = await repository.show(id);
  return result.when(
    success: (data) => data,
    failure: (failure) => throw Exception(failure.message),
  );
});
