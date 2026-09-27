import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../../../core/storage/supabase_session_storage.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/role_dashboard_repository.dart';
import '../domain/role_dashboards.dart';

final roleDashboardRepositoryProvider = Provider<RoleDashboardRepository>(
    (ref) => RoleDashboardRepositoryImpl(ref.watch(restDioProvider)));

/// The dashboard view picked by hand, kept on the device; null until someone
/// picks one, when the role's own view applies (0102).
class DashboardViewController extends StateNotifier<DashboardView?> {
  DashboardViewController(this._store) : super(null) {
    _restore();
  }

  final SecureKeyValueStore _store;
  static const _key = 'dashboard_view';

  Future<void> _restore() async {
    try {
      final v = DashboardView.parse(await _store.read(_key));
      if (v != null && state == null) state = v;
    } catch (_) {}
  }

  Future<void> pick(DashboardView view) async {
    state = view;
    try {
      await _store.write(_key, view.wire);
    } catch (_) {}
  }
}

final dashboardViewProvider = StateNotifierProvider<DashboardViewController, DashboardView?>(
    (ref) => DashboardViewController(const FlutterSecureKeyValueStore()));

final inboundScheduleProvider = FutureProvider.autoDispose<InboundSchedule>((ref) async {
  final r = await ref
      .watch(roleDashboardRepositoryProvider)
      .inboundSchedule(warehouseId: ref.watch(activeWarehouseIdProvider));
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

/// Country and search for the purchasing view; null country = home.
final stockOverviewCountryProvider = StateProvider<String?>((_) => null);
final stockOverviewSearchProvider = StateProvider<String>((_) => '');

final stockOverviewProvider = FutureProvider.autoDispose<StockOverview>((ref) async {
  final r = await ref.watch(roleDashboardRepositoryProvider).stockOverview(
      countryCode: ref.watch(stockOverviewCountryProvider),
      search: ref.watch(stockOverviewSearchProvider));
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

/// Whose orders the sales view counts; CN unless changed, '' = every country.
final salesCycleCountryProvider = StateProvider<String>((_) => 'CN');

final salesCycleProvider = FutureProvider.autoDispose<SalesCycle>((ref) async {
  final c = ref.watch(salesCycleCountryProvider);
  final r = await ref
      .watch(roleDashboardRepositoryProvider)
      .salesCycle(countryCode: c.isEmpty ? null : c);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});
