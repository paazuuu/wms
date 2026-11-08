import 'package:equatable/equatable.dart';

import 'overseas_stock.dart';

String? _s(Object? v) {
  final t = v?.toString().trim();
  return t == null || t.isEmpty ? null : t;
}

num _n(Object? v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;

/// A product as compared across shipments and counts: its JAN, else its 品番
/// and name (as `overseas_key` on the server).
String overseasKey(String? jan, String? code, String? name) {
  final j = jan?.trim() ?? '';
  if (j.isNotEmpty) return j;
  return 'c:${(code ?? '').trim().toLowerCase()}:${(name ?? '').trim().toLowerCase()}';
}

String overseasKeyOf(OverseasLine l) => overseasKey(l.jan, l.code, l.name);

/// A site's stock now, by product (0209): shipped in all, the last count the
/// partner gave and its day, shipped since, and the estimate.
class OverseasEstimate extends Equatable {
  const OverseasEstimate({
    this.jan,
    this.code,
    this.name,
    this.maker,
    this.unit,
    this.shippedTotal = 0,
    this.reported,
    this.reportedOn,
    this.shippedSince = 0,
    this.estimate = 0,
    this.ours,
  });

  final String? jan;
  final String? code;
  final String? name;
  final String? maker;
  final String? unit;
  final num shippedTotal;

  /// Null: no count given yet.
  final num? reported;
  final DateTime? reportedOn;
  final num shippedSince;
  final num estimate;
  final String? ours;

  String get label => name ?? code ?? jan ?? '';

  factory OverseasEstimate.fromJson(Map<String, dynamic> j) => OverseasEstimate(
        jan: _s(j['jan']),
        code: _s(j['code']),
        name: _s(j['name']),
        maker: _s(j['maker']),
        unit: _s(j['unit']),
        shippedTotal: _n(j['shipped_total']),
        reported: j['reported'] == null ? null : _n(j['reported']),
        reportedOn: DateTime.tryParse('${j['reported_on'] ?? ''}'),
        shippedSince: _n(j['shipped_since']),
        estimate: _n(j['estimate']),
        ours: _s(j['ours']),
      );

  @override
  List<Object?> get props => [jan, code, name, shippedTotal, reported, reportedOn, shippedSince, estimate];
}

/// A list shipped to the site's card, or a count the partner gave.
class OverseasEvent extends Equatable {
  const OverseasEvent({required this.day, required this.lines, this.id, this.outboundFileId, this.fileName, this.report = false});

  final DateTime day;
  final List<OverseasLine> lines;
  final int? id;

  /// The 出庫 list it is (a shipment).
  final int? outboundFileId;
  final String? fileName;

  /// A count the partner gave (else a shipment).
  final bool report;

  num get units => lines.fold<num>(0, (a, l) => a + l.quantity);

  @override
  List<Object?> get props => [day, lines, id, report];
}

/// The shipments and the counts given, in time order.
class OverseasEvents extends Equatable {
  const OverseasEvents({this.shipments = const [], this.reports = const []});

  final List<OverseasEvent> shipments;
  final List<OverseasEvent> reports;

  factory OverseasEvents.fromJson(Map<String, dynamic> j) {
    List<OverseasLine> lines(Object? v) =>
        [for (final l in (v as List? ?? const []).whereType<Map>()) OverseasLine.fromJson(l.cast<String, dynamic>())];
    return OverseasEvents(
      shipments: [
        for (final e in (j['shipments'] as List? ?? const []).whereType<Map>())
          OverseasEvent(
            day: DateTime.parse('${e['shipped_on']}'),
            lines: lines(e['lines']),
            id: (e['id'] as num?)?.toInt(),
            outboundFileId: (e['outbound_file_id'] as num?)?.toInt(),
            fileName: _s(e['file_name']),
          ),
      ],
      reports: [
        for (final e in (j['reports'] as List? ?? const []).whereType<Map>())
          OverseasEvent(
            day: DateTime.parse('${e['as_of']}'),
            lines: lines(e['lines']),
            id: (e['id'] as num?)?.toInt(),
            fileName: _s(e['file_name']),
            report: true,
          ),
      ],
    );
  }

  /// Every product (or maker) met: key → (label, maker).
  Map<String, ({String label, String? maker})> products() {
    final out = <String, ({String label, String? maker})>{};
    for (final e in [...shipments, ...reports]) {
      for (final l in e.lines) {
        final k = overseasKeyOf(l);
        final had = out[k];
        out[k] = (label: had?.label ?? l.label, maker: had?.maker ?? l.maker);
      }
    }
    return out;
  }

  List<String> makers() => {for (final p in products().values) if (p.maker != null) p.maker!}.toList()..sort();

  @override
  List<Object?> get props => [shipments, reports];
}

/// What was used between two counts: the first count, what was shipped
/// after it up to the next, the next count, and the difference — the goods
/// sold or used downstream. Before the first count, the period starts at the
/// first shipment from 0.
class OverseasUse extends Equatable {
  const OverseasUse({required this.from, required this.to, required this.start, required this.shipped, required this.end});

  final DateTime from;
  final DateTime to;
  final num start;
  final num shipped;
  final num end;

  num get used => start + shipped - end;
  int get days => to.difference(from).inDays;

  /// Used per 30 days.
  double? get perMonth => days <= 0 ? null : used * 30 / days;

  @override
  List<Object?> get props => [from, to, start, shipped, end];
}

/// A product's (or a maker's) stock over time and what was used.
class OverseasTrend extends Equatable {
  const OverseasTrend({this.points = const [], this.periods = const [], this.months = const {}});

  /// The estimate after each event: a shipment adds, a count sets.
  final List<({DateTime day, num stock, bool report})> points;
  final List<OverseasUse> periods;

  /// Used by month (yyyy-MM), each period spread over its days.
  final Map<String, num> months;

  @override
  List<Object?> get props => [points, periods, months];
}

/// The stock of the lines [match] picks over time: a shipment adds to the
/// estimate, a count given sets it (what a count leaves out is 0). A
/// shipment on a count's day is in that count.
OverseasTrend overseasTrend(OverseasEvents ev, bool Function(OverseasLine l) match) {
  num sum(OverseasEvent e) => e.lines.where(match).fold<num>(0, (a, l) => a + l.quantity);
  final events = [...ev.shipments, ...ev.reports]..sort((a, b) {
      final c = a.day.compareTo(b.day);
      if (c != 0) return c;
      return (a.report ? 1 : 0) - (b.report ? 1 : 0);
    });
  final points = <({DateTime day, num stock, bool report})>[];
  final periods = <OverseasUse>[];
  num stock = 0;
  DateTime? from;
  num start = 0;
  num shipped = 0;
  for (final e in events) {
    if (e.report) {
      final count = sum(e);
      if (from != null) periods.add(OverseasUse(from: from, to: e.day, start: start, shipped: shipped, end: count));
      stock = count;
      from = e.day;
      start = count;
      shipped = 0;
      points.add((day: e.day, stock: stock, report: true));
    } else {
      final q = sum(e);
      if (q == 0) continue;
      from ??= e.day;
      stock += q;
      shipped += q;
      points.add((day: e.day, stock: stock, report: false));
    }
  }
  return OverseasTrend(points: points, periods: periods, months: _byMonth(periods));
}

String _ym(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

Map<String, num> _byMonth(List<OverseasUse> periods) {
  final out = <String, num>{};
  for (final p in periods) {
    final days = p.days;
    if (days <= 0) {
      out[_ym(p.to)] = (out[_ym(p.to)] ?? 0) + p.used;
      continue;
    }
    final perDay = p.used / days;
    for (var i = 1; i <= days; i++) {
      final d = DateTime(p.from.year, p.from.month, p.from.day + i);
      out[_ym(d)] = (out[_ym(d)] ?? 0) + perDay;
    }
  }
  final keys = out.keys.toList()..sort();
  return {for (final k in keys) k: out[k]!};
}
