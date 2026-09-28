import 'package:dio/dio.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../domain/supply_chain.dart';

/// The supply chain layer (0107): calculations through the `supply-chain`
/// edge function, masters and history through the `sc_*` RPCs. Nothing here
/// changes stock or orders (rule 3).
abstract class SupplyChainRepository {
  Future<ApiResult<ScRun>> dashboard({int? warehouseId, bool save = false});
  Future<ApiResult<ScComparison>> run({int? warehouseId, required ScScenarioParams params, String? name, int? scenarioId});
  Future<ApiResult<ScMultiComparison>> compare({int? warehouseId, required List<(String, ScScenarioParams)> scenarios});
  Future<ApiResult<ScProductView>> product({required int productId, int? warehouseId, List<double> rates = const [], ScScenarioParams? params});
  Future<ApiResult<ScComparison>> disruption({int? warehouseId, required List<Map<String, dynamic>> disruptions, String? name});
  Future<ApiResult<List<ScPurchaseCheck>>> purchaseCheck({int? warehouseId, required List<Map<String, dynamic>> lines});

  Future<ApiResult<ScModel>> model({int? warehouseId, List<int>? productIds});
  Future<ApiResult<List<ScSupplierStat>>> supplierStats();
  Future<ApiResult<Map<String, dynamic>>> seedFromHistory();

  Future<ApiResult<int>> saveNode(Map<String, dynamic> node);
  Future<ApiResult<int>> saveRoute({int? id, required String name, required List<ScEdge> edges, String? note});
  Future<ApiResult<int>> saveTerm(ScSupplyTerm term);
  Future<ApiResult<int>> saveProfile(int productId, ScProfile profile);
  Future<ApiResult<int>> saveCostRule(ScCostRule rule);
  Future<ApiResult<int>> saveTariffRule(ScTariffRule rule);
  Future<ApiResult<bool>> saveFx(String currency, double rate);
  Future<ApiResult<int>> saveRiskEvent(ScRiskEvent event);
  Future<ApiResult<bool>> archive(String kind, int id);

  Future<ApiResult<int>> saveScenario({int? id, required String name, String? description, int? warehouseId, required ScScenarioParams params});
  Future<ApiResult<List<ScScenario>>> scenarios();
  Future<ApiResult<List<ScResultRow>>> results({int limit = 50, String? kind});
  Future<ApiResult<Map<String, dynamic>>> result(int id);
}

dynamic _unwrap(dynamic data) =>
    data is List && data.length == 1 && (data.first is List || data.first is Map) ? data.first : data;

Map<String, dynamic> _obj(dynamic data) {
  final d = _unwrap(data);
  return d is Map ? d.cast<String, dynamic>() : const {};
}

List<Map<String, dynamic>> _list(dynamic data) {
  final d = _unwrap(data);
  return [
    for (final e in (d as List? ?? const []))
      if (e is Map) e.cast<String, dynamic>(),
  ];
}

int _id(dynamic data) {
  final d = _unwrap(data);
  return d is int ? d : int.tryParse('$d') ?? 0;
}

class SupplyChainRepositoryImpl implements SupplyChainRepository {
  SupplyChainRepositoryImpl(this._functions, this._rest);

  final Dio _functions;
  final Dio _rest;

  Future<ApiResult<T>> _fn<T>(Map<String, dynamic> body, T Function(Map<String, dynamic>) parse) async {
    try {
      final r = await _functions.post('/supply-chain', data: body);
      return ApiSuccess(parse(_obj(_obj(r.data)['data'])));
    } on DioException catch (e) {
      return mapDioError<T>(e);
    }
  }

  Future<ApiResult<T>> _rpc<T>(String name, Map<String, dynamic> body, T Function(dynamic) parse) async {
    try {
      final r = await _rest.post('/rpc/$name', data: body);
      return ApiSuccess(parse(r.data));
    } on DioException catch (e) {
      return mapDioError<T>(e);
    }
  }

  @override
  Future<ApiResult<ScRun>> dashboard({int? warehouseId, bool save = false}) =>
      _fn({'action': 'dashboard', 'warehouse_id': warehouseId, 'save': save}, ScRun.fromJson);

  @override
  Future<ApiResult<ScComparison>> run({int? warehouseId, required ScScenarioParams params, String? name, int? scenarioId}) =>
      _fn({
        'action': 'run',
        'warehouse_id': warehouseId,
        'params': params.toJson(),
        'name': name,
        'scenario_id': scenarioId,
      }, ScComparison.fromJson);

