import 'package:equatable/equatable.dart';

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
  });

  final int id;
  final int cartonNo;
  final String? label;
  final List<CartonItem> items;

  int get totalUnits => items.fold(0, (s, it) => s + it.quantity);

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
    );
  }

  @override
  List<Object?> get props => [id, cartonNo, label, items];
}
