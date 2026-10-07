import 'package:equatable/equatable.dart';

String? _s(Object? v) {
  final t = v?.toString().trim();
  return t == null || t.isEmpty ? null : t;
}

int _n(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

/// A company goods often go to, kept so a shipment picks it instead of
/// typing it again (0139).
class ShipDestination extends Equatable {
  const ShipDestination({
    this.id,
    required this.name,
    this.department,
    this.contactName,
    this.postalCode,
    this.address1,
    this.address2,
    this.phone,
    this.email,
    this.countryCode,
    this.note,
    this.useCount = 0,
    this.lastUsedAt,
  });

  /// Null for one not saved yet.
  final int? id;
  final String name;
  final String? department;
  final String? contactName;
  final String? postalCode;
  final String? address1;
  final String? address2;
  final String? phone;
  final String? email;
  final String? countryCode;
  final String? note;
  final int useCount;
  final DateTime? lastUsedAt;

  factory ShipDestination.fromJson(Map<String, dynamic> j) => ShipDestination(
        id: (j['id'] as num?)?.toInt(),
        name: _s(j['name']) ?? '',
        department: _s(j['department']),
        contactName: _s(j['contact_name']),
        postalCode: _s(j['postal_code']),
        address1: _s(j['address1']),
        address2: _s(j['address2']),
        phone: _s(j['phone']),
        email: _s(j['email']),
        countryCode: _s(j['country_code']),
        note: _s(j['note']),
        useCount: _n(j['use_count']),
        lastUsedAt: DateTime.tryParse('${j['last_used_at'] ?? ''}')?.toLocal(),
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        'department': department,
        'contact_name': contactName,
        'postal_code': postalCode,
        'address1': address1,
        'address2': address2,
        'phone': phone,
        'email': email,
        'country_code': countryCode,
        'note': note,
      };

  /// 〒 and the address on one line.
  String get addressLine => [
        if (postalCode != null) '〒$postalCode',
        if (address1 != null) address1!,
        if (address2 != null) address2!,
      ].join(' ');

  @override
  List<Object?> get props =>
      [id, name, department, contactName, postalCode, address1, address2, phone, email, countryCode, note, useCount];
}

/// What one product has in a warehouse, for working out a shipment.
class OutboundStockItem extends Equatable {
  const OutboundStockItem({
    required this.janCode,
    required this.name,
    this.productId,
    this.nameEn,
    this.maker,
    this.sku,
    this.unit,
    this.onHand = 0,
    this.reserved = 0,
    this.inOpen = 0,
    this.free = 0,
  });

  final String janCode;
  final String name;
  final int? productId;
  final String? nameEn;
  final String? maker;
  final String? sku;
  final String? unit;

  /// 全在庫: everything in the warehouse.
  final int onHand;

  /// Promised to orders.
  final int reserved;

  /// Already on shipments that have not left.
  final int inOpen;

  /// 出荷可能: what may still be sent.
  final int free;

  factory OutboundStockItem.fromJson(Map<String, dynamic> j) => OutboundStockItem(
        janCode: _s(j['jan_code']) ?? '',
        name: _s(j['name']) ?? _s(j['jan_code']) ?? '',
        productId: (j['product_id'] as num?)?.toInt(),
        nameEn: _s(j['name_en']),
        maker: _s(j['maker']),
        sku: _s(j['sku']),
        unit: _s(j['unit']),
        onHand: _n(j['on_hand']),
        reserved: _n(j['reserved']),
        inOpen: _n(j['in_open']),
        free: _n(j['free']),
      );

  @override
  List<Object?> get props => [janCode, name, productId, onHand, reserved, inOpen, free];
}

/// What a percentage is taken of.
enum ProposalBase { onHand, free }

/// How a percentage is turned into whole units.
enum ProposalRounding { down, nearest, up }

/// A percentage of each product's stock, in whole units and never more than
/// can be sent: 全在庫 × [percent] (or 出荷可能 × [percent]), rounded as
/// [rounding] says, then capped at 出荷可能. Products at 0 stay at 0.
Map<String, int> proposeByPercent(
  List<OutboundStockItem> items,
  double percent, {
  ProposalBase base = ProposalBase.onHand,
  ProposalRounding rounding = ProposalRounding.down,
}) {
  final p = percent.clamp(0, 100) / 100;
  final out = <String, int>{};
  for (final i in items) {
    final from = base == ProposalBase.onHand ? i.onHand : i.free;
    final raw = from * p;
    // A hair of floating point must not turn 30.000000001 into 31.
    const eps = 1e-9;
    final q = switch (rounding) {
      ProposalRounding.down => (raw + eps).floor(),
      ProposalRounding.nearest => raw.round(),
      ProposalRounding.up => (raw - eps).ceil(),
    };
    out[i.janCode] = q.clamp(0, i.free);
  }
  return out;
}

/// The lines of a shipment's sheet: who it goes to, what goes.
class OutboundSheet extends Equatable {
  const OutboundSheet({
    required this.id,
    required this.shipmentNumber,
    this.status,
    this.shipDate,
    this.note,
    this.warehouseName,
    this.shipTo,
    this.carrier,
    this.trackingNumber,
    this.lines = const [],
  });

  final int id;
  final String shipmentNumber;
  final String? status;
  final String? shipDate;
  final String? note;
  final String? warehouseName;
  final ShipDestination? shipTo;
  final String? carrier;
  final String? trackingNumber;
  final List<OutboundSheetLine> lines;

  int get totalUnits => lines.fold(0, (s, l) => s + l.quantity);

  factory OutboundSheet.fromJson(Map<String, dynamic> j) {
    final to = j['ship_to'];
    return OutboundSheet(
      id: _n(j['id']),
      shipmentNumber: _s(j['shipment_number']) ?? '',
      status: _s(j['status']),
      shipDate: _s(j['ship_date']),
      note: _s(j['note']),
      warehouseName: _s(j['warehouse_name']),
      shipTo: to is Map && _s(to['name']) != null ? ShipDestination.fromJson(to.cast<String, dynamic>()) : null,
      carrier: _s(j['carrier']),
      trackingNumber: _s(j['tracking_number']),
      lines: [
        for (final l in (j['lines'] as List? ?? const []).whereType<Map>())
          OutboundSheetLine.fromJson(l.cast<String, dynamic>()),
      ],
    );
  }

  @override
  List<Object?> get props => [id, shipmentNumber, status, shipDate, shipTo, lines];
}

class OutboundSheetLine extends Equatable {
  const OutboundSheetLine({
    required this.janCode,
    required this.name,
    required this.quantity,
    this.nameEn,
    this.maker,
    this.productCode,
    this.unit,
  });

  final String janCode;
  final String name;
  final int quantity;
  final String? nameEn;
  final String? maker;
  final String? productCode;
  final String? unit;

  factory OutboundSheetLine.fromJson(Map<String, dynamic> j) => OutboundSheetLine(
        janCode: _s(j['jan_code']) ?? '',
        name: _s(j['name']) ?? '',
        quantity: _n(j['quantity']),
        nameEn: _s(j['name_en']),
        maker: _s(j['maker']),
        productCode: _s(j['product_code']),
        unit: _s(j['unit']),
      );

  @override
  List<Object?> get props => [janCode, name, quantity, nameEn, maker, productCode, unit];
}

/// One row of the stock list in Excel.
class StockExportRow extends Equatable {
  const StockExportRow({
    required this.warehouseName,
    required this.janCode,
    required this.name,
    this.warehouseCode,
    this.nameEn,
    this.maker,
    this.sku,
    this.unit,
    this.onHand = 0,
    this.reserved = 0,
    this.updatedAt,
  });

  final String warehouseName;
  final String? warehouseCode;
  final String janCode;
  final String name;
  final String? nameEn;
  final String? maker;
  final String? sku;
  final String? unit;
  final int onHand;
  final int reserved;
  final DateTime? updatedAt;

  factory StockExportRow.fromJson(Map<String, dynamic> j) => StockExportRow(
        warehouseName: _s(j['warehouse_name']) ?? '',
        warehouseCode: _s(j['warehouse_code']),
        janCode: _s(j['jan_code']) ?? '',
        name: _s(j['name']) ?? '',
        nameEn: _s(j['name_en']),
        maker: _s(j['maker']),
        sku: _s(j['sku']),
        unit: _s(j['unit']),
        onHand: _n(j['on_hand']),
        reserved: _n(j['reserved']),
        updatedAt: DateTime.tryParse('${j['updated_at'] ?? ''}')?.toLocal(),
      );

  @override
  List<Object?> get props => [warehouseName, janCode, name, onHand, reserved];
}

/// What creating a shipment gave back.
class OutboundCreated extends Equatable {
  const OutboundCreated({required this.id, required this.shipmentNumber, this.lines = 0, this.units = 0});

  final int id;
  final String shipmentNumber;
  final int lines;
  final int units;

  factory OutboundCreated.fromJson(Map<String, dynamic> j) => OutboundCreated(
        id: _n(j['id']),
        shipmentNumber: _s(j['shipment_number']) ?? '',
        lines: _n(j['lines']),
        units: _n(j['units']),
      );

  @override
  List<Object?> get props => [id, shipmentNumber, lines, units];
}
