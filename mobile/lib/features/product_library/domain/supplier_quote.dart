import 'package:equatable/equatable.dart';

/// A quotation as read: its lines in the supplier's own words, each tied to
/// our product where one was found.
class QuoteRead extends Equatable {
  const QuoteRead({required this.lines, this.partnerId, this.source, this.verified = true});

  final int? partnerId;

  /// xlsx, csv, pdf_text or gemini (read by the AI).
  final String? source;

  /// False when the AI's second reading disagreed with its first.
  final bool verified;

  /// The reader's lines, kept whole so they can go on to registration and
  /// to `save_supplier_quote` as they came.
  final List<Map<String, dynamic>> lines;

  factory QuoteRead.fromJson(Map<String, dynamic> j) => QuoteRead(
        partnerId: (j['partner_id'] as num?)?.toInt(),
        source: j['source']?.toString(),
        verified: j['verified'] != false,
        lines: [
          for (final l in (j['lines'] as List? ?? const []).whereType<Map>()) l.cast<String, dynamic>(),
        ],
      );

  @override
  List<Object?> get props => [partnerId, source, verified, lines];
}

/// What one quotation line says, read out of the reader's map.
class QuoteLine {
  const QuoteLine._();

  static String _s(Object? v) => v == null ? '' : '$v'.trim();
  static double? _n(Object? v) => v is num ? v.toDouble() : double.tryParse(_s(v));

  static int? productId(Map<String, dynamic> l) => (l['product_id'] as num?)?.toInt();

  /// The JAN, digits only ('' when the line has none).
  static String jan(Map<String, dynamic> l) {
    final j = _s(l['jan_code']).isEmpty ? _s(l['raw_jan_code']) : _s(l['jan_code']);
    return j.replaceAll(RegExp(r'\D'), '');
  }

  static bool hasJan(Map<String, dynamic> l) => const {8, 13}.contains(jan(l).length);

  /// Our product's name when the line is tied to one, else the supplier's.
  static String name(Map<String, dynamic> l) {
    final p = l['product'];
    if (p is Map && _s(p['name']).isNotEmpty) return _s(p['name']);
    return _s(l['product_name']);
  }

  static String supplierName(Map<String, dynamic> l) => _s(l['product_name']);
  static String? maker(Map<String, dynamic> l) {
    final p = l['product'];
    final m = p is Map && _s(p['maker']).isNotEmpty ? _s(p['maker']) : _s(l['maker']);
    return m.isEmpty ? null : m;
  }

  static String? code(Map<String, dynamic> l) {
    final c = _s(l['supplier_code']).isNotEmpty ? _s(l['supplier_code']) : _s(l['product_code']);
    return c.isEmpty ? null : c;
  }

  static double? unitPrice(Map<String, dynamic> l) => _n(l['unit_price']);
  static double? listPrice(Map<String, dynamic> l) => _n(l['list_price']);
  static double? discountRate(Map<String, dynamic> l) => _n(l['discount_rate']);
  static double? caseQuantity(Map<String, dynamic> l) => _n(l['case_quantity']);

  /// The price to keep: the unit price, else list price × rate.
  static double? price(Map<String, dynamic> l) {
    final u = unitPrice(l);
    if (u != null) return u;
    final lp = listPrice(l);
    final r = discountRate(l);
    return lp != null && r != null ? lp * r : null;
  }

  /// The fields `save_supplier_quote` reads, and those the dictionary learns
  /// the supplier's writing from.
  static Map<String, dynamic> toSaveJson(Map<String, dynamic> l) => {
        'product_id': productId(l),
        'jan_code': l['jan_code'],
        'raw_jan_code': l['raw_jan_code'],
        'maker': l['maker'],
        'product_name': l['product_name'],
        'product_code': l['product_code'],
        'supplier_code': l['supplier_code'],
        'spec': l['spec'],
        'unit': l['unit'],
        'unit_price': l['unit_price'],
        'list_price': l['list_price'],
        'discount_rate': l['discount_rate'],
        'case_quantity': l['case_quantity'],
        'attributes': l['attributes'],
      };
}

/// What saving a quotation did.
class QuoteSaved extends Equatable {
  const QuoteSaved({this.prices = 0, this.products = 0, this.skipped = 0});

  /// Products whose price for this supplier was kept or updated.
  final int prices;

  /// Products the quotation named (with or without a price).
  final int products;

  /// Lines with no product of ours, left out.
  final int skipped;

  factory QuoteSaved.fromJson(Map<String, dynamic> j) => QuoteSaved(
        prices: (j['prices'] as num?)?.toInt() ?? 0,
        products: (j['products'] as num?)?.toInt() ?? 0,
        skipped: (j['skipped'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [prices, products, skipped];
}
