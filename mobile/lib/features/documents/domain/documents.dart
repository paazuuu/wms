import 'package:equatable/equatable.dart';

// A supplier's invoice and the four-way match against the order, the
// delivery and the inspection (0108, spec §51, §55).

double _d(dynamic v, [double d = 0]) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) ?? d : d);
double? _dn(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
int _i(dynamic v, [int d = 0]) => v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? d);
int? _in(dynamic v) => v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
String? _s(dynamic v) {
  final t = v?.toString().trim();
  return t == null || t.isEmpty ? null : t;
}

List<Map<String, dynamic>> _rows(dynamic v) => [
      for (final e in (v as List? ?? const []))
        if (e is Map) e.cast<String, dynamic>(),
    ];

Map<String, double>? _conf(dynamic v) =>
    v is Map ? {for (final e in v.entries) e.key.toString(): _d(e.value)} : null;

enum InvoiceStatus {
  open,
  matched,
  mismatch,
  approved,
  voided;

  static InvoiceStatus parse(String? s) => switch (s) {
        'matched' => matched,
        'mismatch' => mismatch,
        'approved' => approved,
        'void' => voided,
        _ => open,
      };

  String get wire => this == voided ? 'void' : name;
}

class InvoiceLine extends Equatable {
  const InvoiceLine({
    this.productId,
    this.janCode,
    this.productCode,
    this.productName,
    this.maker,
    this.quantity = 0,
    this.unitPrice,
    this.discountRate,
    this.amount,
    this.confidence,
    this.flags = const [],
  });

  final int? productId;
  final String? janCode;
  final String? productCode;
  final String? productName;
  final String? maker;
  final double quantity;
  final double? unitPrice;
  final double? discountRate;
  final double? amount;
  final Map<String, double>? confidence;
  final List<String> flags;

  double get lineAmount => amount ?? quantity * (unitPrice ?? 0);

  factory InvoiceLine.fromJson(Map<String, dynamic> j) => InvoiceLine(
        productId: _in(j['product_id']),
        janCode: _s(j['jan_code']),
        productCode: _s(j['product_code']),
        productName: _s(j['product_name']),
        maker: _s(j['maker']),
        quantity: _d(j['quantity'] ?? j['planned_quantity']),
        unitPrice: _dn(j['unit_price']),
        discountRate: _dn(j['discount_rate']),
        amount: _dn(j['amount']),
        confidence: _conf(j['confidence']),
        flags: [for (final f in (j['flags'] as List? ?? const [])) f.toString()],
      );

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'jan_code': janCode,
        'product_code': productCode,
        'product_name': productName,
        'maker': maker,
        'quantity': quantity,
        'unit_price': unitPrice,
        'discount_rate': discountRate,
        'amount': amount,
        if (confidence != null) 'confidence': confidence,
        if (flags.isNotEmpty) 'flags': flags,
      };

  InvoiceLine copyWith({String? janCode, String? productName, double? quantity, double? unitPrice, double? amount, bool clearAmount = false}) => InvoiceLine(
        productId: janCode != null && janCode != this.janCode ? null : productId,
        janCode: janCode ?? this.janCode,
        productCode: productCode,
        productName: productName ?? this.productName,
        maker: maker,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        discountRate: discountRate,
        amount: clearAmount ? null : (amount ?? this.amount),
        // A person corrected it: it is as sure as it gets.
        confidence: null,
        flags: const [],
      );

  @override
  List<Object?> get props => [productId, janCode, productName, quantity, unitPrice, amount];
}

class SupplierInvoice extends Equatable {
  const SupplierInvoice({
    this.id,
    required this.invoiceNumber,
    this.partnerId,
    this.partnerName,
    this.purchaseOrderId,
    this.poNumber,
    this.invoiceDate,
    this.currency,
    this.subtotal,
    this.tax,
    this.total,
    this.status = InvoiceStatus.open,
    this.source = 'manual',
    this.confidence,
    this.note,
    this.lines = const [],
    this.lineCount = 0,
    this.linesAmount,
  });

