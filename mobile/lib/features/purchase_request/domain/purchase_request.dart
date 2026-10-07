import 'package:equatable/equatable.dart';

String? _s(Object? v) {
  final t = v?.toString().trim();
  return t == null || t.isEmpty ? null : t;
}

int? _ni(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

/// One product of 商品マスタ as a candidate for the request (0140): its stock
/// and, with a supplier chosen, what that supplier calls it.
class RequestCandidate extends Equatable {
  const RequestCandidate({
    required this.productId,
    required this.name,
    this.janCode,
    this.nameEn,
    this.maker,
    this.sku,
    this.unit,
    this.onHand = 0,
    this.minStock,
    this.reorderPoint,
    this.maxStock,
    this.supplierCode,
    this.supplierProductName,
    this.fromSupplier = false,
  });

  final int productId;
  final String name;
  final String? janCode;
  final String? nameEn;
  final String? maker;
  final String? sku;
  final String? unit;
  final int onHand;
  final int? minStock;
  final int? reorderPoint;
  final int? maxStock;

  /// The chosen supplier's code and name for it.
  final String? supplierCode;
  final String? supplierProductName;

  /// Whether the chosen supplier is known to carry it.
  final bool fromSupplier;

  factory RequestCandidate.fromJson(Map<String, dynamic> j) => RequestCandidate(
        productId: _ni(j['product_id']) ?? 0,
        name: _s(j['name']) ?? _s(j['jan_code']) ?? '',
        janCode: _s(j['jan_code']),
        nameEn: _s(j['name_en']),
        maker: _s(j['maker']),
        sku: _s(j['sku']),
        unit: _s(j['unit']),
        onHand: _ni(j['on_hand']) ?? 0,
        minStock: _ni(j['min_stock']),
        reorderPoint: _ni(j['reorder_point']),
        maxStock: _ni(j['max_stock']),
        supplierCode: _s(j['supplier_code']),
        supplierProductName: _s(j['supplier_product_name']),
        fromSupplier: j['from_supplier'] == true,
      );

  @override
  List<Object?> get props => [productId, name, janCode, onHand, maxStock, supplierCode, fromSupplier];
}

/// How a bulk setting turns into quantities.
enum BulkMode {
  /// A percentage of each product's stock.
  percentOfStock,

  /// The same number for every product.
  fixed,

  /// Up to the warehouse's maximum stock (or its reorder point when no
  /// maximum is set).
  upToMax,
}

enum BulkRounding { down, nearest, up }

/// One row of the list being made: a product of ours or one typed by hand,
/// whether it is in the request, and how many are wanted.
class RequestRow extends Equatable {
  const RequestRow({
    required this.key,
    required this.name,
    this.productId,
    this.janCode,
    this.nameEn,
    this.maker,
    this.sku,
    this.unit,
    this.onHand,
    this.minStock,
    this.reorderPoint,
    this.maxStock,
    this.supplierCode,
    this.supplierProductName,
    this.fromSupplier = false,
    this.inList = false,
    this.quantity = 0,
    this.note,
    this.manual = false,
  });

  /// p<product id>, or m<n> for a row typed by hand.
  final String key;
  final String name;
  final int? productId;
  final String? janCode;
  final String? nameEn;
  final String? maker;
  final String? sku;
  final String? unit;
  final int? onHand;
  final int? minStock;
  final int? reorderPoint;
  final int? maxStock;
  final String? supplierCode;
  final String? supplierProductName;
  final bool fromSupplier;
  final bool inList;
  final int quantity;
  final String? note;
  final bool manual;

  factory RequestRow.fromCandidate(RequestCandidate c) => RequestRow(
        key: 'p${c.productId}',
        name: c.name,
        productId: c.productId,
        janCode: c.janCode,
        nameEn: c.nameEn,
        maker: c.maker,
        sku: c.sku,
        unit: c.unit,
        onHand: c.onHand,
        minStock: c.minStock,
        reorderPoint: c.reorderPoint,
        maxStock: c.maxStock,
        supplierCode: c.supplierCode,
        supplierProductName: c.supplierProductName,
        fromSupplier: c.fromSupplier,
      );

  RequestRow copyWith({bool? inList, int? quantity, String? note}) => RequestRow(
        key: key,
        name: name,
        productId: productId,
        janCode: janCode,
        nameEn: nameEn,
        maker: maker,
        sku: sku,
        unit: unit,
        onHand: onHand,
        minStock: minStock,
        reorderPoint: reorderPoint,
        maxStock: maxStock,
        supplierCode: supplierCode,
        supplierProductName: supplierProductName,
        fromSupplier: fromSupplier,
        inList: inList ?? this.inList,
        quantity: quantity ?? this.quantity,
        note: note ?? this.note,
        manual: manual,
      );

  /// The same product with a new candidate's stock and supplier names,
  /// keeping what was set on it.
  RequestRow refreshedFrom(RequestCandidate c) => RequestRow.fromCandidate(c).copyWith(
        inList: inList,
        quantity: quantity,
        note: note,
      );

  /// What `purchase_request_save` takes.
  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'jan_code': janCode,
        'name': name,
        'name_en': nameEn,
        'maker': maker,
        'sku': sku,
        'supplier_code': supplierCode,
        'supplier_product_name': supplierProductName,
        'unit': unit,
        'quantity': quantity,
        'on_hand': onHand,
        'note': note,
      };

  factory RequestRow.fromSaved(Map<String, dynamic> j, int n) {
    final pid = _ni(j['product_id']);
    return RequestRow(
      key: pid == null ? 'm$n' : 'p$pid',
      name: _s(j['name']) ?? '',
      productId: pid,
      janCode: _s(j['jan_code']),
      nameEn: _s(j['name_en']),
      maker: _s(j['maker']),
      sku: _s(j['sku']),
      unit: _s(j['unit']),
      onHand: _ni(j['on_hand']),
      supplierCode: _s(j['supplier_code']),
      supplierProductName: _s(j['supplier_product_name']),
      inList: true,
      quantity: _ni(j['quantity']) ?? 0,
      note: _s(j['note']),
      manual: pid == null,
    );
  }

  @override
  List<Object?> get props => [key, name, productId, janCode, onHand, inList, quantity, note, supplierCode, manual];
}

