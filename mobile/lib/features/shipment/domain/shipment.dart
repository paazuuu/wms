import 'package:equatable/equatable.dart';

import 'carton.dart';
import 'shipment_line.dart';
import 'shipment_status.dart';

/// A shipment (出庫): a list imported from a customer's Excel/PDF, subdivided
/// into cartons for packing, then confirmed to deduct stock.
class Shipment extends Equatable {
  const Shipment({
    required this.id,
    required this.shipmentNumber,
    this.customerName,
    this.customerCode,
    this.registrationNumber,
    this.referenceNo,
    this.docNumber,
    this.orderDate,
    this.shipDate,
    this.needsReview = false,
    this.status = ShipmentStatus.open,
    this.lines = const [],
    this.cartons = const [],
    int? lineCount,
    int? cartonCount,
  })  : _lineCount = lineCount,
        _cartonCount = cartonCount;

  final int id;
  final String shipmentNumber;
  final String? customerName;
  final String? customerCode;
  final String? registrationNumber;
  final String? referenceNo;
  final String? docNumber;
  final String? orderDate;
  final String? shipDate;
  final bool needsReview;
  final ShipmentStatus status;
  final List<ShipmentLine> lines;
  final List<Carton> cartons;
  final int? _lineCount;
  final int? _cartonCount;

  int get lineCount => _lineCount ?? lines.length;
  int get cartonCount => _cartonCount ?? cartons.length;

  int get totalUnits => lines.fold(0, (s, l) => s + l.quantity);

  /// Units already assigned to a carton, keyed by JAN.
  Map<String, int> get packedByJan {
    final m = <String, int>{};
    for (final c in cartons) {
      for (final it in c.items) {
        m[it.janCode] = (m[it.janCode] ?? 0) + it.quantity;
      }
    }
    return m;
  }

  factory Shipment.fromJson(Map<String, dynamic> json) {
    int? asInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v');
    }

    final rawLines = json['lines'] as List<dynamic>? ?? const [];
    final rawCartons = json['cartons'] as List<dynamic>? ?? const [];
    final cartons = rawCartons
        .map((e) => Carton.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.cartonNo.compareTo(b.cartonNo));
    return Shipment(
      id: asInt(json['id']) ?? 0,
      shipmentNumber: (json['shipment_number'] ?? '').toString(),
      customerName: json['customer_name'] as String?,
      customerCode: json['customer_code']?.toString(),
      registrationNumber: json['registration_number'] as String?,
      referenceNo: json['reference_no'] as String?,
      docNumber: json['doc_number']?.toString(),
      orderDate: json['order_date']?.toString(),
      shipDate: json['ship_date']?.toString(),
      needsReview: json['needs_review'] == true,
      status: ShipmentStatus.fromWire(json['status'] as String?),
      lines: (rawLines..sort((a, b) => (asInt(a['id']) ?? 0).compareTo(asInt(b['id']) ?? 0)))
          .map((e) => ShipmentLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      cartons: cartons,
      lineCount: asInt(json['line_count']),
      cartonCount: asInt(json['carton_count']),
    );
  }

  @override
  List<Object?> get props => [id, shipmentNumber, status, lines, cartons];
}
