import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

/// One parcel awaiting put-away in a warehouse (§14, 0069).
///
/// A *parcel*, not a JAN: since 0069 the queue reads the stock units that have
/// no bin yet, so it can say "the forty on lot QC-L1 that are still held for
/// inspection" rather than only "forty of this JAN". That matters because the
/// forty held for QC and the forty that passed have different destinations.
///
/// Still derived, and now more strictly so: there is no stored quantity at all,
/// derived or otherwise. The queue is a filter over the stock itself, which is
/// what §14 asks for — 「queueの数量を独立した在庫として持たない」.
class PutawayTask extends Equatable {
  const PutawayTask({
    required this.janCode,
    required this.pendingQuantity,
    this.productId,
    this.productName = '',
    this.warehouseOnHand = 0,
    this.lotId,
    this.lotCode,
    this.expiry,
    this.serialId,
    this.serialNumber,
    this.statusCode = 'OK',
    this.statusName,
    this.countsAvailable = true,
    this.suggestions = const [],
  });

  final String janCode;
  final int? productId;
  final String productName;

  /// Still to be put away — the number the operator is working through.
  final int pendingQuantity;

  /// The whole warehouse balance for this product, for context.
  final int warehouseOnHand;

  final int? lotId;
  final String? lotCode;
  final DateTime? expiry;
  final int? serialId;
  final String? serialNumber;

  /// Which stock status this parcel is in. A parcel that is not available cannot
  /// go into a pickable bin at all (the server refuses it), so the screen has to
  /// show the status rather than treat every parcel the same.
  final String statusCode;
  final String? statusName;
  final bool countsAvailable;

  /// Where to put it, best first, each with the reason it was suggested (§14).
  final List<PutawaySuggestion> suggestions;

  String get title => productName.isNotEmpty ? productName : janCode;

  /// Held, failed or otherwise unshippable. The server will only accept a bin
  /// that may hold such stock, so the screen says so before the operator walks.
  bool get isHeld => !countsAvailable;

  PutawaySuggestion? get bestSuggestion =>
      suggestions.isEmpty ? null : suggestions.first;

  /// A parcel with nowhere to go. Not a loading failure — a real floor problem,
  /// usually a warehouse with no bin of the right kind for held stock.
  bool get hasNowhereToGo => suggestions.isEmpty;

  factory PutawayTask.fromJson(Map<String, dynamic> json) => PutawayTask(
        janCode: (json['jan_code'] ?? '').toString(),
        productId: json['product_id'] == null ? null : _asInt(json['product_id']),
        productName: json['product_name'] as String? ?? '',
        pendingQuantity: _asInt(json['pending_quantity']),
        warehouseOnHand: _asInt(json['warehouse_on_hand']),
        lotId: json['lot_id'] == null ? null : _asInt(json['lot_id']),
        lotCode: json['lot_code'] as String?,
        expiry: DateTime.tryParse('${json['expiry']}'),
        serialId: json['serial_id'] == null ? null : _asInt(json['serial_id']),
        serialNumber: json['serial_number'] as String?,
        statusCode: (json['status_code'] ?? 'OK').toString(),
        statusName: json['status_name'] as String?,
        countsAvailable: json['counts_available'] != false,
        suggestions: (json['suggestions'] as List?)
                ?.whereType<Map>()
                .map((e) => PutawaySuggestion.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props => [
        janCode,
        pendingQuantity,
        warehouseOnHand,
        lotId,
        serialId,
        statusCode,
        suggestions,
      ];
}

/// Where §14 says this parcel should go, and why.
///
/// The reason is the whole point. A suggestion an operator cannot see the logic
/// of is one they tap past, so the server sends the reason it used
/// (`同一商品あり / 定位置ゾーン / 空き12`) rather than only a score.
class PutawaySuggestion extends Equatable {
  const PutawaySuggestion({
    required this.binId,
    required this.binCode,
    this.binType = '',
    this.zoneId,
    this.onHand = 0,
    this.sameLot = false,
    this.capacity,
    this.freeCapacity,
    this.score = 0,
    this.reason,
  });

  final int binId;
  final String binCode;
  final String binType;
  final int? zoneId;

  /// What the bin already holds of this product — the first criterion §14 lists.
  final int onHand;
  final bool sameLot;

  /// Null when nobody has recorded a capacity for this bin. Distinct from zero,
  /// and the reason capacity is a preference rather than a hard rule: a
  /// suggestion engine that refuses to suggest anything until every shelf has
  /// been measured is one nobody switches on.
  final int? capacity;
  final int? freeCapacity;

  final int score;
  final String? reason;

  bool get hasCapacityRecorded => capacity != null;

  factory PutawaySuggestion.fromJson(Map<String, dynamic> json) =>
      PutawaySuggestion(
        binId: _asInt(json['bin_id']),
        binCode: (json['bin_code'] ?? '').toString(),
        binType: (json['bin_type'] ?? '').toString(),
        zoneId: json['zone_id'] == null ? null : _asInt(json['zone_id']),
        onHand: _asInt(json['on_hand']),
        sameLot: json['same_lot'] == true,
        capacity: json['capacity'] == null ? null : _asInt(json['capacity']),
        freeCapacity:
            json['free_capacity'] == null ? null : _asInt(json['free_capacity']),
        score: _asInt(json['score']),
        reason: (json['reason'] as String?)?.trim().isEmpty ?? true
            ? null
            : (json['reason'] as String).trim(),
      );

  @override
  List<Object?> get props => [binId, binCode, binType, onHand, sameLot, score];
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
    this.moved = 0,
    this.productId,
  });

  final String janCode;
  final int quantity;
  final String binCode;

  /// The bin's balance for this JAN after the put-away.
  final int binOnHand;

  /// How much of this JAN still awaits put-away.
  final int pendingAfter;

  /// How many units the parcel move actually relocated (0069). Normally equal to
  /// [quantity]; a smaller number means fewer matching parcels were unbinned than
  /// the bin-level total suggested, which is worth surfacing rather than hiding.
  final int moved;
  final int? productId;

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
        moved: _asInt(json['moved']),
        productId:
            json['product_id'] == null ? null : _asInt(json['product_id']),
      );

  @override
  List<Object?> get props => [janCode, quantity, binCode, pendingAfter, replayed];
}
