import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../../core/export/xlsx.dart';
import '../../qc/domain/inspection.dart' show normalizeJan;

/// How a stock file's quantities are taken (0144).
enum StockFileMode {
  /// Each quantity is added to what the warehouse has.
  add('add'),

  /// The warehouse's stock becomes each quantity.
  set('set');

  const StockFileMode(this.wire);
  final String wire;
}

/// One product's quantity from a stock file. [lineNo] is the sheet's own
/// row number, so a problem can say where to look.
class StockFileLine extends Equatable {
  const StockFileLine({
    required this.lineNo,
    required this.janCode,
    required this.quantity,
    this.name,
    this.merged = 1,
    this.doubtful = false,
    this.maker,
    this.code,
  });

  final int lineNo;
  final String janCode;
  final int quantity;
  final String? name;

  /// The file's maker and 品番 for it, when it had them: what a product made
  /// from this line is registered with.
  final String? maker;
  final String? code;

  /// How many of the file's rows had this JAN (their quantities summed).
  final int merged;

  /// The AI was not sure of this line (its two readings disagreed, or the
  /// JAN's check digit failed): to be looked at before it goes in.
  final bool doubtful;

  StockFileLine copyWith({int? quantity}) => StockFileLine(
        lineNo: lineNo,
        janCode: janCode,
        quantity: quantity ?? this.quantity,
        name: name,
        merged: merged,
        doubtful: doubtful,
        maker: maker,
        code: code,
      );

  /// The line as 価格台帳 takes it, to register its product.
  Map<String, dynamic> toPriceBookLine() => {
        'jan_code': janCode,
        'product_name': name,
        if (maker != null) 'maker': maker,
        if (code != null) 'product_code': code,
      };

  Map<String, dynamic> toJson() => {'line_no': lineNo, 'jan_code': janCode, 'quantity': quantity};

  @override
  List<Object?> get props => [lineNo, janCode, quantity, name, merged, doubtful, maker, code];
}

/// A row the file had that cannot be taken: its row number and why.
class StockFileProblem extends Equatable {
  const StockFileProblem(this.lineNo, this.code, {this.value});

  final int lineNo;

  /// `no_jan`, `bad_quantity`, `unknown_jan`.
  final String code;
  final String? value;

  @override
  List<Object?> get props => [lineNo, code, value];
}

/// One row of the file as it was read, before anything was made of it: its
/// JAN, name and quantity as the file has them, and what the reader was
/// unsure of. Kept with the import (0146) so it can be set beside the
/// original.
class ReadRow extends Equatable {
  const ReadRow({
    required this.lineNo,
    this.jan = '',
    this.name = '',
    this.quantity = '',
    this.maker = '',
    this.code = '',
    this.flags = const [],
  });

  final int lineNo;
  final String jan;
  final String name;
  final String quantity;
  final String maker;
  final String code;
  final List<String> flags;

  Map<String, dynamic> toJson() => {
        'line_no': lineNo,
        'jan': jan,
        'name': name,
        'quantity': quantity,
        if (maker.isNotEmpty) 'maker': maker,
        if (code.isNotEmpty) 'code': code,
        if (flags.isNotEmpty) 'flags': flags,
      };

  factory ReadRow.fromJson(Map<String, dynamic> j) => ReadRow(
        lineNo: (j['line_no'] as num?)?.toInt() ?? 0,
        jan: '${j['jan'] ?? ''}',
        name: '${j['name'] ?? ''}',
        quantity: '${j['quantity'] ?? ''}',
        maker: '${j['maker'] ?? ''}',
        code: '${j['code'] ?? ''}',
        flags: [for (final f in (j['flags'] as List? ?? const [])) '$f'],
      );

  @override
  List<Object?> get props => [lineNo, jan, name, quantity, maker, code, flags];
}

/// What a stock file holds: its lines, one per JAN, and the rows that could
/// not be read. [header] is false when no JAN and quantity columns were
/// found at all.
class StockSheet extends Equatable {
  const StockSheet({
    this.lines = const [],
    this.problems = const [],
    this.header = true,
    this.byAi = false,
    this.read = const [],
  });

  final List<StockFileLine> lines;

  /// Every row as it was read, lines and problems alike.
  final List<ReadRow> read;
  final List<StockFileProblem> problems;
  final bool header;

