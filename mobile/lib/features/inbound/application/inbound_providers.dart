import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/inbound_repository.dart';
import '../domain/inbound.dart';

final inboundRepositoryProvider = Provider<InboundRepository>((ref) {
  return InboundRepositoryImpl(ref.watch(restDioProvider));
});

/// One expected receipt with its receipts, inspections, files and history.
final expectedReceiptProvider = FutureProvider.autoDispose.family<ExpectedReceipt, int>((ref, planId) async {
  final r = await ref.watch(inboundRepositoryProvider).timeline(planId);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

/// 今日の入荷 for the current warehouse; null when no warehouse is picked.
final inboundTodayProvider = FutureProvider.autoDispose<InboundToday?>((ref) async {
  final warehouseId = ref.watch(activeWarehouseIdProvider);
  if (warehouseId == null) return null;
  final r = await ref.watch(inboundRepositoryProvider).today(warehouseId);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

/// Everything that came in for one product.
final productInboundHistoryProvider =
    FutureProvider.autoDispose.family<ProductInboundHistory, int>((ref, productId) async {
  final r = await ref.watch(inboundRepositoryProvider).productHistory(productId);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});
