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

/// One item packed into a carton. `lotCode`/`expiryDate`/`serialNumber` are
/// only populated when the read joins them — `carton_detail`/`shipment_packing`
/// do (0076), the `shipments` edge function's plain `select *` does not, so a
/// [Carton] read through that path carries [lotId]/[serialId] with no text to
/// show for them.
class CartonItem extends Equatable {
  const CartonItem({
    required this.janCode,
    required this.quantity,
    this.id,
    this.shipmentLineId,
    this.productName = '',
    this.spec,
    this.lotId,
    this.lotCode,
    this.expiryDate,
    this.serialId,
    this.serialNumber,
    this.stockUnitId,
    this.note,
  });

  final int? id;
  final int? shipmentLineId;
  final String janCode;
  final String productName;
  final String? spec;
  final int quantity;
  final int? lotId;
  final String? lotCode;
  final String? expiryDate;
  final int? serialId;
  final String? serialNumber;
  final int? stockUnitId;
  final String? note;

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
      lotId: asInt(json['lot_id']),
      lotCode: json['lot_code'] as String?,
      expiryDate: json['expiry_date'] as String?,
      serialId: asInt(json['serial_id']),
      serialNumber: json['serial_number'] as String?,
      stockUnitId: asInt(json['stock_unit_id']),
      note: json['note'] as String?,
    );
  }

  @override
  List<Object?> get props =>
      [id, janCode, quantity, shipmentLineId, lotId, serialId];
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

/// One product's packing ceiling and progress (0076): how much this shipment
/// may put in boxes — what was picked, or the order when picking never ran —
/// and how much of that is already packed, in any carton. [unpacked] is the
/// number a new parcel's quantity is bounded by, wherever it gets recorded.
class PackableLine extends Equatable {
  const PackableLine({
    required this.productId,
    required this.janCode,
    required this.productName,
    required this.packable,
    required this.packed,
    required this.unpacked,
  });

  final int productId;
  final String janCode;
  final String productName;
  final int packable;
  final int packed;
  final int unpacked;

  factory PackableLine.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) =>
        v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
    return PackableLine(
      productId: asInt(json['product_id']),
      janCode: (json['jan_code'] ?? '').toString(),
      productName: json['product_name'] as String? ?? '',
      packable: asInt(json['packable']),
      packed: asInt(json['packed']),
      unpacked: asInt(json['unpacked']),
    );
  }

  @override
  List<Object?> get props => [productId, janCode, packable, packed, unpacked];
}

/// What `shipment_packing` reads for one shipment (0076): each product's
/// packing ceiling next to every carton's own detail, both joined properly —
/// unlike the `shipments` edge function's cartons, these carry lot/serial text.
class ShipmentPacking extends Equatable {
  const ShipmentPacking({
    required this.shipmentPlanId,
    this.lines = const [],
    this.cartons = const [],
  });

  final int shipmentPlanId;
  final List<PackableLine> lines;
  final List<Carton> cartons;

  factory ShipmentPacking.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) =>
        v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
    return ShipmentPacking(
      shipmentPlanId: asInt(json['shipment_plan_id']),
      lines: (json['lines'] as List<dynamic>? ?? const [])
          .map((e) => PackableLine.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      cartons: (json['cartons'] as List<dynamic>? ?? const [])
          .map((e) => Carton.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [shipmentPlanId, lines, cartons];
}