  /// Read by the AI (a PDF, a picture, or a sheet without the headings),
  /// not cell by cell: its lines are to be checked by eye.
  final bool byAi;

  StockSheet copyWith({List<StockFileLine>? lines}) =>
      StockSheet(lines: lines ?? this.lines, problems: problems, header: header, byAi: byAi, read: read);

  @override
  List<Object?> get props => [lines, problems, header, byAi, read];
}

String _key(String s) => s.toLowerCase().replaceAll(RegExp(r'[\s　_\-()（）・/]'), '');

const _janNames = {'jan', 'janコード', 'jancode', 'バーコード', 'barcode', 'ean', 'ean13', 'janno'};
const _qtyNames = {'数量', '在庫数', '在庫', '個数', '入庫数', '実在庫', '実在庫数', 'qty', 'quantity', 'stock', 'onhand'};
const _nameNames = {'商品名', '品名', '名称', 'name', 'productname', 'itemname'};
const _makerNames = {'メーカー', 'メーカー名', 'maker', 'brand', 'manufacturer'};
const _codeNames = {'品番', '型番', '商品コード', 'sku', 'itemcode', 'productcode'};

/// Reads the rows of a stock sheet: the first row (of the top ten) naming a
/// JAN column and a quantity column is the header. A JAN is any 8–14 digits
/// (full-width too) and is normalized as the scanner does; a quantity is a
/// whole number of 0 or more. The same JAN twice is one line, its
/// quantities summed.
StockSheet parseStockRows(List<List<String>> rows) {
  var head = -1, jan = -1, qty = -1, name = -1, makerCol = -1, codeCol = -1;
  for (var r = 0; r < rows.length && r < 10; r++) {
    final keys = [for (final c in rows[r]) _key(c)];
    final j = keys.indexWhere(_janNames.contains);
    final q = keys.indexWhere(_qtyNames.contains);
    if (j >= 0 && q >= 0) {
      head = r;
      jan = j;
      qty = q;
      name = keys.indexWhere(_nameNames.contains);
      makerCol = keys.indexWhere(_makerNames.contains);
      codeCol = keys.indexWhere(_codeNames.contains);
      break;
    }
  }
  if (head < 0) return const StockSheet(header: false);

  final byJan = <String, StockFileLine>{};
  final problems = <StockFileProblem>[];
  final read = <ReadRow>[];
  String at(List<String> row, int c) => c >= 0 && c < row.length ? row[c].trim() : '';
  String? opt(List<String> row, int c) => at(row, c).isEmpty ? null : at(row, c);
  for (var r = head + 1; r < rows.length; r++) {
    final row = rows[r];
    if (row.every((c) => c.trim().isEmpty)) continue;
    final no = r + 1;
    read.add(ReadRow(
      lineNo: no,
      jan: at(row, jan),
      name: at(row, name),
      quantity: at(row, qty),
      maker: at(row, makerCol),
      code: at(row, codeCol),
    ));
    final rawJan = at(row, jan);
    final code = normalizeJan(rawJan);
    if (code == null || code.length < 8 || code.length > 14) {
      problems.add(StockFileProblem(no, 'no_jan', value: rawJan));
      continue;
    }
    final rawQty = at(row, qty).replaceAll(RegExp(r'[,，\s]'), '');
    final q = int.tryParse(rawQty) ?? double.tryParse(rawQty)?.let((d) => d == d.roundToDouble() ? d.toInt() : null);
    if (q == null || q < 0) {
      problems.add(StockFileProblem(no, 'bad_quantity', value: at(row, qty)));
      continue;
    }
    final prev = byJan[code];
    byJan[code] = StockFileLine(
      lineNo: prev?.lineNo ?? no,
      janCode: code,
      quantity: (prev?.quantity ?? 0) + q,
      name: prev?.name ?? opt(row, name),
      merged: (prev?.merged ?? 0) + 1,
      maker: prev?.maker ?? opt(row, makerCol),
      code: prev?.code ?? opt(row, codeCol),
    );
  }
  return StockSheet(lines: byJan.values.toList(), problems: problems, read: read);
}

