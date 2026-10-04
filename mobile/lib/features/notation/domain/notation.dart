import 'package:equatable/equatable.dart';

int _int(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
double? _numOrNull(dynamic v) =>
    v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'.replaceAll(',', '')));
int? _intOrNull(dynamic v) =>
    v == null ? null : (v is int ? v : (v is num ? v.toInt() : int.tryParse('$v')));
String? _text(dynamic v) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}

List<Map<String, dynamic>> _rows(dynamic v) =>
    [for (final e in (v as List? ?? const []).whereType<Map>()) e.cast<String, dynamic>()];

/// What a column of a company's file holds (0105 `column_aliases.field`).
enum ColumnField {
  jan('jan'),
  maker('maker'),
  productName('product_name'),
  productCode('product_code'),
  nameCode('name_code'),
  quantity('quantity'),
  caseQuantity('case_quantity'),
  cases('cases'),
  unitPrice('unit_price'),

  /// 定価・上代 and 掛率 (0111): the list price, and the rate paid of it.
  listPrice('list_price'),
  discountRate('discount_rate'),
  amount('amount'),

  /// 単位 (本, 冊, パック…) and the supplier's own 商品コード beside the
  /// maker's 品番 (0111).
  unit('unit'),
  supplierCode('supplier_code'),

  /// The trading company's code for ITS supplier (仕入先コード), and its
  /// code for us (得意先コード) — neither is ours (0112).
  upstreamCode('upstream_code'),
  customerCode('customer_code'),

  /// Several fields in one cell, split by a layout (0114) — which ones, in
  /// what order, is the column's [ReadColumn.parts].
  multi('multi'),
  spec('spec'),
  taxRate('tax_rate'),
  orderDate('order_date'),
  ignore('ignore'),

  /// One of our product attributes (0110) — which one is the column's
  /// [ReadColumn.attribute].
  attr('attr');

  const ColumnField(this.wire);
  final String wire;

  static ColumnField? parse(String? v) {
    for (final f in values) {
      if (f.wire == v) return f;
    }
    return null;
  }
}

/// What a column holds: a field, one of our product attributes (0110), or
/// several fields in one cell (0114). On the wire an attribute is
/// `attr:<key>`, and a combined cell `multi:maker,product_name,product_code`
/// with `|<separator>` when one is set.
class ColumnChoice extends Equatable {
  const ColumnChoice(this.field, [this.attribute])
      : parts = const [],
        separator = null;
  const ColumnChoice.attr(String key)
      : field = ColumnField.attr,
        attribute = key,
        parts = const [],
        separator = null;
  const ColumnChoice.multi(this.parts, [this.separator])
      : field = ColumnField.multi,
        attribute = null;

  final ColumnField field;
  final String? attribute;

  /// For [ColumnField.multi]: the fields in the cell, in order.
  final List<ColumnField> parts;

  /// null: ／ or / when the cell has one, else spaces; `space`: spaces.
  final String? separator;

  String get wire => switch (field) {
        ColumnField.attr => 'attr:$attribute',
        ColumnField.multi when parts.length >= 2 =>
          'multi:${parts.map((p) => p.wire).join(',')}${separator == null ? '' : '|$separator'}',
        _ => field.wire,
      };

  /// The fields a combined cell can be split into.
  static const partFields = [
    ColumnField.ignore, ColumnField.maker, ColumnField.productName, ColumnField.productCode, ColumnField.jan,
    ColumnField.spec, ColumnField.supplierCode, ColumnField.upstreamCode, ColumnField.unit,
  ];

  @override
  List<Object?> get props => [field, attribute, parts, separator];
}

/// One column as it was read (0105): its heading, what it was taken to hold,
/// how that was decided, and what the AI thought when it disagreed.
class ReadColumn extends Equatable {
  const ReadColumn({
    required this.index,
    required this.header,
    this.field,
    this.source,
    this.aiField,
    this.conflict = false,
    this.attribute,
    this.parts = const [],
    this.separator,
  });

  final int index;
  final String header;
  final ColumnField? field;

  /// partner (this company's learned heading), global, contains, values, ai,
  /// override (corrected by hand).
  final String? source;
  final ColumnField? aiField;
  final bool conflict;

