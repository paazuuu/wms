import 'package:equatable/equatable.dart';

int _i(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
int? _ni(Object? v) => v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
double? _nd(Object? v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
String? _s(Object? v) {
  final t = v?.toString().trim();
  return t == null || t.isEmpty ? null : t;
}

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse('$v');

/// One supplier as a card (0143): what is bought from them, how often, and
/// when last.
class SupplierCard extends Equatable {
  const SupplierCard({
    required this.id,
    required this.name,
    this.code,
    this.contactName,
    this.phone,
    this.email,
    this.products = 0,
    this.purchases = 0,
    this.units = 0,
    this.amount = 0,
    this.lastAt,
    this.top = const [],
  });

  final int id;
  final String name;
  final String? code;
  final String? contactName;
  final String? phone;
  final String? email;

  /// Products bought from them or with a name on file for them.
  final int products;

  /// Orders, deliveries and files that brought stock in.
  final int purchases;
  final int units;
  final double amount;
  final DateTime? lastAt;

  /// What is bought from them most, up to three names.
  final List<String> top;

  factory SupplierCard.fromJson(Map<String, dynamic> j) => SupplierCard(
        id: _i(j['id']),
        name: _s(j['name']) ?? '',
        code: _s(j['code']),
        contactName: _s(j['contact_name']),
        phone: _s(j['phone']),
        email: _s(j['email']),
        products: _i(j['products']),
        purchases: _i(j['purchases']),
        units: _i(j['units']),
        amount: _nd(j['amount']) ?? 0,
        lastAt: _date(j['last_at']),
        top: [for (final t in (j['top'] as List? ?? const [])) '$t'],
      );

  @override
  List<Object?> get props => [id, name, code, products, purchases, units, amount, lastAt, top];
}

/// One product as bought from one supplier.
class SupplierProduct extends Equatable {
  const SupplierProduct({
    required this.name,
    this.productId,
    this.janCode,
    this.nameEn,
    this.maker,
    this.sku,
    this.unit,
    this.theirName,
    this.theirCode,
    this.times = 0,
    this.total = 0,
    this.avgQty,
    this.lastQty,
    this.lastPrice,
    this.lastListPrice,
    this.lastRate,
    this.minPrice,
    this.maxPrice,
    this.buys = const [],
    this.firstAt,
    this.lastAt,
    this.intervalDays,
    this.nextDue,
    this.onHand = 0,
  });

  final int? productId;
  final String? janCode;
  final String name;
  final String? nameEn;
  final String? maker;
  final String? sku;
  final String? unit;

  /// What the supplier calls it.
  final String? theirName;
  final String? theirCode;

  /// How many purchases it was in, and how many in all.
  final int times;
  final int total;
  final int? avgQty;
  final int? lastQty;
  final double? lastPrice;

  /// The 定価 the last invoice printed (else the product's), and the rate
  /// (掛率) paid then: last price ÷ 定価.
  final double? lastListPrice;
  final double? lastRate;

  /// The lowest and highest 単価 paid.
  final double? minPrice;
  final double? maxPrice;

  /// Every time it was bought, newest first.
  final List<SupplierBuy> buys;
  final DateTime? firstAt;
  final DateTime? lastAt;

  /// Days between purchases on average, and when the next one would fall.
  final int? intervalDays;
  final DateTime? nextDue;
  final int onHand;

  /// A key for choosing rows: the product, else its JAN or name.
  String get key => productId != null ? 'p$productId' : 'j${janCode ?? name}';

  bool dueBy(DateTime day) => nextDue != null && !nextDue!.isAfter(day);

  factory SupplierProduct.fromJson(Map<String, dynamic> j) => SupplierProduct(
        productId: _ni(j['product_id']),
        janCode: _s(j['jan_code']),
        name: _s(j['name']) ?? _s(j['their_name']) ?? '',
        nameEn: _s(j['name_en']),
        maker: _s(j['maker']),
        sku: _s(j['sku']),
        unit: _s(j['unit']),
        theirName: _s(j['their_name']),
        theirCode: _s(j['their_code']),
        times: _i(j['times']),
        total: _i(j['total']),
        avgQty: _ni(j['avg_qty']),
        lastQty: _ni(j['last_qty']),
        lastPrice: _nd(j['last_price']),
        lastListPrice: _nd(j['last_list_price']),
        lastRate: _nd(j['last_rate']),
        minPrice: _nd(j['min_price']),
        maxPrice: _nd(j['max_price']),
        buys: [for (final b in (j['buys'] as List? ?? const []).whereType<Map>()) SupplierBuy.fromJson(b.cast<String, dynamic>())],
        firstAt: _date(j['first_at']),
        lastAt: _date(j['last_at']),
        intervalDays: _ni(j['interval_days']),
        nextDue: _date(j['next_due']),
        onHand: _i(j['on_hand']),
      );

  @override
  List<Object?> get props =>
      [productId, janCode, name, theirName, theirCode, times, total, lastQty, lastPrice, lastRate, buys, lastAt, nextDue, onHand];
}

/// One time a product was bought from the supplier: the day, how many, the
/// 単価 and 定価 paid, and the order, delivery or file it came in.
class SupplierBuy extends Equatable {
  const SupplierBuy({
    required this.source,
    required this.refId,
    required this.quantity,
    this.refNo,
    this.at,
    this.unitPrice,
    this.listPrice,
  });

  final PurchaseSource source;
  final int refId;
  final String? refNo;
  final DateTime? at;
  final int quantity;
  final double? unitPrice;
  final double? listPrice;

  /// 掛率: the price paid ÷ 定価, when both are known.
  double? get rate => unitPrice != null && (listPrice ?? 0) > 0 ? unitPrice! / listPrice! : null;
  double? get amount => unitPrice == null ? null : unitPrice! * quantity;

  factory SupplierBuy.fromJson(Map<String, dynamic> j) => SupplierBuy(
        source: purchaseSourceOf(j['source']),
        refId: _i(j['ref_id']),
        refNo: _s(j['ref_no']),
        at: _date(j['at']),
        quantity: _i(j['quantity']),
        unitPrice: _nd(j['unit_price']),
        listPrice: _nd(j['list_price']),
      );

  @override
  List<Object?> get props => [source, refId, at, quantity, unitPrice, listPrice];
}

/// Where a purchase was recorded.
enum PurchaseSource { po, delivery, import }

PurchaseSource purchaseSourceOf(Object? v) => switch (v) {
      'po' => PurchaseSource.po,
      'delivery' => PurchaseSource.delivery,
      _ => PurchaseSource.import,
    };

/// One purchase: an order, a delivery or a file.
class SupplierPurchase extends Equatable {
  const SupplierPurchase({required this.source, required this.refId, this.refNo, this.at, this.lines = 0, this.units = 0, this.amount});

  final PurchaseSource source;
  final int refId;
  final String? refNo;
  final DateTime? at;
  final int lines;
  final int units;
  final double? amount;

  factory SupplierPurchase.fromJson(Map<String, dynamic> j) => SupplierPurchase(
        source: purchaseSourceOf(j['source']),
        refId: _i(j['ref_id']),
        refNo: _s(j['ref_no']),
        at: _date(j['at']),
        lines: _i(j['lines']),
        units: _i(j['units']),
        amount: _nd(j['amount']),
      );

  @override
  List<Object?> get props => [source, refId, refNo, at, lines, units, amount];
}

/// One supplier with everything bought from them.
class SupplierHistory extends Equatable {
  const SupplierHistory({
    required this.supplierId,
    required this.name,
    this.code,
    this.contactName,
    this.phone,
    this.email,
    this.address,
    this.paymentTerms,
    this.notes,
    this.purchases = 0,
    this.units = 0,
    this.amount = 0,
    this.firstAt,
    this.lastAt,
    this.products = const [],
    this.events = const [],
  });

  final int supplierId;
  final String name;
  final String? code;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? address;
  final String? paymentTerms;
  final String? notes;
  final int purchases;
  final int units;
  final double amount;
  final DateTime? firstAt;
  final DateTime? lastAt;
  final List<SupplierProduct> products;
  final List<SupplierPurchase> events;

  factory SupplierHistory.fromJson(Map<String, dynamic> j) {
    final s = (j['supplier'] as Map? ?? const {}).cast<String, dynamic>();
    final t = (j['totals'] as Map? ?? const {}).cast<String, dynamic>();
    return SupplierHistory(
      supplierId: _i(s['id']),
      name: _s(s['name']) ?? '',
      code: _s(s['code']),
      contactName: _s(s['contact_name']),
      phone: _s(s['phone']),
      email: _s(s['email']),
      address: _s(s['address']),
      paymentTerms: _s(s['payment_terms']),
      notes: _s(s['notes']),
      purchases: _i(t['purchases']),
      units: _i(t['units']),
      amount: _nd(t['amount']) ?? 0,
      firstAt: _date(t['first_at']),
      lastAt: _date(t['last_at']),
      products: [
        for (final p in (j['products'] as List? ?? const []).whereType<Map>()) SupplierProduct.fromJson(p.cast<String, dynamic>()),
      ],
      events: [
        for (final e in (j['events'] as List? ?? const []).whereType<Map>()) SupplierPurchase.fromJson(e.cast<String, dynamic>()),
      ],
    );
  }

  @override
  List<Object?> get props => [supplierId, name, purchases, units, amount, lastAt, products, events];
}

/// How a next order's quantities are filled in.
enum NextOrderQty { last, average, none }

/// The quantity [p] gets in a next order made [how].
int nextOrderQuantity(SupplierProduct p, NextOrderQty how) => switch (how) {
      NextOrderQty.last => p.lastQty ?? p.avgQty ?? 0,
      NextOrderQty.average => p.avgQty ?? p.lastQty ?? 0,
      NextOrderQty.none => 0,
    };