/// The quantity [mode] gives one row: a percentage of its stock, the same
/// number for all, or what brings it up to its maximum (or reorder point).
/// Never below zero.
int bulkQuantity(RequestRow r, BulkMode mode, double value, {BulkRounding rounding = BulkRounding.up}) {
  const eps = 1e-9;
  int round(double x) => switch (rounding) {
        BulkRounding.down => (x + eps).floor(),
        BulkRounding.nearest => x.round(),
        BulkRounding.up => (x - eps).ceil(),
      };
  final q = switch (mode) {
    BulkMode.percentOfStock => round((r.onHand ?? 0) * value / 100),
    BulkMode.fixed => round(value),
    BulkMode.upToMax => (r.maxStock ?? r.reorderPoint) == null ? 0 : (r.maxStock ?? r.reorderPoint)! - (r.onHand ?? 0),
  };
  return q < 0 ? 0 : q;
}

/// The keys between [a] and [b] in [order], both included — the rows a
/// shift-click selects.
List<String> keysBetween(List<String> order, String a, String b) {
  final i = order.indexOf(a);
  final j = order.indexOf(b);
  if (i < 0 || j < 0) return [if (j >= 0) b];
  final lo = i < j ? i : j;
  final hi = i < j ? j : i;
  return order.sublist(lo, hi + 1);
}

/// A kept list (0140).
class PurchaseRequest extends Equatable {
  const PurchaseRequest({
    required this.id,
    required this.number,
    this.supplierId,
    this.supplierName,
    this.warehouseId,
    this.warehouseName,
    this.title,
    this.note,
    this.replyBy,
    this.status = 'draft',
    this.updatedAt,
    this.createdByName,
    this.lineCount = 0,
    this.units = 0,
    this.lines = const [],
  });

  final int id;
  final String number;
  final int? supplierId;
  final String? supplierName;
  final int? warehouseId;
  final String? warehouseName;
  final String? title;
  final String? note;
  final DateTime? replyBy;
  final String status;
  final DateTime? updatedAt;
  final String? createdByName;
  final int lineCount;
  final int units;
  final List<RequestRow> lines;

  factory PurchaseRequest.fromJson(Map<String, dynamic> j) => PurchaseRequest(
        id: _ni(j['id']) ?? 0,
        number: _s(j['request_number']) ?? '',
        supplierId: _ni(j['supplier_id']),
        supplierName: _s(j['supplier_name']),
        warehouseId: _ni(j['warehouse_id']),
        warehouseName: _s(j['warehouse_name']),
        title: _s(j['title']),
        note: _s(j['note']),
        replyBy: DateTime.tryParse('${j['reply_by'] ?? ''}'),
        status: _s(j['status']) ?? 'draft',
        updatedAt: DateTime.tryParse('${j['updated_at'] ?? ''}')?.toLocal(),
        createdByName: _s(j['created_by_name']),
        lineCount: _ni(j['line_count']) ?? 0,
        units: _ni(j['units']) ?? 0,
        lines: [
          for (final (i, l) in (j['lines'] as List? ?? const []).whereType<Map>().indexed)
            RequestRow.fromSaved(l.cast<String, dynamic>(), i + 1),
        ],
      );

  @override
  List<Object?> get props => [id, number, supplierId, warehouseId, title, note, replyBy, status, lineCount, units, lines];
}

/// What saving gave back.
class RequestSaved extends Equatable {
  const RequestSaved({required this.id, required this.number, this.lines = 0, this.units = 0});

  final int id;
  final String number;
  final int lines;
  final int units;

  factory RequestSaved.fromJson(Map<String, dynamic> j) => RequestSaved(
        id: _ni(j['id']) ?? 0,
        number: _s(j['request_number']) ?? '',
        lines: _ni(j['lines']) ?? 0,
        units: _ni(j['units']) ?? 0,
      );

  @override
  List<Object?> get props => [id, number, lines, units];
}
