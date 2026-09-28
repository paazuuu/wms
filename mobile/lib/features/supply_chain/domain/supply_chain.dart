import 'package:equatable/equatable.dart';

// The supply chain profit & risk layer (0107, spec §4–§34): what the
// `supply-chain` edge function returns and the masters `sc_model` reads.
// Every amount is in the base currency (¥ unless the settings say
// otherwise) and per unit unless the name says total.

double _d(dynamic v, [double d = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? d;
  return d;
}

double? _dn(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int _i(dynamic v, [int d = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? d;
  return d;
}

int? _in(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

String? _s(dynamic v) {
  if (v == null) return null;
  final t = v.toString().trim();
  return t.isEmpty ? null : t;
}

List<Map<String, dynamic>> _rows(dynamic v) => [
      for (final e in (v as List? ?? const []))
        if (e is Map) e.cast<String, dynamic>(),
    ];

Map<String, dynamic> _map(dynamic v) => v is Map ? v.cast<String, dynamic>() : const {};

/// The cost lines of a landed cost, in the order they are added (§11).
enum CostLine {
  purchase('purchase'),
  fxImpact('fx_impact'),
  internationalFreight('international_freight'),
  insurance('insurance'),
  customsDuty('customs_duty'),
  importTax('import_tax'),
  customsFee('customs_fee'),
  portFee('port_fee'),
  domesticFreight('domestic_freight'),
  warehouse('warehouse'),
  receiving('receiving'),
  inspection('inspection'),
  packing('packing'),
  labor('labor'),
  overhead('overhead'),
  other('other');

  const CostLine(this.wire);
  final String wire;

  static CostLine? parse(String? w) {
    for (final l in values) {
      if (l.wire == w) return l;
    }
    return null;
  }
}

/// One unit's cost, line by line.
class CostBreakdown extends Equatable {
  const CostBreakdown({this.lines = const {}, this.landed = 0, this.salesRelated = 0, this.recoverable = 0});

  final Map<CostLine, double> lines;
  final double landed;
  final double salesRelated;

  /// Shown, not counted: recoverable import tax, non-expensed rules.
  final double recoverable;

  double operator [](CostLine l) => lines[l] ?? 0;

  factory CostBreakdown.fromJson(Map<String, dynamic> j) => CostBreakdown(
        lines: {for (final l in CostLine.values) l: _d(j[l.wire])},
        landed: _d(j['landed']),
        salesRelated: _d(j['sales_related']),
        recoverable: _d(j['recoverable']),
      );

  /// The groups the KPI cards use (§4).
  double get logistics =>
      this[CostLine.internationalFreight] + this[CostLine.insurance] + this[CostLine.portFee] + this[CostLine.domesticFreight];
  double get customs => this[CostLine.customsDuty] + this[CostLine.importTax] + this[CostLine.customsFee];
  double get labor => this[CostLine.receiving] + this[CostLine.inspection] + this[CostLine.packing] + this[CostLine.labor];

  @override
  List<Object?> get props => [lines, landed, salesRelated, recoverable];
}

/// Totals of a run (§4 KPIs, §15 result).
class ScSummary extends Equatable {
  const ScSummary({
    this.revenue = 0,
    this.units = 0,
    this.purchase = 0,
    this.fxImpact = 0,
    this.logistics = 0,
    this.customs = 0,
    this.warehouse = 0,
    this.labor = 0,
    this.other = 0,
    this.landedCost = 0,
    this.salesRelated = 0,
    this.totalCost = 0,
    this.profit = 0,
    this.margin,
    this.leadTimeDays,
    this.lines = const {},
    this.recoverable = 0,
  });

  final double revenue;
  final double units;
  final double purchase;
  final double fxImpact;
  final double logistics;
  final double customs;
  final double warehouse;
  final double labor;
  final double other;
  final double landedCost;
  final double salesRelated;
  final double totalCost;
  final double profit;
  final double? margin;
  final double? leadTimeDays;
  final Map<CostLine, double> lines;
  final double recoverable;

  factory ScSummary.fromJson(Map<String, dynamic> j) {
    final lines = _map(j['lines']);
    return ScSummary(
      revenue: _d(j['revenue']),
      units: _d(j['units']),
      purchase: _d(j['purchase']),
      fxImpact: _d(j['fx_impact']),
      logistics: _d(j['logistics']),
      customs: _d(j['customs']),
      warehouse: _d(j['warehouse']),
      labor: _d(j['labor']),
      other: _d(j['other']),
      landedCost: _d(j['landed_cost']),
      salesRelated: _d(j['sales_related']),
      totalCost: _d(j['total_cost']),
      profit: _d(j['profit']),
      margin: _dn(j['margin']),
      leadTimeDays: _dn(j['lead_time_days']),
      lines: {for (final l in CostLine.values) l: _d(lines[l.wire])},
      recoverable: _d(j['recoverable']),
    );
  }

  @override
  List<Object?> get props => [revenue, landedCost, profit, margin, leadTimeDays];
}

/// One way to get a product: a supplier and a route (§5, §9).
class ScOption extends Equatable {
  const ScOption({
    required this.key,
    required this.productId,
    required this.partnerId,
    required this.partnerName,
    this.hypothetical = false,
    this.routeId,
    this.routeName,
    this.mode,
    this.modes = const [],
    this.leadTimeDays = 0,
    this.lot = 1,
    this.currency = 'JPY',
    this.unitPriceForeign = 0,
    this.discountRate,
    this.moq,
    this.unit = const CostBreakdown(),
    this.salesPrice = 0,
    this.profitPerUnit = 0,
    this.margin,
    this.available = true,
    this.blockedBy = const [],
    this.notes = const [],
    this.share = 1,
  });

  final String key;
  final int productId;
  final int partnerId;
  final String partnerName;
  final bool hypothetical;
  final int? routeId;
  final String? routeName;
  final String? mode;
  final List<String> modes;
  final double leadTimeDays;
  final double lot;
  final String currency;
  final double unitPriceForeign;
  final double? discountRate;
  final int? moq;
  final CostBreakdown unit;
  final double salesPrice;
  final double profitPerUnit;
  final double? margin;
  final bool available;
  final List<String> blockedBy;
  final List<String> notes;

  /// The part of the volume it carries (chosen options only).
  final double share;

  factory ScOption.fromJson(Map<String, dynamic> j) => ScOption(
        key: (j['key'] ?? '').toString(),
        productId: _i(j['product_id']),
        partnerId: _i(j['partner_id']),
        partnerName: (j['partner_name'] ?? '').toString(),
        hypothetical: j['hypothetical'] == true,
        routeId: _in(j['route_id']),
        routeName: _s(j['route_name']),
        mode: _s(j['mode']),
        modes: [for (final m in (j['modes'] as List? ?? const [])) m.toString()],
        leadTimeDays: _d(j['lead_time_days']),
        lot: _d(j['lot'], 1),
        currency: (j['currency'] ?? 'JPY').toString(),
        unitPriceForeign: _d(j['unit_price_foreign']),
        discountRate: _dn(j['discount_rate']),
        moq: _in(j['moq']),
        unit: CostBreakdown.fromJson(_map(j['unit'])),
        salesPrice: _d(j['sales_price']),
        profitPerUnit: _d(j['profit_per_unit']),
        margin: _dn(j['margin']),
        available: j['available'] != false,
        blockedBy: [for (final b in (j['blocked_by'] as List? ?? const [])) b.toString()],
        notes: [for (final b in (j['notes'] as List? ?? const [])) b.toString()],
        share: _d(j['share'], 1),
      );

  @override
  List<Object?> get props => [key, productId, unit, share];
}

class ScProduct extends Equatable {
  const ScProduct({
    required this.productId,
    required this.name,
    this.janCode,
    this.sku,
    this.maker,
    this.volume = 0,
    this.onHand = 0,
    this.salesPrice = 0,
    this.unit = const CostBreakdown(),
    this.profitPerUnit = 0,
    this.margin,
    this.leadTimeDays = 0,
    this.revenue = 0,
    this.landedTotal = 0,
    this.profitTotal = 0,
    this.chosen = const [],
    this.options = const [],
    this.singleSource = false,
    this.notes = const [],
  });

  final int productId;
  final String name;
  final String? janCode;
  final String? sku;
  final String? maker;
  final double volume;
  final double onHand;
  final double salesPrice;
  final CostBreakdown unit;
  final double profitPerUnit;
  final double? margin;
  final double leadTimeDays;
  final double revenue;
  final double landedTotal;
  final double profitTotal;
  final List<ScOption> chosen;
  final List<ScOption> options;
  final bool singleSource;
  final List<String> notes;

  bool get supplied => chosen.isNotEmpty;

  factory ScProduct.fromJson(Map<String, dynamic> j) => ScProduct(
        productId: _i(j['product_id']),
        name: (j['name'] ?? '').toString(),
        janCode: _s(j['jan_code']),
        sku: _s(j['sku']),
        maker: _s(j['maker']),
        volume: _d(j['volume']),
        onHand: _d(j['on_hand']),
        salesPrice: _d(j['sales_price']),
        unit: CostBreakdown.fromJson(_map(j['unit'])),
        profitPerUnit: _d(j['profit_per_unit']),
        margin: _dn(j['margin']),
        leadTimeDays: _d(j['lead_time_days']),
        revenue: _d(j['revenue']),
        landedTotal: _d(j['landed_total']),
        profitTotal: _d(j['profit_total']),
        chosen: [for (final o in _rows(j['chosen'])) ScOption.fromJson(o)],
        options: [for (final o in _rows(j['options'])) ScOption.fromJson(o)],
        singleSource: j['single_source'] == true,
        notes: [for (final n in (j['notes'] as List? ?? const [])) n.toString()],
      );

  @override
  List<Object?> get props => [productId, unit, chosen];
}

enum LoadStatus {
  ok,
  busy,
  exceeded,
  noCapacity,
  stopped;

  static LoadStatus parse(String? s) => switch (s) {
        'busy' => busy,
        'exceeded' => exceeded,
        'stopped' => stopped,
        'no_capacity' => noCapacity,
        _ => ok,
      };
}

/// A node or leg and how full it is (§18).
class ScLoad extends Equatable {
  const ScLoad({
    required this.kind,
    required this.id,
    required this.name,
    this.nodeKind,
    this.mode,
    this.routeId,
    this.unitsMonth = 0,
    this.kgMonth = 0,
    this.capacityUnitsMonth,
    this.capacityKgMonth,
    this.load,
    this.status = LoadStatus.ok,
    this.hasAlternative = true,
    this.products = const [],
  });

  final String kind;
  final int id;
  final String name;
  final String? nodeKind;
  final String? mode;
  final int? routeId;
  final double unitsMonth;
  final double kgMonth;
  final double? capacityUnitsMonth;
  final double? capacityKgMonth;
  final double? load;
  final LoadStatus status;
  final bool hasAlternative;
  final List<int> products;

  factory ScLoad.fromJson(Map<String, dynamic> j) => ScLoad(
        kind: (j['kind'] ?? 'node').toString(),
        id: _i(j['id']),
        name: (j['name'] ?? '').toString(),
        nodeKind: _s(j['node_kind']),
        mode: _s(j['mode']),
        routeId: _in(j['route_id']),
        unitsMonth: _d(j['units_month']),
        kgMonth: _d(j['kg_month']),
        capacityUnitsMonth: _dn(j['capacity_units_month']),
        capacityKgMonth: _dn(j['capacity_kg_month']),
        load: _dn(j['load']),
        status: LoadStatus.parse(j['status'] as String?),
        hasAlternative: j['has_alternative'] != false,
        products: [for (final p in (j['products'] as List? ?? const [])) _i(p)],
      );

  @override
  List<Object?> get props => [kind, id, load, status];
}

enum RiskLevel {
  low,
  medium,
  high,
  critical;

  static RiskLevel parse(String? s) => switch (s) {
        'medium' => medium,
        'high' => high,
        'critical' => critical,
        _ => low,
      };
}

/// A rule-based risk score with its reasons (§17, §34).
class ScRisk extends Equatable {
  const ScRisk({required this.kind, required this.id, required this.name, this.score = 0, this.level = RiskLevel.low, this.reasons = const []});

  final String kind;
  final int id;
  final String name;
  final double score;
  final RiskLevel level;
  final List<String> reasons;

  factory ScRisk.fromJson(Map<String, dynamic> j) => ScRisk(
        kind: (j['kind'] ?? '').toString(),
        id: _i(j['id']),
        name: (j['name'] ?? '').toString(),
        score: _d(j['score']),
        level: RiskLevel.parse(j['level'] as String?),
        reasons: [for (final r in (j['reasons'] as List? ?? const [])) r.toString()],
      );

  @override
  List<Object?> get props => [kind, id, score, reasons];
}

class ScDisruptionProduct extends Equatable {
  const ScDisruptionProduct({
    required this.productId,
    required this.name,
    this.affectedUnits = 0,
    this.reroutedUnits = 0,
    this.lostUnits = 0,
    this.alternative,
    this.extraCostPerUnit = 0,
    this.leadTimeChange,
    this.coverageDays,
    this.extraCost = 0,
    this.lostProfit = 0,
    this.impact = 0,
  });

  final int productId;
  final String name;
  final double affectedUnits;
  final double reroutedUnits;
  final double lostUnits;
  final String? alternative;
  final double extraCostPerUnit;
  final double? leadTimeChange;
  final double? coverageDays;
  final double extraCost;
  final double lostProfit;
  final double impact;

  factory ScDisruptionProduct.fromJson(Map<String, dynamic> j) => ScDisruptionProduct(
        productId: _i(j['product_id']),
        name: (j['name'] ?? '').toString(),
        affectedUnits: _d(j['affected_units']),
        reroutedUnits: _d(j['rerouted_units']),
        lostUnits: _d(j['lost_units']),
        alternative: _s(j['alternative']),
        extraCostPerUnit: _d(j['extra_cost_per_unit']),
        leadTimeChange: _dn(j['lead_time_change']),
        coverageDays: _dn(j['coverage_days']),
        extraCost: _d(j['extra_cost']),
        lostProfit: _d(j['lost_profit']),
        impact: _d(j['impact']),
      );

  @override
  List<Object?> get props => [productId, impact];
}

/// What a stop or delay costs (§19).
class ScDisruptionImpact extends Equatable {
  const ScDisruptionImpact({required this.label, this.products = const [], this.extraCost = 0, this.lostProfit = 0, this.lostUnits = 0, this.impact = 0});

  final String label;
  final List<ScDisruptionProduct> products;
  final double extraCost;
  final double lostProfit;
  final double lostUnits;
  final double impact;

  factory ScDisruptionImpact.fromJson(Map<String, dynamic> j) => ScDisruptionImpact(
        label: (j['label'] ?? '').toString(),
        products: [for (final p in _rows(j['affected_products'])) ScDisruptionProduct.fromJson(p)],
        extraCost: _d(j['extra_cost']),
        lostProfit: _d(j['lost_profit']),
        lostUnits: _d(j['lost_units']),
        impact: _d(j['impact']),
      );

  @override
  List<Object?> get props => [label, impact];
}

class ScRun extends Equatable {
  const ScRun({
    this.name = '',
    this.summary = const ScSummary(),
    this.products = const [],
    this.bottlenecks = const [],
    this.risks = const [],
    this.disruptions = const [],
    this.warnings = const [],
    this.resultId,
  });

  final String name;
  final ScSummary summary;
  final List<ScProduct> products;
  final List<ScLoad> bottlenecks;
  final List<ScRisk> risks;
  final List<ScDisruptionImpact> disruptions;
  final List<String> warnings;
  final int? resultId;

  double get disruptionImpact => disruptions.fold(0, (s, d) => s + d.impact);

  factory ScRun.fromJson(Map<String, dynamic> j) => ScRun(
        name: (j['name'] ?? '').toString(),
        summary: ScSummary.fromJson(_map(j['summary'])),
        products: [for (final p in _rows(j['products'])) ScProduct.fromJson(p)],
        bottlenecks: [for (final b in _rows(j['bottlenecks'])) ScLoad.fromJson(b)],
        risks: [for (final r in _rows(j['risks'])) ScRisk.fromJson(r)],
        disruptions: [for (final d in _rows(j['disruptions'])) ScDisruptionImpact.fromJson(d)],
        warnings: [for (final w in (j['warnings'] as List? ?? const [])) w.toString()],
        resultId: _in(j['result_id']),
      );

  @override
  List<Object?> get props => [name, summary, products, resultId];
}

/// One line that moved the profit, and by how much (§20, §30).
class ScDriver extends Equatable {
  const ScDriver(this.line, this.delta);

  /// A [CostLine] wire value, or `revenue` / `sales_related`.
  final String line;
  final double delta;

  factory ScDriver.fromJson(Map<String, dynamic> j) => ScDriver((j['line'] ?? '').toString(), _d(j['delta']));

  @override
  List<Object?> get props => [line, delta];
}

/// Current vs. scenario (§15).
class ScComparison extends Equatable {
  const ScComparison({
    required this.baseline,
    required this.scenario,
    this.deltaProfit = 0,
    this.deltaRevenue = 0,
    this.deltaLanded = 0,
    this.deltaMargin,
    this.deltaLeadTime,
    this.drivers = const [],
    this.resultId,
    this.disruptionImpact = 0,
  });

  final ScRun baseline;
  final ScRun scenario;
  final double deltaProfit;
  final double deltaRevenue;
  final double deltaLanded;
  final double? deltaMargin;
  final double? deltaLeadTime;
  final List<ScDriver> drivers;
  final int? resultId;
  final double disruptionImpact;

  factory ScComparison.fromJson(Map<String, dynamic> j) {
    final d = _map(j['delta']);
    return ScComparison(
      baseline: ScRun.fromJson(_map(j['baseline'])),
      scenario: ScRun.fromJson(_map(j['scenario'])),
      deltaProfit: _d(d['profit']),
      deltaRevenue: _d(d['revenue']),
      deltaLanded: _d(d['landed_cost']),
      deltaMargin: _dn(d['margin']),
      deltaLeadTime: _dn(d['lead_time_days']),
      drivers: [for (final x in _rows(j['drivers'])) ScDriver.fromJson(x)],
      resultId: _in(j['result_id']),
      disruptionImpact: _d(j['disruption_impact']),
    );
  }

  @override
  List<Object?> get props => [baseline, scenario, resultId];
}

/// Up to five scenarios side by side (§16).
class ScMultiComparison extends Equatable {
  const ScMultiComparison({required this.baseline, this.scenarios = const [], this.resultId});

  final ScCompareColumn baseline;
  final List<ScCompareColumn> scenarios;
  final int? resultId;

  factory ScMultiComparison.fromJson(Map<String, dynamic> j) => ScMultiComparison(
        baseline: ScCompareColumn.fromJson(_map(j['baseline'])),
        scenarios: [for (final s in _rows(j['scenarios'])) ScCompareColumn.fromJson(s)],
        resultId: _in(j['result_id']),
      );

  @override
  List<Object?> get props => [baseline, scenarios];
}

class ScCompareColumn extends Equatable {
  const ScCompareColumn({required this.name, required this.summary, this.risksHigh = 0, this.bottlenecksExceeded = 0, this.deltaProfit = 0, this.drivers = const []});

  final String name;
  final ScSummary summary;
  final int risksHigh;
  final int bottlenecksExceeded;
  final double deltaProfit;
  final List<ScDriver> drivers;

  factory ScCompareColumn.fromJson(Map<String, dynamic> j) => ScCompareColumn(
        name: (j['name'] ?? '').toString(),
        summary: ScSummary.fromJson(_map(j['summary'])),
        risksHigh: _i(j['risks_high']),
        bottlenecksExceeded: _i(j['bottlenecks_exceeded']),
        deltaProfit: _d(j['delta_profit']),
        drivers: [for (final x in _rows(j['drivers'])) ScDriver.fromJson(x)],
      );

  @override
  List<Object?> get props => [name, summary];
}

/// A product's options, and the same at other 掛率 (§5, §7, §27).
class ScProductView extends Equatable {
  const ScProductView({this.product, this.sweeps = const [], this.risks = const []});

  final ScProduct? product;
  final List<ScRateSweep> sweeps;
  final List<ScRisk> risks;

  factory ScProductView.fromJson(Map<String, dynamic> j) => ScProductView(
        product: j['product'] is Map ? ScProduct.fromJson(_map(j['product'])) : null,
        sweeps: [for (final s in _rows(j['sweeps'])) ScRateSweep.fromJson(s)],
        risks: [for (final r in _rows(j['risks'])) ScRisk.fromJson(r)],
      );

  @override
  List<Object?> get props => [product, sweeps];
}

class ScRateSweep extends Equatable {
  const ScRateSweep({required this.rate, this.options = const []});

  final double rate;
  final List<ScOption> options;

  factory ScRateSweep.fromJson(Map<String, dynamic> j) => ScRateSweep(
        rate: _d(j['rate']),
        options: [for (final o in _rows(j['options'])) ScOption.fromJson(o)],
      );

  @override
  List<Object?> get props => [rate, options];
}

/// One purchase line checked before ordering (§29–30).
class ScPurchaseCheck extends Equatable {
  const ScPurchaseCheck({
    required this.productId,
    required this.partnerId,
    required this.name,
    this.unitPrice,
    this.quantity,
    this.salesPrice,
    this.landedBefore,
    this.landedAfter,
    this.profitBefore,
    this.profitAfter,
    this.marginBefore,
    this.marginAfter,
    this.warn = const [],
    this.drivers = const [],
  });

  final int productId;
  final int partnerId;
  final String name;
  final double? unitPrice;
  final double? quantity;
  final double? salesPrice;
  final double? landedBefore;
  final double? landedAfter;
  final double? profitBefore;
  final double? profitAfter;
  final double? marginBefore;
  final double? marginAfter;
  final List<String> warn;
  final List<ScDriver> drivers;

  bool get warns => warn.any((w) => w != 'new_supplier');

  factory ScPurchaseCheck.fromJson(Map<String, dynamic> j) => ScPurchaseCheck(
        productId: _i(j['product_id']),
        partnerId: _i(j['partner_id']),
        name: (j['name'] ?? '').toString(),
        unitPrice: _dn(j['unit_price']),
        quantity: _dn(j['quantity']),
        salesPrice: _dn(j['sales_price']),
        landedBefore: _dn(j['landed_before']),
        landedAfter: _dn(j['landed_after']),
        profitBefore: _dn(j['profit_before']),
        profitAfter: _dn(j['profit_after']),
        marginBefore: _dn(j['margin_before']),
        marginAfter: _dn(j['margin_after']),
        warn: [for (final w in (j['warn'] as List? ?? const [])) w.toString()],
        drivers: [for (final x in _rows(j['drivers'])) ScDriver.fromJson(x)],
      );

  @override
  List<Object?> get props => [productId, partnerId, marginAfter, warn];
}

// ---------------------------------------------------------------- masters

class ScNode extends Equatable {
  const ScNode({
    required this.id,
    required this.name,
    required this.kind,
    this.code,
    this.partnerId,
    this.warehouseId,
    this.countryCode,
    this.capacityUnitsMonth,
    this.capacityKgMonth,
    this.dwellDays = 0,
    this.handlingCostPerUnit = 0,
    this.handlingCostPerShipment = 0,
    this.riskLevel = RiskLevel.low,
    this.riskNote,
  });

  final int id;
  final String name;
  final String kind;
  final String? code;
  final int? partnerId;
  final int? warehouseId;
  final String? countryCode;
  final double? capacityUnitsMonth;
  final double? capacityKgMonth;
  final double dwellDays;
  final double handlingCostPerUnit;
  final double handlingCostPerShipment;
  final RiskLevel riskLevel;
  final String? riskNote;

  factory ScNode.fromJson(Map<String, dynamic> j) => ScNode(
        id: _i(j['id']),
        name: (j['name'] ?? '').toString(),
        kind: (j['kind'] ?? 'hub').toString(),
        code: _s(j['code']),
        partnerId: _in(j['partner_id']),
        warehouseId: _in(j['warehouse_id']),
        countryCode: _s(j['country_code']),
        capacityUnitsMonth: _dn(j['capacity_units_month']),
        capacityKgMonth: _dn(j['capacity_kg_month']),
        dwellDays: _d(j['dwell_days']),
        handlingCostPerUnit: _d(j['handling_cost_per_unit']),
        handlingCostPerShipment: _d(j['handling_cost_per_shipment']),
        riskLevel: RiskLevel.parse(j['risk_level'] as String?),
        riskNote: _s(j['risk_note']),
      );

  Map<String, dynamic> toJson() => {
        'id': id == 0 ? null : id,
        'name': name,
        'kind': kind,
        'code': code,
        'partner_id': partnerId,
        'warehouse_id': warehouseId,
        'country_code': countryCode,
        'capacity_units_month': capacityUnitsMonth,
        'capacity_kg_month': capacityKgMonth,
        'dwell_days': dwellDays,
        'handling_cost_per_unit': handlingCostPerUnit,
        'handling_cost_per_shipment': handlingCostPerShipment,
        'risk_level': riskLevel.name,
        'risk_note': riskNote,
      };

  @override
  List<Object?> get props => [id, name, kind, capacityUnitsMonth, riskLevel];
}

/// One leg of a route (§8, §22).
class ScEdge extends Equatable {
  const ScEdge({
    required this.fromNodeId,
    required this.toNodeId,
    this.seq = 1,
    this.mode = 'truck',
    this.currency,
    this.distanceKm,
    this.leadTimeDays = 0,
    this.baseCost = 0,
    this.costPerKg = 0,
    this.costPerUnit = 0,
    this.fuelSurchargeRate = 0,
    this.insuranceRate = 0,
    this.capacityKgMonth,
    this.capacityUnitsMonth,
    this.customsClearance = false,
    this.customsCost = 0,
    this.tariffRate,
    this.handlingCost = 0,
    this.handlingCostPerUnit = 0,
    this.riskLevel = RiskLevel.low,
  });

  final int seq;
  final int fromNodeId;
  final int toNodeId;
  final String mode;
  final String? currency;
  final double? distanceKm;
  final double leadTimeDays;
  final double baseCost;
  final double costPerKg;
  final double costPerUnit;
  final double fuelSurchargeRate;
  final double insuranceRate;
  final double? capacityKgMonth;
  final double? capacityUnitsMonth;
  final bool customsClearance;
  final double customsCost;
  final double? tariffRate;
  final double handlingCost;
  final double handlingCostPerUnit;
  final RiskLevel riskLevel;

  factory ScEdge.fromJson(Map<String, dynamic> j) => ScEdge(
        seq: _i(j['seq'], 1),
        fromNodeId: _i(j['from_node_id']),
        toNodeId: _i(j['to_node_id']),
        mode: (j['transport_mode'] ?? 'truck').toString(),
        currency: _s(j['currency']),
        distanceKm: _dn(j['distance_km']),
        leadTimeDays: _d(j['lead_time_days']),
        baseCost: _d(j['base_cost']),
        costPerKg: _d(j['cost_per_kg']),
        costPerUnit: _d(j['cost_per_unit']),
        fuelSurchargeRate: _d(j['fuel_surcharge_rate']),
        insuranceRate: _d(j['insurance_rate']),
        capacityKgMonth: _dn(j['capacity_kg_month']),
        capacityUnitsMonth: _dn(j['capacity_units_month']),
        customsClearance: j['customs_clearance'] == true,
        customsCost: _d(j['customs_cost']),
        tariffRate: _dn(j['tariff_rate']),
        handlingCost: _d(j['handling_cost']),
        handlingCostPerUnit: _d(j['handling_cost_per_unit']),
        riskLevel: RiskLevel.parse(j['risk_level'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'from_node_id': fromNodeId,
        'to_node_id': toNodeId,
        'transport_mode': mode,
        'currency': currency,
        'distance_km': distanceKm,
        'lead_time_days': leadTimeDays,
        'base_cost': baseCost,
        'cost_per_kg': costPerKg,
        'cost_per_unit': costPerUnit,
        'fuel_surcharge_rate': fuelSurchargeRate,
        'insurance_rate': insuranceRate,
        'capacity_kg_month': capacityKgMonth,
        'capacity_units_month': capacityUnitsMonth,
        'customs_clearance': customsClearance,
        'customs_cost': customsCost,
        'tariff_rate': tariffRate,
        'handling_cost': handlingCost,
        'handling_cost_per_unit': handlingCostPerUnit,
        'risk_level': riskLevel.name,
      };

  ScEdge copyWith({int? fromNodeId, int? toNodeId, String? mode, double? leadTimeDays, double? baseCost, double? costPerKg, double? costPerUnit, double? insuranceRate, bool? customsClearance, double? customsCost, double? capacityKgMonth, RiskLevel? riskLevel}) => ScEdge(
        seq: seq,
        fromNodeId: fromNodeId ?? this.fromNodeId,
        toNodeId: toNodeId ?? this.toNodeId,
        mode: mode ?? this.mode,
        currency: currency,
        distanceKm: distanceKm,
        leadTimeDays: leadTimeDays ?? this.leadTimeDays,
        baseCost: baseCost ?? this.baseCost,
        costPerKg: costPerKg ?? this.costPerKg,
        costPerUnit: costPerUnit ?? this.costPerUnit,
        fuelSurchargeRate: fuelSurchargeRate,
        insuranceRate: insuranceRate ?? this.insuranceRate,
        capacityKgMonth: capacityKgMonth ?? this.capacityKgMonth,
        capacityUnitsMonth: capacityUnitsMonth,
        customsClearance: customsClearance ?? this.customsClearance,
        customsCost: customsCost ?? this.customsCost,
        tariffRate: tariffRate,
        handlingCost: handlingCost,
        handlingCostPerUnit: handlingCostPerUnit,
        riskLevel: riskLevel ?? this.riskLevel,
      );

  @override
  List<Object?> get props => [seq, fromNodeId, toNodeId, mode, leadTimeDays, baseCost, costPerKg, costPerUnit];
}

class ScRoute extends Equatable {
  const ScRoute({required this.id, required this.name, required this.originNodeId, required this.destinationNodeId, this.code, this.note, this.edges = const []});

  final int id;
  final String name;
  final String? code;
  final int originNodeId;
  final int destinationNodeId;
  final String? note;
  final List<ScEdge> edges;

  double get leadTimeDays => edges.fold(0, (s, e) => s + e.leadTimeDays);

  factory ScRoute.fromJson(Map<String, dynamic> j) => ScRoute(
        id: _i(j['id']),
        name: (j['name'] ?? '').toString(),
        code: _s(j['code']),
        originNodeId: _i(j['origin_node_id']),
        destinationNodeId: _i(j['destination_node_id']),
        note: _s(j['note']),
        edges: [for (final e in _rows(j['edges'])) ScEdge.fromJson(e)]..sort((a, b) => a.seq.compareTo(b.seq)),
      );

  @override
  List<Object?> get props => [id, name, edges];
}

/// Our product from one supplier: price, 掛率, currency, MOQ, lead time.
class ScSupplyTerm extends Equatable {
  const ScSupplyTerm({
    this.id,
    required this.partnerId,
    required this.productId,
    this.supplierSku,
    this.listPrice,
    this.discountRate,
    this.unitPrice,
    this.currency,
    this.moq,
    this.orderLot,
    this.leadTimeDays,
    this.paymentTerms,
    this.defaultRouteId,
    this.isPrimary = false,
    this.source = 'manual',
    this.partnerName,
  });

  final int? id;
  final int partnerId;

  /// A supplier added in a scenario only, not on file (§6).
  final String? partnerName;
  final int productId;
  final String? supplierSku;
  final double? listPrice;
  final double? discountRate;
  final double? unitPrice;
  final String? currency;
  final int? moq;
  final int? orderLot;
  final double? leadTimeDays;
  final String? paymentTerms;
  final int? defaultRouteId;
  final bool isPrimary;
  final String source;

  /// The purchase price before FX, as the term states it.
  double? get effectivePrice => unitPrice ?? (listPrice != null ? listPrice! * (discountRate ?? 1) : null);

  ScSupplyTerm withName(String name) => ScSupplyTerm(
        id: id,
        partnerId: partnerId,
        productId: productId,
        supplierSku: supplierSku,
        listPrice: listPrice,
        discountRate: discountRate,
        unitPrice: unitPrice,
        currency: currency,
        moq: moq,
        orderLot: orderLot,
        leadTimeDays: leadTimeDays,
        paymentTerms: paymentTerms,
        defaultRouteId: defaultRouteId,
        isPrimary: isPrimary,
        source: source,
        partnerName: name,
      );

  factory ScSupplyTerm.fromJson(Map<String, dynamic> j) => ScSupplyTerm(
        id: _in(j['id']),
        partnerId: _i(j['partner_id']),
        productId: _i(j['product_id']),
        supplierSku: _s(j['supplier_sku']),
        listPrice: _dn(j['list_price']),
        discountRate: _dn(j['discount_rate']),
        unitPrice: _dn(j['unit_price']),
        currency: _s(j['currency']),
        moq: _in(j['moq']),
        orderLot: _in(j['order_lot']),
        leadTimeDays: _dn(j['lead_time_days']),
        paymentTerms: _s(j['payment_terms']),
        defaultRouteId: _in(j['default_route_id']),
        isPrimary: j['is_primary'] == true,
        source: (j['source'] ?? 'manual').toString(),
        partnerName: _s(j['partner_name']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'partner_id': partnerId,
        'product_id': productId,
        'supplier_sku': supplierSku,
        'list_price': listPrice,
        'discount_rate': discountRate,
        'unit_price': unitPrice,
        'currency': currency,
        'moq': moq,
        'order_lot': orderLot,
        'lead_time_days': leadTimeDays,
        'payment_terms': paymentTerms,
        'default_route_id': defaultRouteId,
        'is_primary': isPrimary,
        if (partnerName != null) 'partner_name': partnerName,
      };

  @override
  List<Object?> get props => [id, partnerId, productId, listPrice, discountRate, unitPrice];
}

class ScProfile extends Equatable {
  const ScProfile({
    this.salesPrice,
    this.annualVolume,
    this.unitWeightKg,
    this.unitsPerCarton,
    this.unitsPerLine,
    this.unitsPerOrder,
    this.storageDays,
    this.hsCode,
    this.originCountry,
    this.destinationCountry,
  });

  final double? salesPrice;
  final double? annualVolume;
  final double? unitWeightKg;
  final int? unitsPerCarton;
  final double? unitsPerLine;
  final double? unitsPerOrder;
  final double? storageDays;
  final String? hsCode;
  final String? originCountry;
  final String? destinationCountry;

  factory ScProfile.fromJson(Map<String, dynamic> j) => ScProfile(
        salesPrice: _dn(j['sales_price']),
        annualVolume: _dn(j['annual_volume']),
        unitWeightKg: _dn(j['unit_weight_kg']),
        unitsPerCarton: _in(j['units_per_carton']),
        unitsPerLine: _dn(j['units_per_line']),
        unitsPerOrder: _dn(j['units_per_order']),
        storageDays: _dn(j['storage_days']),
        hsCode: _s(j['hs_code']),
        originCountry: _s(j['origin_country']),
        destinationCountry: _s(j['destination_country']),
      );

  Map<String, dynamic> toJson(int productId) => {
        'product_id': productId,
        'sales_price': salesPrice,
        'annual_volume': annualVolume,
        'unit_weight_kg': unitWeightKg,
        'units_per_carton': unitsPerCarton,
        'units_per_line': unitsPerLine,
        'units_per_order': unitsPerOrder,
        'storage_days': storageDays,
        'hs_code': hsCode,
        'origin_country': originCountry,
        'destination_country': destinationCountry,
      };

  @override
  List<Object?> get props => [salesPrice, annualVolume, unitWeightKg, hsCode];
}

class ScModelProduct extends Equatable {
  const ScModelProduct({required this.id, required this.name, this.janCode, this.sku, this.maker, this.price, this.profile, this.onHand = 0, this.shipped12m = 0});

  final int id;
  final String name;
  final String? janCode;
  final String? sku;
  final String? maker;
  final double? price;
  final ScProfile? profile;
  final double onHand;
  final double shipped12m;

  factory ScModelProduct.fromJson(Map<String, dynamic> j) => ScModelProduct(
        id: _i(j['id']),
        name: (j['name'] ?? '').toString(),
        janCode: _s(j['jan_code']),
        sku: _s(j['sku']),
        maker: _s(j['maker']),
        price: _dn(j['price']),
        profile: j['profile'] is Map ? ScProfile.fromJson(_map(j['profile'])) : null,
        onHand: _d(j['on_hand']),
        shipped12m: _d(j['shipped_12m']),
      );

  @override
  List<Object?> get props => [id, name, profile];
}

const costCategories = [
  'storage', 'receiving', 'inspection', 'packing', 'picking', 'shipping', 'labor',
  'overhead', 'domestic_freight', 'sales_related', 'other',
];
const costBases = [
  'per_unit', 'per_unit_month', 'per_carton', 'per_line', 'per_order', 'per_hour',
  'percent_of_revenue', 'percent_of_purchase', 'fixed_monthly',
];

class ScCostRule extends Equatable {
  const ScCostRule({this.id, required this.name, this.category = 'other', this.basis = 'per_unit', this.amount = 0, this.unitsPerBasis, this.currency, this.warehouseId, this.productId, this.partnerId, this.expensed = true, this.note});

  final int? id;
  final String name;
  final String category;
  final String basis;
  final double amount;
  final double? unitsPerBasis;
  final String? currency;
  final int? warehouseId;
  final int? productId;
  final int? partnerId;
  final bool expensed;
  final String? note;

  bool get isPercent => basis.startsWith('percent');

  factory ScCostRule.fromJson(Map<String, dynamic> j) => ScCostRule(
        id: _in(j['id']),
        name: (j['name'] ?? '').toString(),
        category: (j['category'] ?? 'other').toString(),
        basis: (j['basis'] ?? 'per_unit').toString(),
        amount: _d(j['amount']),
        unitsPerBasis: _dn(j['units_per_basis']),
        currency: _s(j['currency']),
        warehouseId: _in(j['warehouse_id']),
        productId: _in(j['product_id']),
        partnerId: _in(j['partner_id']),
        expensed: j['expensed'] != false,
        note: _s(j['note']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'basis': basis,
        'amount': amount,
        'units_per_basis': unitsPerBasis,
        'currency': currency,
        'warehouse_id': warehouseId,
        'product_id': productId,
        'partner_id': partnerId,
        'expensed': expensed,
        'note': note,
      };

  @override
  List<Object?> get props => [id, name, category, basis, amount, unitsPerBasis];
}

class ScTariffRule extends Equatable {
  const ScTariffRule({this.id, this.name, this.productId, this.hsCodePrefix, this.originCountry, this.destinationCountry, this.tariffRate = 0, this.importTaxRate = 0, this.importTaxRecoverable = true, this.otherRate = 0, this.valuation = 'CIF'});

  final int? id;
  final String? name;
  final int? productId;
  final String? hsCodePrefix;
  final String? originCountry;
  final String? destinationCountry;
  final double tariffRate;
  final double importTaxRate;
  final bool importTaxRecoverable;
  final double otherRate;
  final String valuation;

  factory ScTariffRule.fromJson(Map<String, dynamic> j) => ScTariffRule(
        id: _in(j['id']),
        name: _s(j['name']),
        productId: _in(j['product_id']),
        hsCodePrefix: _s(j['hs_code_prefix']),
        originCountry: _s(j['origin_country']),
        destinationCountry: _s(j['destination_country']),
        tariffRate: _d(j['tariff_rate']),
        importTaxRate: _d(j['import_tax_rate']),
        importTaxRecoverable: j['import_tax_recoverable'] != false,
        otherRate: _d(j['other_rate']),
        valuation: (j['valuation'] ?? 'CIF').toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'product_id': productId,
        'hs_code_prefix': hsCodePrefix,
        'origin_country': originCountry,
        'destination_country': destinationCountry,
        'tariff_rate': tariffRate,
        'import_tax_rate': importTaxRate,
        'import_tax_recoverable': importTaxRecoverable,
        'other_rate': otherRate,
        'valuation': valuation,
      };

  @override
  List<Object?> get props => [id, hsCodePrefix, tariffRate, importTaxRate];
}

const riskEventKinds = [
  'supplier_stop', 'supplier_price', 'supplier_delay', 'route_stop', 'mode_stop',
  'port_stop', 'airport_stop', 'customs_delay', 'warehouse_capacity', 'warehouse_stop',
  'domestic_stop', 'staff_shortage', 'cost_spike',
];

class ScRiskEvent extends Equatable {
  const ScRiskEvent({this.id, required this.title, this.kind = 'cost_spike', this.severity = RiskLevel.medium, this.nodeId, this.routeId, this.partnerId, this.mode, this.startsOn, this.endsOn, this.priceMultiplier, this.costMultiplier, this.capacityMultiplier, this.delayDays, this.note});

  final int? id;
  final String title;
  final String kind;
  final RiskLevel severity;
  final int? nodeId;
  final int? routeId;
  final int? partnerId;
  final String? mode;
  final String? startsOn;
  final String? endsOn;
  final double? priceMultiplier;
  final double? costMultiplier;
  final double? capacityMultiplier;
  final double? delayDays;
  final String? note;

  factory ScRiskEvent.fromJson(Map<String, dynamic> j) => ScRiskEvent(
        id: _in(j['id']),
        title: (j['title'] ?? '').toString(),
        kind: (j['kind'] ?? 'cost_spike').toString(),
        severity: RiskLevel.parse(j['severity'] as String?),
        nodeId: _in(j['node_id']),
        routeId: _in(j['route_id']),
        partnerId: _in(j['partner_id']),
        mode: _s(j['transport_mode']),
        startsOn: _s(j['starts_on']),
        endsOn: _s(j['ends_on']),
        priceMultiplier: _dn(j['price_multiplier']),
        costMultiplier: _dn(j['cost_multiplier']),
        capacityMultiplier: _dn(j['capacity_multiplier']),
        delayDays: _dn(j['delay_days']),
        note: _s(j['note']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'kind': kind,
        'severity': severity.name,
        'node_id': nodeId,
        'route_id': routeId,
        'partner_id': partnerId,
        'transport_mode': mode,
        'starts_on': startsOn,
        'ends_on': endsOn,
        'price_multiplier': priceMultiplier,
        'cost_multiplier': costMultiplier,
        'capacity_multiplier': capacityMultiplier,
        'delay_days': delayDays,
        'note': note,
      };

  @override
  List<Object?> get props => [id, title, kind, severity];
}

class ScPartner extends Equatable {
  const ScPartner({required this.id, required this.name, this.code, this.countryCode});

  final int id;
  final String name;
  final String? code;
  final String? countryCode;

  factory ScPartner.fromJson(Map<String, dynamic> j) =>
      ScPartner(id: _i(j['id']), name: (j['name'] ?? '').toString(), code: _s(j['code']), countryCode: _s(j['country_code']));

  @override
  List<Object?> get props => [id, name];
}

class ScSettings extends Equatable {
  const ScSettings({this.baseCurrency = 'JPY', this.marginWarn = 0.15, this.marginDropWarn = 0.05, this.loadWarn = 0.8, this.loadExceeded = 1, this.defaultLotMonths = 1});

  final String baseCurrency;
  final double marginWarn;
  final double marginDropWarn;
  final double loadWarn;
  final double loadExceeded;
  final double defaultLotMonths;

  factory ScSettings.fromJson(Map<String, dynamic> j) => ScSettings(
        baseCurrency: (j['base_currency'] ?? 'JPY').toString(),
        marginWarn: _d(j['margin_warn'], 0.15),
        marginDropWarn: _d(j['margin_drop_warn'], 0.05),
        loadWarn: _d(j['load_warn'], 0.8),
        loadExceeded: _d(j['load_exceeded'], 1),
        defaultLotMonths: _d(j['default_lot_months'], 1),
      );

  @override
  List<Object?> get props => [baseCurrency, marginWarn, marginDropWarn, loadWarn, loadExceeded, defaultLotMonths];
}

/// Everything `sc_model` returns: the masters the screens show and edit.
class ScModel extends Equatable {
  const ScModel({
    this.settings = const ScSettings(),
    this.fx = const {},
    this.nodes = const [],
    this.routes = const [],
    this.partners = const [],
    this.terms = const [],
    this.products = const [],
    this.costRules = const [],
    this.tariffRules = const [],
    this.riskEvents = const [],
  });

  final ScSettings settings;
  final Map<String, double> fx;
  final List<ScNode> nodes;
  final List<ScRoute> routes;
  final List<ScPartner> partners;
  final List<ScSupplyTerm> terms;
  final List<ScModelProduct> products;
  final List<ScCostRule> costRules;
  final List<ScTariffRule> tariffRules;
  final List<ScRiskEvent> riskEvents;

  ScNode? node(int id) {
    for (final n in nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  String partnerName(int id) {
    for (final p in partners) {
      if (p.id == id) return p.name;
    }
    return '#$id';
  }

  factory ScModel.fromJson(Map<String, dynamic> j) => ScModel(
        settings: ScSettings.fromJson(_map(j['settings'])),
        fx: {for (final e in _map(j['fx']).entries) e.key: _d(e.value, 1)},
        nodes: [for (final n in _rows(j['nodes'])) ScNode.fromJson(n)],
        routes: [for (final r in _rows(j['routes'])) ScRoute.fromJson(r)],
        partners: [for (final p in _rows(j['partners'])) ScPartner.fromJson(p)],
        terms: [for (final t in _rows(j['supplier_products'])) ScSupplyTerm.fromJson(t)],
        products: [for (final p in _rows(j['products'])) ScModelProduct.fromJson(p)],
        costRules: [for (final c in _rows(j['cost_rules'])) ScCostRule.fromJson(c)],
        tariffRules: [for (final t in _rows(j['tariff_rules'])) ScTariffRule.fromJson(t)],
        riskEvents: [for (final r in _rows(j['risk_events'])) ScRiskEvent.fromJson(r)],
      );

  @override
  List<Object?> get props => [settings, fx, nodes, routes, partners, terms, products, costRules, tariffRules, riskEvents];
}

/// A saved what-if (§14).
class ScScenario extends Equatable {
  const ScScenario({required this.id, required this.name, this.description, this.warehouseId, this.params = const {}, this.lastProfit, this.lastBaselineProfit, this.lastMargin, this.updatedAt});

  final int id;
  final String name;
  final String? description;
  final int? warehouseId;
  final Map<String, dynamic> params;
  final double? lastProfit;
  final double? lastBaselineProfit;
  final double? lastMargin;
  final DateTime? updatedAt;

  factory ScScenario.fromJson(Map<String, dynamic> j) {
    final last = _map(j['last_run']);
    return ScScenario(
      id: _i(j['id']),
      name: (j['name'] ?? '').toString(),
      description: _s(j['description']),
      warehouseId: _in(j['warehouse_id']),
      params: _map(j['params']),
      lastProfit: _dn(last['profit']),
      lastBaselineProfit: _dn(last['baseline_profit']),
      lastMargin: _dn(last['margin']),
      updatedAt: DateTime.tryParse('${j['updated_at'] ?? ''}'),
    );
  }

  @override
  List<Object?> get props => [id, name, params];
}

/// A stored run (rule 4).
class ScResultRow extends Equatable {
  const ScResultRow({required this.id, required this.kind, this.name, this.scenarioName, this.createdByName, this.createdAt, this.revenue, this.profit, this.margin, this.baselineProfit});

  final int id;
  final String kind;
  final String? name;
  final String? scenarioName;
  final String? createdByName;
  final DateTime? createdAt;
  final double? revenue;
  final double? profit;
  final double? margin;
  final double? baselineProfit;

  double? get deltaProfit => profit != null && baselineProfit != null ? profit! - baselineProfit! : null;

  factory ScResultRow.fromJson(Map<String, dynamic> j) => ScResultRow(
        id: _i(j['id']),
        kind: (j['kind'] ?? '').toString(),
        name: _s(j['name']),
        scenarioName: _s(j['scenario_name']),
        createdByName: _s(j['created_by_name']),
        createdAt: DateTime.tryParse('${j['created_at'] ?? ''}'),
        revenue: _dn(j['revenue']),
        profit: _dn(j['profit']),
        margin: _dn(j['margin']),
        baselineProfit: _dn(j['baseline_profit']),
      );

  @override
  List<Object?> get props => [id, kind, profit];
}

/// A supplier's record (§28).
class ScSupplierStat extends Equatable {
  const ScSupplierStat({required this.partnerId, required this.name, this.countryCode, this.products = 0, this.soleSourceProducts = 0, this.purchaseOrders = 0, this.purchasedAmount = 0, this.avgLeadTimeDays, this.lateRate, this.defectRate, this.inspectedUnits = 0});

  final int partnerId;
  final String name;
  final String? countryCode;
  final int products;
  final int soleSourceProducts;
  final int purchaseOrders;
  final double purchasedAmount;
  final double? avgLeadTimeDays;
  final double? lateRate;
  final double? defectRate;
  final double inspectedUnits;

  factory ScSupplierStat.fromJson(Map<String, dynamic> j) => ScSupplierStat(
        partnerId: _i(j['partner_id']),
        name: (j['name'] ?? '').toString(),
        countryCode: _s(j['country_code']),
        products: _i(j['products']),
        soleSourceProducts: _i(j['sole_source_products']),
        purchaseOrders: _i(j['purchase_orders']),
        purchasedAmount: _d(j['purchased_amount']),
        avgLeadTimeDays: _dn(j['avg_lead_time_days']),
        lateRate: _dn(j['late_rate']),
        defectRate: _dn(j['defect_rate']),
        inspectedUnits: _d(j['inspected_units']),
      );

  @override
  List<Object?> get props => [partnerId, products, lateRate, defectRate];
}

/// What a scenario changes, as the engine reads it (§23). Multipliers are
/// relative (1.10 = +10%); null leaves a thing as it is.
class ScScenarioParams extends Equatable {
  const ScScenarioParams({
    this.supplierPriceMultiplier,
    this.discountRates = const {},
    this.freightMultiplier,
    this.seaFreightMultiplier,
    this.airFreightMultiplier,
    this.tariffMultiplier,
    this.customsCostMultiplier,
    this.warehouseCostMultiplier,
    this.laborCostMultiplier,
    this.overheadMultiplier,
    this.fxMultiplier,
    this.salesPriceMultiplier,
    this.volumeMultiplier,
    this.routeMode = 'current',
    this.supplierChoice = 'current',
    this.enabledSuppliers,
    this.addedSuppliers = const [],
    this.disruptions = const [],
    this.applyRiskEvents = false,
    this.productIds,
    this.lotQuantity,
  });

  final double? supplierPriceMultiplier;

  /// 掛率 by partner id.
  final Map<int, double> discountRates;
  final double? freightMultiplier;
  final double? seaFreightMultiplier;
  final double? airFreightMultiplier;
  final double? tariffMultiplier;
  final double? customsCostMultiplier;
  final double? warehouseCostMultiplier;
  final double? laborCostMultiplier;
  final double? overheadMultiplier;
  final double? fxMultiplier;
  final double? salesPriceMultiplier;
  final double? volumeMultiplier;

  /// current / cheapest / fastest / sea / air / truck …
  final String routeMode;

  /// current / cheapest / fastest
  final String supplierChoice;
  final Set<int>? enabledSuppliers;
  final List<ScSupplyTerm> addedSuppliers;
  final List<Map<String, dynamic>> disruptions;
  final bool applyRiskEvents;
  final List<int>? productIds;

  /// Units per order, for comparing at a given quantity (§5).
  final int? lotQuantity;

  bool get isEmpty => toJson().isEmpty;

  Map<String, dynamic> toJson() {
    final out = <String, dynamic>{};
    void put(String k, double? v) {
      if (v != null && v != 1) out[k] = v;
    }

    put('supplier_price_multiplier', supplierPriceMultiplier);
    if (discountRates.isNotEmpty) {
      out['discount_rate_overrides'] = {for (final e in discountRates.entries) '${e.key}': e.value};
    }
    put('freight_multiplier', freightMultiplier);
    final byMode = <String, double>{
      if (seaFreightMultiplier != null && seaFreightMultiplier != 1) 'sea': seaFreightMultiplier!,
      if (airFreightMultiplier != null && airFreightMultiplier != 1) 'air': airFreightMultiplier!,
    };
    if (byMode.isNotEmpty) out['freight_multipliers'] = byMode;
    put('tariff_multiplier', tariffMultiplier);
    put('customs_cost_multiplier', customsCostMultiplier);
    put('warehouse_cost_multiplier', warehouseCostMultiplier);
    put('labor_cost_multiplier', laborCostMultiplier);
    put('overhead_multiplier', overheadMultiplier);
    put('fx_multiplier', fxMultiplier);
    put('sales_price_multiplier', salesPriceMultiplier);
    put('volume_multiplier', volumeMultiplier);
    if (routeMode != 'current') out['route_mode'] = routeMode;
    if (supplierChoice != 'current') out['supplier_choice'] = supplierChoice;
    if (enabledSuppliers != null) out['supplier_enabled'] = enabledSuppliers!.toList()..sort();
    if (addedSuppliers.isNotEmpty) {
      out['added_suppliers'] = [
        for (final t in addedSuppliers) {...t.toJson()..removeWhere((_, v) => v == null)},
      ];
    }
    if (disruptions.isNotEmpty) out['disruptions'] = disruptions;
    if (applyRiskEvents) out['apply_risk_events'] = true;
    if (productIds != null && productIds!.isNotEmpty) out['product_ids'] = productIds;
    if (lotQuantity != null && lotQuantity! > 0) out['lot_quantity'] = lotQuantity;
    return out;
  }

  factory ScScenarioParams.fromJson(Map<String, dynamic> j) {
    final byMode = _map(j['freight_multipliers']);
    final rates = _map(j['discount_rate_overrides']);
    return ScScenarioParams(
      supplierPriceMultiplier: _dn(j['supplier_price_multiplier']),
      discountRates: {
        for (final e in rates.entries)
          if (int.tryParse(e.key) != null) int.parse(e.key): _d(e.value),
      },
      freightMultiplier: _dn(j['freight_multiplier']),
      seaFreightMultiplier: _dn(byMode['sea']),
      airFreightMultiplier: _dn(byMode['air']),
      tariffMultiplier: _dn(j['tariff_multiplier']),
      customsCostMultiplier: _dn(j['customs_cost_multiplier']),
      warehouseCostMultiplier: _dn(j['warehouse_cost_multiplier']),
      laborCostMultiplier: _dn(j['labor_cost_multiplier']),
      overheadMultiplier: _dn(j['overhead_multiplier']),
      fxMultiplier: _dn(j['fx_multiplier']),
      salesPriceMultiplier: _dn(j['sales_price_multiplier']),
      volumeMultiplier: _dn(j['volume_multiplier']),
      routeMode: (j['route_mode'] ?? 'current').toString(),
      supplierChoice: (j['supplier_choice'] ?? 'current').toString(),
      enabledSuppliers: j['supplier_enabled'] is List ? {for (final x in j['supplier_enabled'] as List) _i(x)} : null,
      addedSuppliers: [for (final t in _rows(j['added_suppliers'])) ScSupplyTerm.fromJson(t)],
      disruptions: _rows(j['disruptions']),
      applyRiskEvents: j['apply_risk_events'] == true,
      productIds: j['product_ids'] is List ? [for (final x in j['product_ids'] as List) _i(x)] : null,
      lotQuantity: _in(j['lot_quantity']),
    );
  }

  @override
  List<Object?> get props => [toJson().toString()];
}
