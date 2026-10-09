import 'package:equatable/equatable.dart';

/// Digits only.
String janDigits(String s) => s.replaceAll(RegExp(r'\D'), '');

/// Whether [jan] (8 or 13 digits) carries the right check digit.
bool janCheckOk(String jan) {
  if (!RegExp(r'^\d+$').hasMatch(jan) || (jan.length != 8 && jan.length != 13)) return false;
  final body = jan.substring(0, jan.length - 1);
  var sum = 0;
  for (var i = 0; i < body.length; i++) {
    final d = body.codeUnitAt(body.length - 1 - i) - 48;
    sum += i.isEven ? d * 3 : d;
  }
  return (10 - sum % 10) % 10 == jan.codeUnitAt(jan.length - 1) - 48;
}

/// One line of a file on its way into 商品マスタ (0138): what the supplier
/// calls the product, the names we give it, and how many there are.
class MasterLine extends Equatable {
  const MasterLine({
    required this.lineNo,
    this.janCode = '',
    this.supplierName = '',
    this.name = '',
    this.nameEn = '',
    this.maker = '',
    this.productCode = '',
    this.supplierCode = '',
    this.spec = '',
    this.unit = '',
    this.listPrice = '',
    this.quantity = '',
    this.attributes = const [],
    this.flags = const [],
    this.knownProductId,
    this.knownName,
  });

  final int lineNo;
  final String janCode;

  /// 仕入先の商品名, as written.
  final String supplierName;

  /// 自社の商品名; empty means the supplier's name is used for a new product.
  final String name;

  /// 英語の商品名.
  final String nameEn;
  final String maker;
  final String productCode;
  final String supplierCode;
  final String spec;
  final String unit;
  final String listPrice;

  /// As typed or read, so a bad figure can be shown back.
  final String quantity;
  final List<Map<String, dynamic>> attributes;

  /// What the reader noticed (ai_disagree, jan_check …).
  final List<String> flags;

  /// The product 商品マスタ already has for this JAN, as the reader found it.
  final int? knownProductId;
  final String? knownName;

  static String _s(Object? v) {
    if (v == null) return '';
    if (v is double && v == v.roundToDouble()) return v.toInt().toString();
    return '$v'.trim();
  }

  /// A line as import-plan reads it.
  factory MasterLine.fromRead(Map<String, dynamic> l, int lineNo) {
    final p = l['product'];
    final jan = _s(l['jan_code']).isNotEmpty ? _s(l['jan_code']) : _s(l['raw_jan_code']);
    final qty = l['planned_quantity'] ?? l['quantity'];
    return MasterLine(
      lineNo: lineNo,
      janCode: jan,
      supplierName: _s(l['product_name']),
      maker: _s(l['maker']),
      productCode: _s(l['product_code']),
      supplierCode: _s(l['supplier_code']),
      spec: _s(l['spec']),
      unit: _s(l['unit']),
      listPrice: _s(l['list_price']),
      quantity: qty == null || (qty is num && qty == 0) ? '' : _s(qty),
      attributes: [for (final a in (l['attributes'] as List? ?? const []).whereType<Map>()) a.cast<String, dynamic>()],
      flags: [for (final f in (l['flags'] as List? ?? const [])) '$f'],
      knownProductId: (l['product_id'] as num?)?.toInt(),
      knownName: p is Map && _s(p['name']).isNotEmpty ? _s(p['name']) : null,
    );
  }

  MasterLine copyWith({
    int? lineNo,
    String? janCode,
    String? supplierName,
    String? name,
    String? nameEn,
    String? maker,
    String? productCode,
    String? supplierCode,
    String? spec,
    String? unit,
    String? listPrice,
    String? quantity,
    List<String>? flags,
  }) =>
      MasterLine(
        lineNo: lineNo ?? this.lineNo,
        janCode: janCode ?? this.janCode,
        supplierName: supplierName ?? this.supplierName,
        name: name ?? this.name,
        nameEn: nameEn ?? this.nameEn,
        maker: maker ?? this.maker,
        productCode: productCode ?? this.productCode,
        supplierCode: supplierCode ?? this.supplierCode,
        spec: spec ?? this.spec,
        unit: unit ?? this.unit,
        listPrice: listPrice ?? this.listPrice,
        quantity: quantity ?? this.quantity,
        attributes: attributes,
        flags: flags ?? this.flags,
        knownProductId: knownProductId,
        knownName: knownName,
      );

