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
    this.countryCode = 'JP',
    this.createdAt,
    this.updatedAt,
    this.theirCodeForUs,
    this.vendorCodes = 0,
    this.readingNotes,
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

  /// Which country the partner is in (0102) — "orders from China" are orders
  /// from customers whose country is CN.
  final String countryCode;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Our code for the company is [code], numbered by our rule (0112); this
  /// is its code for us (得意先コード), from its documents or typed in.
  final String? theirCodeForUs;

  /// How many of its own supplier codes (仕入先コード) we have learned.
  final int vendorCodes;

  /// 書式メモ (0114): how its documents are laid out, in plain words, given
  /// to the AI with every document from it.
  final String? readingNotes;

  bool get isActive => status == 'active';

  factory TradingPartner.fromJson(Map<String, dynamic> json) => TradingPartner(
        id: _asInt(json['id']),
        name: (json['name'] ?? '').toString(),
        kind: PartnerKind.parse(json['kind'] as String?),
        countryCode: (json['country_code'] as String?) ?? 'JP',
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
        theirCodeForUs: json['their_code_for_us'] as String?,
        vendorCodes: _asInt(json['vendor_codes']),
        readingNotes: json['reading_notes'] as String?,
      );

  @override
  List<Object?> get props => [id, name, kind, code, status, theirCodeForUs];
}

/// How our codes for companies of one kind are numbered (0112): e.g. S +
/// 5 digits → S00001.
class PartnerCodeFormat extends Equatable {
  const PartnerCodeFormat({required this.kind, this.prefix = '', this.digits = 5, this.nextNumber = 1, this.nextCode = ''});

  final PartnerKind kind;
  final String prefix;
  final int digits;
  final int nextNumber;

  /// The code the next new company of this kind gets.
  final String nextCode;

  factory PartnerCodeFormat.fromJson(Map<String, dynamic> j) => PartnerCodeFormat(
        kind: PartnerKind.parse(j['kind'] as String?),
        prefix: (j['prefix'] ?? '').toString(),
        digits: _asInt(j['digits']),
        nextNumber: _asInt(j['next_number']),
        nextCode: (j['next_code'] ?? '').toString(),
      );

  @override
  List<Object?> get props => [kind, prefix, digits, nextNumber];
}

/// A company's code for one of its own suppliers (仕入先コード), and the
/// maker we learned it stands for (0112).
class PartnerVendorCode extends Equatable {
  const PartnerVendorCode({required this.id, required this.code, this.makerName, this.rawMaker, this.seenCount = 0});

  final int id;
  final String code;
  final String? makerName;
  final String? rawMaker;
  final int seenCount;

  factory PartnerVendorCode.fromJson(Map<String, dynamic> j) => PartnerVendorCode(
        id: _asInt(j['id']),
        code: (j['code'] ?? '').toString(),
        makerName: j['maker_name'] as String?,
        rawMaker: j['raw_maker'] as String?,
        seenCount: _asInt(j['seen_count']),
      );

  @override
  List<Object?> get props => [id, code, makerName];
}
