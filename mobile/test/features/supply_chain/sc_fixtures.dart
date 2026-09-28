// Test fixtures are plain JSON-shaped literals.
// ignore_for_file: prefer_const_literals_to_create_immutables
// Fixtures shaped like the `supply-chain` edge function's own output (see
// supabase/functions/_shared/supply_chain_engine_test.ts: one product, two
// suppliers in China, sea and air into one warehouse), so the parsing is
// exercised against the real wire format.
import 'package:wms_mobile/features/supply_chain/domain/supply_chain.dart';

Map<String, dynamic> unitJson({
  double purchase = 700,
  double intl = 22,
  double domestic = 15,
  double insurance = 2.1,
  double duty = 36.205,
  double customsFee = 10,
  double warehouse = 15,
  double inspection = 25,
  double packing = 6,
  double salesRelated = 90,
  double fx = 0,
}) {
  final landed = purchase + fx + intl + domestic + insurance + duty + customsFee + warehouse + inspection + packing;
  return {
    'purchase': purchase,
    'fx_impact': fx,
    'international_freight': intl,
    'insurance': insurance,
    'customs_duty': duty,
    'import_tax': 0,
    'customs_fee': customsFee,
    'port_fee': 0,
    'domestic_freight': domestic,
    'warehouse': warehouse,
    'receiving': 0,
    'inspection': inspection,
    'packing': packing,
    'labor': 0,
    'overhead': 0,
    'other': 0,
    'landed': landed,
    'sales_related': salesRelated,
    'recoverable': 76.03,
  };
}

Map<String, dynamic> optionJson({
  required String key,
  required int partnerId,
  required String partner,
  int? routeId,
  String? route,
  String? mode,
  double lead = 24,
  Map<String, dynamic>? unit,
  double price = 1800,
  List<String> notes = const [],
  double share = 1,
}) {
  final u = unit ?? unitJson();
  final profit = price - (u['landed'] as double) - (u['sales_related'] as double);
  return {
    'key': key,
    'product_id': 1,
    'partner_id': partnerId,
    'partner_name': partner,
    'hypothetical': false,
    'route_id': routeId,
    'route_name': route,
    'mode': mode,
    'modes': [if (mode != null) mode],
    'lead_time_days': lead,
    'lot': 1000,
    'currency': 'JPY',
    'unit_price_foreign': u['purchase'],
    'discount_rate': partnerId == 1 ? 0.7 : null,
    'moq': 100,
    'unit': u,
    'sales_price': price,
    'profit_per_unit': profit,
    'margin': profit / price,
    'available': true,
    'blocked_by': <String>[],
    'notes': notes,
    'node_ids': <int>[],
    'share': share,
  };
}

final aSea = optionJson(key: '1:100', partnerId: 1, partner: 'Supplier A', routeId: 100, route: 'A 船便', mode: 'sea');
final aAir = optionJson(
  key: '1:101',
  partnerId: 1,
  partner: 'Supplier A',
  routeId: 101,
  route: 'A 航空便',
  mode: 'air',
  lead: 18,
  unit: unitJson(intl: 250, domestic: 20),
);
final bSea = optionJson(key: '2:102', partnerId: 2, partner: 'Supplier B', routeId: 102, route: 'B 船便', mode: 'sea', lead: 32, unit: unitJson(purchase: 650, domestic: 18));

Map<String, dynamic> productJson({Map<String, dynamic>? chosen, List<Map<String, dynamic>>? options, double volume = 12000, String name = 'ABC-001'}) {
  final c = chosen ?? aSea;
  final u = c['unit'] as Map<String, dynamic>;
  return {
    'product_id': 1,
    'name': name,
    'jan_code': '4901234567894',
    'sku': 'ABC-001',
    'maker': 'テスト文具',
    'volume': volume,
    'on_hand': 0,
    'sales_price': 1800,
    'unit': u,
    'profit_per_unit': c['profit_per_unit'],
    'margin': c['margin'],
    'lead_time_days': c['lead_time_days'],
    'revenue': 1800 * volume,
    'landed_total': (u['landed'] as double) * volume,
    'profit_total': (c['profit_per_unit'] as double) * volume,
    'chosen': [c],
    'options': options ?? [aSea, aAir, bSea],
    'single_source': false,
    'notes': <String>[],
  };
}

