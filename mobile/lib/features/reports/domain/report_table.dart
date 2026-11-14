import 'package:intl/intl.dart';

import 'report.dart';

/// One column of a report as people read it: the key the server sends,
/// its heading, and whether it holds numbers (right-aligned, summed).
class ReportColumn {
  const ReportColumn(this.key, this.label, {this.numeric = false, this.summed = false, this.flex = 1});

  final String key;
  final String label;
  final bool numeric;

  /// Added up under the table: a quantity moved, not a level or a price.
  final bool summed;

  /// Its share of an A4 page's width.
  final double flex;
}

/// A report's rows as text, ready for the page, Excel and the PDF: the
/// columns worth reading in a sensible order with their headings, dates and
/// numbers written out, and ids and codes nobody reads left out.
class ReportTable {
  const ReportTable({required this.columns, required this.rows});

  final List<ReportColumn> columns;

  /// Each row's cells, in [columns]' order.
  final List<List<String>> rows;

  /// The distinct values of column [i], sorted, for its filter.
  List<String> values(int i) => ({for (final r in rows) r[i]}.toList()..sort());

  /// The rows whose cell in every filtered column is one of the values
  /// chosen for it ([filters]: column index → chosen values).
  ReportTable where(Map<int, Set<String>> filters) {
    if (filters.isEmpty) return this;
    return ReportTable(columns: columns, rows: [
      for (final r in rows)
        if (filters.entries.every((f) => f.value.contains(r[f.key]))) r,
    ]);
  }

  /// The sum of each summed column (null for the others).
  List<String?> totals() => [
        for (final (i, c) in columns.indexed)
          c.summed
              ? _num.format(rows.fold<num>(0, (a, r) => a + (num.tryParse(r[i].replaceAll(',', '')) ?? 0)))
              : null,
      ];

  /// The rows split into A4 pages of [perPage].
  List<List<List<String>>> pages(int perPage) => [
        for (var i = 0; i < rows.length; i += perPage)
          rows.sublist(i, i + perPage > rows.length ? rows.length : i + perPage),
      ];
}

final _num = NumberFormat('#,##0.##');
final _day = DateFormat('y/MM/dd');
final _time = DateFormat('y/MM/dd HH:mm');

/// Headings for the keys the sources send; a key not here keeps its name.
const _labels = {
  'created_at': '日時',
  'jan_code': 'JAN',
  'product_name': '商品名',
  'name': '商品名',
  'warehouse_name': '倉庫',
  'movement_type': '種類',
  'quantity_before': '変更前',
  'quantity': '数量',
  'quantity_after': '変更後',
  'event_type': '操作',
  'entity_type': '対象',
  'entity_id': '対象ID',
  'details': '内容',
  'category': 'カテゴリ',
  'price': '価格',
  'status': '状態',
  'country_code': '国',
  'reference': '番号',
  'supplier_name': '仕入先',
  'customer_name': '顧客',
  'order_number': '番号',
};

/// Columns kept out of what people read: inner ids.
const _hidden = {'id', 'warehouse_id', 'actor_user_id', 'product_id', 'company_id'};

/// The order the known keys are shown in; others follow as they come.
const _order = [
  'created_at', 'warehouse_name', 'country_code', 'movement_type', 'event_type', 'entity_type', 'entity_id',
  'jan_code', 'product_name', 'name', 'category', 'status', 'quantity_before', 'quantity', 'quantity_after',
  'price', 'details',
];

const _numericKeys = {'quantity', 'quantity_before', 'quantity_after', 'price'};
const _summedKeys = {'quantity'};

const _flex = {
  'created_at': 2.0, 'product_name': 2.5, 'name': 2.5, 'details': 3.0, 'jan_code': 1.6, 'warehouse_name': 1.3,
  'quantity_before': 0.9, 'quantity': 0.9, 'quantity_after': 0.9, 'price': 1.0, 'country_code': 0.6,
};

/// Movement and status codes in words.
const _words = {
  'ADJUST': '在庫調整',
  'RECEIVE': '入荷',
  'RECEIPT': '入荷',
  'SHIP': '出庫',
  'TRANSFER_IN': '移動（入）',
  'TRANSFER_OUT': '移動（出）',
  'COUNT': '棚卸',
  'PICK': 'ピッキング',
  'active': '有効',
  'inactive': '無効',
};

String _cell(String key, Object? v) {
  if (v == null) return '';
  if (key == 'created_at' || key.endsWith('_at')) {
    final d = DateTime.tryParse('$v')?.toLocal();
    if (d != null) return d.hour == 0 && d.minute == 0 && d.second == 0 ? _day.format(d) : _time.format(d);
  }
  if (v is num) return _num.format(v);
  if (v is Map) return v.entries.where((e) => e.value != null).map((e) => '${e.key}: ${e.value}').join(' / ');
  if (v is List) return v.join(', ');
  final s = '$v';
  return _words[s] ?? s;
}

/// [result]'s rows as a [ReportTable]. The country column only when more
/// than one country is in it.
ReportTable reportTable(ReportResult result) {
  if (result.rows.isEmpty) return const ReportTable(columns: [], rows: []);
  final keys = <String>{for (final r in result.rows) ...r.keys};
  final countries = {for (final r in result.rows) r['country_code']};
  final shown = [
    for (final k in _order)
      if (keys.contains(k) && !(k == 'country_code' && countries.length < 2)) k,
    for (final k in keys)
      if (!_order.contains(k) && !_hidden.contains(k)) k,
  ];
  return ReportTable(
    columns: [
      for (final k in shown)
        ReportColumn(k, _labels[k] ?? k,
            numeric: _numericKeys.contains(k), summed: _summedKeys.contains(k), flex: _flex[k] ?? 1.2),
    ],
    rows: [
      for (final r in result.rows) [for (final k in shown) _cell(k, r[k])],
    ],
  );
}
