import 'package:equatable/equatable.dart';

/// Total on-hand quantity for one JAN, accumulated across all completed
/// reconciliations (the "総在庫" column).
class StockItem extends Equatable {
  const StockItem({
    required this.janCode,
    required this.onHand,
    this.productName = '',
  });

  final String janCode;
  final int onHand;
  final String productName;

  factory StockItem.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) =>
        v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
    return StockItem(
      janCode: (json['jan_code'] ?? '').toString(),
      onHand: asInt(json['on_hand']),
      productName: json['product_name'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [janCode, onHand, productName];
}