Map<String, dynamic> summaryJson(Map<String, dynamic> product) {
  final u = product['unit'] as Map<String, dynamic>;
  final v = product['volume'] as double;
  final lines = {for (final l in CostLine.values) l.wire: (u[l.wire] as num).toDouble() * v};
  final landed = (u['landed'] as double) * v;
  final sr = (u['sales_related'] as double) * v;
  final revenue = 1800 * v;
  return {
    'revenue': revenue,
    'units': v,
    'purchase': lines['purchase'],
    'fx_impact': lines['fx_impact'],
    'logistics': lines['international_freight']! + lines['insurance']! + lines['port_fee']! + lines['domestic_freight']!,
    'customs': lines['customs_duty']! + lines['import_tax']! + lines['customs_fee']!,
    'warehouse': lines['warehouse'],
    'labor': lines['receiving']! + lines['inspection']! + lines['packing']! + lines['labor']!,
    'other': lines['overhead']! + lines['other']!,
    'landed_cost': landed,
    'sales_related': sr,
    'total_cost': landed + sr,
    'profit': revenue - landed - sr,
    'margin': (revenue - landed - sr) / revenue,
    'lead_time_days': product['lead_time_days'],
    'lines': lines,
    'recoverable': 0,
  };
}

Map<String, dynamic> runJson({Map<String, dynamic>? product, String name = '現在', List<Map<String, dynamic>> disruptions = const []}) {
  final p = product ?? productJson();
  return {
    'name': name,
    'summary': summaryJson(p),
    'products': [p],
    'bottlenecks': [
      {
        'kind': 'node', 'id': 21, 'name': '大阪港', 'node_kind': 'port', 'units_month': 1000, 'kg_month': 500,
        'capacity_units_month': 800, 'capacity_kg_month': null, 'load': 1.25, 'status': 'exceeded',
        'has_alternative': true, 'products': [1],
      },
      {
        'kind': 'node', 'id': 30, 'name': '大阪倉庫', 'node_kind': 'warehouse', 'units_month': 1000, 'kg_month': 500,
        'capacity_units_month': null, 'capacity_kg_month': null, 'load': null, 'status': 'no_capacity',
        'has_alternative': false, 'products': [1],
      },
    ],
    'risks': [
      {'kind': 'node', 'id': 21, 'name': '大阪港', 'score': 35, 'level': 'medium', 'reasons': ['level:low', 'load_exceeded']},
      {'kind': 'supplier', 'id': 1, 'name': 'Supplier A', 'score': 55, 'level': 'high', 'reasons': ['level:medium', 'late_rate:20', 'event:supplier_price']},
    ],
    'disruptions': disruptions,
    'warnings': <String>[],
  };
}

ScRun dashboardRun() => ScRun.fromJson(runJson());

ScComparison priceUpComparison() {
  final after = productJson(chosen: optionJson(key: '1:100', partnerId: 1, partner: 'Supplier A', routeId: 100, route: 'A 船便', mode: 'sea', unit: unitJson(purchase: 770, duty: 39.8)));
  final base = runJson();
  final scen = runJson(product: after, name: '値上げ');
  final profit = (scen['summary'] as Map)['profit'] as double;
  final baseProfit = (base['summary'] as Map)['profit'] as double;
  return ScComparison.fromJson({
    'baseline': base,
    'scenario': scen,
    'delta': {'profit': profit - baseProfit, 'revenue': 0, 'landed_cost': baseProfit - profit, 'margin': -0.04, 'lead_time_days': 0},
    'drivers': [
      {'line': 'purchase', 'delta': 70 * 12000},
      {'line': 'customs_duty', 'delta': 3.595 * 12000},
    ],
    'result_id': 9,
  });
}

