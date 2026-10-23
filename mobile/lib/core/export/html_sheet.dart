import 'dart:convert';

import 'xlsx.dart' show columnLetters;

/// A table as a web page that looks like a spreadsheet: column letters along
/// the top, row numbers down the side, gridlines, the header kept in view
/// while scrolling, and [flagged] cells (row, column over [rows]) in yellow
/// — the same as [buildXlsx] makes, to open in a browser tab and read,
/// select and copy without Excel. Light and dark follow the browser.
///
/// [top] rows come above the header (what the document is), [bottom] rows
/// under the lines.
String htmlSheet({
  required String title,
  required List<String> headers,
  required List<List<Object?>> rows,
  Set<(int, int)> flagged = const {},
  List<List<Object?>> top = const [],
  List<List<Object?>> bottom = const [],
  String? downloadHint,
}) {
  const esc = HtmlEscape(HtmlEscapeMode.element);
  String cell(Object? v) => v == null ? '' : esc.convert('$v');
  bool numeric(Object? v) => v is num;
  final cols = [headers.length, for (final r in [...top, ...rows, ...bottom]) r.length].fold<int>(0, (m, n) => n > m ? n : m);

  final b = StringBuffer()
    ..write('<!doctype html><html lang="ja"><head><meta charset="utf-8">')
    ..write('<meta name="viewport" content="width=device-width, initial-scale=1">')
    ..write('<title>${esc.convert(title)}</title><style>')
    ..write(':root{--bg:#fff;--fg:#1f2328;--grid:#d0d7de;--head:#f3f4f6;--hfg:#57606a;--th:#e8f0e8;--flag:#fff3b0;--top:#f8fafc}')
    ..write('@media (prefers-color-scheme: dark){:root{--bg:#0d1117;--fg:#e6edf3;--grid:#30363d;--head:#161b22;'
        '--hfg:#8b949e;--th:#1c2a1f;--flag:#5c4b00;--top:#11161d}}')
    ..write('*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);'
        'font:13px/1.4 "Yu Gothic UI","Hiragino Sans","Noto Sans JP","Meiryo",system-ui,sans-serif}')
    ..write('header{padding:12px 16px;border-bottom:1px solid var(--grid)}h1{font-size:16px;margin:0 0 4px}')
    ..write('header p{margin:0;color:var(--hfg)}.wrap{overflow:auto;max-height:calc(100vh - 64px)}')
    ..write('table{border-collapse:separate;border-spacing:0;min-width:100%}')
    ..write('td,th{border-right:1px solid var(--grid);border-bottom:1px solid var(--grid);padding:3px 8px;'
        'white-space:pre-wrap;vertical-align:top;user-select:text}')
    ..write('thead th{position:sticky;top:0;background:var(--head);color:var(--hfg);font-weight:normal;z-index:2;text-align:center}')
    ..write('tr.h th{position:sticky;top:23px;background:var(--th);color:var(--fg);font-weight:bold;z-index:2;text-align:left}')
    ..write('td.n,th.n{position:sticky;left:0;background:var(--head);color:var(--hfg);text-align:right;z-index:1;min-width:40px}')
    ..write('thead th.n{z-index:3}tr.h th.n{text-align:right;font-weight:normal;color:var(--hfg);background:var(--head);'
        'left:0;z-index:3}td.n,th.n{width:1%}tr.t td{background:var(--top)}tr.t td:nth-child(2){font-weight:bold}')
    ..write('tr.b td{font-weight:bold}td.num{text-align:right;font-variant-numeric:tabular-nums}td.f{background:var(--flag)}')
    ..write('</style></head><body><header><h1>${esc.convert(title)}</h1>')
    ..write(downloadHint == null ? '' : '<p>${esc.convert(downloadHint)}</p>')
    ..write('</header><div class="wrap"><table><thead><tr><th class="n"></th>');
  for (var c = 0; c < cols; c++) {
    b.write('<th>${columnLetters(c)}</th>');
  }
  b.write('</tr></thead><tbody>');
  var line = 1;
  void row(List<Object?> r, String cls, {int? dataRow}) {
    b.write('<tr${cls.isEmpty ? '' : ' class="$cls"'}><td class="n">${line++}</td>');
    for (var c = 0; c < cols; c++) {
      final v = c < r.length ? r[c] : null;
      final k = [if (numeric(v)) 'num', if (dataRow != null && flagged.contains((dataRow, c))) 'f'].join(' ');
      b.write('<td${k.isEmpty ? '' : ' class="$k"'}>${cell(v)}</td>');
    }
    b.write('</tr>');
  }

  for (final r in top) {
    row(r, 't');
  }
  b.write('<tr class="h"><th class="n">${line++}</th>');
  for (var c = 0; c < cols; c++) {
    b.write('<th>${cell(c < headers.length ? headers[c] : null)}</th>');
  }
  b.write('</tr>');
  for (final (i, r) in rows.indexed) {
    row(r, '', dataRow: i);
  }
  for (final r in bottom) {
    row(r, 'b');
  }
  b.write('</tbody></table></div></body></html>');
  return b.toString();
}
