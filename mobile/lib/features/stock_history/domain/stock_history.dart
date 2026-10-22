import 'package:equatable/equatable.dart';

/// How stock changed (0145), from the movement's kind and what it came from.
enum StockMethod {
  fileStock('file_stock'),
  fileMaster('file_master'),
  receipt('receipt'),
  adjust('adjust'),
  ship('ship'),
  transfer('transfer'),
  other('other');

  const StockMethod(this.wire);
  final String wire;

  static StockMethod fromWire(String? w) => values.firstWhere((m) => m.wire == w, orElse: () => StockMethod.other);

  bool get isFile => this == fileStock || this == fileMaster;

  /// The chart's four groups, each with its fixed color slot: files (1),
  /// receipts (2), corrections and counts (3), everything else (4).
  StockGroup get group => switch (this) {
        fileStock || fileMaster => StockGroup.file,
        receipt => StockGroup.receipt,
        adjust => StockGroup.adjust,
        _ => StockGroup.other,
      };
}

enum StockGroup {
  file(0),
  receipt(1),
  adjust(2),
  other(3);

  const StockGroup(this.slot);
  final int slot;
}

DateTime _at(Object? v) => DateTime.tryParse('${v ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0);
int _int(Object? v) => (v as num?)?.toInt() ?? 0;
String? _text(Object? v) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}

/// One change of a product's stock.
class StockEvent extends Equatable {
  const StockEvent({
    required this.id,
    required this.at,
    required this.method,
    required this.quantity,
    this.type,
    this.warehouseName,
    this.fileName,
    this.importId,
    this.note,
  });

  final int id;
  final DateTime at;
  final StockMethod method;

  /// The change, + in and − out.
  final int quantity;
  final String? type;
  final String? warehouseName;
  final String? fileName;
  final int? importId;
  final String? note;

  factory StockEvent.fromJson(Map<String, dynamic> j) => StockEvent(
        id: _int(j['id']),
        at: _at(j['at']),
        method: StockMethod.fromWire(j['method']?.toString()),
        quantity: _int(j['quantity']),
        type: _text(j['type']),
        warehouseName: _text(j['warehouse_name']),
        fileName: _text(j['file_name']),
        importId: (j['import_id'] as num?)?.toInt(),
        note: _text(j['note']),
      );

  @override
  List<Object?> get props => [id, at, method, quantity, type, warehouseName, fileName, importId, note];
}

/// A product's stock over a period: where it started, each change, and
/// where it is now.
class ProductStockHistory extends Equatable {
  const ProductStockHistory({required this.since, required this.start, required this.current, this.events = const []});

  final DateTime since;
  final int start;
  final int current;
  final List<StockEvent> events;

  factory ProductStockHistory.fromJson(Map<String, dynamic> j) => ProductStockHistory(
        since: _at(j['since']),
        start: _int(j['start']),
        current: _int(j['current']),
        events: [for (final e in (j['events'] as List? ?? const []).whereType<Map>()) StockEvent.fromJson(e.cast())],
      );

  /// The stock after each change, from [start]: (when, stock, the change).
  List<(DateTime, int, StockEvent?)> get levels {
    var level = start;
    return [
      (since, start, null),
      for (final e in events) (e.at, level += e.quantity, e),
    ];
  }

  @override
  List<Object?> get props => [since, start, current, events];
}

/// One day's units in and out by one method, across the library.
class InflowDay extends Equatable {
  const InflowDay({required this.day, required this.method, required this.unitsIn, required this.unitsOut, required this.products});

  final DateTime day;
  final StockMethod method;
  final int unitsIn;
  final int unitsOut;
  final int products;

  factory InflowDay.fromJson(Map<String, dynamic> j) => InflowDay(
        day: _at(j['day']),
        method: StockMethod.fromWire(j['method']?.toString()),
        unitsIn: _int(j['units_in']),
        unitsOut: _int(j['units_out']),
        products: _int(j['products']),
      );

  @override
  List<Object?> get props => [day, method, unitsIn, unitsOut, products];
}

/// A file that changed stock: when, which, how, how much, by whom.
class InflowFile extends Equatable {
  const InflowFile({
    required this.importId,
    required this.at,
    required this.method,
    required this.products,
    required this.units,
    this.fileName,
    this.warehouseName,
    this.by,
  });

  final int importId;
  final DateTime at;
  final StockMethod method;
  final int products;
  final int units;
  final String? fileName;
  final String? warehouseName;
  final String? by;

  factory InflowFile.fromJson(Map<String, dynamic> j) => InflowFile(
        importId: _int(j['import_id']),
        at: _at(j['at']),
        method: StockMethod.fromWire(j['method']?.toString()),
        products: _int(j['products']),
        units: _int(j['units']),
        fileName: _text(j['file_name']),
        warehouseName: _text(j['warehouse_name']),
        by: _text(j['by']),
      );

  @override
  List<Object?> get props => [importId, at, method, products, units, fileName, warehouseName, by];
}

/// How stock came into the library over a period.
class LibraryInflow extends Equatable {
  const LibraryInflow({required this.since, this.days = const [], this.files = const []});

  final DateTime since;
  final List<InflowDay> days;
  final List<InflowFile> files;

  factory LibraryInflow.fromJson(Map<String, dynamic> j) => LibraryInflow(
        since: _at(j['since']),
        days: [for (final e in (j['days'] as List? ?? const []).whereType<Map>()) InflowDay.fromJson(e.cast())],
        files: [for (final e in (j['files'] as List? ?? const []).whereType<Map>()) InflowFile.fromJson(e.cast())],
      );

  /// Units added in the period, by group.
  Map<StockGroup, int> get totals {
    final out = {for (final g in StockGroup.values) g: 0};
    for (final d in days) {
      out[d.method.group] = out[d.method.group]! + d.unitsIn;
    }
    return out;
  }

  /// Each group's units added so far, day by day from [since] to [until]:
  /// a running total per group, so the lines rise where stock came in.
  /// Only the groups that added anything are returned.
  Map<StockGroup, List<(DateTime, int)>> cumulative(DateTime until) {
    final start = DateTime(since.year, since.month, since.day);
    final byDay = <StockGroup, Map<DateTime, int>>{};
    for (final d in days) {
      if (d.unitsIn == 0) continue;
      final day = DateTime(d.day.year, d.day.month, d.day.day);
      final m = byDay.putIfAbsent(d.method.group, () => {});
      m[day] = (m[day] ?? 0) + d.unitsIn;
    }
    final end = DateTime(until.year, until.month, until.day);
    return {
      for (final g in StockGroup.values)
        if (byDay[g] case final m?)
          g: () {
            final out = <(DateTime, int)>[(start, 0)];
            var sum = 0;
            for (final day in (m.keys.toList()..sort())) {
              sum += m[day]!;
              out.add((day, sum));
            }
            if (out.last.$1.isBefore(end)) out.add((end, sum));
            return out;
          }(),
    };
  }

  @override
  List<Object?> get props => [since, days, files];
}