ScComparison portClosedComparison() => ScComparison.fromJson({
      'baseline': runJson(),
      'scenario': runJson(name: '障害', disruptions: [
        {
          'label': '大阪港 停止 14日',
          'disruption': {'kind': 'stop', 'node_id': 21, 'days': 14},
          'affected_products': [
            {
              'product_id': 1, 'name': 'ABC-001', 'affected_units': 460.3, 'rerouted_units': 460.3, 'lost_units': 0,
              'alternative': 'Supplier A / A 航空便', 'extra_cost_per_unit': 233, 'lead_time_change': -6, 'coverage_days': 152,
              'extra_cost': 107250, 'lost_profit': 0, 'impact': -107250,
            },
          ],
          'extra_cost': 107250, 'lost_profit': 0, 'lost_units': 0, 'impact': -107250,
        },
      ]),
      'delta': {'profit': 0, 'revenue': 0, 'landed_cost': 0, 'margin': 0, 'lead_time_days': 0},
      'drivers': <Map<String, dynamic>>[],
      'disruption_impact': -107250,
    });

ScModel scModel() => ScModel.fromJson({
      'settings': {'base_currency': 'JPY', 'margin_warn': 0.15, 'margin_drop_warn': 0.05},
      'fx': {'JPY': 1, 'CNY': 21.5},
      'nodes': [
        {'id': 10, 'name': 'Supplier A', 'kind': 'supplier', 'partner_id': 1, 'country_code': 'CN'},
        {'id': 11, 'name': 'Supplier B', 'kind': 'supplier', 'partner_id': 2, 'country_code': 'CN'},
        {'id': 20, 'name': '上海港', 'kind': 'port', 'country_code': 'CN'},
        {'id': 21, 'name': '大阪港', 'kind': 'port', 'country_code': 'JP', 'capacity_units_month': 800, 'risk_level': 'medium'},
        {'id': 30, 'name': '大阪倉庫', 'kind': 'warehouse', 'warehouse_id': 1, 'country_code': 'JP'},
      ],
      'routes': [
        {
          'id': 100, 'name': 'A 船便', 'origin_node_id': 10, 'destination_node_id': 30,
          'edges': [
            {'seq': 1, 'from_node_id': 10, 'to_node_id': 20, 'transport_mode': 'truck', 'cost_per_unit': 5, 'lead_time_days': 2},
            {'seq': 2, 'from_node_id': 20, 'to_node_id': 21, 'transport_mode': 'sea', 'base_cost': 12000, 'cost_per_kg': 20, 'lead_time_days': 7, 'customs_clearance': true, 'customs_cost': 10000, 'insurance_rate': 0.003},
            {'seq': 3, 'from_node_id': 21, 'to_node_id': 30, 'transport_mode': 'truck', 'cost_per_unit': 10, 'lead_time_days': 1},
          ],
        },
      ],
      'partners': [
        {'id': 1, 'name': 'Supplier A', 'country_code': 'CN'},
        {'id': 2, 'name': 'Supplier B', 'country_code': 'CN'},
      ],
      'supplier_products': [
        {'id': 5, 'partner_id': 1, 'product_id': 1, 'list_price': 1000, 'discount_rate': 0.7, 'lead_time_days': 14, 'default_route_id': 100, 'is_primary': true},
        {'id': 6, 'partner_id': 2, 'product_id': 1, 'unit_price': 650, 'lead_time_days': 21},
      ],
      'products': [
        {'id': 1, 'name': 'ABC-001', 'jan_code': '4901234567894', 'price': 1800, 'profile': {'annual_volume': 12000, 'unit_weight_kg': 0.5, 'hs_code': '3926'}},
      ],
      'cost_rules': [
        {'id': 1, 'name': '保管', 'category': 'storage', 'basis': 'per_unit_month', 'amount': 15},
        {'id': 2, 'name': '販売手数料', 'category': 'sales_related', 'basis': 'percent_of_revenue', 'amount': 0.05},
      ],
      'tariff_rules': [
        {'id': 1, 'name': 'プラ製品', 'hs_code_prefix': '39', 'origin_country': 'CN', 'destination_country': 'JP', 'tariff_rate': 0.05, 'import_tax_rate': 0.1},
      ],
      'risk_events': [
        {'id': 3, 'title': 'A 値上げ', 'kind': 'supplier_price', 'severity': 'medium', 'partner_id': 1, 'price_multiplier': 1.1},
      ],
    });
