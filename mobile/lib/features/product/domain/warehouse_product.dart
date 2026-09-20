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

/// How a product is handled in one particular warehouse
/// (`warehouse_product_settings`, 0063).
///
/// §22's point: the same product lives at A-01 in Osaka and B-03 in Kobe, so
/// "where does this go" and "when do we reorder" are per-warehouse answers. A
/// product with no row here simply has no special handling, which is why the
/// repository returns null rather than an object full of zeroes.
class WarehouseProduct extends Equatable {
  const WarehouseProduct({
    required this.warehouseId,
    required this.productId,
    this.defaultLocationId,
    this.defaultLocationCode,
    this.defaultBinId,
    this.minStock,
    this.maxStock,
    this.reorderPoint,
    this.pickPriority = 100,
    this.putawayRule = 'MANUAL',
    this.preferredSupplierId,
    this.preferredSupplierName,
    this.leadTimeDays,
    this.note,
    this.isActive = true,
    this.onHand = 0,
    this.available = 0,
  });

  final int warehouseId;
  final int productId;

  /// The put-away target, named in the location tree (0062) rather than in
  /// `bins`, so it can be a rack or a zone and not only a leaf bin.
  final int? defaultLocationId;
  final String? defaultLocationCode;

  /// The bin behind that location, when it is one. Null for a rack or a zone —
  /// which is what the put-away RPCs, still keyed by bin, have to check.
  final int? defaultBinId;

  final int? minStock;
  final int? maxStock;
  final int? reorderPoint;
  final int pickPriority;
  final String putawayRule;
  final int? preferredSupplierId;
  final String? preferredSupplierName;
  final int? leadTimeDays;
  final String? note;
  final bool isActive;

  /// Live numbers, so a reorder point is read next to what is actually there.
  final int onHand;
  final int available;

  /// Below the line and due a reorder. The comparison is against `available`,
  /// not `onHand` — quarantined stock cannot cover an order (§5).
  bool get needsReorder => reorderPoint != null && available < reorderPoint!;

  factory WarehouseProduct.fromJson(Map<String, dynamic> json) =>
      WarehouseProduct(
        warehouseId: _asInt(json['warehouse_id']),
        productId: _asInt(json['product_id']),
        defaultLocationId: _asIntOrNull(json['default_location_id']),
        defaultLocationCode: _asText(json['default_location_code']),
        defaultBinId: _asIntOrNull(json['default_bin_id']),
        minStock: _asIntOrNull(json['min_stock']),
        maxStock: _asIntOrNull(json['max_stock']),
        reorderPoint: _asIntOrNull(json['reorder_point']),
        pickPriority: _asInt(json['pick_priority'] ?? 100),
        putawayRule: (json['putaway_rule'] ?? 'MANUAL').toString(),
        preferredSupplierId: _asIntOrNull(json['preferred_supplier_id']),
        preferredSupplierName: _asText(json['preferred_supplier_name']),
        leadTimeDays: _asIntOrNull(json['lead_time_days']),
        note: _asText(json['note']),
        isActive: json['is_active'] != false,
        onHand: _asInt(json['on_hand'] ?? 0),
        available: _asInt(json['available'] ?? 0),
      );

  @override
  List<Object?> get props => [
        warehouseId,
        productId,
        defaultLocationId,
        minStock,
        maxStock,
        reorderPoint,
        pickPriority,
        putawayRule,
        preferredSupplierId,
        leadTimeDays,
        isActive,
      ];
}

/// One line of `replenishment_suggestions` (0063, §31): a product that has
/// dropped below its reorder point in one warehouse, and how much to order.
///
/// Computed on every read rather than stored, so it cannot go stale — and
/// measured against `available`, which is what makes "100 on hand, 90 blocked"
/// correctly appear here.
class ReplenishmentSuggestion extends Equatable {
  const ReplenishmentSuggestion({
    required this.warehouseId,
    required this.productId,
    required this.productName,
    required this.shortfall,
    required this.suggestedQuantity,
    this.warehouseName,
    this.janCode,
    this.sku,
    this.reorderPoint,
    this.minStock,
    this.maxStock,
    this.onHand = 0,
    this.available = 0,
    this.preferredSupplierId,
    this.preferredSupplierName,
    this.leadTimeDays,
    this.baseUom,
  });

  final int warehouseId;
  final int productId;
  final String productName;

  /// How far under the reorder point this product is.
  final int shortfall;

  /// How much to order: up to `max_stock` when one is set, because ordering
  /// exactly to the reorder point puts the product straight back on this list.
  final int suggestedQuantity;

  final String? warehouseName;
  final String? janCode;
  final String? sku;
  final int? reorderPoint;
  final int? minStock;
  final int? maxStock;
  final int onHand;
  final int available;
  final int? preferredSupplierId;
  final String? preferredSupplierName;
  final int? leadTimeDays;
  final String? baseUom;

  /// On hand but not usable — the gap that explains why a product with stock is
  /// nevertheless on this list.
  int get blocked => onHand - available;

  factory ReplenishmentSuggestion.fromJson(Map<String, dynamic> json) =>
      ReplenishmentSuggestion(
        warehouseId: _asInt(json['warehouse_id']),
        productId: _asInt(json['product_id']),
        productName: (json['product_name'] ?? '').toString(),
        shortfall: _asInt(json['shortfall']),
        suggestedQuantity: _asInt(json['suggested_quantity']),
        warehouseName: _asText(json['warehouse_name']),
        janCode: _asText(json['jan_code']),
        sku: _asText(json['sku']),
        reorderPoint: _asIntOrNull(json['reorder_point']),
        minStock: _asIntOrNull(json['min_stock']),
        maxStock: _asIntOrNull(json['max_stock']),
        onHand: _asInt(json['on_hand'] ?? 0),
        available: _asInt(json['available'] ?? 0),
        preferredSupplierId: _asIntOrNull(json['preferred_supplier_id']),
        preferredSupplierName: _asText(json['preferred_supplier_name']),
        leadTimeDays: _asIntOrNull(json['lead_time_days']),
        baseUom: _asText(json['base_uom']),
      );

  @override
  List<Object?> get props => [
        warehouseId,
        productId,
        shortfall,
        suggestedQuantity,
        onHand,
        available,
        preferredSupplierId,
      ];
}