  /// The JAN as digits when it reads as one, else as written.
  String get jan {
    final d = janDigits(janCode);
    return d.length == 8 || d.length == 13 ? d : janCode.trim();
  }

  /// The quantity as a whole number; null when empty or not one.
  int? get quantityValue {
    final q = quantity.replaceAll(',', '').trim();
    return RegExp(r'^\d+$').hasMatch(q) ? int.parse(q) : null;
  }

  /// What `master_import_commit` takes.
  Map<String, dynamic> toJson() => {
        'line_no': lineNo,
        'jan_code': jan,
        'supplier_name': supplierName.trim(),
        if (name.trim().isNotEmpty) 'name': name.trim(),
        if (nameEn.trim().isNotEmpty) 'name_en': nameEn.trim(),
        if (maker.trim().isNotEmpty) 'maker': maker.trim(),
        if (productCode.trim().isNotEmpty) 'product_code': productCode.trim(),
        if (supplierCode.trim().isNotEmpty) 'supplier_code': supplierCode.trim(),
        if (spec.trim().isNotEmpty) 'spec': spec.trim(),
        if (unit.trim().isNotEmpty) 'unit': unit.trim(),
        if (listPrice.trim().isNotEmpty) 'list_price': listPrice.replaceAll(',', '').trim(),
        'quantity': quantity.replaceAll(',', '').trim(),
        if (attributes.isNotEmpty) 'attributes': attributes,
      };

  @override
  List<Object?> get props => [
        lineNo, janCode, supplierName, name, nameEn, maker, productCode, supplierCode, spec, unit, listPrice,
        quantity, flags, knownProductId,
      ];
}

/// Something that keeps a file out of 商品マスタ, or worth a look.
class MasterProblem extends Equatable {
  const MasterProblem(this.code, {this.lineNo = 0, this.value});

  /// jan_missing, jan_invalid, jan_duplicate, name_missing, qty_invalid,
  /// qty_missing, ai_disagree, totals_mismatch, unverified, no_lines,
  /// name_en_missing, ai_unavailable (value: no_key, auth, quota, network…).
  final String code;

  /// 0 for the file as a whole.
  final int lineNo;
  final String? value;

  /// Whether it stops the file. The rest are only shown.
  bool get blocking => !const {'qty_missing', 'name_en_missing'}.contains(code);

  factory MasterProblem.fromJson(Map<String, dynamic> j) => MasterProblem(
        '${j['code'] ?? ''}',
        lineNo: (j['line_no'] as num?)?.toInt() ?? 0,
        value: j['value']?.toString(),
      );

  Map<String, dynamic> toJson() => {'line_no': lineNo, 'code': code, if (value != null) 'value': value};

  @override
  List<Object?> get props => [code, lineNo, value];
}

/// The reader's flags that say a line cannot be trusted as read.
const _unsureFlags = {'ai_disagree', 'split_disagree', 'split_failed', 'jan_restore_mismatch', 'jan_code_mismatch'};

/// Everything that would stop [lines] going into 商品マスタ, in the order a
/// person would fix them — the same rules `master_import_problems` applies
/// on the server, plus what only the reading knows: lines the AI read two
/// ways ([checked] false), and a document whose own total disagrees with its
/// lines. Once a person has gone through the lines by hand or in Excel,
/// [checked] is true and only the lines themselves count.
List<MasterProblem> checkMasterLines(
  List<MasterLine> lines, {
  bool checked = false,
  bool verified = true,
  bool? totalsOk,
  String? aiFailure,
}) {
  final out = <MasterProblem>[];
  // The AI could not be used while reading: said first, as the reason the
  // names and columns below may be missing.
  if (!checked && aiFailure != null) out.add(MasterProblem('ai_unavailable', value: aiFailure));
  if (lines.isEmpty) return [...out, const MasterProblem('no_lines')];
  if (!checked && !verified) out.add(const MasterProblem('unverified'));
  if (!checked && totalsOk == false) out.add(const MasterProblem('totals_mismatch'));
  final seen = <String>{};
  for (final l in lines) {
    final jan = janDigits(l.janCode);
    if (l.janCode.trim().isEmpty) {
      out.add(MasterProblem('jan_missing', lineNo: l.lineNo));
    } else if ((jan.length != 8 && jan.length != 13) || !janCheckOk(jan)) {
      out.add(MasterProblem('jan_invalid', lineNo: l.lineNo, value: l.janCode));
    } else if (!seen.add(jan)) {
      out.add(MasterProblem('jan_duplicate', lineNo: l.lineNo, value: jan));
    }
    if (l.supplierName.trim().isEmpty && l.name.trim().isEmpty) {
      out.add(MasterProblem('name_missing', lineNo: l.lineNo));
    }
    if (l.quantity.trim().isEmpty) {
      out.add(MasterProblem('qty_missing', lineNo: l.lineNo));
    } else if (l.quantityValue == null) {
      out.add(MasterProblem('qty_invalid', lineNo: l.lineNo, value: l.quantity));
    }
    if (!checked && l.flags.any(_unsureFlags.contains)) {
      out.add(MasterProblem('ai_disagree', lineNo: l.lineNo));
    }
    if (l.nameEn.trim().isEmpty && l.knownProductId == null) {
      out.add(MasterProblem('name_en_missing', lineNo: l.lineNo));
    }
  }
  return out;
}

