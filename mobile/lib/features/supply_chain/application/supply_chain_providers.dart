import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../delivery/application/delivery_providers.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/supply_chain_repository.dart';
import '../domain/supply_chain.dart';

final supplyChainRepositoryProvider = Provider<SupplyChainRepository>(
    (ref) => SupplyChainRepositoryImpl(ref.watch(deliveryDioProvider), ref.watch(restDioProvider)));

T _unwrap<T>(dynamic r) => r.when(success: (T d) => d, failure: (f) => throw Exception(f.message));

/// Seeing the numbers needs `supply_chain.view` (or manage).
final scCanViewProvider = Provider<bool>((ref) {
  final perms = ref.watch(authControllerProvider).user?.permissions ?? const <String>[];
  return perms.contains('supply_chain.view') || perms.contains('supply_chain.manage');
});

/// Editing masters and saving scenarios needs `supply_chain.manage`.
final scCanManageProvider = Provider<bool>((ref) {
  final perms = ref.watch(authControllerProvider).user?.permissions ?? const <String>[];
  return perms.contains('supply_chain.manage');
});

/// The warehouse the numbers are for: the one chosen in the header (§36
/// rule 2), or every warehouse in scope.
final scWarehouseIdProvider = Provider<int?>((ref) => ref.watch(activeWarehouseIdProvider));

/// The current state: totals, products, bottlenecks and risks.
final scDashboardProvider = FutureProvider.autoDispose<ScRun>((ref) async =>
    _unwrap<ScRun>(await ref.watch(supplyChainRepositoryProvider).dashboard(warehouseId: ref.watch(scWarehouseIdProvider))));

/// The masters (nodes, routes, terms, rules…).
final scModelProvider = FutureProvider.autoDispose<ScModel>((ref) async =>
    _unwrap<ScModel>(await ref.watch(supplyChainRepositoryProvider).model(warehouseId: ref.watch(scWarehouseIdProvider))));

final scSupplierStatsProvider = FutureProvider.autoDispose<List<ScSupplierStat>>((ref) async =>
    _unwrap<List<ScSupplierStat>>(await ref.watch(supplyChainRepositoryProvider).supplierStats()));

final scScenariosProvider = FutureProvider.autoDispose<List<ScScenario>>((ref) async =>
    _unwrap<List<ScScenario>>(await ref.watch(supplyChainRepositoryProvider).scenarios()));

final scResultsProvider = FutureProvider.autoDispose<List<ScResultRow>>((ref) async =>
    _unwrap<List<ScResultRow>>(await ref.watch(supplyChainRepositoryProvider).results()));

/// One product's supplier × route options, and the 掛率 sweep asked for.
/// [ScProductQuery.rates] is a comma list ("0.65,0.75") so the key compares
/// by value.
typedef ScProductQuery = ({int productId, String rates, int? lot});

List<double> scParseRates(String rates) => [
      for (final r in rates.split(','))
        if (double.tryParse(r.trim()) != null) double.parse(r.trim()),
    ];

final scProductViewProvider = FutureProvider.autoDispose.family<ScProductView, ScProductQuery>((ref, q) async =>
    _unwrap<ScProductView>(await ref.watch(supplyChainRepositoryProvider).product(
          productId: q.productId,
          warehouseId: ref.watch(scWarehouseIdProvider),
          rates: scParseRates(q.rates),
          params: q.lot == null ? null : ScScenarioParams(lotQuantity: q.lot),
        )));

/// Invalidate everything that reads the masters after an edit.
void refreshSupplyChain(WidgetRef ref) {
  ref.invalidate(scModelProvider);
  ref.invalidate(scDashboardProvider);
  ref.invalidate(scSupplierStatsProvider);
  ref.invalidate(scProductViewProvider);
}
