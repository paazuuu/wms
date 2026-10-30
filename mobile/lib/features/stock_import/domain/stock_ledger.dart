import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Where an import's date came from (0148).
enum DocumentDateSource {
  /// Printed in the file: 発行日, 作成日, 請求日 and the like.
  content('content'),

  /// Not printed in it: the day it was uploaded.
  uploaded('uploaded'),

  /// Set by hand afterwards.
  manual('manual');

  const DocumentDateSource(this.wire);
  final String wire;

  static DocumentDateSource? fromWire(String? v) => values.where((s) => s.wire == v).firstOrNull;
}

/// The date an import is filed under, and how it was found.
class DocumentDate extends Equatable {
  const DocumentDate(this.date, this.source);

  final DateTime date;
  final DocumentDateSource source;

  /// YYYY-MM-DD, as the database takes it.
  String get wire =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  List<Object?> get props => [wire, source];
}

/// A date that could be a document's: from 2000 up to a month ahead.
DateTime? _plausible(int y, int m, int d, DateTime now) {
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  final t = DateTime(y, m, d);
  if (t.month != m || t.day != d) return null;
  if (t.isBefore(DateTime(2000)) || t.isAfter(now.add(const Duration(days: 31)))) return null;
  return t;
}

final _ymd = RegExp(r'(20\d{2})\s*[年/\-.．]\s*(\d{1,2})\s*[月/\-.．]\s*(\d{1,2})\s*日?');
final _reiwa = RegExp(r'(?:令和|R)\s*(\d{1,2}|元)\s*[年/\-.．]\s*(\d{1,2})\s*[月/\-.．]\s*(\d{1,2})');
final _iso = RegExp(r'^(20\d{2})-(\d{2})-(\d{2})');

/// The first date in [text]: 2026年8月19日, 2026/8/19, 2026-08-19, 令和8年8月19日.
DateTime? dateIn(String text, {DateTime? now}) {
  final at = now ?? DateTime.now();
  for (final m in _ymd.allMatches(text)) {
    final t = _plausible(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!), at);
    if (t != null) return t;
  }
  for (final m in _reiwa.allMatches(text)) {
    final y = m[1] == '元' ? 1 : int.parse(m[1]!);
    final t = _plausible(2018 + y, int.parse(m[2]!), int.parse(m[3]!), at);
    if (t != null) return t;
  }
  return null;
}

/// Words that put a date on the document itself, likeliest first.
const _dateLabels = ['発行日', '作成日', '請求日', '発行', '作成', '請求', '納品日', '出荷日', '伝票日付', '日付'];

/// The document's date as a sheet prints it above (or beside) its table: a
/// cell that names it (発行日 …) with the date in it or just after it, else
/// the first date in the top rows.
DateTime? dateInRows(List<List<String>> rows, {DateTime? now}) {
  final top = rows.take(15).toList();
  DateTime? cellDate(String s) {
    final t = dateIn(s, now: now);
    if (t != null) return t;
    // A date cell an .xlsx keeps as a serial number (days since 1899-12-30).
    final n = double.tryParse(s.trim());
    if (n != null && n >= 36526 && n < 80000 && n == n.roundToDouble()) {
      final d = DateTime(1899, 12, 30).add(Duration(days: n.toInt()));
      return _plausible(d.year, d.month, d.day, now ?? DateTime.now());
    }
    return null;
  }

  for (final label in _dateLabels) {
    for (final row in top) {
      for (var c = 0; c < row.length; c++) {
        if (!row[c].contains(label)) continue;
        final here = dateIn(row[c], now: now);
        if (here != null) return here;
        for (var k = c + 1; k < row.length && k <= c + 3; k++) {
          final t = cellDate(row[k]);
          if (t != null) return t;
        }
      }
    }
  }
  for (final row in top) {
    for (final cell in row) {
      final t = dateIn(cell, now: now);
      if (t != null) return t;
    }
  }
  return null;
}

/// The date an import is filed under (0148): what the file prints (the AI's
/// reading of it, or the sheet's top rows), else the upload day. The file's
/// own creation date is not used: it is when the file was saved, not the
/// document's date.
DocumentDate findDocumentDate({
  required String fileName,
  required Uint8List bytes,
  List<List<String>>? rows,
  String? readDate,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final m = readDate == null ? null : _iso.firstMatch(readDate.trim());
  final fromRead = m == null ? null : _plausible(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!), at);
  final content = fromRead ?? (rows == null ? null : dateInRows(rows, now: at));
  if (content != null) return DocumentDate(content, DocumentDateSource.content);
  return DocumentDate(DateTime(at.year, at.month, at.day), DocumentDateSource.uploaded);
}

/// How long a stock file is kept after its date (0148); the day after, it
/// is deleted.
const keepYears = 7;

/// The last day [date]'s import is kept.
DateTime keptUntil(DateTime date) => DateTime(date.year + keepYears, date.month, date.day).subtract(const Duration(days: 1));

/// A stock file waiting for its inspection (0148).
class AwaitingImport extends Equatable {
  const AwaitingImport({
    required this.id,
    this.fileName,
    this.warehouseId,
    this.warehouseName,
    this.createdAt,
    this.documentDate,
    this.createdByName,
    this.lines = 0,
    this.left = 0,
    this.quantityLeft = 0,
  });

  final int id;
  final String? fileName;
  final int? warehouseId;
  final String? warehouseName;
  final DateTime? createdAt;
  final DateTime? documentDate;
  final String? createdByName;
  final int lines;

  /// Lines not yet inspected, and their units.
  final int left;
  final int quantityLeft;

