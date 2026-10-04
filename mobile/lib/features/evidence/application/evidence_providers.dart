import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../data/evidence_repository.dart';
import '../domain/import_document.dart';

final evidenceRepositoryProvider = Provider<EvidenceRepository>((ref) {
  return EvidenceRepositoryImpl(rest: ref.watch(restDioProvider), storage: ref.watch(storageDioProvider));
});

/// The list's filter: what the files were for (null = all) and the search.
final evidencePurposeProvider = StateProvider.autoDispose<EvidencePurpose?>((ref) => null);
final evidenceSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final evidenceListProvider = FutureProvider.autoDispose<List<ImportDocument>>((ref) async {
  final purpose = ref.watch(evidencePurposeProvider);
  final search = ref.watch(evidenceSearchProvider);
  final r = await ref.watch(evidenceRepositoryProvider).list(purpose: purpose, search: search);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

/// The files one inbound plan was read from.
final planEvidenceProvider = FutureProvider.autoDispose.family<List<ImportDocument>, int>((ref, planId) async {
  final r = await ref.watch(evidenceRepositoryProvider).forPlan(deliveryPlanId: planId);
  return r.when(success: (d) => d, failure: (_) => const <ImportDocument>[]);
});
