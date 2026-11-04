import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// A one-sheet .xlsx workbook: a bold header row that stays on screen while
/// scrolling, and [flagged] cells (row, column; 0-based over [rows]) filled
/// yellow so a person sees at once what needs looking at. Text stays text —
/// a JAN keeps its leading zero and is not turned into 4.9E+12.
///
/// [top] rows come above the header — a document's heading: who it is for,
/// who sends it — with their first cell in bold; [bottom] rows come under the
/// lines (a total), in bold.
/// One sheet of a workbook: its name, heading row, rows, cells to fill
/// yellow (row, column) and column widths; rows above the heading ([top])
/// and below the rows ([bottom]) in bold.
class XlsxSheet {
  const XlsxSheet({
    required this.name,
    required this.headers,
    required this.rows,
    this.flagged = const {},
    this.widths,
    this.top = const [],
    this.bottom = const [],
    this.lists = const [],
  });

  final String name;

  /// Cells that offer a list to choose from: (range such as B2:B20, the
  /// list as a formula such as BOX_TYPES!\$A\$2:\$A\$9).
  final List<(String, String)> lists;
  final List<String> headers;
  final List<List<Object?>> rows;
  final Set<(int, int)> flagged;
  final List<double>? widths;
  final List<List<Object?>> top;
  final List<List<Object?>> bottom;
}

Uint8List buildXlsx({
  required String sheetName,
  required List<String> headers,
  required List<List<Object?>> rows,
  Set<(int, int)> flagged = const {},
  List<double>? widths,
  List<List<Object?>> top = const [],
  List<List<Object?>> bottom = const [],
}) =>
    buildXlsxBook([
      XlsxSheet(name: sheetName, headers: headers, rows: rows, flagged: flagged, widths: widths, top: top, bottom: bottom),
    ]);

/// A cell worked out by Excel when the file is opened: [formula] without
/// the leading "=" (H2*K2). [cached] is shown by readers that do not work
/// it out.
class XlsxFormula {
  const XlsxFormula(this.formula, {this.cached});

  final String formula;

  /// A number, or text (a formula that gives text).
  final Object? cached;
}

String _esc(String s) =>
    const HtmlEscape(HtmlEscapeMode.element).convert(s.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), ''));

String _sheetXml(XlsxSheet x) {
  String cell(int r, int c, Object? v, int style) {
    final ref = '${columnLetters(c)}${r + 1}';
    final s = style == 0 ? '' : ' s="$style"';
    if (v == null || (v is String && v.isEmpty)) return style == 0 ? '' : '<c r="$ref"$s/>';
    if (v is XlsxFormula) {
      final f = v.formula.startsWith('=') ? v.formula.substring(1) : v.formula;
      final cached = v.cached;
      if (cached is String) return '<c r="$ref"$s t="str"><f>${_esc(f)}</f><v>${_esc(cached)}</v></c>';
      return '<c r="$ref"$s><f>${_esc(f)}</f>${cached is num && cached.isFinite ? '<v>$cached</v>' : ''}</c>';
    }
    if (v is num && v.isFinite) return '<c r="$ref"$s><v>$v</v></c>';
    return '<c r="$ref"$s t="inlineStr"><is><t xml:space="preserve">${_esc('$v')}</t></is></c>';
  }

  final head = x.top.length;
  final sheet = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')
    ..write('<sheetViews><sheetView workbookViewId="0"><pane ySplit="${head + 1}" topLeftCell="A${head + 2}" '
        'activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>');
  final widths = x.widths;
  if (widths != null && widths.isNotEmpty) {
    sheet.write('<cols>');
    for (final (i, w) in widths.indexed) {
      sheet.write('<col min="${i + 1}" max="${i + 1}" width="$w" customWidth="1"/>');
    }
    sheet.write('</cols>');
  }
  sheet.write('<sheetData>');
  for (final (r, row) in x.top.indexed) {
    sheet.write('<row r="${r + 1}">');
    for (final (c, v) in row.indexed) {
      sheet.write(cell(r, c, v, c == 0 ? 3 : 0));
    }
    sheet.write('</row>');
  }
  sheet.write('<row r="${head + 1}">');
  for (final (c, h) in x.headers.indexed) {
    sheet.write(cell(head, c, h, 1));
  }
  sheet.write('</row>');
  for (final (r, row) in x.rows.indexed) {
    sheet.write('<row r="${head + r + 2}">');
    for (var c = 0; c < x.headers.length; c++) {
      sheet.write(cell(head + r + 1, c, c < row.length ? row[c] : null, x.flagged.contains((r, c)) ? 2 : 0));
    }
    sheet.write('</row>');
  }
  for (final (r, row) in x.bottom.indexed) {
    final at = head + x.rows.length + r + 1;
    sheet.write('<row r="${at + 1}">');
    for (final (c, v) in row.indexed) {
      sheet.write(cell(at, c, v, 3));
    }
    sheet.write('</row>');
  }
  sheet.write('</sheetData>');
  if (x.lists.isNotEmpty) {
    sheet.write('<dataValidations count="${x.lists.length}">');
    for (final (range, formula) in x.lists) {
      sheet.write('<dataValidation type="list" allowBlank="1" showErrorMessage="1" sqref="${_esc(range)}">'
          '<formula1>${_esc(formula.startsWith('=') ? formula.substring(1) : formula)}</formula1></dataValidation>');
    }
    sheet.write('</dataValidations>');
  }
  sheet.write('</worksheet>');
  return sheet.toString();
}