  final int? id;
  final String invoiceNumber;
  final int? partnerId;
  final String? partnerName;
  final int? purchaseOrderId;
  final String? poNumber;
  final String? invoiceDate;
  final String? currency;
  final double? subtotal;
  final double? tax;
  final double? total;
  final InvoiceStatus status;
  final String source;
  final Map<String, double>? confidence;
  final String? note;
  final List<InvoiceLine> lines;
  final int lineCount;
  final double? linesAmount;

  bool get settled => status == InvoiceStatus.approved || status == InvoiceStatus.voided;

  factory SupplierInvoice.fromJson(Map<String, dynamic> j) {
    final lines = [for (final l in _rows(j['lines'])) InvoiceLine.fromJson(l)];
    return SupplierInvoice(
      id: _in(j['id']),
      invoiceNumber: (j['invoice_number'] ?? '').toString(),
      partnerId: _in(j['partner_id']),
      partnerName: _s(j['partner_name']),
      purchaseOrderId: _in(j['purchase_order_id']),
      poNumber: _s(j['po_number']),
      invoiceDate: _s(j['invoice_date']),
      currency: _s(j['currency']),
      subtotal: _dn(j['subtotal']),
      tax: _dn(j['tax']),
      total: _dn(j['total']),
      status: InvoiceStatus.parse(j['status'] as String?),
      source: (j['source'] ?? 'manual').toString(),
      confidence: _conf(j['confidence']),
      note: _s(j['note']),
      lines: lines,
      lineCount: j['line_count'] == null ? lines.length : _i(j['line_count']),
      linesAmount: _dn(j['lines_amount']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'invoice_number': invoiceNumber,
        'partner_id': partnerId,
        'purchase_order_id': purchaseOrderId,
        'invoice_date': invoiceDate,
        'currency': currency,
        'subtotal': subtotal,
        'tax': tax,
        'total': total,
        'source': source,
        if (confidence != null) 'confidence': confidence,
        'note': note,
        'lines': [for (final l in lines) l.toJson()],
      };

  @override
  List<Object?> get props => [id, invoiceNumber, status, lines];
}

/// One product across the four documents.
class MatchLine extends Equatable {
  const MatchLine({
    required this.key,
    this.productId,
    this.janCode,
    this.productName,
    this.ordered = 0,
    this.orderPrice,
    this.invoiced = 0,
    this.invoicePrice,
    this.delivered = 0,
    this.received = 0,
    this.inspected = 0,
    this.passed = 0,
    this.failed = 0,
    this.flags = const [],
  });

  final String key;
  final int? productId;
  final String? janCode;
  final String? productName;
  final double ordered;
  final double? orderPrice;
  final double invoiced;
  final double? invoicePrice;
  final double delivered;
  final double received;
  final double inspected;
  final double passed;
  final double failed;
  final List<String> flags;

  bool get ok => flags.isEmpty;

  factory MatchLine.fromJson(Map<String, dynamic> j) => MatchLine(
        key: (j['key'] ?? '').toString(),
        productId: _in(j['product_id']),
        janCode: _s(j['jan_code']),
        productName: _s(j['product_name']),
        ordered: _d(j['ordered']),
        orderPrice: _dn(j['order_price']),
        invoiced: _d(j['invoiced']),
        invoicePrice: _dn(j['invoice_price']),
        delivered: _d(j['delivered']),
        received: _d(j['received']),
        inspected: _d(j['inspected']),
        passed: _d(j['passed']),
        failed: _d(j['failed']),
        flags: [for (final f in (j['flags'] as List? ?? const [])) f.toString()],
      );

  @override
  List<Object?> get props => [key, ordered, invoiced, received, inspected, flags];
}

class DocRef extends Equatable {
  const DocRef({required this.id, required this.number, this.date, this.status});

  final int id;
  final String number;
  final String? date;
  final String? status;

  @override
  List<Object?> get props => [id, number, status];
}

enum MatchStatus {
  pending,
  match,
  mismatch;

  static MatchStatus parse(String? s) => switch (s) {
        'match' => match,
        'mismatch' => mismatch,
        _ => pending,
      };
}

class DocumentMatch extends Equatable {
  const DocumentMatch({
    required this.purchaseOrderId,
    this.poNumber,
    this.supplierId,
    this.supplierName,
    this.invoices = const [],
    this.deliveries = const [],
    this.lines = const [],
    this.poAmount = 0,
    this.invoiceLinesAmount = 0,
    this.invoiceTotal,
    this.qtyTolerancePct = 0,
    this.priceTolerancePct = 0,
    this.status = MatchStatus.pending,
  });

  final int purchaseOrderId;
  final String? poNumber;
  final int? supplierId;
  final String? supplierName;
  final List<DocRef> invoices;
  final List<DocRef> deliveries;
  final List<MatchLine> lines;
  final double poAmount;
  final double invoiceLinesAmount;
  final double? invoiceTotal;
  final double qtyTolerancePct;
  final double priceTolerancePct;
  final MatchStatus status;

  double get amountDifference => invoiceLinesAmount - poAmount;

  factory DocumentMatch.fromJson(Map<String, dynamic> j) => DocumentMatch(
        purchaseOrderId: _i(j['purchase_order_id']),
        poNumber: _s(j['po_number']),
        supplierId: _in(j['supplier_id']),
        supplierName: _s(j['supplier_name']),
        invoices: [
          for (final r in _rows(j['invoices']))
            DocRef(id: _i(r['id']), number: (r['invoice_number'] ?? '').toString(), date: _s(r['invoice_date']), status: _s(r['status'])),
        ],
        deliveries: [
          for (final r in _rows(j['deliveries']))
            DocRef(id: _i(r['id']), number: (r['delivery_number'] ?? '').toString(), date: _s(r['delivery_date']), status: _s(r['status'])),
        ],
        lines: [for (final l in _rows(j['lines'])) MatchLine.fromJson(l)],
        poAmount: _d(j['po_amount']),
        invoiceLinesAmount: _d(j['invoice_lines_amount']),
        invoiceTotal: _dn(j['invoice_total']),
        qtyTolerancePct: _d(j['qty_tolerance_pct']),
        priceTolerancePct: _d(j['price_tolerance_pct']),
        status: MatchStatus.parse(j['status'] as String?),
      );

  @override
  List<Object?> get props => [purchaseOrderId, lines, status, invoices];
}

/// One difference in the exception queue (§53).
class DocumentException extends Equatable {
  const DocumentException({
    required this.purchaseOrderId,
    required this.kind,
    this.poNumber,
    this.supplierName,
    this.productId,
    this.janCode,
    this.productName,
    this.ordered = 0,
    this.invoiced = 0,
    this.received = 0,
    this.inspected = 0,
    this.failed = 0,
    this.orderPrice,
    this.invoicePrice,
  });

  final int purchaseOrderId;
  final String kind;
  final String? poNumber;
  final String? supplierName;
  final int? productId;
  final String? janCode;
  final String? productName;
  final double ordered;
  final double invoiced;
  final double received;
  final double inspected;
  final double failed;
  final double? orderPrice;
  final double? invoicePrice;

  factory DocumentException.fromJson(Map<String, dynamic> j) => DocumentException(
        purchaseOrderId: _i(j['purchase_order_id']),
        kind: (j['kind'] ?? '').toString(),
        poNumber: _s(j['po_number']),
        supplierName: _s(j['supplier_name']),
        productId: _in(j['product_id']),
        janCode: _s(j['jan_code']),
        productName: _s(j['product_name']),
        ordered: _d(j['ordered']),
        invoiced: _d(j['invoiced']),
        received: _d(j['received']),
        inspected: _d(j['inspected']),
        failed: _d(j['failed']),
        orderPrice: _dn(j['order_price']),
        invoicePrice: _dn(j['invoice_price']),
      );

  @override
  List<Object?> get props => [purchaseOrderId, kind, productId, janCode];
}

class InvoiceSaveResult extends Equatable {
  const InvoiceSaveResult({required this.id, required this.status, this.match});

  final int id;
  final InvoiceStatus status;
  final DocumentMatch? match;

  factory InvoiceSaveResult.fromJson(Map<String, dynamic> j) => InvoiceSaveResult(
        id: _i(j['id']),
        status: InvoiceStatus.parse(j['status'] as String?),
        match: j['match'] is Map ? DocumentMatch.fromJson((j['match'] as Map).cast<String, dynamic>()) : null,
      );

  @override
  List<Object?> get props => [id, status];
}