/// The Excel sheet a reading is turned into, and read back from. The headers
/// are the contract: a sheet sent back is matched by them, in any order.
class MasterSheet {
  const MasterSheet._();

  static const headers = [
    '行', 'JANコード', '仕入先の商品名', '自社の商品名', '英語の商品名', 'メーカー', '品番', '仕入先コード',
    '規格', '単位', '定価', '数量', '確認が必要な点',
  ];
  static const widths = [6.0, 16.0, 36.0, 30.0, 34.0, 16.0, 14.0, 14.0, 18.0, 8.0, 10.0, 8.0, 40.0];

  /// Header text → field, with the other ways people head these columns.
  static const _aliases = <String, String>{
    '行': 'line', 'no': 'line', 'no.': 'line', '#': 'line',
    'janコード': 'jan', 'jan': 'jan', 'janコード(13桁)': 'jan', 'バーコード': 'jan', 'barcode': 'jan',
    '仕入先の商品名': 'supplier_name', '商品名': 'supplier_name', '品名': 'supplier_name', 'product name': 'supplier_name',
    '自社の商品名': 'name', '自社商品名': 'name',
    '英語の商品名': 'name_en', '英語名': 'name_en', 'english name': 'name_en', 'name (en)': 'name_en',
    'メーカー': 'maker', 'maker': 'maker', 'brand': 'maker',
    '品番': 'code', '型番': 'code', 'sku': 'code', 'model': 'code',
    '仕入先コード': 'supplier_code', '仕入先品番': 'supplier_code',
    '規格': 'spec', 'spec': 'spec',
    '単位': 'unit', 'unit': 'unit',
    '定価': 'list_price', 'list price': 'list_price',
    '数量': 'qty', '数': 'qty', '個数': 'qty', '在庫数': 'qty', 'qty': 'qty', 'quantity': 'qty',
    '確認が必要な点': 'note',
  };

  static String _key(String h) => h.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// The rows of the sheet for [lines], and the cells to fill yellow: those
  /// of each line's [problems].
  static (List<List<Object?>>, Set<(int, int)>) rows(
    List<MasterLine> lines,
    List<MasterProblem> problems,
    String Function(MasterProblem) say,
  ) {
    const col = {
      'jan_missing': 1, 'jan_invalid': 1, 'jan_duplicate': 1, 'name_missing': 2, 'name_en_missing': 4,
      'qty_missing': 11, 'qty_invalid': 11,
    };
    final rows = <List<Object?>>[];
    final flagged = <(int, int)>{};
    for (final (i, l) in lines.indexed) {
      final mine = [for (final p in problems) if (p.lineNo == l.lineNo) p];
      for (final p in mine) {
        flagged.add((i, col[p.code] ?? 12));
      }
      if (mine.isNotEmpty) flagged.add((i, 12));
      rows.add([
        l.lineNo, l.jan, l.supplierName, l.name.isEmpty ? (l.knownName ?? '') : l.name, l.nameEn, l.maker,
        l.productCode, l.supplierCode, l.spec, l.unit, l.listPrice, l.quantityValue ?? l.quantity,
        mine.map(say).join(' / '),
      ]);
    }
    return (rows, flagged);
  }

