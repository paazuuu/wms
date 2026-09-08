import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

/// One warehouse of the company, with the headline figures the picker and the
/// "all warehouses" view show (spec §4.2, §6, §50).
class Warehouse extends Equatable {
  const Warehouse({
    required this.id,
    required this.code,
    required this.name,
    this.status = 'active',
    this.isDefault = false,
    this.timezone = 'Asia/Tokyo',
    this.skuCount = 0,
    this.onHand = 0,
    this.inboundOpen = 0,
    this.outboundOpen = 0,
  });

  final int id;
  final String code;
  final String name;

  /// `active` | `inactive`. Warehouses are deactivated, never deleted, once they
  /// carry stock history (spec §6).
  final String status;

  /// The company's default warehouse — preselected as the active context.
  final bool isDefault;

  final String timezone;

  /// SKUs with stock on hand in this warehouse.
  final int skuCount;

  /// Total units on hand in this warehouse.
  final int onHand;

  /// Delivery plans still open/partial (未納 work waiting).
  final int inboundOpen;

  /// Shipments still open (出庫待ち).
  final int outboundOpen;

  bool get isActive => status == 'active';

  factory Warehouse.fromJson(Map<String, dynamic> json) => Warehouse(
        id: _asInt(json['id']),
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        status: json['status'] as String? ?? 'active',
        isDefault: json['is_default'] == true,
        timezone: json['timezone'] as String? ?? 'Asia/Tokyo',
        skuCount: _asInt(json['sku_count']),
        onHand: _asInt(json['on_hand']),
        inboundOpen: _asInt(json['inbound_open']),
        outboundOpen: _asInt(json['outbound_open']),
      );

  @override
  List<Object?> get props =>
      [id, code, name, status, isDefault, timezone, skuCount, onHand, inboundOpen, outboundOpen];
}

/// Company-wide totals across every warehouse (the admin "all" row, spec §50).
class WarehouseTotals extends Equatable {
  const WarehouseTotals({
    this.warehouseCount = 0,
    this.skuCount = 0,
    this.onHand = 0,
    this.inboundOpen = 0,
    this.outboundOpen = 0,
  });

  final int warehouseCount;
  final int skuCount;
  final int onHand;
  final int inboundOpen;
  final int outboundOpen;

  factory WarehouseTotals.fromJson(Map<String, dynamic> json) => WarehouseTotals(
        warehouseCount: _asInt(json['warehouse_count']),
        skuCount: _asInt(json['sku_count']),
        onHand: _asInt(json['on_hand']),
        inboundOpen: _asInt(json['inbound_open']),
        outboundOpen: _asInt(json['outbound_open']),
      );

  @override
  List<Object?> get props =>
      [warehouseCount, skuCount, onHand, inboundOpen, outboundOpen];
}

/// The warehouse list plus company totals, as returned by `warehouse_overview`.
class WarehouseOverview extends Equatable {
  const WarehouseOverview({required this.warehouses, required this.totals});

  final List<Warehouse> warehouses;
  final WarehouseTotals totals;

  /// True once the company runs more than one warehouse — the point at which the
  /// spec wants a persistent picker and an "all warehouses" view (spec §4.2).
  bool get isMultiWarehouse => warehouses.length > 1;

  /// The warehouse to preselect: the default one, else the first.
  Warehouse? get preferred {
    if (warehouses.isEmpty) return null;
    for (final w in warehouses) {
      if (w.isDefault) return w;
    }
    return warehouses.first;
  }

  Warehouse? byId(int? id) {
    if (id == null) return null;
    for (final w in warehouses) {
      if (w.id == id) return w;
    }
    return null;
  }

  factory WarehouseOverview.fromJson(Map<String, dynamic> json) =>
      WarehouseOverview(
        warehouses: (json['warehouses'] as List?)
                ?.whereType<Map>()
                .map((e) => Warehouse.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
        totals: WarehouseTotals.fromJson(
            (json['totals'] as Map?)?.cast<String, dynamic>() ?? const {}),
      );

  @override
  List<Object?> get props => [warehouses, totals];
}

/// A storage bin inside a warehouse (spec §7, §8).
class Bin extends Equatable {
  const Bin({
    required this.id,
    required this.code,
    required this.binType,
    this.isActive = true,
  });

  final int id;
  final String code;

  /// STAGING | PICKABLE | PICKABLE_STAGING | QC_HOLD | SHIPPING | RETURNS |
  /// DAMAGED | VIRTUAL.
  final String binType;
  final bool isActive;

  factory Bin.fromJson(Map<String, dynamic> json) => Bin(
        id: _asInt(json['id']),
        code: json['code'] as String? ?? '',
        binType: json['bin_type'] as String? ?? 'PICKABLE',
        isActive: json['is_active'] != false,
      );

  @override
  List<Object?> get props => [id, code, binType, isActive];
}

/// Fields collected by the add-warehouse wizard (spec §4.2).
class NewWarehouse {
  const NewWarehouse({
    required this.code,
    required this.name,
    this.address,
    this.phone,
    this.timezone = 'Asia/Tokyo',
    this.isActive = true,
    this.createDefaultBins = true,
    this.receivingBin,
    this.shippingBin,
  });

  final String code;
  final String name;
  final String? address;
  final String? phone;
  final String timezone;
  final bool isActive;

  /// Seed STAGING / QC_HOLD / SHIPPING / PICKABLE bins for the new warehouse.
  /// Optional by design — auto-creation is a toggle, not forced (spec §49).
  final bool createDefaultBins;

  /// Default receiving (staging) and shipping bin codes for the wizard.
  final String? receivingBin;
  final String? shippingBin;

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        if (address != null && address!.isNotEmpty) 'address': address,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        'timezone': timezone,
        'is_active': isActive,
        'create_default_bins': createDefaultBins,
        if (receivingBin != null && receivingBin!.isNotEmpty)
          'receiving_bin': receivingBin,
        if (shippingBin != null && shippingBin!.isNotEmpty)
          'shipping_bin': shippingBin,
      };
}
