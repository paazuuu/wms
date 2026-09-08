import 'package:equatable/equatable.dart';

/// One expected line on a delivery plan (納品予定明細), imported from the
/// supplier's Excel on the back office. Matched against what physically arrives
/// during reconciliation, keyed by [janCode].
class DeliveryPlanLine extends Equatable {
  const DeliveryPlanLine({
    required this.id,
    required this.janCode,
    required this.plannedQuantity,
    this.receivedQuantity = 0,
    this.productCode,
    this.productName = '',
    this.spec,
    this.unitPrice,
    this.amount,
    this.taxRate,
  });

  final int id;

  /// JAN / EAN-13 barcode — the reconciliation key.
  final String janCode;

  /// Expected quantity from the supplier's Excel.
  final int plannedQuantity;

  /// Quantity received so far across every (split) delivery. Persisted on the
  /// plan line so the outstanding amount survives between sessions.
  final int receivedQuantity;

  /// Still outstanding (未納): planned minus what has already been received,
  /// never negative.
  int get outstandingQuantity =>
      (plannedQuantity - receivedQuantity).clamp(0, plannedQuantity);

  /// Supplier's own product number (商品番号), if provided.
  final String? productCode;

  /// Human-readable product name (品名).
  final String productName;

  /// Free-form spec column (規格), e.g. a colour or size.
  final String? spec;

  /// Unit price (単価) in yen, if the Excel carries it.
  final int? unitPrice;

  /// Line amount (金額) in yen, if the Excel carries it.
  final int? amount;

  /// Tax rate percent (税率), e.g. 10.0.
  final double? taxRate;

  factory DeliveryPlanLine.fromJson(Map<String, dynamic> json) {
    return DeliveryPlanLine(
      id: _asInt(json['id']) ?? 0,
      janCode: (json['jan_code'] ?? json['jan'] ?? '').toString(),
      plannedQuantity: _asInt(json['planned_quantity']) ?? 0,
      receivedQuantity: _asInt(json['received_quantity']) ?? 0,
      productCode: json['product_code']?.toString(),
      productName: json['product_name'] as String? ?? '',
      spec: json['spec'] as String?,
      unitPrice: _asInt(json['unit_price']),
      amount: _asInt(json['amount']),
      taxRate: _asDouble(json['tax_rate']),
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  @override
  List<Object?> get props => [id, janCode, plannedQuantity];
}