  /// Lines from a sheet: the first row that has a JAN heading is the header
  /// row; every row under it with anything in it is a line. Throws
  /// [FormatException] when no JAN column is found.
  static List<MasterLine> parse(List<List<String>> table) {
    var headerAt = -1;
    Map<int, String> cols = {};
    for (final (i, row) in table.indexed) {
      final m = <int, String>{};
      for (final (c, h) in row.indexed) {
        final f = _aliases[_key(h)];
        if (f != null && !m.containsValue(f)) m[c] = f;
      }
      if (m.containsValue('jan')) {
        headerAt = i;
        cols = m;
        break;
      }
      if (i > 20) break;
    }
    if (headerAt < 0) throw const FormatException('no JAN column');
    String at(List<String> row, String field) {
      final c = cols.entries.where((e) => e.value == field).firstOrNull?.key;
      return c == null || c >= row.length ? '' : row[c].trim();
    }

    final out = <MasterLine>[];
    for (final row in table.skip(headerAt + 1)) {
      if (row.every((c) => c.trim().isEmpty)) continue;
      out.add(MasterLine(
        lineNo: out.length + 1,
        janCode: at(row, 'jan'),
        supplierName: at(row, 'supplier_name'),
        name: at(row, 'name'),
        nameEn: at(row, 'name_en'),
        maker: at(row, 'maker'),
        productCode: at(row, 'code'),
        supplierCode: at(row, 'supplier_code'),
        spec: at(row, 'spec'),
        unit: at(row, 'unit'),
        listPrice: at(row, 'list_price'),
        quantity: at(row, 'qty'),
      ));
    }
    return out;
  }
}

/// A file read for the import: its lines and what the reader thought of it.
class MasterRead extends Equatable {
  const MasterRead({
    required this.lines,
    this.source,
    this.verified = true,
    this.totalsOk,
    this.supplierId,
    this.supplierName,
    this.documentId,
    this.aiFailure,
  });

  final List<MasterLine> lines;

  /// Why the AI could not be used while reading (no_key, auth, quota,
  /// network, overload, bad_request), or null when it could.
  final String? aiFailure;

  /// xlsx, csv, pdf_text or gemini.
  final String? source;
  final bool verified;
  final bool? totalsOk;
  final int? supplierId;
  final String? supplierName;

  /// The copy import-plan kept as evidence (0132).
  final int? documentId;

  factory MasterRead.fromJson(Map<String, dynamic> j) {
    final totals = j['totals'];
    final header = j['header'];
    return MasterRead(
      lines: [
        for (final (i, l) in (j['lines'] as List? ?? const []).whereType<Map>().indexed)
          MasterLine.fromRead(l.cast<String, dynamic>(), i + 1),
      ],
      source: j['source']?.toString(),
      verified: j['verified'] != false,
      totalsOk: totals is Map ? totals['ok'] as bool? : null,
      supplierId: (j['partner_id'] as num?)?.toInt(),
      supplierName: header is Map ? header['supplier_name']?.toString() : null,
      documentId: (j['document_id'] as num?)?.toInt(),
      aiFailure: j['ai_failure'] is Map ? (j['ai_failure'] as Map)['kind']?.toString() : null,
    );
  }

  @override
  List<Object?> get props => [lines, source, verified, totalsOk, supplierId, documentId, aiFailure];
}

/// What stage 1 did, or why it stopped.
class MasterCommitResult extends Equatable {
  const MasterCommitResult({required this.ok, this.problems = const [], this.created = 0, this.updated = 0, this.mapped = 0});

  final bool ok;
  final List<MasterProblem> problems;
  final int created;
  final int updated;
  final int mapped;

