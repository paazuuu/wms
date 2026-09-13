import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

/// One JAN awaiting put-away in a warehouse (UI spec §13, 0038).
///
/// Derived, not stored: [pendingQuantity] is the warehouse balance minus what
/// is already assigned to bins, so anything that raises warehouse stock
/// (receiving, an adjustment, a transfer-in) shows up here automatically.
class PutawayTask extends Equatable {
  const PutawayTask({
    required this.janCode,
    required this.pendingQuantity,
    this.productName = '',
    this.warehouseOnHand = 0,
    this.binnedQuantity = 0,
    this.suggestedBinId,
    this.suggestedBinCode,
  });

  final String janCode;
  final String productName;

  /// Still to be put away — the number the operator is working through.
  final int pendingQuantity;

  /// The whole warehouse balance for this JAN, for context.
  final int warehouseOnHand;

  /// How much of that balance already sits in a bin.
  final int binnedQuantity;

  /// Where this JAN already lives (most-stocked bin), or the first pickable
  /// bin for a first-time item. Suggestion only — the operator scans the bin
  /// they actually used.
  final int? suggestedBinId;
  final String? suggestedBinCode;

  String get title => productName.isNotEmpty ? productName : janCode;

  factory PutawayTask.fromJson(Map<String, dynamic> json) => PutawayTask(
        janCode: (json['jan_code'] ?? '').toString(),
        productName: json['product_name'] as String? ?? '',
        pendingQuantity: _asInt(json['pending_quantity']),
        warehouseOnHand: _asInt(json['warehouse_on_hand']),
        binnedQuantity: _asInt(json['binned_quantity']),
        suggestedBinId: json['suggested_bin_id'] == null
            ? null
            : _asInt(json['suggested_bin_id']),
        suggestedBinCode: json['suggested_bin_code'] as String?,
      );

  @override
  List<Object?> get props => [janCode, pendingQuantity, warehouseOnHand, binnedQuantity];
}

/// One line of what a bin currently holds.
class BinStockLine extends Equatable {
  const BinStockLine({
    required this.janCode,
    required this.onHand,
    this.productName = '',
  });

  final String janCode;
  final String productName;
  final int onHand;

  factory BinStockLine.fromJson(Map<String, dynamic> json) => BinStockLine(
        janCode: (json['jan_code'] ?? '').toString(),
        productName: json['product_name'] as String? ?? '',
        onHand: _asInt(json['on_hand']),
      );

  @override
  List<Object?> get props => [janCode, onHand];
}

/// A scanned location: the bin plus what it holds right now (§13's
/// "ロケーションをスキャン → 現在: …" step).
class BinLocation extends Equatable {
  const BinLocation({
    required this.binId,
    required this.binCode,
    this.binType = '',
    this.isActive = true,
    this.lines = const [],
  });

  final int binId;
  final String binCode;
  final String binType;
  final bool isActive;
  final List<BinStockLine> lines;

  /// What this bin already holds of [janCode], for the "現在" readout.
  int onHandOf(String janCode) => lines
      .where((l) => l.janCode == janCode)
      .fold(0, (sum, l) => sum + l.onHand);

  factory BinLocation.fromJson(Map<String, dynamic> json) => BinLocation(
        binId: _asInt(json['bin_id']),
        binCode: (json['bin_code'] ?? '').toString(),
        binType: (json['bin_type'] ?? '').toString(),
        isActive: json['is_active'] != false,
        lines: (json['lines'] as List?)
                ?.whereType<Map>()
                .map((e) => BinStockLine.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props => [binId, binCode, isActive, lines];
}

/// What `confirm_putaway` reports back.
class PutawayResult extends Equatable {
  const PutawayResult({
    required this.janCode,
    required this.quantity,
    this.binCode = '',
    this.binOnHand = 0,
    this.pendingAfter = 0,
    this.replayed = false,
  });

  final String janCode;
  final int quantity;
  final String binCode;

  /// The bin's balance for this JAN after the put-away.
  final int binOnHand;

  /// How much of this JAN still awaits put-away.
  final int pendingAfter;

  /// True when the server recognised the idempotency key and replayed the
  /// original result instead of posting again (§49).
  final bool replayed;

  factory PutawayResult.fromJson(Map<String, dynamic> json) => PutawayResult(
        janCode: (json['jan_code'] ?? '').toString(),
        quantity: _asInt(json['quantity']),
        binCode: (json['bin_code'] ?? '').toString(),
        binOnHand: _asInt(json['bin_on_hand']),
        pendingAfter: _asInt(json['pending_after']),
        replayed: json['replayed'] == true,
      );

  @override
  List<Object?> get props => [janCode, quantity, binCode, pendingAfter, replayed];
}
