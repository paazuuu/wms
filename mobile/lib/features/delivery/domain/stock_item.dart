import 'package:equatable/equatable.dart';

/// Total on-hand quantity for one JAN, accumulated across all completed
/// reconciliations (the "総在庫" column).
///
/// [productId] is the bridge 0058 added: `stock_levels` now carries a nullable
/// `product_id` filled from the JAN, so a row can be looked up in the new model
/// (its lots, its reservations, its per-status split) — or, when it is null, can
/// say honestly that this code is not in the product master yet. Null is not an
/// error: stock can be received against a bare JAN and the product registered
/// later, at which point the link fills itself in.
class StockItem extends Equatable {
  const StockItem({
    required this.janCode,
    required this.onHand,
    this.productName = '',
    this.productId,
  });

  final String janCode;
  final int onHand;
  final String productName;
  final int? productId;

  /// Whether this row can be asked the questions the new model answers.
  bool get isLinked => productId != null;

  factory StockItem.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) =>
        v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
    final rawProductId = json['product_id'];
    return StockItem(
      janCode: (json['jan_code'] ?? '').toString(),
      onHand: asInt(json['on_hand']),
      productName: json['product_name'] as String? ?? '',
      productId: rawProductId == null ? null : asInt(rawProductId),
    );
  }

  @override
  List<Object?> get props => [janCode, onHand, productName, productId];
}
