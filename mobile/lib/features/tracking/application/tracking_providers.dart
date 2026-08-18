import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/tracking_repository.dart';
import '../domain/product_batch.dart';
import '../domain/product_serial.dart';

final trackingRepositoryProvider = Provider<TrackingRepository>((ref) {
  return TrackingRepositoryImpl(ref.watch(dioProvider));
});

/// The lot/batch records for a given product.
final productBatchesProvider =
    FutureProvider.autoDispose.family<List<ProductBatch>, int>(
  (ref, productId) async {
    final repository = ref.watch(trackingRepositoryProvider);
    final result = await repository.batches(productId);
    return result.when(
      success: (data) => data,
      failure: (failure) => throw Exception(failure.message),
    );
  },
);

/// The serial records for a given product.
final productSerialsProvider =
    FutureProvider.autoDispose.family<List<ProductSerial>, int>(
  (ref, productId) async {
    final repository = ref.watch(trackingRepositoryProvider);
    final result = await repository.serials(productId);
    return result.when(
      success: (data) => data,
      failure: (failure) => throw Exception(failure.message),
    );
  },
);
