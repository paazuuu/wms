import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

/// One product sitting in a bin (`bin_stock_overview`, 0016) — what is
/// actually there, not what the location's own on-hand rollup says in total.
class BinStockLine extends Equatable {
  const BinStockLine({
    required this.janCode,
    required this.productName,
    required this.onHand,
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

/// One bin and what is in it, right now.
class BinStock extends Equatable {
  const BinStock({
    required this.binId,
    required this.binCode,
    this.binType,
    this.lines = const [],
  });

  final int binId;
  final String binCode;
  final String? binType;
  final List<BinStockLine> lines;

  bool get isEmpty => lines.isEmpty;
  int get totalUnits => lines.fold(0, (s, l) => s + l.onHand);

  factory BinStock.fromJson(Map<String, dynamic> json) => BinStock(
        binId: _asInt(json['bin_id']),
        binCode: (json['bin_code'] ?? '').toString(),
        binType: json['bin_type'] as String?,
        lines: (json['lines'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => BinStockLine.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );

  @override
  List<Object?> get props => [binId, binCode, binType, lines];
}
