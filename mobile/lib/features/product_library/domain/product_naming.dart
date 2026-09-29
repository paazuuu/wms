import 'package:equatable/equatable.dart';

// Our own product format (0111): a product's name is built from its parts
// by a template the company chooses, so the whole master can be re-styled
// later in one place.

int _i(dynamic v, [int d = 0]) => v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? d);
int? _iOrNull(dynamic v) => v == null ? null : (v is int ? v : (v is num ? v.toInt() : int.tryParse('$v')));
double? _d(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
String? _s(dynamic v) {
  final t = v?.toString().trim();
  return t == null || t.isEmpty ? null : t;
}

/// The placeholders a template can use besides `{attr:<key>}`.
const namePlaceholders = ['{base}', '{maker}', '{code}', '{jan}', '{unit}'];

/// A template filled in, as the database does it (`render_product_name`):
/// a placeholder with nothing to put in it disappears, and so does a
/// bracket left empty. For previews; the database's result is the name.
String renderProductName(
  String template, {
  String? base,
  String? maker,
  String? code,
  String? jan,
  String? unit,
  Map<String, String> attributes = const {},
}) {
  var v = template
      .replaceAll('{base}', base ?? '')
      .replaceAll('{maker}', maker ?? '')
      .replaceAll('{code}', code ?? '')
      .replaceAll('{jan}', jan ?? '')
      .replaceAll('{unit}', unit ?? '');
  for (final e in attributes.entries) {
    v = v.replaceAll('{attr:${e.key}}', e.value);
  }
  v = v
      .replaceAll(RegExp(r'\{attr:[a-z0-9_]+\}'), '')
      .replaceAll(RegExp(r'\(\s*\)|（\s*）|\[\s*\]|【\s*】'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return v;
}

/// One way of naming products (`product_name_formats`).
class NameFormat extends Equatable {
  const NameFormat({
    required this.id,
    required this.name,
    required this.template,
    this.isDefault = false,
    this.active = true,
    this.products = 0,
  });

  final int id;
  final String name;
  final String template;
  final bool isDefault;
  final bool active;

  /// Products named by it now.
  final int products;

  factory NameFormat.fromJson(Map<String, dynamic> j) => NameFormat(
        id: _i(j['id']),
        name: (j['name'] ?? '').toString(),
        template: (j['template'] ?? '').toString(),
        isDefault: j['is_default'] == true,
        active: (j['status'] ?? 'active') == 'active',
        products: _i(j['products']),
      );

  @override
  List<Object?> get props => [id, name, template, isDefault, active, products];
}

/// A product's name now, and what a template would make it.
class NamePreview extends Equatable {
  const NamePreview({required this.productId, required this.current, required this.next});

  final int productId;
  final String current;
  final String next;

  bool get changes => current != next;

  factory NamePreview.fromJson(Map<String, dynamic> j) => NamePreview(
        productId: _i(j['product_id']),
        current: (j['current'] ?? '').toString(),
        next: (j['next'] ?? '').toString(),
      );

  @override
  List<Object?> get props => [productId, current, next];
}

/// A saved format and how many product names it rebuilt.
class NameFormatSaved {
  const NameFormatSaved({required this.id, required this.renamed, required this.formats});

  final int id;
  final int renamed;
  final List<NameFormat> formats;
}

/// A product's naming parts (`product_naming`).
class ProductNaming extends Equatable {
  const ProductNaming({
    required this.id,
    required this.name,
    this.baseName,
    this.unit,
    this.listPrice,
    this.formatId,
    this.manual = false,
    this.sku,
    this.maker,
    this.janCode,
  });

  final int id;
  final String name;

  /// The name without size or colour; null for a product from before 0111,
  /// which keeps the name it was given.
  final String? baseName;
  final String? unit;
  final double? listPrice;

  /// Null: the default format.
  final int? formatId;

  /// Named by hand: the format does not touch it.
  final bool manual;
  final String? sku;
  final String? maker;
  final String? janCode;

  factory ProductNaming.fromJson(Map<String, dynamic> j) => ProductNaming(
        id: _i(j['id']),
        name: (j['name'] ?? '').toString(),
        baseName: _s(j['base_name']),
        unit: _s(j['unit']),
        listPrice: _d(j['list_price']),
        formatId: _iOrNull(j['name_format_id']),
        manual: j['name_manual'] == true,
        sku: _s(j['sku']),
        maker: _s(j['maker']),
        janCode: _s(j['jan_code']),
      );

  @override
  List<Object?> get props => [id, name, baseName, unit, listPrice, formatId, manual, sku, maker];
}

/// What a person sets for a product's name.
class ProductNamingDraft {
  const ProductNamingDraft({
    this.baseName,
    this.unit,
    this.listPrice,
    this.formatId,
    this.manual = false,
    this.name,
  });

  final String? baseName;
  final String? unit;
  final double? listPrice;
  final int? formatId;
  final bool manual;

  /// The name itself, when [manual].
  final String? name;

  Map<String, dynamic> toJson() => {
        'base_name': baseName,
        'unit': unit,
        'list_price': listPrice,
        'name_format_id': formatId,
        'name_manual': manual,
        if (manual) 'name': name,
      };
}

/// A maker in our master (0105).
class MakerEntry extends Equatable {
  const MakerEntry({required this.id, required this.name, this.products = 0, this.dialects = 0});

  final int id;
  final String name;
  final int products;

  /// Other ways of writing it that read as this maker.
  final int dialects;

  factory MakerEntry.fromJson(Map<String, dynamic> j) => MakerEntry(
        id: _i(j['id']),
        name: (j['name'] ?? '').toString(),
        products: _i(j['products']),
        dialects: _i(j['dialects']),
      );

  @override
  List<Object?> get props => [id, name, products, dialects];
}

/// A supplier line with no product yet, as a product in our format — to be
/// checked and corrected by a person before it is registered.
class ProductProposal extends Equatable {
  const ProductProposal({
    required this.row,
    required this.janCode,
    this.maker,
    this.code,
    this.baseName = '',
    this.baseFromCode = false,
    this.unit,
    this.listPrice,
    this.attributes = const {},
    this.name = '',
    this.source = const {},
  });

  final int row;
  final String janCode;
  final String? maker;

  /// The maker's 品番, which becomes our `sku`.
  final String? code;
  final String baseName;

  /// The document had no name: [baseName] is the 品番 and wants a real name.
  final bool baseFromCode;
  final String? unit;
  final double? listPrice;

  /// Ours, key → value (size: 0.5mm, color: 赤).
  final Map<String, String> attributes;

  /// The name the default format makes of it.
  final String name;

  /// The line as read, learned against the new product.
  final Map<String, dynamic> source;

  factory ProductProposal.fromJson(Map<String, dynamic> j) => ProductProposal(
        row: _i(j['row']),
        janCode: (j['jan_code'] ?? '').toString(),
        maker: _s(j['maker']),
        code: _s(j['code']),
        baseName: (j['base_name'] ?? '').toString(),
        baseFromCode: j['base_from_code'] == true,
        unit: _s(j['unit']),
        listPrice: _d(j['list_price']),
        attributes: {
          for (final e in ((j['attributes'] as Map?) ?? const {}).entries)
            if (_s(e.value) != null) e.key.toString(): _s(e.value)!,
        },
        name: (j['name'] ?? '').toString(),
        source: ((j['source'] as Map?) ?? const {}).cast<String, dynamic>(),
      );

  ProductProposal copyWith({
    String? maker,
    String? code,
    String? baseName,
    String? unit,
    double? listPrice,
    bool clearListPrice = false,
    Map<String, String>? attributes,
  }) =>
      ProductProposal(
        row: row,
        janCode: janCode,
        maker: maker ?? this.maker,
        code: code ?? this.code,
        baseName: baseName ?? this.baseName,
        baseFromCode: baseFromCode && (baseName == null || baseName == this.baseName),
        unit: unit ?? this.unit,
        listPrice: clearListPrice ? null : (listPrice ?? this.listPrice),
        attributes: attributes ?? this.attributes,
        name: name,
        source: source,
      );

  /// Ready to register: a maker and a name.
  bool get complete => (maker ?? '').trim().isNotEmpty && baseName.trim().isNotEmpty;

  Map<String, dynamic> toRegisterJson() => {
        'row': row,
        'jan_code': janCode,
        'maker': maker,
        'code': code,
        'base_name': baseName,
        'unit': unit,
        'list_price': listPrice,
        'attributes': attributes,
        'source': source,
      };

  @override
  List<Object?> get props => [row, janCode, maker, code, baseName, unit, listPrice, attributes];
}

/// A product created from a proposal.
class RegisteredProduct extends Equatable {
  const RegisteredProduct({required this.row, required this.janCode, required this.productId, required this.name});

  final int row;
  final String janCode;
  final int productId;
  final String name;

  factory RegisteredProduct.fromJson(Map<String, dynamic> j) => RegisteredProduct(
        row: _i(j['row']),
        janCode: (j['jan_code'] ?? '').toString(),
        productId: _i(j['product_id']),
        name: (j['name'] ?? '').toString(),
      );

  @override
  List<Object?> get props => [row, janCode, productId];
}