  @override
  Future<ApiResult<ScMultiComparison>> compare({int? warehouseId, required List<(String, ScScenarioParams)> scenarios}) =>
      _fn({
        'action': 'compare',
        'warehouse_id': warehouseId,
        'scenarios': [
          for (final (name, p) in scenarios) {'name': name, 'params': p.toJson()},
        ],
      }, ScMultiComparison.fromJson);

  @override
  Future<ApiResult<ScProductView>> product({required int productId, int? warehouseId, List<double> rates = const [], ScScenarioParams? params}) =>
      _fn({
        'action': 'product',
        'product_id': productId,
        'warehouse_id': warehouseId,
        'rates': rates,
        'params': params?.toJson() ?? const {},
      }, ScProductView.fromJson);

  @override
  Future<ApiResult<ScComparison>> disruption({int? warehouseId, required List<Map<String, dynamic>> disruptions, String? name}) =>
      _fn({'action': 'disruption', 'warehouse_id': warehouseId, 'disruptions': disruptions, 'name': name}, ScComparison.fromJson);

  @override
  Future<ApiResult<List<ScPurchaseCheck>>> purchaseCheck({int? warehouseId, required List<Map<String, dynamic>> lines}) =>
      _fn({'action': 'purchase_check', 'warehouse_id': warehouseId, 'lines': lines},
          (j) => [for (final l in _list(j['lines'])) ScPurchaseCheck.fromJson(l)]);

  @override
  Future<ApiResult<ScModel>> model({int? warehouseId, List<int>? productIds}) =>
      _rpc('sc_model', {'p_warehouse_id': warehouseId, 'p_product_ids': productIds}, (d) => ScModel.fromJson(_obj(d)));

  @override
  Future<ApiResult<List<ScSupplierStat>>> supplierStats() =>
      _rpc('sc_supplier_stats', {'p_partner_id': null}, (d) => [for (final r in _list(d)) ScSupplierStat.fromJson(r)]);

  @override
  Future<ApiResult<Map<String, dynamic>>> seedFromHistory() => _rpc('sc_seed_from_history', const {}, _obj);

  @override
  Future<ApiResult<int>> saveNode(Map<String, dynamic> node) => _rpc('sc_save_node', {'p': node}, _id);

  @override
  Future<ApiResult<int>> saveRoute({int? id, required String name, required List<ScEdge> edges, String? note}) =>
      _rpc('sc_save_route', {
        'p': {
          'id': id,
          'name': name,
          'note': note,
          'edges': [for (final e in edges) e.toJson()],
        },
      }, _id);

  @override
  Future<ApiResult<int>> saveTerm(ScSupplyTerm term) => _rpc('sc_save_supplier_product', {'p': term.toJson()}, _id);

  @override
  Future<ApiResult<int>> saveProfile(int productId, ScProfile profile) =>
      _rpc('sc_save_product_profile', {'p': profile.toJson(productId)}, _id);

  @override
  Future<ApiResult<int>> saveCostRule(ScCostRule rule) => _rpc('sc_save_cost_rule', {'p': rule.toJson()}, _id);

  @override
  Future<ApiResult<int>> saveTariffRule(ScTariffRule rule) => _rpc('sc_save_tariff_rule', {'p': rule.toJson()}, _id);

  @override
  Future<ApiResult<bool>> saveFx(String currency, double rate) =>
      _rpc('sc_save_fx_rate', {'p_currency': currency, 'p_rate': rate, 'p_as_of': null, 'p_note': null}, (_) => true);

  @override
  Future<ApiResult<int>> saveRiskEvent(ScRiskEvent event) => _rpc('sc_save_risk_event', {'p': event.toJson()}, _id);

  @override
  Future<ApiResult<bool>> archive(String kind, int id) => _rpc('sc_archive', {'p_kind': kind, 'p_id': id}, (_) => true);

  @override
  Future<ApiResult<int>> saveScenario({int? id, required String name, String? description, int? warehouseId, required ScScenarioParams params}) =>
      _rpc('sc_save_scenario', {
        'p_id': id,
        'p_name': name,
        'p_description': description,
        'p_warehouse_id': warehouseId,
        'p_params': params.toJson(),
      }, _id);

  @override
  Future<ApiResult<List<ScScenario>>> scenarios() =>
      _rpc('sc_list_scenarios', const {}, (d) => [for (final r in _list(d)) ScScenario.fromJson(r)]);

  @override
  Future<ApiResult<List<ScResultRow>>> results({int limit = 50, String? kind}) =>
      _rpc('sc_list_results', {'p_limit': limit, 'p_kind': kind}, (d) => [for (final r in _list(d)) ScResultRow.fromJson(r)]);

  @override
  Future<ApiResult<Map<String, dynamic>>> result(int id) => _rpc('sc_result', {'p_id': id}, _obj);
}
