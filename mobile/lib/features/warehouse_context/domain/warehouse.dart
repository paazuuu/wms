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
    this.usesLocations = false,
    this.timezone = 'Asia/Tokyo',
    this.countryCode = 'JP',
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

  /// Opt-in shelf locations (spec §7, §49). While false the warehouse keeps a
  /// single balance and bins / put-away stay inactive — the default.
  final bool usesLocations;

  final String timezone;

  /// ISO country the warehouse is in (0087). Stock is only ever added up
  /// within one country (0090).
  final String countryCode;

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
        usesLocations: json['uses_locations'] == true,
        timezone: json['timezone'] as String? ?? 'Asia/Tokyo',
        countryCode: json['country_code'] as String? ?? 'JP',
        skuCount: _asInt(json['sku_count']),
        onHand: _asInt(json['on_hand']),
        inboundOpen: _asInt(json['inbound_open']),
        outboundOpen: _asInt(json['outbound_open']),
      );

  @override
  List<Object?> get props => [
        id, code, name, status, isDefault, usesLocations, timezone, countryCode,
        skuCount, onHand, inboundOpen, outboundOpen
      ];
}

/// Totals over a set of warehouses — since 0090 always within one country;
/// a border is never summed across.
class WarehouseTotals extends Equatable {
  const WarehouseTotals({
    this.countryCode,
    this.warehouseCount = 0,
    this.skuCount = 0,
    this.onHand = 0,
    this.inboundOpen = 0,
    this.outboundOpen = 0,
  });

  /// The country these totals are for; null on the legacy single total.
  final String? countryCode;
  final int warehouseCount;
  final int skuCount;
  final int onHand;
  final int inboundOpen;
  final int outboundOpen;

  factory WarehouseTotals.fromJson(Map<String, dynamic> json) => WarehouseTotals(
        countryCode: json['country_code'] as String?,
        warehouseCount: _asInt(json['warehouse_count']),
        skuCount: _asInt(json['sku_count']),
        onHand: _asInt(json['on_hand']),
        inboundOpen: _asInt(json['inbound_open']),
        outboundOpen: _asInt(json['outbound_open']),
      );

  @override
  List<Object?> get props =>
      [countryCode, warehouseCount, skuCount, onHand, inboundOpen, outboundOpen];
}

/// The warehouse list plus company totals, as returned by `warehouse_overview`.
class WarehouseOverview extends Equatable {
  const WarehouseOverview({
    required this.warehouses,
    required this.totals,
    this.countryTotals = const [],
  });

  final List<Warehouse> warehouses;

  /// The home country's totals (0090 — never a sum across countries).
  final WarehouseTotals totals;

  /// One total per country, home first.
  final List<WarehouseTotals> countryTotals;

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
        countryTotals: (json['country_totals'] as List?)
                ?.whereType<Map>()
                .map((e) => WarehouseTotals.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props => [warehouses, totals, countryTotals];
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
    this.usesLocations = false,
    this.createDefaultBins = false,
    this.receivingBin,
    this.shippingBin,
  });

  final String code;
  final String name;
  final String? address;
  final String? phone;
  final String timezone;
  final bool isActive;

  /// Manage stock by shelf location. Off by default (spec §7: do not force the
  /// hierarchy); turning it on is what makes bins and put-away meaningful.
  final bool usesLocations;

  /// Seed STAGING / QC_HOLD / SHIPPING / PICKABLE bins for the new warehouse.
  /// Only offered once [usesLocations] is on — auto-creation is a toggle, never
  /// a default (spec §49).
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
        'uses_locations': usesLocations,
        'create_default_bins': usesLocations && createDefaultBins,
        if (receivingBin != null && receivingBin!.isNotEmpty)
          'receiving_bin': receivingBin,
        if (shippingBin != null && shippingBin!.isNotEmpty)
          'shipping_bin': shippingBin,
      };
}