/// A workbook of [sheets], in order (sheet names made valid and unique).
Uint8List buildXlsxBook(List<XlsxSheet> sheets) {
  final names = <String>[];
  for (final x in sheets) {
    var n = (x.name.isEmpty ? 'Sheet${names.length + 1}' : x.name).replaceAll(RegExp(r'[\\/?*\[\]:]'), ' ');
    if (n.length > 31) n = n.substring(0, 31);
    var unique = n;
    for (var i = 2; names.contains(unique); i++) {
      unique = '${n.length > 28 ? n.substring(0, 28) : n}($i)';
    }
    names.add(unique);
  }
  const styles = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
      '<fills count="4"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FFE7EEF7"/><bgColor indexed="64"/></patternFill></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FFFFF2A8"/><bgColor indexed="64"/></patternFill></fill></fills>'
      '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="4"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/>'
      '<xf numFmtId="0" fontId="0" fillId="3" borderId="0" xfId="0" applyFill="1"/>'
      '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>'
      '</styleSheet>';
  final overrides = StringBuffer();
  final rels = StringBuffer();
  final entries = StringBuffer();
  for (var i = 0; i < sheets.length; i++) {
    overrides.write('<Override PartName="/xl/worksheets/sheet${i + 1}.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>');
    rels.write('<Relationship Id="rId${i + 1}" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>');
    entries.write('<sheet name="${_esc(names[i])}" sheetId="${i + 1}" r:id="rId${i + 1}"/>');
  }
  final archive = Archive()
    ..add(ArchiveFile.string(
        '[Content_Types].xml',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
            '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
            '<Default Extension="xml" ContentType="application/xml"/>'
            '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
            '$overrides'
            '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
            '</Types>'))
    ..add(ArchiveFile.string(
        '_rels/.rels',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
            '</Relationships>'))
    ..add(ArchiveFile.string(
        'xl/workbook.xml',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
            'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
            '<sheets>$entries</sheets><calcPr calcId="0" fullCalcOnLoad="1"/></workbook>'))
    ..add(ArchiveFile.string(
        'xl/_rels/workbook.xml.rels',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '$rels'
            '<Relationship Id="rId${sheets.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
            '</Relationships>'))
    ..add(ArchiveFile.string('xl/styles.xml', styles));
  for (var i = 0; i < sheets.length; i++) {
    archive.add(ArchiveFile.string('xl/worksheets/sheet${i + 1}.xml', _sheetXml(sheets[i])));
  }
  return ZipEncoder().encodeBytes(archive);
}

/// A, B, … Z, AA, AB … for a 0-based column.
String columnLetters(int c) {
  var n = c + 1;
  var out = '';
  while (n > 0) {
    final m = (n - 1) % 26;
    out = String.fromCharCode(65 + m) + out;
    n = (n - 1) ~/ 26;
  }
  return out;
}

String _shared(List<String> shared, String v) {
  final i = int.tryParse(v);
  return i != null && i >= 0 && i < shared.length ? shared[i] : '';
}

int _columnIndex(String ref) {
  var n = 0;
  for (final ch in ref.toUpperCase().codeUnits) {
    if (ch < 65 || ch > 90) break;
    n = n * 26 + (ch - 64);
  }
  return n - 1;
}

/// One sheet of a workbook as read: its name and its rows of text.
typedef XlsxSheetRows = ({String name, List<List<String>> rows});

