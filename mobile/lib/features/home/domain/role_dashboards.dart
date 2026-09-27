import 'package:equatable/equatable.dart';

int _asInt(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

String? _asText(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

DateTime? _asDate(dynamic v) => v == null ? null : DateTime.tryParse('$v');

List<Map<String, dynamic>> _rows(dynamic v) =>
    [for (final e in (v as List? ?? const []).whereType<Map>()) e.cast<String, dynamic>()];

/// Which dashboard view (0102). Each job has one; any can be opened by hand.
enum DashboardView {
  overview('overview'),
  inspection('inspection'),
  purchasing('purchasing'),
  sales('sales');

  const DashboardView(this.wire);
  final String wire;

  static DashboardView? parse(String? v) {
    for (final d in DashboardView.values) {
      if (d.wire == v) return d;
    }
    return null;
  }

  /// Offered to whoever may read what it shows.
  bool visibleFor(Iterable<String> permissions) => switch (this) {
        DashboardView.overview => true,
        DashboardView.inspection => permissions.any((p) =>
            p == 'receiving.view' || p == 'inspection.view' || p == 'inspection.confirm'),
        DashboardView.purchasing => permissions.any(
            (p) => p == 'inventory.view' || p == 'purchase_order.view'),
        DashboardView.sales => permissions.contains('sales_order.view'),
      };

  /// The view a role opens on: inspection for the floor, purchasing for the
  /// buyers, sales for whoever takes the orders; the overview otherwise.
  static DashboardView defaultFor(Iterable<String> roles) {
    final r = roles.toSet();
    if (r.contains('system_admin') || r.contains('company_admin') || r.contains('warehouse_manager')) {
      return DashboardView.overview;
    }
    if (r.contains('purchasing')) return DashboardView.purchasing;
    if (r.contains('sales')) return DashboardView.sales;
    if (r.contains('inspector') || r.contains('receiving') || r.contains('putaway_operator')) {
      return DashboardView.inspection;
    }
    return DashboardView.overview;
  }
}

/// One delivery still to come (0102 `dashboard_inbound_schedule`).
class InboundPlan extends Equatable {
  const InboundPlan({
    required this.id,
    required this.deliveryNumber,
    this.supplierName,
    this.poNumber,
    this.expectedOn,
    this.manual = false,
    this.lineCount = 0,
    this.outstandingUnits = 0,
    this.preview = const [],
    this.warehouseName,
  });

  final int id;
  final String deliveryNumber;
  final String? supplierName;
  final String? poNumber;
  final DateTime? expectedOn;

  /// Written by hand (MN-…) because the supplier sent no list.
  final bool manual;
  final int lineCount;
  final int outstandingUnits;
  final List<({String name, String jan, int quantity})> preview;
  final String? warehouseName;

  factory InboundPlan.fromJson(Map<String, dynamic> j) => InboundPlan(
        id: _asInt(j['id']),
        deliveryNumber: (j['delivery_number'] ?? '').toString(),
        supplierName: _asText(j['supplier_name']),
        poNumber: _asText(j['po_number']),
        expectedOn: _asDate(j['expected_on']),
        manual: j['manual'] == true,
        lineCount: _asInt(j['line_count']),
        outstandingUnits: _asInt(j['outstanding_units']),
        warehouseName: _asText(j['warehouse_name']),
        preview: [
          for (final p in _rows(j['preview']))
            (
              name: (p['product_name'] ?? '').toString(),
              jan: (p['jan_code'] ?? '').toString(),
              quantity: _asInt(p['outstanding']),
            ),
        ],
      );

  @override
  List<Object?> get props => [id, expectedOn, outstandingUnits];
}

/// An approved purchase order nobody has written a delivery up for yet.
class UnplannedOrder extends Equatable {
  const UnplannedOrder({
    required this.id,
    required this.poNumber,
    this.supplierName,
    this.expectedDate,
    this.outstandingUnits = 0,
    this.lineCount = 0,
  });

  final int id;
  final String poNumber;
  final String? supplierName;
  final DateTime? expectedDate;
  final int outstandingUnits;
  final int lineCount;

  factory UnplannedOrder.fromJson(Map<String, dynamic> j) => UnplannedOrder(
        id: _asInt(j['id']),
        poNumber: (j['po_number'] ?? '').toString(),
        supplierName: _asText(j['supplier_name']),
        expectedDate: _asDate(j['expected_date']),
        outstandingUnits: _asInt(j['outstanding_units']),
        lineCount: _asInt(j['line_count']),
      );

  @override
  List<Object?> get props => [id, expectedDate, outstandingUnits];
}

class InboundSchedule extends Equatable {
  const InboundSchedule({
    this.today,
    this.plans = const [],
    this.unplannedOrders = const [],
    this.awaitingLines = 0,
    this.awaitingUnits = 0,
    this.awaitingInspections = 0,
  });

  final DateTime? today;
  final List<InboundPlan> plans;
  final List<UnplannedOrder> unplannedOrders;
  final int awaitingLines;
  final int awaitingUnits;
  final int awaitingInspections;

  factory InboundSchedule.fromJson(Map<String, dynamic> j) {
    final a = (j['awaiting_inspection'] as Map?)?.cast<String, dynamic>() ?? const {};
    return InboundSchedule(
      today: _asDate(j['today']),
      plans: [for (final r in _rows(j['plans'])) InboundPlan.fromJson(r)],
      unplannedOrders: [for (final r in _rows(j['unplanned_orders'])) UnplannedOrder.fromJson(r)],
      awaitingLines: _asInt(a['lines']),
      awaitingUnits: _asInt(a['units']),
      awaitingInspections: _asInt(a['inspections']),
    );
  }

  @override
  List<Object?> get props => [today, plans, unplannedOrders, awaitingLines, awaitingUnits];
}

/// One product's stock as it really stands in one country (0102).
class StockOverviewRow extends Equatable {
  const StockOverviewRow({
    required this.productId,
    required this.janCode,
    required this.productName,
    this.usable = 0,
    this.qcPending = 0,
    this.held = 0,
    this.reserved = 0,
    this.available = 0,
    this.incoming = 0,
    this.nextExpected,
    this.backordered = 0,
    this.shortfall = 0,
  });

  final int productId;
  final String janCode;
  final String productName;
  final int usable;
  final int qcPending;
  final int held;
  final int reserved;
  final int available;
  final int incoming;
  final DateTime? nextExpected;
  final int backordered;

  /// What orders still need after free stock and what is already coming.
  final int shortfall;

  int get onHand => usable + qcPending + held;

  factory StockOverviewRow.fromJson(Map<String, dynamic> j) => StockOverviewRow(
        productId: _asInt(j['product_id']),
        janCode: (j['jan_code'] ?? '').toString(),
        productName: (j['product_name'] ?? '').toString(),
        usable: _asInt(j['usable']),
        qcPending: _asInt(j['qc_pending']),
        held: _asInt(j['held']),
        reserved: _asInt(j['reserved']),
        available: _asInt(j['available']),
        incoming: _asInt(j['incoming']),
        nextExpected: _asDate(j['next_expected']),
        backordered: _asInt(j['backordered']),
        shortfall: _asInt(j['shortfall']),
      );

  @override
  List<Object?> get props => [productId, usable, qcPending, held, incoming, shortfall];
}

class StockOverview extends Equatable {
  const StockOverview({
    this.countryCode = '',
    this.products = const [],
    this.usable = 0,
    this.qcPending = 0,
    this.held = 0,
    this.incoming = 0,
    this.productCount = 0,
  });

  final String countryCode;
  final List<StockOverviewRow> products;
  final int usable;
  final int qcPending;
  final int held;
  final int incoming;
  final int productCount;

  factory StockOverview.fromJson(Map<String, dynamic> j) {
    final t = (j['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    return StockOverview(
      countryCode: (j['country_code'] ?? '').toString(),
      products: [for (final r in _rows(j['products'])) StockOverviewRow.fromJson(r)],
      usable: _asInt(t['usable']),
      qcPending: _asInt(t['qc_pending']),
      held: _asInt(t['held']),
      incoming: _asInt(t['incoming']),
      productCount: _asInt(t['products']),
    );
  }

  @override
  List<Object?> get props => [countryCode, products, usable, qcPending, held, incoming];
}

/// Orders from one country, a year at a time (0102).
class SalesCycle extends Equatable {
  const SalesCycle({
    this.countryCode,
    this.months = const [],
    this.totalUnits = 0,
    this.prevTotalUnits = 0,
    this.totalOrders = 0,
    this.topProducts = const [],
    this.toPurchase = const [],
  });

  final String? countryCode;
  final List<({String month, int orders, int units, int prevUnits})> months;
  final int totalUnits;
  final int prevTotalUnits;
  final int totalOrders;
  final List<({String name, String jan, int units, int orders})> topProducts;
  final List<({String name, String jan, int backordered, int incoming, int shortfall})> toPurchase;

  /// Change against the same months a year before; null with nothing to compare.
  double? get change => prevTotalUnits == 0 ? null : (totalUnits - prevTotalUnits) / prevTotalUnits;

  factory SalesCycle.fromJson(Map<String, dynamic> j) => SalesCycle(
        countryCode: _asText(j['country_code']),
        months: [
          for (final m in _rows(j['months']))
            (
              month: (m['month'] ?? '').toString(),
              orders: _asInt(m['orders']),
              units: _asInt(m['units']),
              prevUnits: _asInt(m['prev_units']),
            ),
        ],
        totalUnits: _asInt(j['total_units']),
        prevTotalUnits: _asInt(j['prev_total_units']),
        totalOrders: _asInt(j['total_orders']),
        topProducts: [
          for (final p in _rows(j['top_products']))
            (
              name: (p['product_name'] ?? p['jan_code'] ?? '').toString(),
              jan: (p['jan_code'] ?? '').toString(),
              units: _asInt(p['units']),
              orders: _asInt(p['orders']),
            ),
        ],
        toPurchase: [
          for (final p in _rows(j['to_purchase']))
            (
              name: (p['product_name'] ?? p['jan_code'] ?? '').toString(),
              jan: (p['jan_code'] ?? '').toString(),
              backordered: _asInt(p['backordered']),
              incoming: _asInt(p['incoming']),
              shortfall: _asInt(p['shortfall']),
            ),
        ],
      );

  @override
  List<Object?> get props => [countryCode, months, totalUnits, prevTotalUnits, topProducts, toPurchase];
}
