import 'package:equatable/equatable.dart';

import 'pricing.dart';

String? _s(Object? v) {
  final t = v?.toString().trim();
  return t == null || t.isEmpty ? null : t;
}

int _n(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

double? _d(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');

/// One more phone number on a card: whose it is (会社, 携帯 …) and the number.
class DestinationPhone extends Equatable {
  const DestinationPhone({this.label, required this.number});

  final String? label;
  final String number;

  factory DestinationPhone.fromJson(Map<String, dynamic> j) =>
      DestinationPhone(label: _s(j['label']), number: _s(j['number']) ?? '');

  Map<String, dynamic> toJson() => {'label': label, 'number': number};

  @override
  String toString() => label == null ? number : '$label $number';

  @override
  List<Object?> get props => [label, number];
}

/// How goods go to a destination (0190).
const destinationTransports = ['sea', 'air', 'courier', 'truck', 'other'];

/// The trade terms most used, offered first (any other can be typed).
const destinationIncoterms = ['EXW', 'FCA', 'FOB', 'CFR', 'CIF', 'CPT', 'CIP', 'DAP', 'DPU', 'DDP'];

/// A company goods often go to, kept so a shipment picks it instead of
/// typing it again (0139) — with what an export needs (出荷先カード, 0190):
/// the name and address in English, more phone numbers, a tax number, the
/// port, the trade term, how goods go, a Notify Party when it is another
/// company, the forwarder, and the documents needed.
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
    this.nameEn,
    this.addressEn,
    this.phones = const [],
    this.taxIdKind,
    this.taxId,
    this.port,
    this.incoterms,
    this.transport,
    this.notifySame = true,
    this.notifyName,
    this.notifyAddress,
    this.notifyContact,
    this.notifyPhone,
    this.forwarderName,
    this.forwarderContact,
    this.forwarderPhone,
    this.forwarderEmail,
    this.documentsNote,
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

  /// The company and its address in English, for the invoice.
  final String? nameEn;
  final String? addressEn;

  /// More numbers than [phone]: 担当者の携帯, 倉庫 …
  final List<DestinationPhone> phones;

  /// 統一社会信用コード, VAT, EORI …, and the number.
  final String? taxIdKind;
  final String? taxId;

  /// The port or airport goods go to.
  final String? port;

  /// FOB, CIF, DAP …
  final String? incoterms;

  /// One of [destinationTransports], or what was typed.
  final String? transport;

  /// The Notify Party is this company itself; else the notify fields.
  final bool notifySame;
  final String? notifyName;
  final String? notifyAddress;
  final String? notifyContact;
  final String? notifyPhone;

  /// 通関業者 / forwarder and who to reach there.
  final String? forwarderName;
  final String? forwarderContact;
  final String? forwarderPhone;
  final String? forwarderEmail;

  /// The documents the shipment needs (invoice, packing list, …).
  final String? documentsNote;

  /// Anything for an export written down.
  bool get hasExport =>
      nameEn != null ||
      addressEn != null ||
      taxId != null ||
      port != null ||
      incoterms != null ||
      transport != null ||
      !notifySame ||
      forwarderName != null ||
      documentsNote != null;

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
        nameEn: _s(j['name_en']),
        addressEn: _s(j['address_en']),
        phones: [
          for (final p in (j['phones'] as List? ?? const []).whereType<Map>())
            if (_s(p['number']) != null) DestinationPhone.fromJson(p.cast<String, dynamic>()),
        ],
        taxIdKind: _s(j['tax_id_kind']),
        taxId: _s(j['tax_id']),
        port: _s(j['port']),
        incoterms: _s(j['incoterms']),
        transport: _s(j['transport']),
        notifySame: j['notify_same'] != false,
        notifyName: _s(j['notify_name']),
        notifyAddress: _s(j['notify_address']),
        notifyContact: _s(j['notify_contact']),
        notifyPhone: _s(j['notify_phone']),
        forwarderName: _s(j['forwarder_name']),
        forwarderContact: _s(j['forwarder_contact']),
        forwarderPhone: _s(j['forwarder_phone']),
        forwarderEmail: _s(j['forwarder_email']),
        documentsNote: _s(j['documents_note']),
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
        'name_en': nameEn,
        'address_en': addressEn,
        'phones': [for (final p in phones) p.toJson()],
        'tax_id_kind': taxIdKind,
        'tax_id': taxId,
        'port': port,
        'incoterms': incoterms,
        'transport': transport,
        'notify_same': notifySame,
        'notify_name': notifyName,
        'notify_address': notifyAddress,
        'notify_contact': notifyContact,
        'notify_phone': notifyPhone,
        'forwarder_name': forwarderName,
        'forwarder_contact': forwarderContact,
        'forwarder_phone': forwarderPhone,
        'forwarder_email': forwarderEmail,
        'documents_note': documentsNote,
      };

  /// The same card with the id the server gave it.
  ShipDestination withId(int newId) => ShipDestination.fromJson({...toJson(), 'id': newId, 'use_count': useCount});

  /// 〒 and the address on one line.
  String get addressLine => [
        if (postalCode != null) '〒$postalCode',
        if (address1 != null) address1!,
        if (address2 != null) address2!,
      ].join(' ');

  /// Every phone number, the main one first.
  List<String> get allPhones => [if (phone != null) phone!, for (final p in phones) '$p'];

  @override
  List<Object?> get props => [
        id, name, department, contactName, postalCode, address1, address2, phone, email, countryCode, note, useCount,
        nameEn, addressEn, phones, taxIdKind, taxId, port, incoterms, transport, notifySame, notifyName, notifyAddress,
        notifyContact, notifyPhone, forwarderName, forwarderContact, forwarderPhone, forwarderEmail, documentsNote,
      ];
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
    this.costPrice,
    this.listPrice,
    this.sellPrice,
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

  /// 原価・定価・販売価格 (0142), to work a shipment price out from.
  final double? costPrice;
  final double? listPrice;
  final double? sellPrice;

  PriceInputs prices({double? ship}) => PriceInputs(cost: costPrice, list: listPrice, sell: sellPrice, ship: ship);

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
        costPrice: _d(j['cost_price']),
        listPrice: _d(j['list_price']),
        sellPrice: _d(j['sell_price']),
      );

  @override
  List<Object?> get props => [janCode, name, productId, onHand, reserved, inOpen, free, costPrice, listPrice, sellPrice];
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