/// The first sheet of an .xlsx as rows of text, the way the cells read:
/// shared and inline strings, numbers (a whole number without ".0"), and
/// empty cells as ''. Throws [FormatException] when the bytes are not a
/// workbook.
List<List<String>> readXlsx(Uint8List bytes) {
  final sheets = readXlsxSheets(bytes, keepRowNumbers: false, firstOnly: true);
  return sheets.isEmpty ? const [] : sheets.first.rows;
}

/// Every sheet of an .xlsx, in the workbook's order. With [keepRowNumbers]
/// a row Excel left out (empty) is an empty row here, so rows[i] is the
/// sheet's row i + 1. A formula reads as the value Excel saved for it.
List<XlsxSheetRows> readXlsxSheets(Uint8List bytes, {bool keepRowNumbers = true, bool firstOnly = false}) {
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const FormatException('not an xlsx workbook');
  }
  String? text(String name) {
    final f = zip.findFile(name);
    final b = f?.readBytes();
    return b == null ? null : utf8.decode(b, allowMalformed: true);
  }

  // Which file each sheet is: workbook.xml → its relationship.
  final targets = <(String, String)>[];
  final wb = text('xl/workbook.xml');
  final rels = text('xl/_rels/workbook.xml.rels');
  if (wb != null && rels != null) {
    final relDoc = XmlDocument.parse(rels);
    for (final sh in XmlDocument.parse(wb).findAllElements('sheet')) {
      final rid = sh.attributes.where((a) => a.name.local == 'id').firstOrNull?.value;
      final target = relDoc
          .findAllElements('Relationship')
          .where((r) => r.getAttribute('Id') == rid)
          .firstOrNull
          ?.getAttribute('Target');
      if (target == null) continue;
      final path = target.startsWith('/') ? target.substring(1) : 'xl/${target.replaceFirst(RegExp(r'^\./'), '')}';
      targets.add((sh.getAttribute('name') ?? 'Sheet${targets.length + 1}', path));
      if (firstOnly) break;
    }
  }
  if (targets.isEmpty) targets.add(('Sheet1', 'xl/worksheets/sheet1.xml'));

  final shared = <String>[];
  final sst = text('xl/sharedStrings.xml');
  if (sst != null) {
    for (final si in XmlDocument.parse(sst).findAllElements('si')) {
      // Phonetic runs (rPh) are readings, not the text.
      shared.add(si.findAllElements('t').where((t) => t.parentElement?.name.local != 'rPh').map((t) => t.innerText).join());
    }
  }

  String number(String v) {
    final d = double.tryParse(v);
    if (d == null) return v;
    if (d == d.roundToDouble() && d.abs() < 1e15) return d.toInt().toString();
    // 50.00000000000001 (55/1.1) reads as 50; a price keeps its decimals.
    final r = double.parse(d.toStringAsFixed(6));
    if (r == r.roundToDouble() && r.abs() < 1e15) return r.toInt().toString();
    return r.toString();
  }

  final out = <XlsxSheetRows>[];
  for (final (name, path) in targets) {
    final sheet = text(path);
    if (sheet == null) {
      if (firstOnly) throw const FormatException('the workbook has no sheet');
      continue;
    }
    final rows = <List<String>>[];
    for (final row in XmlDocument.parse(sheet).findAllElements('row')) {
      if (keepRowNumbers) {
        final at = int.tryParse(row.getAttribute('r') ?? '');
        while (at != null && rows.length < at - 1) {
          rows.add(const []);
        }
      }
      final cells = <int, String>{};
      var next = 0;
      for (final c in row.findElements('c')) {
        final ref = c.getAttribute('r');
        final col = ref == null ? next : _columnIndex(ref);
        next = col + 1;
        final type = c.getAttribute('t');
        final v = c.getElement('v')?.innerText ?? '';
        final String value = switch (type) {
          's' => _shared(shared, v),
          'inlineStr' => c.findAllElements('t').map((t) => t.innerText).join(),
          'str' || 'e' => v,
          'b' => v == '1' ? 'TRUE' : 'FALSE',
          _ => number(v),
        };
        cells[col] = value.trim();
      }
      final width = cells.isEmpty ? 0 : cells.keys.reduce((a, b) => a > b ? a : b) + 1;
      rows.add([for (var i = 0; i < width; i++) cells[i] ?? '']);
    }
    // Trailing empty rows say nothing.
    while (rows.isNotEmpty && rows.last.every((c) => c.isEmpty)) {
      rows.removeLast();
    }
    out.add((name: name, rows: rows));
  }
  if (out.isEmpty) throw const FormatException('the workbook has no sheet');
  return out;
}
