import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

/// Whether a [TradingPartner] is a supplier, a customer, or both — a single
/// real-world company can be either side of the ledger.
enum PartnerKind {
  supplier('supplier'),
  customer('customer'),
  both('both');

  const PartnerKind(this.wire);
  final String wire;

  static PartnerKind parse(String? value) => switch (value) {
        'customer' => PartnerKind.customer,
        'both' => PartnerKind.both,
        _ => PartnerKind.supplier,
      };
}

/// One row of `list_trading_partners` (0035) — `delivery_suppliers` extended
/// into a general trading-partner master. Referenced by both
/// `delivery_plans.supplier_id` (inbound) and `shipment_plans.party_id`
/// (outbound), so this is one directory rather than separate supplier and
/// customer tables.
class TradingPartner extends Equatable {
  const TradingPartner({
    required this.id,
    required this.name,
    this.kind = PartnerKind.supplier,
    this.code,
    this.contactName,
    this.phone,
    this.email,
    this.address,
    this.paymentTerms,
    this.notes,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final PartnerKind kind;
  final String? code;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? address;
  final String? paymentTerms;
  final String? notes;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == 'active';

  factory TradingPartner.fromJson(Map<String, dynamic> json) => TradingPartner(
        id: _asInt(json['id']),
        name: (json['name'] ?? '').toString(),
        kind: PartnerKind.parse(json['kind'] as String?),
        code: json['code'] as String?,
        contactName: json['contact_name'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        address: json['address'] as String?,
        paymentTerms: json['payment_terms'] as String?,
        notes: json['notes'] as String?,
        status: (json['status'] ?? 'active').toString(),
        createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
        updatedAt: DateTime.tryParse('${json['updated_at']}')?.toLocal(),
      );

  @override
  List<Object?> get props => [id, name, kind, code, status];
}