  factory AwaitingImport.fromJson(Map<String, dynamic> j) {
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    return AwaitingImport(
      id: n(j['id']),
      fileName: j['original_name']?.toString(),
      warehouseId: (j['warehouse_id'] as num?)?.toInt(),
      warehouseName: j['warehouse_name']?.toString(),
      createdAt: DateTime.tryParse('${j['created_at'] ?? ''}')?.toLocal(),
      documentDate: DateTime.tryParse('${j['document_date'] ?? ''}'),
      createdByName: j['created_by_name']?.toString(),
      lines: n(j['lines']),
      left: n(j['left']),
      quantityLeft: n(j['quantity_left']),
    );
  }

  @override
  List<Object?> get props => [id, fileName, warehouseId, lines, left, quantityLeft];
}

/// A stock file on the calendar (0148).
class CalendarImport extends Equatable {
  const CalendarImport({
    required this.id,
    required this.day,
    this.source,
    this.fileName,
    this.warehouseName,
    this.status,
    this.undone = false,
    this.lines = 0,
    this.change = 0,
    this.paid = false,
    this.note,
    this.createdAt,
    this.dayKind = 'document',
    this.documentDate,
    this.proofCount = 0,
  });

  final int id;

  /// Transfer proofs kept for it (0173).
  final int proofCount;

  /// Inspected and in stock (a count correction goes in at once).
  bool get inStock => status == 'stock_done' && !undone;

  /// The day it is shown on: its document's date, or the day it came in
  /// (0165: on both, when they differ).
  final DateTime day;

  /// document, imported, or both (the same day).
  final String dayKind;
  final DateTime? documentDate;
  final DocumentDateSource? source;
  final String? fileName;
  final String? warehouseName;
  final String? status;
  final bool undone;
  final int lines;
  final int change;
  final bool paid;
  final String? note;
  final DateTime? createdAt;

  bool get awaiting => status == 'awaiting_inspection' && !undone;

  factory CalendarImport.fromJson(Map<String, dynamic> j) {
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    final d = DateTime.tryParse('${j['day'] ?? ''}') ?? DateTime(2000);
    return CalendarImport(
      id: n(j['id']),
      day: DateTime(d.year, d.month, d.day),
      source: DocumentDateSource.fromWire(j['document_date_source']?.toString()),
      fileName: j['original_name']?.toString(),
      warehouseName: j['warehouse_name']?.toString(),
      status: j['status']?.toString(),
      undone: j['undone_at'] != null,
      lines: n(j['stock_lines']) > 0 ? n(j['stock_lines']) : n(j['line_count']),
      change: n(j['stock_added']),
      paid: j['paid'] == true,
      note: j['note']?.toString(),
      createdAt: DateTime.tryParse('${j['created_at'] ?? ''}')?.toLocal(),
      dayKind: j['day_kind']?.toString() ?? 'document',
      documentDate: DateTime.tryParse('${j['document_date'] ?? ''}'),
      proofCount: n(j['proof_count']),
    );
  }

  @override
  List<Object?> get props => [id, day, dayKind, status, undone, lines, change, paid, note, proofCount];
}

/// One line as the inspector counted it.
class InspectedLine {
  const InspectedLine(this.lineNo, this.quantity);
  final int lineNo;
  final int quantity;

  Map<String, dynamic> toJson() => {'line_no': lineNo, 'quantity': quantity};
}

/// What an inspection booked.
class InspectionResult extends Equatable {
  const InspectionResult({this.lines = 0, this.change = 0, this.difference = 0, this.left = 0});

  final int lines;
  final int change;

  /// Counted minus the file's, over the lines checked.
  final int difference;

  /// Lines still to check.
  final int left;

  factory InspectionResult.fromJson(Map<String, dynamic> j) {
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    return InspectionResult(lines: n(j['lines']), change: n(j['change']), difference: n(j['difference']), left: n(j['left']));
  }

  @override
  List<Object?> get props => [lines, change, difference, left];
}

/// Units read in from files and waiting for inspection (0148), by warehouse
/// and JAN — shown beside the stock, never added into it.
class PendingInspection extends Equatable {
  const PendingInspection([this._byWarehouse = const {}]);

  /// warehouse → JAN → units.
  final Map<int, Map<String, int>> _byWarehouse;

  factory PendingInspection.fromRows(Iterable<Map> rows) {
    final out = <int, Map<String, int>>{};
    for (final e in rows) {
      final w = (e['warehouse_id'] as num?)?.toInt() ?? 0;
      final jan = '${e['jan_code'] ?? ''}';
      final q = (e['quantity'] as num?)?.toInt() ?? 0;
      final m = out.putIfAbsent(w, () => {});
      m[jan] = (m[jan] ?? 0) + q;
    }
    return PendingInspection(out);
  }

  bool get isEmpty => _byWarehouse.values.every((m) => m.isEmpty);

  /// [jan]'s units waiting in [warehouseId], or in every warehouse.
  int of(String jan, {int? warehouseId}) => warehouseId != null
      ? (_byWarehouse[warehouseId]?[jan] ?? 0)
      : _byWarehouse.values.fold(0, (s, m) => s + (m[jan] ?? 0));

  /// [jan]'s units waiting, warehouse by warehouse (only those with some).
  Map<int, int> byWarehouse(String jan) => {
        for (final e in _byWarehouse.entries)
          if ((e.value[jan] ?? 0) > 0) e.key: e.value[jan]!,
      };

  @override
  List<Object?> get props => [_byWarehouse];
}
