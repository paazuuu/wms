import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/search_repository.dart';
import '../domain/search_result.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepositoryImpl(ref.watch(restDioProvider));
});

/// The in-progress query text, updated as the user types.
final searchQueryProvider = StateProvider<String>((_) => '');

/// Results for the current query, scoped to the active warehouse. Empty query
/// short-circuits to an empty list without a round trip.
final searchResultsProvider =
    FutureProvider.autoDispose<List<SearchResult>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return const [];
  final warehouseId = ref.watch(activeWarehouseIdProvider);
  final result = await ref
      .watch(searchRepositoryProvider)
      .search(query, warehouseId: warehouseId);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});