/// Whether the app reads [fileName] itself (a sheet or CSV); anything else
/// — a PDF, a scan, a photo, an old .xls — is read by the AI.
bool readsLocally(String fileName) {
  final lower = fileName.toLowerCase();
  return ['.xlsx', '.xlsm', '.csv', '.tsv', '.txt'].any(lower.endsWith);
}

/// Flags that say something is missing, not that the reading is in doubt.
const _noDoubt = {'no_maker'};

/// Lines the AI read (import-plan, nothing booked) as a stock sheet: a JAN
/// and a quantity each, the same JAN summed, and the ones it could not be
/// sure of (any flag on the row) marked.
StockSheet stockSheetFromRead(List<ReadRow> rows) {
  final byJan = <String, StockFileLine>{};
  final problems = <StockFileProblem>[];
  for (final row in rows) {
    final no = row.lineNo;
    final code = normalizeJan(row.jan);
    if (code == null || code.length < 8 || code.length > 14) {
      problems.add(StockFileProblem(no, 'no_jan', value: row.jan.isEmpty ? row.name : row.jan));
      continue;
    }
    final t = row.quantity.replaceAll(RegExp(r'[,，\s]'), '');
    final d = double.tryParse(t);
    final q = int.tryParse(t) ?? (d != null && d == d.roundToDouble() ? d.toInt() : null);
    if (q == null || q < 0) {
      problems.add(StockFileProblem(no, 'bad_quantity', value: row.quantity.isEmpty ? '—' : row.quantity));
      continue;
    }
    final prev = byJan[code];
    byJan[code] = StockFileLine(
      lineNo: prev?.lineNo ?? no,
      janCode: code,
      quantity: (prev?.quantity ?? 0) + q,
      name: prev?.name ?? (row.name.isEmpty ? null : row.name),
      merged: (prev?.merged ?? 0) + 1,
      doubtful: (prev?.doubtful ?? false) || row.flags.any((f) => !_noDoubt.contains(f.split(':').first)),
      maker: prev?.maker ?? (row.maker.isEmpty ? null : row.maker),
      code: prev?.code ?? (row.code.isEmpty ? null : row.code),
    );
  }
  return StockSheet(lines: byJan.values.toList(), problems: problems, byAi: true, read: rows);
}

/// A stock file's rows: an .xlsx's first sheet, or a UTF-8 CSV / TSV with
/// quoted cells. Throws [FormatException] for anything else.
List<List<String>> readStockFile(String fileName, Uint8List bytes) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.xlsx') || lower.endsWith('.xlsm')) return readXlsx(bytes);
  if (lower.endsWith('.csv') || lower.endsWith('.txt') || lower.endsWith('.tsv')) {
    final text = utf8.decode(bytes, allowMalformed: true).replaceFirst('﻿', '');
    return parseCsv(text, separator: lower.endsWith('.tsv') ? '\t' : ',');
  }
  throw const FormatException('not a stock sheet');
}

/// CSV rows: quoted cells may hold commas, newlines and doubled quotes.
List<List<String>> parseCsv(String text, {String separator = ','}) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"') {
      quoted = true;
    } else if (ch == separator) {
      row.add(cell.toString());
      cell.clear();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = <String>[];
    } else {
      cell.write(ch);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows;
}

/// The sheet to fill in: JAN, 商品名 (for the reader's eye only) and 数量.
Uint8List stockTemplateXlsx() => buildXlsx(
      sheetName: '在庫登録',
      headers: const ['JANコード', '商品名', '数量'],
      rows: const [],
      widths: const [18, 40, 10],
    );

/// What the server did with a stock file.
class StockFileResult extends Equatable {
  const StockFileResult({required this.importId, required this.lines, required this.change, this.skipped = const []});

  final int importId;
  final int lines;

  /// The total change in units (negative when [StockFileMode.set] lowered it).
  final int change;
  final List<String> skipped;

  factory StockFileResult.fromJson(Map<String, dynamic> j) => StockFileResult(
        importId: (j['import_id'] as num?)?.toInt() ?? 0,
        lines: (j['lines'] as num?)?.toInt() ?? 0,
        change: (j['change'] as num?)?.toInt() ?? 0,
        skipped: [
          for (final s in (j['skipped'] as List? ?? const []).whereType<Map>()) '${s['jan_code'] ?? ''}',
        ],
      );

  @override
  List<Object?> get props => [importId, lines, change, skipped];
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
