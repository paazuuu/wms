import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/inspection/application/inspection_providers.dart';
import 'connectivity_monitor.dart';
import 'offline_database.dart';
import 'offline_sync_service.dart';

final offlineDatabaseProvider = Provider<OfflineDatabase>((ref) {
  final db = OfflineDatabase();
  ref.onDispose(db.close);
  return db;
});

final connectivityMonitorProvider =
    Provider<ConnectivityMonitor>((ref) => ConnectivityMonitor());

final offlineSyncServiceProvider = Provider<OfflineSyncService>((ref) {
  final monitor = ref.watch(connectivityMonitorProvider);
  final service = OfflineSyncService(
    database: ref.watch(offlineDatabaseProvider),
    repository: ref.watch(inspectionRepositoryProvider),
    connectivityStream: monitor.onlineStream,
    isOnline: () => monitor.isOnline,
  );
  service.start();
  ref.onDispose(service.dispose);
  return service;
});
