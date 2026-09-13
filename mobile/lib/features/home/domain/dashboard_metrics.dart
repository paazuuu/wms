import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

/// One day of the inbound/outbound trend series.
class TrendPoint extends Equatable {
  const TrendPoint(
      {required this.day, required this.inbound, required this.outbound});

  /// ISO date string, e.g. "2026-09-09".
  final String day;
  final int inbound;
  final int outbound;

  factory TrendPoint.fromJson(Map<String, dynamic> json) => TrendPoint(
        day: json['day'] as String? ?? '',
        inbound: _asInt(json['inbound']),
        outbound: _asInt(json['outbound']),
      );

  @override
  List<Object?> get props => [day, inbound, outbound];
}

/// A plan still carrying an outstanding (未納) quantity.
class OutstandingPlanBrief extends Equatable {
  const OutstandingPlanBrief({
    required this.id,
    required this.deliveryNumber,
    required this.outstanding,
    this.supplierName,
  });

  final int id;
  final String deliveryNumber;
  final String? supplierName;
  final int outstanding;

  factory OutstandingPlanBrief.fromJson(Map<String, dynamic> json) =>
      OutstandingPlanBrief(
        id: _asInt(json['id']),
        deliveryNumber: json['delivery_number'] as String? ?? '',
        supplierName: json['supplier_name'] as String?,
        outstanding: _asInt(json['outstanding']),
      );

  @override
  List<Object?> get props => [id, deliveryNumber, supplierName, outstanding];
}

/// A SKU at or below the low-stock threshold.
class LowStockBrief extends Equatable {
  const LowStockBrief(
      {required this.janCode, required this.onHand, this.productName});

  final String janCode;
  final String? productName;
  final int onHand;

  factory LowStockBrief.fromJson(Map<String, dynamic> json) => LowStockBrief(
        janCode: json['jan_code'] as String? ?? '',
        productName: json['product_name'] as String?,
        onHand: _asInt(json['on_hand']),
      );

  @override
  List<Object?> get props => [janCode, productName, onHand];
}

/// Aggregated home-dashboard figures, computed server-side by the
/// `dashboard_metrics` RPC so the client makes a single round trip.
class DashboardMetrics extends Equatable {
  const DashboardMetrics({
    required this.asOf,
    required this.inboundTodayUnits,
    required this.inboundTodayEvents,
    required this.outboundTodayUnits,
    required this.outboundTodayEvents,
    required this.outstandingPlanCount,
    required this.outstandingUnits,
    required this.totalSkus,
    required this.totalOnHand,
    required this.lowStockCount,
    required this.lowThreshold,
    this.pendingInspectionCount = 0,
    this.openPickingCount = 0,
    this.packingWaitCount = 0,
    this.shippingWaitCount = 0,
    this.openCountCount = 0,
    this.openTransferCount = 0,
    this.putawayPendingCount = 0,
    this.putawayPendingUnits = 0,
    required this.trend,
    required this.outstandingList,
    required this.lowStockList,
  });

  final String asOf;
  final int inboundTodayUnits;
  final int inboundTodayEvents;
  final int outboundTodayUnits;
  final int outboundTodayEvents;
  final int outstandingPlanCount;
  final int outstandingUnits;
  final int totalSkus;
  final int totalOnHand;
  final int lowStockCount;
  final int lowThreshold;

  /// 検品待ち: inbound lots not yet fully inspected.
  final int pendingInspectionCount;

  /// ピッキング: pick lists currently being worked.
  final int openPickingCount;

  /// 梱包待ち: shipments not yet started into cartons.
  final int packingWaitCount;

  /// 出荷待ち: shipments packed, ready to confirm.
  final int shippingWaitCount;

  /// 棚卸: cycle counts still being counted.
  final int openCountCount;

  /// 倉庫間移動: transfers in flight, either direction.
  final int openTransferCount;

  /// 棚入れ待ち: JANs whose warehouse balance is not yet fully assigned to a
  /// bin (0038). Always 0 for a warehouse that does not use locations.
  final int putawayPendingCount;

  /// Units behind [putawayPendingCount] — the pieces still to be shelved.
  final int putawayPendingUnits;

  final List<TrendPoint> trend;
  final List<OutstandingPlanBrief> outstandingList;
  final List<LowStockBrief> lowStockList;

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) {
    List<T> parseList<T>(String key, T Function(Map<String, dynamic>) f) =>
        (json[key] as List?)
                ?.whereType<Map>()
                .map((e) => f(e.cast<String, dynamic>()))
                .toList() ??
            const [];
    return DashboardMetrics(
      asOf: json['as_of'] as String? ?? '',
      inboundTodayUnits: _asInt(json['inbound_today_units']),
      inboundTodayEvents: _asInt(json['inbound_today_events']),
      outboundTodayUnits: _asInt(json['outbound_today_units']),
      outboundTodayEvents: _asInt(json['outbound_today_events']),
      outstandingPlanCount: _asInt(json['outstanding_plan_count']),
      outstandingUnits: _asInt(json['outstanding_units']),
      totalSkus: _asInt(json['total_skus']),
      totalOnHand: _asInt(json['total_on_hand']),
      lowStockCount: _asInt(json['low_stock_count']),
      lowThreshold: _asInt(json['low_threshold']),
      pendingInspectionCount: _asInt(json['pending_inspection_count']),
      openPickingCount: _asInt(json['open_picking_count']),
      packingWaitCount: _asInt(json['packing_wait_count']),
      shippingWaitCount: _asInt(json['shipping_wait_count']),
      openCountCount: _asInt(json['open_count_count']),
      openTransferCount: _asInt(json['open_transfer_count']),
      putawayPendingCount: _asInt(json['putaway_pending_count']),
      putawayPendingUnits: _asInt(json['putaway_pending_units']),
      trend: parseList('trend', TrendPoint.fromJson),
      outstandingList:
          parseList('outstanding_list', OutstandingPlanBrief.fromJson),
      lowStockList: parseList('low_stock_list', LowStockBrief.fromJson),
    );
  }

  @override
  List<Object?> get props => [
        asOf,
        inboundTodayUnits,
        outboundTodayUnits,
        outstandingPlanCount,
        outstandingUnits,
        totalSkus,
        totalOnHand,
        lowStockCount,
        lowThreshold,
        pendingInspectionCount,
        openPickingCount,
        packingWaitCount,
        shippingWaitCount,
        openCountCount,
        openTransferCount,
        putawayPendingCount,
        putawayPendingUnits,
        trend,
        outstandingList,
        lowStockList,
      ];
}
