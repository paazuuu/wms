import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../data/ai_review_repository.dart';
import '../domain/ai_analysis_entry.dart';

final aiReviewRepositoryProvider = Provider<AiReviewRepository>((ref) {
  return AiReviewRepositoryImpl(ref.watch(restDioProvider));
});

/// Results awaiting a human decision (docs/ai_architecture.md §1). `autoDispose`
/// — this screen is opened occasionally, not worth keeping warm.
final aiReviewPendingListProvider =
    FutureProvider.autoDispose<List<AiAnalysisEntry>>((ref) async {
  final result = await ref.watch(aiReviewRepositoryProvider).list();
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});
