import 'package:equatable/equatable.dart';

import 'delivery_plan_line.dart';
import 'delivery_plan_status.dart';

/// A supplier's expected delivery (納品予定), imported from their Excel on the
/// back office and reconciled on a handheld when the goods physically arrive.
///
/// The header mirrors the printed 納品書: supplier, delivery/voucher number,
/// customer code, date and the tax registration number.
class DeliveryPlan extends Equatable {
  const DeliveryPlan({
    required this.id,
    required this.deliveryNumber,
    this.supplierName,
    this.supplierCode,
    this.customerCode,
    this.deliveryDate,
    this.registrationNumber,
    this.referenceNo,
    this.orderDate,
    this.needsReview = false,
    this.status = DeliveryPlanStatus.open,
    this.lines = const [],
    int? lineCount,
  }) : _lineCount = lineCount;

  final int id;

  /// Voucher / delivery-note number (伝票番号), e.g. "0901".
  final String deliveryNumber;

  final String? supplierName;
  final String? supplierCode;

  /// Customer code printed on the note (お客様コード).
  final String? customerCode;

  /// Delivery date as printed (納品日), kept as a display string.
  final String? deliveryDate;

  /// Japanese invoice registration number (登録番号), e.g. "T3122001027817".
  final String? registrationNumber;

  /// Per-company reference number (整理番号) assigned at import, e.g. "ABC-00001".
  final String? referenceNo;

  /// Order date (注文日) carried for traceability, as a display string.
  final String? orderDate;

  /// The company could not be read at import, so this plan is in the UNKNOWN
  /// reference series and wants a manual supplier assignment.
  final bool needsReview;

  final DeliveryPlanStatus status;

  final List<DeliveryPlanLine> lines;

  final int? _lineCount;

  /// Number of expected lines. Falls back to the loaded [lines] length so a
  /// list payload without an explicit count still renders sensibly.
  int get lineCount => _lineCount ?? lines.length;

  /// Total planned units across all lines.
  int get plannedTotal =>
      lines.fold(0, (sum, line) => sum + line.plannedQuantity);

  factory DeliveryPlan.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'] as List<dynamic>? ?? const [];
    return DeliveryPlan(
      id: _asInt(json['id']) ?? 0,
      deliveryNumber:
          (json['delivery_number'] ?? json['voucher_number'] ?? '').toString(),
      supplierName: json['supplier_name'] as String?,
      supplierCode: json['supplier_code']?.toString(),
      customerCode: json['customer_code']?.toString(),
      deliveryDate: json['delivery_date']?.toString(),
      registrationNumber: json['registration_number'] as String?,
      referenceNo: json['reference_no'] as String?,
      orderDate: json['order_date']?.toString(),
      needsReview: json['needs_review'] == true,
      status: DeliveryPlanStatus.fromWire(json['status'] as String?),
      lines: rawLines
          .map((e) => DeliveryPlanLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      lineCount: _asInt(json['line_count']),
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  @override
  List<Object?> get props => [id, deliveryNumber, status, lines];
}
