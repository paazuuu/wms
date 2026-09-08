import 'package:equatable/equatable.dart';

/// One recorded receipt (照合) against a delivery plan — a single physical
/// delivery that was counted in. Shown in the receipt history so a mistaken or
/// duplicate receipt can be cancelled (訂正／取消).
class Receipt extends Equatable {
  const Receipt({
    required this.id,
    required this.totalUnits,
    required this.lineCount,
    this.referenceNo,
    this.noteReference,
    this.status = 'received',
    this.createdAt,
  });

  final int id;

  /// Units counted in on this receipt.
  final int totalUnits;

  /// Number of JAN lines counted on this receipt.
  final int lineCount;

  /// Per-company reference (整理番号) assigned to this receipt.
  final String? referenceNo;

  /// Free-form note reference the operator typed, if any.
  final String? noteReference;

  /// 'received' / 'partial' / 'completed' / 'cancelled'.
  final String status;

  final DateTime? createdAt;

  bool get isCancelled => status == 'cancelled';

  factory Receipt.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) =>
        v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
    return Receipt(
      id: asInt(json['id']),
      totalUnits: asInt(json['total_units']),
      lineCount: asInt(json['line_count']),
      referenceNo: json['reference_no'] as String?,
      noteReference: json['note_reference'] as String?,
      status: json['status'] as String? ?? 'received',
      createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
    );
  }

  @override
  List<Object?> get props => [id, totalUnits, status];
}
