import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/inspection_repository.dart';
import '../domain/inspection.dart';

final inspectionRepositoryProvider = Provider<InspectionRepository>((ref) {
  return InspectionRepositoryImpl(ref.watch(dioProvider));
});

/// Loads the inspection list. Refreshable via `ref.invalidate`.
final inspectionListProvider =
    FutureProvider.autoDispose<List<Inspection>>((ref) async {
  final repository = ref.watch(inspectionRepositoryProvider);
  final result = await repository.list();
  return result.when(
    success: (data) => data,
    failure: (failure) => throw Exception(failure.message),
  );
});

/// Loads a single inspection detail by id.
final inspectionDetailProvider =
    FutureProvider.autoDispose.family<Inspection, int>((ref, id) async {
  final repository = ref.watch(inspectionRepositoryProvider);
  final result = await repository.show(id);
  return result.when(
    success: (data) => data,
    failure: (failure) => throw Exception(failure.message),
  );
});
