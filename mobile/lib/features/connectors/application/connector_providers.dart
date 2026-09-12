import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../data/connector_repository.dart';
import '../domain/connector.dart';

final connectorRepositoryProvider = Provider<ConnectorRepository>((ref) {
  return ConnectorRepositoryImpl(ref.watch(restDioProvider));
});

/// The registered connectors (spec §34). `autoDispose` — this screen is
/// admin-only and rarely open, no reason to hold it warm in the background.
final connectorListProvider = FutureProvider.autoDispose<List<Connector>>((ref) async {
  final result = await ref.watch(connectorRepositoryProvider).list();
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});
