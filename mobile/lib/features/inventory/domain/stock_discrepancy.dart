import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

int? _asIntOrNull(dynamic v) => v == null
    ? null
    : (v is int ? v : (v is num ? v.toInt() : int.tryParse('$v')));

/// One place the ledger's own safety property has come apart
/// (`stock_reconciliation`, 0061): `stock_levels.on_hand`, the running total
/// every movement is meant to keep in step, disagrees with what
/// `stock_units` actually sums to for the same product and warehouse. An
/// empty list from the RPC is the invariant holding; every row here is either
/// a movement that could not be attributed to a product (an unlinked JAN) or
/// a writer that went around the trigger that is supposed to make this
/// impossible.
class StockDiscrepancy extends Equatable {
  const StockDiscrepancy({
    required this.warehouseId,
    required this.janCode,
    required this.stockLevelsOnHand,
    required this.stockUnitsOnHand,
    required this.reason,
    this.productId,
  });

  final int warehouseId;
  final String janCode;

  /// Null only when [reason] is `unlinked jan_code` — a movement recorded
  /// against a barcode that never resolved to a product.
  final int? productId;

  /// The ledger's own running total.
  final int stockLevelsOnHand;

  /// What the stock units actually sum to.
  final int stockUnitsOnHand;

  /// `unlinked jan_code` or `quantity drift`, straight from the RPC — the
  /// database already knows which of the two this is.
  final String reason;

  /// Positive means the ledger claims more than the units back up; negative
  /// means the units hold more than the ledger admits to.
  int get drift => stockLevelsOnHand - stockUnitsOnHand;

  bool get isUnlinked => productId == null;

  factory StockDiscrepancy.fromJson(Map<String, dynamic> json) =>
      StockDiscrepancy(
        warehouseId: _asInt(json['warehouse_id']),
        janCode: (json['jan_code'] ?? '').toString(),
        productId: _asIntOrNull(json['product_id']),
        stockLevelsOnHand: _asInt(json['stock_levels_on_hand']),
        stockUnitsOnHand: _asInt(json['stock_units_on_hand']),
        reason: (json['reason'] ?? '').toString(),
      );

  @override
  List<Object?> get props => [
        warehouseId,
        janCode,
        productId,
        stockLevelsOnHand,
        stockUnitsOnHand,
        reason,
      ];
}
