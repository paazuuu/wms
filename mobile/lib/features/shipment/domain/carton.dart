import 'package:equatable/equatable.dart';

double? _asDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse('$v');
}

/// A carton's lifecycle (§17, 0076): OPEN while being filled, PACKED once the
/// packer closes it, SHIPPED once the shipment ships — that last step follows
/// the plan automatically, it is not something the client sets directly.
enum CartonStatus {
  open('OPEN'),
  packed('PACKED'),
  shipped('SHIPPED'),
  cancelled('CANCELLED');

  const CartonStatus(this.wire);
  final String wire;

  static CartonStatus parse(String? v) => switch (v) {
        'PACKED' => CartonStatus.packed,
        'SHIPPED' => CartonStatus.shipped,
        'CANCELLED' => CartonStatus.cancelled,
        _ => CartonStatus.open,
      };
}

/// One item packed into a carton.
class CartonItem extends Equatable {
  const CartonItem({
    required this.janCode,
    required this.quantity,
    this.id,
    this.shipmentLineId,
    this.productName = '',
    this.spec,
  });

  final int? id;
  final int? shipmentLineId;
  final String janCode;
  final String productName;
  final String? spec;
  final int quantity;

  Map<String, dynamic> toJson() => {
        if (shipmentLineId != null) 'shipment_line_id': shipmentLineId,
        'jan_code': janCode,
        'product_name': productName,
        if (spec != null) 'spec': spec,
        'quantity': quantity,
      };

  factory CartonItem.fromJson(Map<String, dynamic> json) {
    int? asInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v');
    }

    return CartonItem(
      id: asInt(json['id']),
      shipmentLineId: asInt(json['shipment_line_id']),
      janCode: (json['jan_code'] ?? '').toString(),
      productName: json['product_name'] as String? ?? '',
      spec: json['spec'] as String?,
      quantity: asInt(json['quantity']) ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, janCode, quantity, shipmentLineId];
}

/// One carton (段ボール / 小口) within a shipment, and its contents.
class Carton extends Equatable {
  const Carton({
    required this.id,
    required this.cartonNo,
    this.label,
    this.items = const [],
    this.status = CartonStatus.open,
    this.cartonType,
    this.weightKg,
    this.lengthCm,
    this.widthCm,
    this.heightCm,
    this.trackingNumber,
    this.note,
  });

  final int id;
  final int cartonNo;
  final String? label;
  final List<CartonItem> items;

  /// §17's lifecycle and per-box facts (0076). All optional: a carton the
  /// old edge-function path created has none of these set yet.
  final CartonStatus status;
  final String? cartonType;
  final double? weightKg;
  final double? lengthCm;
  final double? widthCm;
  final double? heightCm;
  final String? trackingNumber;
  final String? note;

  int get totalUnits => items.fold(0, (s, it) => s + it.quantity);

  bool get isOpen => status == CartonStatus.open;
  bool get hasMeasurements =>
      weightKg != null ||
      lengthCm != null ||
      widthCm != null ||
      heightCm != null ||
      trackingNumber != null;

  factory Carton.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) =>
        v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return Carton(
      id: asInt(json['id']),
      cartonNo: asInt(json['carton_no']),
      label: json['label'] as String?,
      items: rawItems
          .map((e) => CartonItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      status: CartonStatus.parse(json['status'] as String?),
      cartonType: json['carton_type'] as String?,
      weightKg: _asDoubleOrNull(json['weight_kg']),
      lengthCm: _asDoubleOrNull(json['length_cm']),
      widthCm: _asDoubleOrNull(json['width_cm']),
      heightCm: _asDoubleOrNull(json['height_cm']),
      trackingNumber: json['tracking_number'] as String?,
      note: json['note'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        cartonNo,
        label,
        items,
        status,
        cartonType,
        weightKg,
        lengthCm,
        widthCm,
        heightCm,
        trackingNumber,
      ];
}