  factory MasterCommitResult.fromJson(Map<String, dynamic> j) => MasterCommitResult(
        ok: j['ok'] == true,
        problems: [
          for (final p in (j['problems'] as List? ?? const []).whereType<Map>())
            MasterProblem.fromJson(p.cast<String, dynamic>()),
        ],
        created: (j['created'] as num?)?.toInt() ?? 0,
        updated: (j['updated'] as num?)?.toInt() ?? 0,
        mapped: (j['mapped'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [ok, problems, created, updated, mapped];
}

enum MasterImportStatus {
  reading('reading'),
  stopped('stopped'),
  masterDone('master_done'),
  stockDone('stock_done'),
  cancelled('cancelled');

  const MasterImportStatus(this.wire);
  final String wire;

  static MasterImportStatus fromWire(String? v) =>
      values.firstWhere((s) => s.wire == v, orElse: () => MasterImportStatus.reading);
}

/// A kept file of an import.
class MasterImportFile extends Equatable {
  const MasterImportFile({required this.kind, required this.name, required this.path});

  /// original, converted or corrected.
  final String kind;
  final String name;
  final String path;

  @override
  List<Object?> get props => [kind, name, path];
}

/// One line as the import keeps it: the product it became and, after the
/// second stage, the stock it found, as corrected, what was added and what
/// it came to.
class MasterImportLine extends Equatable {
  const MasterImportLine({
    required this.lineNo,
    required this.janCode,
    this.productId,
    this.name,
    this.nameEn,
    this.supplierName,
    this.quantity = 0,
    this.masterStatus,
    this.onHandBefore,
    this.onHandSet,
    this.added,
    this.onHandAfter,
    this.onHandNow,
  });

  final int lineNo;
  final String janCode;
  final int? productId;

  /// From 商品マスタ.
  final String? name;
  final String? nameEn;
  final String? supplierName;
  final int quantity;

  /// new or updated.
  final String? masterStatus;
  final int? onHandBefore;
  final int? onHandSet;
  final int? added;
  final int? onHandAfter;

  /// The stock in the warehouse asked about, now.
  final int? onHandNow;

  factory MasterImportLine.fromJson(Map<String, dynamic> j) {
    int? n(Object? v) => (v as num?)?.toInt();
    return MasterImportLine(
      lineNo: n(j['line_no']) ?? 0,
      janCode: '${j['jan_code'] ?? ''}',
      productId: n(j['product_id']),
      name: j['name']?.toString(),
      nameEn: j['name_en']?.toString(),
      supplierName: j['supplier_name']?.toString(),
      quantity: n(j['quantity']) ?? 0,
      masterStatus: j['master_status']?.toString(),
      onHandBefore: n(j['on_hand_before']),
      onHandSet: n(j['on_hand_set']),
      added: n(j['added']),
      onHandAfter: n(j['on_hand_after']),
      onHandNow: n(j['on_hand_now']),
    );
  }

  @override
  List<Object?> get props =>
      [lineNo, janCode, productId, name, nameEn, quantity, masterStatus, onHandBefore, onHandSet, added, onHandAfter, onHandNow];
}

/// An import: its files, where it got to, and its lines when asked for.
class MasterImport extends Equatable {
  const MasterImport({
    required this.id,
    required this.status,
    this.source,
    this.supplierName,
    this.warehouseName,
    this.files = const [],
    this.lineCount = 0,
    this.issues = const [],
    this.created = 0,
    this.updated = 0,
    this.stockLines = 0,
    this.stockAdded = 0,
    this.createdAt,
    this.createdByName,
    this.lines = const [],
  });

  final int id;
  final MasterImportStatus status;
  final String? source;
  final String? supplierName;
  final String? warehouseName;
  final List<MasterImportFile> files;
  final int lineCount;
  final List<MasterProblem> issues;
  final int created;
  final int updated;
  final int stockLines;
  final int stockAdded;
  final DateTime? createdAt;
  final String? createdByName;
  final List<MasterImportLine> lines;

  String? get originalName => files.where((f) => f.kind == 'original').firstOrNull?.name;

  factory MasterImport.fromJson(Map<String, dynamic> j) {
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    return MasterImport(
      id: n(j['id']),
      status: MasterImportStatus.fromWire(j['status']?.toString()),
      source: j['source']?.toString(),
      supplierName: j['supplier_name']?.toString(),
      warehouseName: j['warehouse_name']?.toString(),
      files: [
        for (final k in const ['original', 'converted', 'corrected'])
          if ('${j['${k}_path'] ?? ''}'.isNotEmpty)
            MasterImportFile(kind: k, name: '${j['${k}_name'] ?? j['${k}_path']}', path: '${j['${k}_path']}'),
      ],
      lineCount: n(j['line_count']),
      issues: [
        for (final p in (j['issues'] as List? ?? const []).whereType<Map>())
          MasterProblem.fromJson(p.cast<String, dynamic>()),
      ],
      created: n(j['master_created']),
      updated: n(j['master_updated']),
      stockLines: n(j['stock_lines']),
      stockAdded: n(j['stock_added']),
      createdAt: DateTime.tryParse('${j['created_at'] ?? ''}')?.toLocal(),
      createdByName: j['created_by_name']?.toString(),
      lines: [
        for (final l in (j['lines'] as List? ?? const []).whereType<Map>())
          MasterImportLine.fromJson(l.cast<String, dynamic>()),
      ],
    );
  }

  @override
  List<Object?> get props => [id, status, files, lineCount, issues, created, updated, stockLines, stockAdded, lines];
}
