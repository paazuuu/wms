import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// A one-sheet .xlsx workbook: a bold header row that stays on screen while
/// scrolling, and [flagged] cells (row, column; 0-based over [rows]) filled
/// yellow so a person sees at once what needs looking at. Text stays text —
/// a JAN keeps its leading zero and is not turned into 4.9E+12.
Uint8List buildXlsx({
  required String sheetName,
  required List<String> headers,
  required List<List<Object?>> rows,
  Set<(int, int)> flagged = const {},
  List<double>? widths,
}) {
  String esc(String s) => const HtmlEscape(HtmlEscapeMode.element).convert(s.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), ''));

  String cell(int r, int c, Object? v, int style) {
    final ref = '${columnLetters(c)}${r + 1}';
    final s = style == 0 ? '' : ' s="$style"';
    if (v == null || (v is String && v.isEmpty)) return style == 0 ? '' : '<c r="$ref"$s/>';
    if (v is num && v.isFinite) return '<c r="$ref"$s><v>$v</v></c>';
    return '<c r="$ref"$s t="inlineStr"><is><t xml:space="preserve">${esc('$v')}</t></is></c>';
  }

  final sheet = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')
    ..write('<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>');
  if (widths != null && widths.isNotEmpty) {
    sheet.write('<cols>');
    for (final (i, w) in widths.indexed) {
      sheet.write('<col min="${i + 1}" max="${i + 1}" width="$w" customWidth="1"/>');
    }
    sheet.write('</cols>');
  }
  sheet.write('<sheetData><row r="1">');
  for (final (c, h) in headers.indexed) {
    sheet.write(cell(0, c, h, 1));
  }
  sheet.write('</row>');
  for (final (r, row) in rows.indexed) {
    sheet.write('<row r="${r + 2}">');
    for (var c = 0; c < headers.length; c++) {
      sheet.write(cell(r + 1, c, c < row.length ? row[c] : null, flagged.contains((r, c)) ? 2 : 0));
    }
    sheet.write('</row>');
  }
  sheet.write('</sheetData></worksheet>');

  final name = esc(sheetName.isEmpty ? 'Sheet1' : (sheetName.length > 31 ? sheetName.substring(0, 31) : sheetName))
      .replaceAll(RegExp(r'[\\/?*\[\]:]'), ' ');
  const styles = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
      '<fills count="4"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FFE7EEF7"/><bgColor indexed="64"/></patternFill></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FFFFF2A8"/><bgColor indexed="64"/></patternFill></fill></fills>'
      '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="3"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/>'
      '<xf numFmtId="0" fontId="0" fillId="3" borderId="0" xfId="0" applyFill="1"/></cellXfs>'
      '</styleSheet>';
  final archive = Archive()
    ..add(ArchiveFile.string(
        '[Content_Types].xml',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
            '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
            '<Default Extension="xml" ContentType="application/xml"/>'
            '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
            '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
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
            '<sheets><sheet name="$name" sheetId="1" r:id="rId1"/></sheets></workbook>'))
    ..add(ArchiveFile.string(
        'xl/_rels/workbook.xml.rels',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
            '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
            '</Relationships>'))
    ..add(ArchiveFile.string('xl/styles.xml', styles))
    ..add(ArchiveFile.string('xl/worksheets/sheet1.xml', sheet.toString()));
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

/// The first sheet of an .xlsx as rows of text, the way the cells read:
/// shared and inline strings, numbers (a whole number without ".0"), and
/// empty cells as ''. Throws [FormatException] when the bytes are not a
/// workbook.
List<List<String>> readXlsx(Uint8List bytes) {
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

  // Which file is the first sheet: workbook.xml → its relationship.
  var sheetPath = 'xl/worksheets/sheet1.xml';
  final wb = text('xl/workbook.xml');
  final rels = text('xl/_rels/workbook.xml.rels');
  if (wb != null && rels != null) {
    final first = XmlDocument.parse(wb).findAllElements('sheet').firstOrNull;
    final rid = first?.attributes.where((a) => a.name.local == 'id').firstOrNull?.value;
    if (rid != null) {
      final target = XmlDocument.parse(rels)
          .findAllElements('Relationship')
          .where((r) => r.getAttribute('Id') == rid)
          .firstOrNull
          ?.getAttribute('Target');
      if (target != null) {
        sheetPath = target.startsWith('/') ? target.substring(1) : 'xl/${target.replaceFirst(RegExp(r'^\./'), '')}';
      }
    }
  }
  final sheet = text(sheetPath) ?? text('xl/worksheets/sheet1.xml');
  if (sheet == null) throw const FormatException('the workbook has no sheet');

  final shared = <String>[];
  final sst = text('xl/sharedStrings.xml');
  if (sst != null) {
    for (final si in XmlDocument.parse(sst).findAllElements('si')) {
      shared.add(si.findAllElements('t').map((t) => t.innerText).join());
    }
  }

  String number(String v) {
    final d = double.tryParse(v);
    if (d == null) return v;
    if (d == d.roundToDouble() && d.abs() < 1e15) return d.toInt().toString();
    return v;
  }

  final out = <List<String>>[];
  for (final row in XmlDocument.parse(sheet).findAllElements('row')) {
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
    out.add([for (var i = 0; i < width; i++) cells[i] ?? '']);
  }
  // Trailing empty rows say nothing.
  while (out.isNotEmpty && out.last.every((c) => c.isEmpty)) {
    out.removeLast();
  }
  return out;
}
