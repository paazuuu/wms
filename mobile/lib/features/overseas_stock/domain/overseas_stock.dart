import 'package:equatable/equatable.dart';

import '../../master_import/domain/master_import.dart' show MasterLine;
import '../../outbound_file/domain/outbound_sheet.dart';

String? _s(Object? v) {
  final t = v?.toString().trim();
  return t == null || t.isEmpty ? null : t;
}

int? _ni(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
num _n(Object? v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;
DateTime? _d(Object? v) => DateTime.tryParse('${v ?? ''}');

/// A branch of ours or a partner company abroad whose stock we keep a rough
/// eye on (0207) — apart from our own stock.
class OverseasSite extends Equatable {
  const OverseasSite({
    required this.id,
    required this.name,
    this.kind = 'branch',
    this.country,
    this.city,
    this.contact,
    this.note,
    this.archivedAt,
    this.latest,
    this.importCount = 0,
    this.noteCount = 0,
    this.destinationId,
    this.destinationName,
    this.isDefault = false,
    this.shipmentCount = 0,
    this.shippedUnits = 0,
    this.lastShippedOn,
    this.estimateUnits = 0,
    this.estimateItems = 0,
  });

  /// The 出荷先カード the site sums up (0209); what is shipped to it is kept here.
  final int? destinationId;
  final String? destinationName;

  /// 国外の仮想在庫（中国・広東）, made with its card (0209).
  final bool isDefault;
  final int shipmentCount;
  final num shippedUnits;
  final DateTime? lastShippedOn;

  /// The last count the partner gave plus what was shipped since.
  final num estimateUnits;
  final int estimateItems;

  final int id;
  final String name;

  /// branch (自社の支店) or partner (パートナー会社).
  final String kind;
  final String? country;
  final String? city;
  final String? contact;
  final String? note;
  final DateTime? archivedAt;

  /// The file that is its stock now.
  final OverseasImport? latest;
  final int importCount;
  final int noteCount;

  bool get partner => kind == 'partner';
  bool get archived => archivedAt != null;

  factory OverseasSite.fromJson(Map<String, dynamic> j) => OverseasSite(
        id: _ni(j['id']) ?? 0,
        name: _s(j['name']) ?? '',
        kind: _s(j['kind']) ?? 'branch',
        country: _s(j['country']),
        city: _s(j['city']),
        contact: _s(j['contact']),
        note: _s(j['note']),
        archivedAt: _d(j['archived_at']),
        latest: j['latest'] is Map ? OverseasImport.fromJson((j['latest'] as Map).cast<String, dynamic>()) : null,
        importCount: _ni(j['import_count']) ?? 0,
        noteCount: _ni(j['note_count']) ?? 0,
        destinationId: _ni(j['destination_id']),
        destinationName: _s(j['destination_name']),
        isDefault: j['is_default'] == true,
        shipmentCount: _ni(j['shipment_count']) ?? 0,
        shippedUnits: _n(j['shipped_units']),
        lastShippedOn: _d(j['last_shipped_on']),
        estimateUnits: _n(j['estimate_units']),
        estimateItems: _ni(j['estimate_items']) ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id == 0 ? null : id,
        'name': name,
        'kind': kind,
        'country': country,
        'city': city,
        'contact': contact,
        'note': note,
      };

  @override
  List<Object?> get props =>
      [id, name, kind, country, city, contact, note, archivedAt, latest, importCount, noteCount, destinationId, shipmentCount, estimateUnits];
}

/// One file read for a site, as of a day.
class OverseasImport extends Equatable {
  const OverseasImport({
    required this.id,
    this.asOf,
    this.fileName,
    this.storagePath,
    this.readPath,
    this.sheetName,
    this.readBy = 'sheet',
    this.lineCount = 0,
    this.units = 0,
    this.note,
    this.createdAt,
    this.createdByName,
    this.undoneAt,
  });

  final int id;
  final DateTime? asOf;
  final String? fileName;
  final String? storagePath;

  /// What was read, kept as Excel beside the file (0208).
  final String? readPath;
  final String? sheetName;

  /// sheet (the columns of a sheet), ai (read by the AI), manual.
  final String readBy;
  final int lineCount;
  final num units;
  final String? note;
  final DateTime? createdAt;
  final String? createdByName;
  final DateTime? undoneAt;

  bool get undone => undoneAt != null;

  factory OverseasImport.fromJson(Map<String, dynamic> j) => OverseasImport(
        id: _ni(j['id']) ?? 0,
        asOf: _d(j['as_of']),
        fileName: _s(j['file_name']),
        storagePath: _s(j['storage_path']),
        readPath: _s(j['read_path']),
        sheetName: _s(j['sheet_name']),
        readBy: _s(j['read_by']) ?? 'sheet',
        lineCount: _ni(j['line_count']) ?? 0,
        units: _n(j['units']),
        note: _s(j['note']),
        createdAt: _d(j['created_at'])?.toLocal(),
        createdByName: _s(j['created_by_name']),
        undoneAt: _d(j['undone_at']),
      );

  @override
  List<Object?> get props => [id, asOf, fileName, readBy, lineCount, units, undoneAt];
}

/// A row of a site's stock.
class OverseasLine extends Equatable {
  const OverseasLine({
    this.rowNo,
    this.jan,
    this.code,
    this.name,
    this.maker,
    this.quantity = 0,
    this.unit,
    this.ours,
    this.raw = const {},
  });

  final int? rowNo;
  final String? jan;
  final String? code;
  final String? name;
  final String? maker;
  final num quantity;
  final String? unit;

  /// Our product's name, when its JAN is in our library (pointed out only).
  final String? ours;
  final Map<String, String> raw;

  String get label => name ?? code ?? jan ?? '';

  factory OverseasLine.fromJson(Map<String, dynamic> j) => OverseasLine(
        rowNo: _ni(j['row_no']),
        jan: _s(j['jan']),
        code: _s(j['code']),
        name: _s(j['name']),
        maker: _s(j['maker']),
        quantity: _n(j['quantity']),
        unit: _s(j['unit']),
        ours: _s(j['ours']),
        raw: {
          if (j['raw'] is Map)
            for (final e in (j['raw'] as Map).entries) '${e.key}': '${e.value}',
        },
      );

  /// What `overseas_stock_import` takes.
  Map<String, dynamic> toJson() => {
        'row_no': rowNo,
        'jan': jan,
        'code': code,
        'name': name,
        'maker': maker,
        'quantity': quantity,
        'unit': unit,
        if (raw.isNotEmpty) 'raw': raw,
      };

  OverseasLine withQuantity(num q) =>
      OverseasLine(rowNo: rowNo, jan: jan, code: code, name: name, maker: maker, quantity: q, unit: unit, ours: ours, raw: raw);

  @override
  List<Object?> get props => [rowNo, jan, code, name, maker, quantity, unit, ours];
}

/// A site's stock: the file it is from and its rows.
class OverseasStock extends Equatable {
  const OverseasStock({this.import, this.lines = const []});

  final OverseasImport? import;
  final List<OverseasLine> lines;

  factory OverseasStock.fromJson(Map<String, dynamic> j) => OverseasStock(
        import: j['import'] is Map ? OverseasImport.fromJson((j['import'] as Map).cast<String, dynamic>()) : null,
        lines: [for (final l in (j['lines'] as List? ?? const []).whereType<Map>()) OverseasLine.fromJson(l.cast<String, dynamic>())],
      );

  @override
  List<Object?> get props => [import, lines];
}

/// What one site holds of a product, within the overview.
class OverseasHolding extends Equatable {
  const OverseasHolding({required this.siteId, required this.siteName, this.kind = 'branch', this.country, this.quantity = 0, this.asOf});

  final int siteId;
  final String siteName;
  final String kind;
  final String? country;
  final num quantity;
  final DateTime? asOf;

  factory OverseasHolding.fromJson(Map<String, dynamic> j) => OverseasHolding(
        siteId: _ni(j['site_id']) ?? 0,
        siteName: _s(j['site_name']) ?? '',
        kind: _s(j['kind']) ?? 'branch',
        country: _s(j['country']),
        quantity: _n(j['quantity']),
        asOf: _d(j['as_of']),
      );

  @override
  List<Object?> get props => [siteId, quantity, asOf];
}

/// A product across the sites' stock now.
class OverseasProduct extends Equatable {
  const OverseasProduct({this.jan, this.code, this.name, this.maker, this.unit, this.total = 0, this.sites = const [], this.ours});

  final String? jan;
  final String? code;
  final String? name;
  final String? maker;
  final String? unit;
  final num total;
  final List<OverseasHolding> sites;
  final String? ours;

  String get label => name ?? code ?? jan ?? '';

  factory OverseasProduct.fromJson(Map<String, dynamic> j) => OverseasProduct(
        jan: _s(j['jan']),
        code: _s(j['code']),
        name: _s(j['name']),
        maker: _s(j['maker']),
        unit: _s(j['unit']),
        total: _n(j['total']),
        ours: _s(j['ours']),
        sites: [for (final s in (j['sites'] as List? ?? const []).whereType<Map>()) OverseasHolding.fromJson(s.cast<String, dynamic>())],
      );

  @override
  List<Object?> get props => [jan, code, name, total, sites];
}

/// The columns a site's stock list is read by.
const overseasColumns = [
  OutboundColumn.jan,
  OutboundColumn.code,
  OutboundColumn.name,
  OutboundColumn.maker,
  OutboundColumn.quantity,
];

/// A sheet's rows as stock rows: those with a JAN, 品番 or name and a
/// quantity (a total line, a blank one left out).
List<OverseasLine> overseasLinesFromSheet(OutboundSheet sheet) => [
      for (final r in sheet.rows)
        if ((r.jan.isNotEmpty || r.code != null || r.name != null) && r.quantity != null)
          OverseasLine(
            rowNo: r.rowNo,
            jan: r.jan.isEmpty ? (r.janRaw.isEmpty ? null : r.janRaw) : r.jan,
            code: r.code,
            name: r.name,
            maker: r.maker,
            quantity: r.quantity!,
            raw: r.raw,
          ),
    ];

/// The rows the AI read (import-plan) as stock rows.
List<OverseasLine> overseasLinesFromAi(List<MasterLine> lines) => [
      for (final l in lines)
        if ((l.janCode.isNotEmpty || l.productCode.isNotEmpty || l.name.isNotEmpty))
          OverseasLine(
            rowNo: l.lineNo,
            jan: l.janCode.isEmpty ? null : l.janCode,
            code: l.productCode.isNotEmpty ? l.productCode : (l.supplierCode.isEmpty ? null : l.supplierCode),
            name: l.name.isEmpty ? null : l.name,
            maker: l.maker.isEmpty ? null : l.maker,
            quantity: num.tryParse(l.quantity.replaceAll(',', '').trim()) ?? 0,
            unit: l.unit.isEmpty ? null : l.unit,
          ),
    ];

/// What a reading field (import-plan's map_columns) is as a column here.
OutboundColumn? overseasColumnOfField(String field) => switch (field) {
      'jan' => OutboundColumn.jan,
      'quantity' => OutboundColumn.quantity,
      'product_name' || 'name_code' => OutboundColumn.name,
      'product_code' || 'supplier_code' => OutboundColumn.code,
      'maker' => OutboundColumn.maker,
      _ => null,
    };

/// Whether a file is read as a sheet here (else the AI reads it).
bool overseasReadsAsSheet(String fileName) {
  final n = fileName.toLowerCase();
  return n.endsWith('.xlsx') || n.endsWith('.xlsm') || n.endsWith('.csv') || n.endsWith('.tsv') || n.endsWith('.txt');
}
