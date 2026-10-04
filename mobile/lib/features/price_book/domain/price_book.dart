import 'package:equatable/equatable.dart';

import '../../product/domain/product.dart' show ProductLifecycle, ProductStock;

String? _t(Object? v) {
  final s = v == null ? '' : '$v'.trim();
  return s.isEmpty ? null : s;
}

double? _d(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
int? _i(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse('$v');

/// What one supplier offers an item on (0124): for one of its branches (支店)
/// or one of our warehouses, from a date and until one. A new term for the
/// same supplier and branch closes the one before it, so these read as a
/// history.
class PriceBookTerm extends Equatable {
  const PriceBookTerm({
    required this.id,
    required this.partnerId,
    required this.partnerName,
    required this.validFrom,
    this.branch,
    this.warehouseId,
    this.warehouseName,
    this.theirName,
    this.theirCode,
    this.unitPrice,
    this.listPrice,
    this.discountRate,
    this.caseQuantity,
    this.moq,
    this.currency = 'JPY',
    this.validTo,
    this.source = 'file',
    this.sourceFile,
    this.note,
  });

  final int id;
  final int partnerId;
  final String partnerName;
  final String? branch;
  final int? warehouseId;
  final String? warehouseName;
  final String? theirName;
  final String? theirCode;
  final double? unitPrice;
  final double? listPrice;

  /// 掛率 as a fraction (0.6 = 60%).
  final double? discountRate;
  final int? caseQuantity;
  final int? moq;
  final String currency;
  final DateTime validFrom;
  final DateTime? validTo;

  /// `file` (read from a document) or `manual`.
  final String source;
  final String? sourceFile;
  final String? note;

  /// Where the term applies: the supplier's branch and/or our warehouse.
  String? get where => [if (branch != null) branch!, if (warehouseName != null) warehouseName!].join(' / ').ifEmpty;

  /// Whether it applies on [day].
  bool appliesOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return !validFrom.isAfter(d) && (validTo == null || !validTo!.isBefore(d));
  }

  factory PriceBookTerm.fromJson(Map<String, dynamic> j) => PriceBookTerm(
        id: _i(j['id']) ?? 0,
        partnerId: _i(j['partner_id']) ?? 0,
        partnerName: _t(j['partner_name']) ?? '#${j['partner_id']}',
        branch: _t(j['branch']),
        warehouseId: _i(j['warehouse_id']),
        warehouseName: _t(j['warehouse_name']),
        theirName: _t(j['their_name']),
        theirCode: _t(j['their_code']),
        unitPrice: _d(j['unit_price']),
        listPrice: _d(j['list_price']),
        discountRate: _d(j['discount_rate']),
        caseQuantity: _i(j['case_quantity']),
        moq: _i(j['moq']),
        currency: _t(j['currency']) ?? 'JPY',
        validFrom: _date(j['valid_from']) ?? DateTime(2000),
        validTo: _date(j['valid_to']),
        source: _t(j['source']) ?? 'file',
        sourceFile: _t(j['source_file']),
        note: _t(j['note']),
      );

  @override
  List<Object?> get props => [id, partnerId, branch, warehouseId, unitPrice, listPrice, discountRate, caseQuantity, validFrom, validTo];
}

extension on String {
  String? get ifEmpty => isEmpty ? null : this;
}

/// The item's product in the master (`products`), when there is one: linked
/// by registering, or found by its JAN.
class PriceBookProductRef extends Equatable {
  const PriceBookProductRef({required this.id, required this.name, required this.lifecycle, required this.linked});

  final int id;
  final String name;
  final ProductLifecycle lifecycle;

  /// True when registered from the price book; false when only its JAN matches.
  final bool linked;

  @override
  List<Object?> get props => [id, name, lifecycle, linked];
}

/// One product in 価格台帳 (0124) — what a file or a person brought
/// in, kept apart from the product master: reading a file again updates it,
/// deleting it removes only it, and neither touches stock or anything
/// booked.
class PriceBookItem extends Equatable {
  const PriceBookItem({
    required this.id,
    required this.name,
    this.janCode,
    this.maker,
    this.baseName,
    this.itemCode,
    this.spec,
    this.unit,
    this.category,
    this.listPrice,
    this.attributes = const [],
    this.note,
    this.sourceFile,
    this.product,
    this.stock,
    this.terms = const [],
    this.termCount = 0,
    this.weightG,
    this.widthMm,
    this.depthMm,
    this.heightMm,
    this.sizeNote,
    this.imagePaths = const [],
    this.facePath,
    this.imageCount = 0,
    this.source = 'file',
    this.updatedAt,
  });

  final int id;
  final String name;
  final String? janCode;
  final String? maker;
  final String? baseName;
  final String? itemCode;
  final String? spec;
  final String? unit;
  final String? category;
  final double? listPrice;

  /// (name, value) as read: 色 青, サイズ 0.5 …
  final List<(String, String)> attributes;
  final String? note;
  final String? sourceFile;
  final PriceBookProductRef? product;

  /// The master product's stock, when there is a product.
  final ProductStock? stock;

  /// The terms that apply today: one per supplier, branch and warehouse,
  /// cheapest first.
  final List<PriceBookTerm> terms;

  /// Every term it has had, current and past.
  final int termCount;

  /// Its own record of weight and size (0125), copied from a file or the
  /// master and kept when the master changes or loses the product.
  final double? weightG;
  final double? widthMm;
  final double? depthMm;
  final double? heightMm;
  final String? sizeNote;

  /// Its own pictures' storage paths, and the face to show: its first, else
  /// its product's. [imageCount] counts whichever is more.
  final List<String> imagePaths;
  final String? facePath;
  final int imageCount;

  /// `file`, `manual` or `master` (brought in from the master).
  final String source;
  final DateTime? updatedAt;

  bool get inMaster => product != null;

  /// Every supplier the item has a term with, in order of first appearance.
  List<(int, String)> get suppliers {
    final seen = <int, String>{};
    for (final t in terms) {
      seen.putIfAbsent(t.partnerId, () => t.partnerName);
    }
    return [for (final e in seen.entries) (e.key, e.value)];
  }

  PriceBookTerm? get cheapest => ([for (final t in terms) if (t.unitPrice != null) t]
        ..sort((a, b) => a.unitPrice!.compareTo(b.unitPrice!)))
      .firstOrNull;

  factory PriceBookItem.fromJson(Map<String, dynamic> j) {
    final p = j['product'];
    return PriceBookItem(
      id: _i(j['id']) ?? 0,
      name: _t(j['name']) ?? '',
      janCode: _t(j['jan_code']),
      maker: _t(j['maker']),
      baseName: _t(j['base_name']),
      itemCode: _t(j['item_code']),
      spec: _t(j['spec']),
      unit: _t(j['unit']),
      category: _t(j['category']),
      listPrice: _d(j['list_price']),
      attributes: [
        for (final a in (j['attributes'] is List ? j['attributes'] as List : const []).whereType<Map>())
          if (_t(a['value']) case final v?) ('${a['name'] ?? a['key'] ?? ''}', v),
      ],
      note: _t(j['note']),
      sourceFile: _t(j['source_file']),
      product: p is Map
          ? PriceBookProductRef(
              id: _i(p['id']) ?? 0,
              name: _t(p['name']) ?? '',
              lifecycle: ProductLifecycle.parse(p['lifecycle']) ?? ProductLifecycle.active,
              linked: p['linked'] == true,
            )
          : null,
      stock: j['stock'] is Map ? ProductStock.fromJson((j['stock'] as Map).cast<String, dynamic>()) : null,
      terms: [
        for (final t in (j['terms'] as List? ?? const []).whereType<Map>()) PriceBookTerm.fromJson(t.cast<String, dynamic>()),
      ],
      termCount: _i(j['term_count']) ?? 0,
      weightG: _d(j['weight_g']),
      widthMm: _d(j['width_mm']),
      depthMm: _d(j['depth_mm']),
      heightMm: _d(j['height_mm']),
      sizeNote: _t(j['size_note']),
      imagePaths: [for (final x in (j['image_paths'] as List? ?? const [])) if (_t(x) case final v?) v],
      facePath: _t(j['face_path']),
      imageCount: _i(j['image_count']) ?? 0,
      source: _t(j['source']) ?? 'file',
      updatedAt: _date(j['updated_at']),
    );
  }

  @override
  List<Object?> get props => [
        id, name, janCode, maker, itemCode, spec, product, stock, terms, termCount,
        weightG, widthMm, depthMm, heightMm, sizeNote, imagePaths, facePath, imageCount,
      ];
}

/// What reading a file into the price book did.
class PriceBookImported extends Equatable {
  const PriceBookImported({this.created = 0, this.updated = 0, this.terms = 0, this.skipped = 0, this.ids = const []});

  final int created;
  final int updated;
  final int terms;
  final int skipped;

  /// The price book items the lines became or updated (0127), for taking them
  /// into the master straight after.
  final List<int> ids;

  factory PriceBookImported.fromJson(Map<String, dynamic> j) => PriceBookImported(
        created: _i(j['created']) ?? 0,
        updated: _i(j['updated']) ?? 0,
        terms: _i(j['terms']) ?? 0,
        skipped: _i(j['skipped']) ?? 0,
        ids: [for (final x in (j['ids'] as List? ?? const [])) if (_i(x) case final id?) id],
      );

  @override
  List<Object?> get props => [created, updated, terms, skipped, ids];
}

/// A master product that is not in the price book yet (0125), as
/// `price_book_master_candidates` lists it.
class MasterCandidate extends Equatable {
  const MasterCandidate({
    required this.id,
    required this.name,
    this.maker,
    this.sku,
    this.janCode,
    this.lifecycle = ProductLifecycle.active,
    this.supplierCount = 0,
  });

  final int id;
  final String name;
  final String? maker;
  final String? sku;
  final String? janCode;
  final ProductLifecycle lifecycle;
  final int supplierCount;

  factory MasterCandidate.fromJson(Map<String, dynamic> j) => MasterCandidate(
        id: _i(j['id']) ?? 0,
        name: _t(j['name']) ?? '',
        maker: _t(j['maker']),
        sku: _t(j['sku']),
        janCode: _t(j['jan_code']),
        lifecycle: ProductLifecycle.parse(j['lifecycle']) ?? ProductLifecycle.active,
        supplierCount: _i(j['supplier_count']) ?? 0,
      );

  @override
  List<Object?> get props => [id, name, maker, sku, janCode, lifecycle, supplierCount];
}
