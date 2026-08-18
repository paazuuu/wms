import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper translating `connectivity_plus` results into a simple
/// online/offline boolean stream. Kept separate so [OfflineSyncService] can be
/// unit-tested with a plain `Stream<bool>` and no platform channels.
class ConnectivityMonitor {
  ConnectivityMonitor([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  Stream<bool> get onlineStream =>
      _connectivity.onConnectivityChanged.map(_isOnline);

  Future<bool> get isOnline async =>
      _isOnline(await _connectivity.checkConnectivity());
}
