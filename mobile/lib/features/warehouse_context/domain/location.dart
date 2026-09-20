import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

int? _asIntOrNull(dynamic v) => v == null
    ? null
    : (v is int ? v : (v is num ? v.toInt() : int.tryParse('$v')));

String? _asText(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// One node of the location tree (`location_tree`, 0062).
///
/// §7 keeps Warehouse → Zone → Bin and generalises it, so this is a tree of
/// arbitrary depth: a warehouse laid out as Zone → Aisle → Rack → Shelf → Bin
/// says so instead of flattening three levels into a bin code.
///
/// [children] arrives nested from the server rather than being rebuilt here from
/// parent ids — one shape, assembled once, so no two screens can disagree about
/// what the hierarchy is.
class Location extends Equatable {
  const Location({
    required this.id,
    required this.code,
    required this.locationType,
    this.name,
    this.barcode,
    this.isActive = true,
    this.pickable = true,
    this.receivable = false,
    this.shipping = false,
    this.quarantine = false,
    this.isVirtual = false,
    this.zoneId,
    this.binId,
    this.onHand,
    this.children = const [],
  });

  final int id;
  final String code;

  /// STORAGE / PICKING / RECEIVING / QC / PACKING / SHIPPING / QUARANTINE /
  /// DAMAGED / RETURN / TRANSIT / VIRTUAL (0062). Kept as the code because the
  /// vocabulary is a table, and a type added later should show as itself.
  final String locationType;
  final String? name;
  final String? barcode;
  final bool isActive;
  final bool pickable;
  final bool receivable;
  final bool shipping;
  final bool quarantine;
  final bool isVirtual;

  /// The zone or bin this node mirrors, when it mirrors one. A rack, an aisle or
  /// a virtual RECEIVING area has neither — those exist only in the tree.
  final int? zoneId;
  final int? binId;

  /// `bin_stock` for a node that is a bin. Null — not zero — for one that is
  /// not: "no stock here" and "this is not somewhere stock is counted" are
  /// different answers.
  final int? onHand;

  final List<Location> children;

  bool get isBin => binId != null;
  bool get hasChildren => children.isNotEmpty;

  /// Every node at or below this one, depth first — for counting and searching
  /// without each caller writing its own recursion.
  Iterable<Location> get descendants =>
      [this, for (final child in children) ...child.descendants];

  factory Location.fromJson(Map<String, dynamic> json) {
    final kids = json['children'];
    return Location(
      id: _asInt(json['id']),
      code: (json['code'] ?? '').toString(),
      locationType: (json['location_type'] ?? 'STORAGE').toString(),
      name: _asText(json['name']),
      barcode: _asText(json['barcode']),
      isActive: json['is_active'] != false,
      pickable: json['pickable'] == true,
      receivable: json['receivable'] == true,
      shipping: json['shipping'] == true,
      quarantine: json['quarantine'] == true,
      isVirtual: json['is_virtual'] == true,
      zoneId: _asIntOrNull(json['zone_id']),
      binId: _asIntOrNull(json['bin_id']),
      onHand: _asIntOrNull(json['on_hand']),
      children: kids is List
          ? kids
              .whereType<Map>()
              .map((e) => Location.fromJson(e.cast<String, dynamic>()))
              .toList(growable: false)
          : const [],
    );
  }

  @override
  List<Object?> get props => [
        id,
        code,
        locationType,
        name,
        barcode,
        isActive,
        pickable,
        receivable,
        shipping,
        quarantine,
        isVirtual,
        zoneId,
        binId,
        onHand,
        children,
      ];
}

/// One row of `location_types` (0062, §8).
///
/// The type carries the defaults a new location of that type starts with, which
/// is §8's point: "can stock be picked from here" is a column, not a convention
/// written into each query that asks.
class LocationType extends Equatable {
  const LocationType({
    required this.code,
    required this.name,
    this.defaultPickable = true,
    this.defaultReceivable = false,
    this.defaultShipping = false,
    this.defaultQuarantine = false,
    this.defaultVirtual = false,
  });

  final String code;
  final String name;
  final bool defaultPickable;
  final bool defaultReceivable;
  final bool defaultShipping;
  final bool defaultQuarantine;
  final bool defaultVirtual;

  factory LocationType.fromJson(Map<String, dynamic> json) => LocationType(
        code: (json['code'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        defaultPickable: json['default_pickable'] == true,
        defaultReceivable: json['default_receivable'] == true,
        defaultShipping: json['default_shipping'] == true,
        defaultQuarantine: json['default_quarantine'] == true,
        defaultVirtual: json['default_virtual'] == true,
      );

  @override
  List<Object?> get props => [code, name, defaultPickable, defaultVirtual];
}
