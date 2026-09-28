import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../data/notation_repository.dart';
import '../domain/notation.dart';

final notationRepositoryProvider = Provider<NotationRepository>((ref) =>
    NotationRepositoryImpl(ref.watch(deliveryDioProvider), ref.watch(restDioProvider)));

T _unwrap<T>(dynamic r) => r.when(success: (T d) => d, failure: (f) => throw Exception(f.message));

final trainingRunsProvider = FutureProvider.autoDispose<List<TrainingRun>>((ref) async =>
    _unwrap<List<TrainingRun>>(await ref.watch(notationRepositoryProvider).trainings()));

final trainingStatsProvider = FutureProvider.autoDispose<List<PartnerTrainingStats>>((ref) async =>
    _unwrap<List<PartnerTrainingStats>>(await ref.watch(notationRepositoryProvider).stats()));

/// The dictionary's filters: company, field (jan/maker/name/code) and search.
final dialectPartnerProvider = StateProvider<int?>((_) => null);
final dialectFieldProvider = StateProvider<String?>((_) => null);
final dialectSearchProvider = StateProvider<String>((_) => '');
final dialectUnconfirmedProvider = StateProvider<bool>((_) => false);

final dialectsProvider = FutureProvider.autoDispose<List<NotationDialect>>((ref) async =>
    _unwrap<List<NotationDialect>>(await ref.watch(notationRepositoryProvider).dialects(
          partnerId: ref.watch(dialectPartnerProvider),
          field: ref.watch(dialectFieldProvider),
          search: ref.watch(dialectSearchProvider),
          unconfirmedOnly: ref.watch(dialectUnconfirmedProvider),
        )));

final columnAliasesProvider = FutureProvider.autoDispose<List<ColumnAlias>>((ref) async =>
    _unwrap<List<ColumnAlias>>(await ref
        .watch(notationRepositoryProvider)
        .columnAliases(partnerId: ref.watch(dialectPartnerProvider))));
