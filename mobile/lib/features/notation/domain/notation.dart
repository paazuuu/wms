import 'package:equatable/equatable.dart';

int _int(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
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
  amount('amount'),
  spec('spec'),
  taxRate('tax_rate'),
  orderDate('order_date'),
  ignore('ignore');

  const ColumnField(this.wire);
  final String wire;

  static ColumnField? parse(String? v) {
    for (final f in values) {
      if (f.wire == v) return f;
    }
    return null;
  }
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
  });

  final int index;
  final String header;
  final ColumnField? field;

  /// partner (this company's learned heading), global, contains, values, ai,
  /// override (corrected by hand).
  final String? source;
  final ColumnField? aiField;
  final bool conflict;

  factory ReadColumn.fromJson(Map<String, dynamic> j) => ReadColumn(
        index: _int(j['index']),
        header: (j['header'] ?? '').toString(),
        field: ColumnField.parse(j['field'] as String?),
        source: _text(j['source']),
        aiField: ColumnField.parse(j['ai_field'] as String?),
        conflict: j['conflict'] == true,
      );

  Map<String, dynamic> toJson() => {'index': index, 'header': header, 'field': field?.wire};

  ReadColumn withField(ColumnField? f) => ReadColumn(
      index: index, header: header, field: f, source: 'override', aiField: aiField);

  @override
  List<Object?> get props => [index, header, field, source, aiField, conflict];
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
      );

  /// What is taught from this line: the company's writing, tied to ours.
  Map<String, dynamic> toLearnJson() => {
        'product_id': product?.id,
        'raw_jan_code': rawJanCode,
        'maker': maker,
        'product_name': productName,
        'product_code': productCode,
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
  });

  final int? trainingId;
  final int? partnerId;
  final String? source;

  /// Whether the AI's check pass ran (a PDF or photo is read twice).
  final bool verified;
  final List<ReadColumn> columns;
  final List<ReadLineResult> lines;

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
      );

  TrainingRead copyWith({List<ReadColumn>? columns, List<ReadLineResult>? lines}) => TrainingRead(
        trainingId: trainingId,
        partnerId: partnerId,
        source: source,
        verified: verified,
        columns: columns ?? this.columns,
        lines: lines ?? this.lines,
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
  });

  final int id;
  final String header;
  final ColumnField? field;
  final int? partnerId;
  final String? partnerName;
  final String? source;
  final int seenCount;

  bool get isSeed => source == 'seed';

  factory ColumnAlias.fromJson(Map<String, dynamic> j) => ColumnAlias(
        id: _int(j['id']),
        header: (j['header'] ?? '').toString(),
        field: ColumnField.parse(j['field'] as String?),
        partnerId: _intOrNull(j['partner_id']),
        partnerName: _text(j['partner_name']),
        source: _text(j['source']),
        seenCount: _int(j['seen_count']),
      );

  @override
  List<Object?> get props => [id, header, field];
}

/// What was learned from a checked sample.
class LearnResult extends Equatable {
  const LearnResult({this.learned = 0, this.added = 0, this.conflicts = 0});

  final int learned;
  final int added;
  final int conflicts;

  factory LearnResult.fromJson(Map<String, dynamic> j) {
    final l = (j['learned'] as Map?)?.cast<String, dynamic>() ?? const {};
    return LearnResult(
      learned: _int(l['learned']),
      added: _int(l['new']),
      conflicts: (l['conflicts'] as List? ?? const []).length,
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
    'not_verified',
  };

  static bool isProblem(String flag) => problems.contains(flag.split(':').first);
}