/// How the bulk setting of a shipment chosen from the library (少ロット
/// の出荷, 出荷の提案) gives each product its quantity.
enum ShipBulkMode {
  /// A percentage of what is free to ship (在庫 − キープ).
  percentFree,

  /// A percentage of the stock, never more than is free.
  percentOnHand,

  /// The same number for each, up to what is free.
  fixed,

  /// Everything free.
  allFree,
}

/// The quantity [mode] gives [item]: never below 0 nor above what is free.
int shipBulkQuantity(OutboundStockItem item, ShipBulkMode mode, double value,
    {ProposalRounding rounding = ProposalRounding.down}) {
  final free = item.free < 0 ? 0 : item.free;
  return switch (mode) {
    ShipBulkMode.percentFree =>
      proposeByPercent([item], value, base: ProposalBase.free, rounding: rounding)[item.janCode] ?? 0,
    ShipBulkMode.percentOnHand =>
      proposeByPercent([item], value, base: ProposalBase.onHand, rounding: rounding)[item.janCode] ?? 0,
    ShipBulkMode.fixed => (switch (rounding) {
        ProposalRounding.down => (value + 1e-9).floor(),
        ProposalRounding.nearest => value.round(),
        ProposalRounding.up => (value - 1e-9).ceil(),
      })
          .clamp(0, free),
    ShipBulkMode.allFree => free,
  };
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
    this.priceColumns = const [],
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

  /// The prices its sheet shows, as chosen when it was made (0142).
  final List<PriceColumn> priceColumns;

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
      priceColumns: [
        for (final c in (j['price_columns'] as List? ?? const []))
          if (PriceColumn.fromWire('$c') case final col?) col,
      ],
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
    this.unitPrice,
    this.costPrice,
    this.listPrice,
    this.sellPrice,
  });

  final String janCode;
  final String name;
  final int quantity;
  final String? nameEn;
  final String? maker;
  final String? productCode;
  final String? unit;

  /// 出荷単価, and the prices it was worked out from (0142).
  final double? unitPrice;
  final double? costPrice;
  final double? listPrice;
  final double? sellPrice;

  double? price(PriceColumn c) => switch (c) {
        PriceColumn.cost => costPrice,
        PriceColumn.list => listPrice,
        PriceColumn.sell => sellPrice,
        PriceColumn.ship => unitPrice,
      };

  factory OutboundSheetLine.fromJson(Map<String, dynamic> j) => OutboundSheetLine(
        janCode: _s(j['jan_code']) ?? '',
        name: _s(j['name']) ?? '',
        quantity: _n(j['quantity']),
        nameEn: _s(j['name_en']),
        maker: _s(j['maker']),
        productCode: _s(j['product_code']),
        unit: _s(j['unit']),
        unitPrice: _d(j['unit_price']),
        costPrice: _d(j['cost_price']),
        listPrice: _d(j['list_price']),
        sellPrice: _d(j['sell_price']),
      );

  @override
  List<Object?> get props =>
      [janCode, name, quantity, nameEn, maker, productCode, unit, unitPrice, costPrice, listPrice, sellPrice];
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
  const OutboundCreated({required this.id, required this.shipmentNumber, this.lines = 0, this.units = 0, this.total});

  final int id;
  final String shipmentNumber;
  final int lines;
  final int units;

  /// The shipment's value at its prices, when it has any (0142).
  final double? total;

  factory OutboundCreated.fromJson(Map<String, dynamic> j) => OutboundCreated(
        id: _n(j['id']),
        shipmentNumber: _s(j['shipment_number']) ?? '',
        lines: _n(j['lines']),
        units: _n(j['units']),
        total: _d(j['total']),
      );

  @override
  List<Object?> get props => [id, shipmentNumber, lines, units];
}