  /// For [ColumnField.attr]: which of our attributes (color, size, …).
  final String? attribute;

  /// For [ColumnField.multi]: the fields in the cell and what splits them.
  final List<ColumnField> parts;
  final String? separator;

  ColumnChoice? get choice => switch (field) {
        null => null,
        ColumnField.attr => attribute == null ? null : ColumnChoice.attr(attribute!),
        ColumnField.multi => parts.length >= 2 ? ColumnChoice.multi(parts, separator) : const ColumnChoice(ColumnField.multi),
        _ => ColumnChoice(field!),
      };

  factory ReadColumn.fromJson(Map<String, dynamic> j) => ReadColumn(
        index: _int(j['index']),
        header: (j['header'] ?? '').toString(),
        field: ColumnField.parse(j['field'] as String?),
        source: _text(j['source']),
        aiField: ColumnField.parse(j['ai_field'] as String?),
        conflict: j['conflict'] == true,
        attribute: _text(j['attribute']),
        parts: [
          for (final p in (j['parts'] as List? ?? const []))
            if (ColumnField.parse('$p') != null) ColumnField.parse('$p')!,
        ],
        separator: _text(j['separator']),
      );

  Map<String, dynamic> toJson() => {
        'index': index,
        'header': header,
        'field': field?.wire,
        if (field == ColumnField.attr) 'attribute': attribute,
        if (field == ColumnField.multi) ...{'parts': [for (final p in parts) p.wire], 'separator': separator},
      };

  ReadColumn withField(ColumnField? f) => ReadColumn(
      index: index, header: header, field: f, source: 'override', aiField: aiField);

  @override
  List<Object?> get props => [index, header, field, source, aiField, conflict, attribute, parts, separator];
}

/// Our product a line resolved to.
class ResolvedProduct extends Equatable {
  const ResolvedProduct({required this.id, required this.janCode, required this.name, this.sku, this.maker});

  final int id;
  final String janCode;
  final String name;
  final String? sku;
  final String? maker;

