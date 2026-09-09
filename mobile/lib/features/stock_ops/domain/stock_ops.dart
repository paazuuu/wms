import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
int? _asIntOrNull(dynamic v) =>
    v == null ? null : (v is int ? v : (v is num ? v.toInt() : int.tryParse('$v')));

/// Why a manual correction was made (spec §17). The movement carries the
/// arithmetic; the reason is what a later stock-take review actually reads.
enum AdjustReason {
  damage('DAMAGE'),
  loss('LOSS'),
  found('FOUND'),
  correction('CORRECTION'),
  returned('RETURN'),
  other('OTHER');

  const AdjustReason(this.wire);
  final String wire;

  static AdjustReason parse(String? v) => switch (v) {
        'DAMAGE' => AdjustReason.damage,
        'LOSS' => AdjustReason.loss,
        'FOUND' => AdjustReason.found,
        'CORRECTION' => AdjustReason.correction,
        'RETURN' => AdjustReason.returned,
        _ => AdjustReason.other,
      };
}

class StockAdjustment extends Equatable {
  const StockAdjustment({
    required this.id,
    required this.janCode,
    required this.quantityDelta,
    required this.reason,
    this.productName = '',
    this.note,
    this.createdAt,
  });

  final int id;
  final String janCode;
  final String productName;

  /// Signed. Negative removes stock, positive adds it.
  final int quantityDelta;
  final AdjustReason reason;
  final String? note;
  final DateTime? createdAt;

  factory StockAdjustment.fromJson(Map<String, dynamic> json) => StockAdjustment(
        id: _asInt(json['id']),
        janCode: (json['jan_code'] ?? '').toString(),
        productName: json['product_name'] as String? ?? '',
        quantityDelta: _asInt(json['quantity_delta']),
        reason: AdjustReason.parse(json['reason'] as String?),
        note: json['note'] as String?,
        createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
      );

  @override
  List<Object?> get props => [id, janCode, quantityDelta, reason];
}

enum CountStatus {
  counting('COUNTING'),
  completed('COMPLETED'),
  cancelled('CANCELLED');

  const CountStatus(this.wire);
  final String wire;

  static CountStatus parse(String? v) => switch (v) {
        'COMPLETED' => CountStatus.completed,
        'CANCELLED' => CountStatus.cancelled,
        _ => CountStatus.counting,
      };
}

/// One line of a count. While a blind session is open the backend withholds
/// [systemQuantity] and [variance], so both are nullable by design — the
/// counter is not supposed to see what the system thinks.
class StockCountLine extends Equatable {
  const StockCountLine({
    required this.id,
    required this.janCode,
    this.productName = '',
    this.systemQuantity,
    this.countedQuantity,
    this.variance,
    this.countedAt,
  });

  final int id;
  final String janCode;
  final String productName;
  final int? systemQuantity;
  final int? countedQuantity;
  final int? variance;
  final DateTime? countedAt;

  bool get isCounted => countedQuantity != null;

  factory StockCountLine.fromJson(Map<String, dynamic> json) => StockCountLine(
        id: _asInt(json['id']),
        janCode: (json['jan_code'] ?? '').toString(),
        productName: json['product_name'] as String? ?? '',
        systemQuantity: _asIntOrNull(json['system_quantity']),
        countedQuantity: _asIntOrNull(json['counted_quantity']),
        variance: _asIntOrNull(json['variance']),
        countedAt: DateTime.tryParse('${json['counted_at']}')?.toLocal(),
      );

  @override
  List<Object?> get props =>
      [id, janCode, systemQuantity, countedQuantity, variance];
}

class StockCount extends Equatable {
  const StockCount({
    required this.id,
    required this.status,
    this.warehouseId,
    this.warehouseName,
    this.isBlind = true,
    this.hideSystem = false,
    this.note,
    this.createdAt,
    this.completedAt,
    this.lines = const [],
    this.lineCount,
  });

  final int id;
  final CountStatus status;
  final int? warehouseId;
  final String? warehouseName;
  final bool isBlind;

  /// True while the backend is withholding system quantities (blind + open).
  final bool hideSystem;
  final String? note;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final List<StockCountLine> lines;
  final int? lineCount;

  bool get isOpen => status == CountStatus.counting;
  int get totalLines => lines.isNotEmpty ? lines.length : (lineCount ?? 0);
  int get countedLines => lines.where((l) => l.isCounted).length;
  int get uncountedLines => lines.where((l) => !l.isCounted).length;

  /// Only meaningful once the count is completed (variance is masked before).
  int get netVariance =>
      lines.fold(0, (sum, l) => sum + (l.variance ?? 0));

  factory StockCount.fromJson(Map<String, dynamic> json) => StockCount(
        id: _asInt(json['id']),
        status: CountStatus.parse(json['status'] as String?),
        warehouseId: _asIntOrNull(json['warehouse_id']),
        warehouseName: json['warehouse_name'] as String?,
        isBlind: json['is_blind'] != false,
        hideSystem: json['hide_system'] == true,
        note: json['note'] as String?,
        createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
        completedAt: DateTime.tryParse('${json['completed_at']}')?.toLocal(),
        lines: (json['lines'] as List?)
                ?.whereType<Map>()
                .map((e) => StockCountLine.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
        lineCount: _asIntOrNull(json['line_count']),
      );

  @override
  List<Object?> get props => [id, status, hideSystem, lines, lineCount];
}

/// What completing a count actually changed.
class CountSummary extends Equatable {
  const CountSummary({
    required this.adjustedLines,
    required this.netChange,
    required this.uncountedLines,
  });

  final int adjustedLines;
  final int netChange;
  final int uncountedLines;

  factory CountSummary.fromJson(Map<String, dynamic> json) => CountSummary(
        adjustedLines: _asInt(json['adjusted_lines']),
        netChange: _asInt(json['net_change']),
        uncountedLines: _asInt(json['uncounted_lines']),
      );

  @override
  List<Object?> get props => [adjustedLines, netChange, uncountedLines];
}
