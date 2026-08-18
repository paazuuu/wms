import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../receiving/application/receiving_providers.dart';
import '../../receiving/domain/purchase_order.dart';

/// Purchase orders matching a search query, across every status (unlike the
/// receiving list, which is limited to sent/partial). Reuses the receiving
/// repository so there is one source of truth for the `/purchase-orders` API.
final purchaseOrderSearchProvider = FutureProvider.autoDispose
    .family<List<PurchaseOrder>, String>((ref, query) async {
  final repository = ref.watch(receivingRepositoryProvider);
  final result = await repository.list(search: query);
  final orders = result.when(
    success: (data) => data,
    failure: (failure) => throw Exception(failure.message),
  );
  orders.sort((a, b) => b.id.compareTo(a.id));
  return orders;
});