  factory ResolvedProduct.fromJson(Map<String, dynamic> j) => ResolvedProduct(
        id: _int(j['id']),
        janCode: (j['jan_code'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        sku: _text(j['sku']),
        maker: _text(j['maker']),
      );

  @override
  List<Object?> get props => [id];
}

/// One line as the company wrote it, with what the checks found and our
/// product when it resolved.
class ReadLineResult extends Equatable {
  const ReadLineResult({
    required this.row,
    this.rawJanCode,
    this.janCode = '',
    this.maker,
    this.productName,
    this.productCode,
    this.rawNameCode,
    this.splitBy,
    this.quantity = 0,
    this.flags = const [],
    this.alternatives = const {},
    this.product,
    this.matchedBy,
    this.attributes = const [],
    this.spec,
    this.caseQuantity,
    this.unit,
    this.unitPrice,
    this.listPrice,
    this.supplierCode,
    this.upstreamCode,
    this.customerCode,
  });

  final int row;
  final String? rawJanCode;
  final String janCode;
  final String? maker;
  final String? productName;
  final String? productCode;

  /// The cell that held name and 品番 together, before it was split.
  final String? rawNameCode;
  final String? splitBy;
  final int quantity;
  final List<String> flags;

  /// The other reading, field by field, where two readings disagreed.
  final Map<String, String?> alternatives;
  final ResolvedProduct? product;
  final String? matchedBy;

  /// The line's attributes as the company wrote them (0110).
  final List<ReadAttribute> attributes;
  final String? spec;
  final int? caseQuantity;

  /// 単位, 単価, 定価 and the supplier's own 商品コード as written (0111).
  final String? unit;
  final double? unitPrice;
  final double? listPrice;
  final String? supplierCode;

  /// 仕入先コード and 得意先コード as the company wrote them (0112).
  final String? upstreamCode;
  final String? customerCode;

  bool get resolved => product != null;
  bool get needsReview => flags.any((f) => NotationFlag.isProblem(f));

  factory ReadLineResult.fromJson(Map<String, dynamic> j) => ReadLineResult(
        row: _int(j['row']),
        rawJanCode: _text(j['raw_jan_code']),
        janCode: (j['jan_code'] ?? '').toString(),
        maker: _text(j['maker']),
        productName: _text(j['product_name']),
        productCode: _text(j['product_code']),
        rawNameCode: _text(j['raw_name_code']),
        splitBy: _text(j['split_by']),
        quantity: _int(j['planned_quantity']),
        flags: [for (final f in (j['flags'] as List? ?? const [])) f.toString()],
        alternatives: {
          for (final e in ((j['alternatives'] as Map?) ?? const {}).entries)
            e.key.toString(): e.value?.toString(),
        },
        product: j['product'] is Map
            ? ResolvedProduct.fromJson((j['product'] as Map).cast<String, dynamic>())
            : null,
        matchedBy: _text(j['matched_by']),
        attributes: [
          for (final a in (j['attributes'] as List? ?? const []))
            if (a is Map) ReadAttribute.fromJson(a.cast<String, dynamic>()),
        ],
        spec: _text(j['spec']),
        caseQuantity: _intOrNull(j['case_quantity']),
        unit: _text(j['unit']),
        unitPrice: _numOrNull(j['unit_price']),
        listPrice: _numOrNull(j['list_price']),
        supplierCode: _text(j['supplier_code']),
        upstreamCode: _text(j['upstream_code']),
        customerCode: _text(j['customer_code']),
      );

  ReadLineResult withProduct(ResolvedProduct? p) => ReadLineResult(
        row: row,
        rawJanCode: rawJanCode,
        janCode: janCode,
        maker: maker,
        productName: productName,
        productCode: productCode,
        rawNameCode: rawNameCode,
        splitBy: splitBy,
        quantity: quantity,
        flags: [for (final f in flags) if (p == null || f != 'unresolved') f],
        alternatives: alternatives,
        product: p,
        matchedBy: p == null ? null : 'manual',
        attributes: attributes,
        spec: spec,
        caseQuantity: caseQuantity,
        unit: unit,
        unitPrice: unitPrice,
        listPrice: listPrice,
        supplierCode: supplierCode,
        upstreamCode: upstreamCode,
        customerCode: customerCode,
      );

  /// What is taught from this line: the company's writing, tied to ours.
  Map<String, dynamic> toLearnJson() => {
        'product_id': product?.id,
        'raw_jan_code': rawJanCode,
        'maker': maker,
        'product_name': productName,
        'product_code': productCode,
        'spec': spec,
        'case_quantity': caseQuantity,
        'supplier_code': supplierCode,
        'unit': unit,
        'list_price': listPrice,
        'upstream_code': upstreamCode,
        'attributes': [for (final a in attributes) a.toJson()],
      };

  /// The line as sent to propose a product for it in our format (0111).
  Map<String, dynamic> toProposeJson() => {
        'row': row,
        ...toLearnJson(),
        'jan_code': janCode,
      };

  @override
  List<Object?> get props => [row, rawJanCode, productName, productCode, product, flags];
}

/// One reading of a sample file (0106).
class TrainingRead extends Equatable {
  const TrainingRead({
    this.trainingId,
    this.partnerId,
    this.source,
    this.verified = true,
    this.columns = const [],
    this.lines = const [],
    this.totals,
  });

  final int? trainingId;
  final int? partnerId;
  final String? source;

  /// Whether the AI's check pass ran (a PDF or photo is read twice).
  final bool verified;
  final List<ReadColumn> columns;
  final List<ReadLineResult> lines;

  /// The lines against the document's own totals (0114).
  final ReadTotals? totals;

  int get resolvedCount => lines.where((l) => l.resolved).length;
  int get reviewCount => lines.where((l) => l.needsReview || !l.resolved).length;

  /// How many lines had each kind of problem.
  Map<String, int> get flagCounts {
    final m = <String, int>{};
    for (final l in lines) {
      for (final f in l.flags) {
        final k = f.split(':').first;
        m[k] = (m[k] ?? 0) + 1;
      }
    }
    return m;
  }

  factory TrainingRead.fromJson(Map<String, dynamic> j) => TrainingRead(
        trainingId: _intOrNull(j['training_id'] ?? j['id']),
        partnerId: _intOrNull(j['partner_id']),
        source: _text(j['source']),
        verified: j['verified'] != false,
        columns: [for (final c in _rows(j['columns'])) ReadColumn.fromJson(c)],
        lines: [for (final l in _rows(j['lines'])) ReadLineResult.fromJson(l)],
        totals: j['totals'] is Map ? ReadTotals.fromJson((j['totals'] as Map).cast<String, dynamic>()) : null,
      );

  TrainingRead copyWith({List<ReadColumn>? columns, List<ReadLineResult>? lines}) => TrainingRead(
        trainingId: trainingId,
        partnerId: partnerId,
        source: source,
        verified: verified,
        columns: columns ?? this.columns,
        lines: lines ?? this.lines,
        totals: totals,
      );

  @override
  List<Object?> get props => [trainingId, columns, lines];
}

/// A past training run, for the history (0106).
class TrainingRun extends Equatable {
  const TrainingRun({
    required this.id,
    this.partnerName,
    this.fileName,
    this.source,
    this.lineCount = 0,
    this.resolvedCount = 0,
    this.flagCounts = const {},
    this.status = 'read',
    this.createdAt,
  });

  final int id;
  final String? partnerName;
  final String? fileName;
  final String? source;
  final int lineCount;
  final int resolvedCount;
  final Map<String, int> flagCounts;
  final String status;
  final DateTime? createdAt;

  bool get learned => status == 'learned';

  factory TrainingRun.fromJson(Map<String, dynamic> j) => TrainingRun(
        id: _int(j['id']),
        partnerName: _text(j['partner_name']),
        fileName: _text(j['file_name']),
        source: _text(j['source']),
        lineCount: _int(j['line_count']),
        resolvedCount: _int(j['resolved_count']),
        flagCounts: {
          for (final e in ((j['flag_counts'] as Map?) ?? const {}).entries)
            e.key.toString(): _int(e.value),
        },
        status: (j['status'] ?? 'read').toString(),
        createdAt: DateTime.tryParse('${j['created_at']}')?.toLocal(),
      );

  @override
  List<Object?> get props => [id, status];
}

/// Per company: what its documents tend to get wrong (0106).
class PartnerTrainingStats extends Equatable {
  const PartnerTrainingStats({
    this.partnerId,
    this.partnerName,
    this.runs = 0,
    this.lines = 0,
    this.resolved = 0,
    this.dialects = 0,
    this.columns = 0,
    this.flags = const {},
  });

  final int? partnerId;
  final String? partnerName;
  final int runs;
  final int lines;
  final int resolved;
  final int dialects;
  final int columns;
  final Map<String, int> flags;

  factory PartnerTrainingStats.fromJson(Map<String, dynamic> j) => PartnerTrainingStats(
        partnerId: _intOrNull(j['partner_id']),
        partnerName: _text(j['partner_name']),
        runs: _int(j['runs']),
        lines: _int(j['lines']),
        resolved: _int(j['resolved']),
        dialects: _int(j['dialects']),
        columns: _int(j['columns']),
        flags: {
          for (final e in ((j['flags'] as Map?) ?? const {}).entries) e.key.toString(): _int(e.value),
        },
      );

  @override
  List<Object?> get props => [partnerId, runs, lines, flags];
}

/// One entry of the dialect dictionary (0105): a company's way of writing a
/// JAN, maker, name or 品番, and ours it stands for.
class NotationDialect extends Equatable {
  const NotationDialect({
    required this.id,
    required this.code,
    required this.field,
    required this.rawValue,
    this.rawValues = const [],
    this.partnerId,
    this.partnerName,
    this.productId,
    this.productJan,
    this.productName,
    this.productSku,
    this.productMaker,
    this.makerId,
    this.makerName,
    this.confirmed = false,
    this.source,
    this.seenCount = 0,
  });

  final int id;

  /// D-000123: the dialect's own id.
  final String code;

  /// jan, maker, name or code.
  final String field;
  final String rawValue;
  final List<String> rawValues;
  final int? partnerId;
  final String? partnerName;
  final int? productId;
  final String? productJan;
  final String? productName;
  final String? productSku;
  final String? productMaker;
  final int? makerId;
  final String? makerName;
  final bool confirmed;
  final String? source;
  final int seenCount;

  factory NotationDialect.fromJson(Map<String, dynamic> j) => NotationDialect(
        id: _int(j['id']),
        code: (j['code'] ?? '').toString(),
        field: (j['field'] ?? '').toString(),
        rawValue: (j['raw_value'] ?? '').toString(),
        rawValues: [for (final v in (j['raw_values'] as List? ?? const [])) v.toString()],
        partnerId: _intOrNull(j['partner_id']),
        partnerName: _text(j['partner_name']),
        productId: _intOrNull(j['product_id']),
        productJan: _text(j['product_jan']),
        productName: _text(j['product_name']),
        productSku: _text(j['product_sku']),
        productMaker: _text(j['product_maker']),
        makerId: _intOrNull(j['maker_id']),
        makerName: _text(j['maker_name']),
        confirmed: j['confirmed'] == true,
        source: _text(j['source']),
        seenCount: _int(j['seen_count']),
      );

  @override
  List<Object?> get props => [id, confirmed, productId, makerId, seenCount];
}

/// An attribute as a company wrote it on one line: which of ours, the
/// company's heading, and the value as written (0110).
class ReadAttribute extends Equatable {
  const ReadAttribute({required this.key, required this.name, required this.value});

  final String key;
  final String name;
  final String value;

  factory ReadAttribute.fromJson(Map<String, dynamic> j) => ReadAttribute(
        key: (j['key'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        value: (j['value'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {'key': key, 'name': name, 'value': value};

  @override
  List<Object?> get props => [key, name, value];
}

/// A company's column heading and the field it means (0105).
class ColumnAlias extends Equatable {
  const ColumnAlias({
    required this.id,
    required this.header,
    required this.field,
    this.partnerId,
    this.partnerName,
    this.source,
    this.seenCount = 0,
    this.attributeName,
    this.parts = const [],
    this.separator,
  });

  final int id;
  final String header;
  final ColumnField? field;

  /// For a combined cell (0114): its fields in order, and what splits them.
  final List<ColumnField> parts;
  final String? separator;
  final int? partnerId;
  final String? partnerName;
  final String? source;
  final int seenCount;

  /// For an attribute heading: which of our attributes, by name (色, サイズ…).
  final String? attributeName;

  bool get isSeed => source == 'seed';

  factory ColumnAlias.fromJson(Map<String, dynamic> j) => ColumnAlias(
        id: _int(j['id']),
        header: (j['header'] ?? '').toString(),
        field: ColumnField.parse(j['field'] as String?),
        partnerId: _intOrNull(j['partner_id']),
        partnerName: _text(j['partner_name']),
        source: _text(j['source']),
        seenCount: _int(j['seen_count']),
        attributeName: _text(j['attribute_name']),
        parts: [
          for (final p in (j['parts'] as List? ?? const []))
            if (ColumnField.parse('$p') != null) ColumnField.parse('$p')!,
        ],
        separator: _text(j['separator']),
      );

  @override
  List<Object?> get props => [id, header, field];
}

/// What was learned from a checked sample.
class LearnResult extends Equatable {
  const LearnResult({this.learned = 0, this.added = 0, this.conflicts = 0, this.profiles = 0, this.attributes = 0});

  final int learned;
  final int added;
  final int conflicts;

  /// Supplier profiles written to the product library, and attributes (0110).
  final int profiles;
  final int attributes;

  factory LearnResult.fromJson(Map<String, dynamic> j) {
    final l = (j['learned'] as Map?)?.cast<String, dynamic>() ?? const {};
    return LearnResult(
      learned: _int(l['learned']),
      added: _int(l['new']),
      conflicts: (l['conflicts'] as List? ?? const []).length,
      profiles: _int(l['profiles']),
      attributes: _int(l['attributes']),
    );
  }

  @override
  List<Object?> get props => [learned, added, conflicts];
}

/// The kinds of problem a reading can flag, and which ones need a person.
abstract final class NotationFlag {
  static const problems = {
    'unresolved', 'jan_check', 'ai_disagree', 'split_disagree', 'split_failed',
    'no_quantity', 'no_maker', 'amount_mismatch', 'added_by_check', 'dropped_by_check',
    'not_verified', 'jan_exponent',
    // The JAN checked against the 品番 on the same line (0113).
    'jan_restored', 'jan_restore_mismatch', 'jan_code_mismatch',
  };

  /// Worth a warning, but the reading is right (0113): a JAN shown in
  /// exponent form whose digits are all there; a quantity worked out from
  /// 金額÷単価 because none was printed on its line (0131).
  static const notices = {'jan_display_exponent', 'qty_from_amount'};

  static bool isProblem(String flag) => problems.contains(flag.split(':').first);

  /// Shown with a warning mark: a problem, or a notice.
  static bool isWarning(String flag) => isProblem(flag) || notices.contains(flag.split(':').first);

  /// The JAN warnings the import review counts at the top.
  static const janWarnings = {
    'jan_display_exponent', 'jan_exponent', 'jan_restored', 'jan_restore_mismatch', 'jan_code_mismatch', 'jan_check',
  };
}


/// One numbered version of a company's dictionary (0108, spec §60).
class LibraryVersion extends Equatable {
  const LibraryVersion({
    required this.id,
    required this.version,
    this.source = 'manual',
    this.note,
    this.dialectCount = 0,
    this.aliasCount = 0,
    this.added = 0,
    this.removed = 0,
    this.createdAt,
    this.createdByName,
  });

  final int id;
  final int version;

  /// manual / training / restore
  final String source;
  final String? note;
  final int dialectCount;
  final int aliasCount;
  final int added;
  final int removed;
  final DateTime? createdAt;
  final String? createdByName;

  factory LibraryVersion.fromJson(Map<String, dynamic> j) => LibraryVersion(
        id: _int(j['id']),
        version: _int(j['version']),
        source: (j['source'] ?? 'manual').toString(),
        note: _text(j['note']),
        dialectCount: _int(j['dialect_count']),
        aliasCount: _int(j['alias_count']),
        added: _int(j['added']),
        removed: _int(j['removed']),
        createdAt: DateTime.tryParse('${j['created_at'] ?? ''}'),
        createdByName: _text(j['created_by_name']),
      );

  @override
  List<Object?> get props => [id, version, dialectCount, aliasCount];
}

/// What bringing an old version back did.
class LibraryRestoreResult extends Equatable {
  const LibraryRestoreResult({this.dialects = 0, this.aliases = 0, this.conflicts = 0});

  final int dialects;
  final int aliases;
  final int conflicts;

  factory LibraryRestoreResult.fromJson(Map<String, dynamic> j) => LibraryRestoreResult(
        dialects: _int(j['restored_dialects']),
        aliases: _int(j['restored_aliases']),
        conflicts: (j['conflicts'] as List? ?? const []).length,
      );

  @override
  List<Object?> get props => [dialects, aliases, conflicts];
}

/// One heading a company uses for a field, in the field library (0112).
class FieldHeading extends Equatable {
  const FieldHeading({required this.id, required this.header, this.partnerId, this.partnerName, this.source, this.seenCount = 0});

  final int id;
  final String header;

  /// Null: everyone's heading.
  final int? partnerId;
  final String? partnerName;
  final String? source;
  final int seenCount;

  bool get isSeed => source == 'seed';

  factory FieldHeading.fromJson(Map<String, dynamic> j) => FieldHeading(
        id: _int(j['id']),
        header: (j['header'] ?? '').toString(),
        partnerId: _intOrNull(j['partner_id']),
        partnerName: _text(j['partner_name']),
        source: _text(j['source']),
        seenCount: _int(j['seen_count']),
      );

  @override
  List<Object?> get props => [id, header, partnerId];
}

/// A field of the library (0112): what a document column can mean, the
/// names we chose to show for it (per language; empty = the built-in
/// name), and every heading that means it.
class DocumentField extends Equatable {
  const DocumentField({
    required this.key,
    this.labels = const {},
    this.description,
    this.headings = const [],
  });

  final String key;
  final Map<String, String> labels;
  final String? description;
  final List<FieldHeading> headings;

  ColumnField? get field => ColumnField.parse(key);

  factory DocumentField.fromJson(Map<String, dynamic> j) => DocumentField(
        key: (j['key'] ?? '').toString(),
        labels: {
          for (final e in ((j['labels'] as Map?) ?? const {}).entries)
            if (_text(e.value) != null) e.key.toString(): _text(e.value)!,
        },
        description: _text(j['description']),
        headings: [for (final h in _rows(j['headings'])) FieldHeading.fromJson(h)],
      );

  @override
  List<Object?> get props => [key, labels, description, headings];
}

/// One of our product attributes in the library, with its headings.
class AttributeHeadings extends Equatable {
  const AttributeHeadings({required this.id, required this.key, required this.name, this.unit, this.active = true, this.headings = const []});

  final int id;
  final String key;
  final String name;
  final String? unit;
  final bool active;
  final List<FieldHeading> headings;

  factory AttributeHeadings.fromJson(Map<String, dynamic> j) => AttributeHeadings(
        id: _int(j['id']),
        key: (j['key'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        unit: _text(j['unit']),
        active: (j['status'] ?? 'active') == 'active',
        headings: [for (final h in _rows(j['headings'])) FieldHeading.fromJson(h)],
      );

  @override
  List<Object?> get props => [id, key, name, headings];
}

/// The whole field library.
class FieldLibrary extends Equatable {
  const FieldLibrary({this.fields = const [], this.attributes = const []});

  final List<DocumentField> fields;
  final List<AttributeHeadings> attributes;

  factory FieldLibrary.fromJson(Map<String, dynamic> j) => FieldLibrary(
        fields: [for (final f in _rows(j['fields'])) DocumentField.fromJson(f)],
        attributes: [for (final a in _rows(j['attributes'])) AttributeHeadings.fromJson(a)],
      );

  @override
  List<Object?> get props => [fields, attributes];
}

/// How one kind of warning has fared with the people who checked it (0113).
class WarningStat extends Equatable {
  const WarningStat({required this.flag, this.right = 0, this.wrong = 0, this.notes = const []});

  final String flag;
  final int right;
  final int wrong;

  /// The latest notes, newest first.
  final List<({String verdict, String note, String? partnerName})> notes;

  factory WarningStat.fromJson(Map<String, dynamic> j) => WarningStat(
        flag: (j['flag'] ?? '').toString(),
        right: _int(j['right']),
        wrong: _int(j['wrong']),
        notes: [
          for (final n in _rows(j['notes']))
            (verdict: (n['verdict'] ?? '').toString(), note: (n['note'] ?? '').toString(), partnerName: _text(n['partner_name'])),
        ],
      );

  @override
  List<Object?> get props => [flag, right, wrong];
}

/// What a document's lines add up to against what it says it totals (0114).
class ReadTotals extends Equatable {
  const ReadTotals({this.linesSum, this.docSubtotal, this.docTax, this.docTotal, this.matched, this.ok});

  final double? linesSum;
  final double? docSubtotal;
  final double? docTax;
  final double? docTotal;

  /// subtotal / total_minus_tax / total / found.
  final String? matched;

  /// null: nothing to compare with.
  final bool? ok;

  /// The document's figure the lines should come to.
  double? get expected => docSubtotal ?? (docTotal != null && docTax != null ? docTotal! - docTax! : docTotal);

  factory ReadTotals.fromJson(Map<String, dynamic> j) => ReadTotals(
        linesSum: _numOrNull(j['lines_sum']),
        docSubtotal: _numOrNull(j['doc_subtotal']),
        docTax: _numOrNull(j['doc_tax']),
        docTotal: _numOrNull(j['doc_total']),
        matched: _text(j['matched']),
        ok: j['ok'] is bool ? j['ok'] as bool : null,
      );

  Map<String, dynamic> toJson() => {
        'lines_sum': linesSum,
        'doc_subtotal': docSubtotal,
        'doc_tax': docTax,
        'doc_total': docTotal,
        'matched': matched,
        'ok': ok,
      };

  @override
  List<Object?> get props => [linesSum, docSubtotal, docTax, docTotal, matched, ok];
}
