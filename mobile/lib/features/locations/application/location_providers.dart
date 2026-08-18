import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/location_repository.dart';
import '../domain/location.dart';

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepositoryImpl(ref.watch(dioProvider));
});

/// Locations matching a search query. Empty query lists all (recent) locations.
final locationSearchProvider =
    FutureProvider.autoDispose.family<List<Location>, String>((ref, query) async {
  final repository = ref.watch(locationRepositoryProvider);
  final result = await repository.list(search: query);
  return result.when(
    success: (data) => data,
    failure: (failure) => throw Exception(failure.message),
  );
});

/// A single location with its full detail.
final locationDetailProvider =
    FutureProvider.autoDispose.family<Location, int>((ref, id) async {
  final repository = ref.watch(locationRepositoryProvider);
  final result = await repository.show(id);
  return result.when(
    success: (data) => data,
    failure: (failure) => throw Exception(failure.message),
  );
});
