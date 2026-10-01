import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_result.dart';
import '../../delivery/application/delivery_providers.dart';
import '../data/packaging_repository.dart';
import '../domain/packaging.dart';

final packagingRepositoryProvider = Provider<PackagingRepository>(
    (ref) => PackagingRepositoryImpl(ref.watch(restDioProvider)));

/// The boxes in use, for choosing one (0115).
final cartonTypesProvider = FutureProvider<List<CartonType>>((ref) async {
  final r = await ref.watch(packagingRepositoryProvider).cartonTypes();
  return switch (r) {
    ApiSuccess(:final data) => data,
    ApiFailure(:final message) => throw Exception(message),
  };
});

/// Every box, retired ones too, for the settings screen.
final allCartonTypesProvider = FutureProvider<List<CartonType>>((ref) async {
  final r = await ref.watch(packagingRepositoryProvider).cartonTypes(includeInactive: true);
  return switch (r) {
    ApiSuccess(:final data) => data,
    ApiFailure(:final message) => throw Exception(message),
  };
});

/// What one shipment should weigh.
final shipmentWeightProvider = FutureProvider.autoDispose.family<ShipmentWeightEstimate, int>((ref, planId) async {
  final r = await ref.watch(packagingRepositoryProvider).estimate(planId);
  return switch (r) {
    ApiSuccess(:final data) => data,
    ApiFailure(:final message) => throw Exception(message),
  };
});
