import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../data/shipment_repository.dart';
import '../domain/shipment.dart';

/// Reuses the delivery feature's Dio (Supabase Edge Functions base + anon key);
/// the shipments function lives under the same functions/v1 gateway.
final shipmentRepositoryProvider = Provider<ShipmentRepository>((ref) {
  return ShipmentRepositoryImpl(ref.watch(deliveryDioProvider));
});

/// Also show already-shipped shipments (for reprints / corrections).
final showShippedProvider = StateProvider<bool>((_) => false);

/// Shipments still to pack/ship (open, packing) — plus shipped ones when the
/// toggle is on — newest first.
final shipmentsListProvider =
    FutureProvider.autoDispose<List<Shipment>>((ref) async {
  final repo = ref.watch(shipmentRepositoryProvider);
  final includeShipped = ref.watch(showShippedProvider);
  final statuses = ['open', 'packing', if (includeShipped) 'shipped'];

  final all = <Shipment>[];
  for (final status in statuses) {
    final result = await repo.list(status: status);
    result.when(
      success: all.addAll,
      failure: (f) => throw Exception(f.message),
    );
  }
  all.sort((a, b) => b.id.compareTo(a.id));
  return all;
});

/// One shipment with its lines and cartons.
final shipmentDetailProvider =
    FutureProvider.autoDispose.family<Shipment, int>((ref, id) async {
  final result = await ref.watch(shipmentRepositoryProvider).show(id);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});
