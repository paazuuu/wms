import 'package:equatable/equatable.dart';

import '../../shipment/domain/packaging.dart' show CartonType;

int? _ni(Object? v) => v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
double? _nd(Object? v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
String? _s(Object? v) {
  final t = v?.toString().trim();
  return t == null || t.isEmpty ? null : t;
}

double _r3(double v) => (v * 1000).roundToDouble() / 1000;

/// A product's own case (メーカーの元箱, 0192): how many go in one, its size,
/// what a full one weighs.
class CasePack extends Equatable {
  const CasePack({
    required this.productId,
    required this.caseQuantity,
    this.jan,
    this.name,
    this.maker,
    this.sku,
    this.unitWeightG,
    this.lengthCm,
    this.widthCm,
    this.heightCm,
    this.grossKg,
    this.source = 'manual',
    this.seenCount = 1,
  });

  final int productId;
  final int caseQuantity;
  final String? jan;
  final String? name;
  final String? maker;
  final String? sku;
  final double? unitWeightG;
  final double? lengthCm;
  final double? widthCm;
  final double? heightCm;
  final double? grossKg;

  /// 'manual' or 'packing_list' (learned).
  final String source;
  final int seenCount;

  bool get learned => source == 'packing_list';

  /// m³ of one case.
  double? get volumeM3 =>
      lengthCm == null || widthCm == null || heightCm == null ? null : lengthCm! * widthCm! * heightCm! / 1000000;

  factory CasePack.fromJson(Map<String, dynamic> j) => CasePack(
        productId: _ni(j['product_id']) ?? 0,
        caseQuantity: _ni(j['case_quantity']) ?? 0,
        jan: _s(j['jan']),
        name: _s(j['name']),
        maker: _s(j['maker']),
        sku: _s(j['sku']),
        unitWeightG: _nd(j['unit_weight_g']),
        lengthCm: _nd(j['length_cm']),
        widthCm: _nd(j['width_cm']),
        heightCm: _nd(j['height_cm']),
        grossKg: _nd(j['gross_kg']),
        source: _s(j['source']) ?? 'manual',
        seenCount: _ni(j['seen_count']) ?? 1,
      );

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'case_quantity': caseQuantity,
        'length_cm': lengthCm,
        'width_cm': widthCm,
        'height_cm': heightCm,
        'gross_kg': grossKg,
      };

  @override
  List<Object?> get props => [productId, caseQuantity, lengthCm, widthCm, heightCm, grossKg, source];
}

/// What goes in one box: a product and how many.
class PackItem extends Equatable {
  const PackItem({
    required this.quantity,
    this.id,
    this.fileLineId,
    this.productId,
    this.jan,
    this.code,
    this.name,
    this.maker,
    this.unitWeightG,
    this.checked = false,
  });

  final int? id;
  final int? fileLineId;
  final int? productId;
  final String? jan;
  final String? code;
  final String? name;
  final String? maker;
  final int quantity;
  final double? unitWeightG;

  /// Scanned or ticked on the floor.
  final bool checked;

  double? get weightKg => unitWeightG == null ? null : unitWeightG! * quantity / 1000;

  PackItem copyWith({int? quantity, bool? checked, String? jan, int? productId}) => PackItem(
        id: id,
        fileLineId: fileLineId,
        productId: productId ?? this.productId,
        jan: jan ?? this.jan,
        code: code,
        name: name,
        maker: maker,
        quantity: quantity ?? this.quantity,
        unitWeightG: unitWeightG,
        checked: checked ?? this.checked,
      );

  factory PackItem.fromJson(Map<String, dynamic> j) => PackItem(
        id: _ni(j['id']),
        fileLineId: _ni(j['file_line_id']),
        productId: _ni(j['product_id']),
        jan: _s(j['jan']),
        code: _s(j['code']),
        name: _s(j['name']),
        maker: _s(j['maker']),
        quantity: _ni(j['quantity']) ?? 0,
        unitWeightG: _nd(j['unit_weight_g']),
        checked: j['checked'] == true,
      );

  Map<String, dynamic> toJson() => {
        'file_line_id': fileLineId,
        'product_id': productId,
        'jan': jan,
        'code': code,
        'name': name,
        'maker': maker,
        'quantity': quantity,
        'checked': checked,
      };

  @override
  List<Object?> get props => [id, fileLineId, productId, jan, code, quantity, checked];
}

/// One box: its number within its mark (注番 group), the carton or the
/// product's own case, size, weight worked out and weighed, and its contents.
class PackBox extends Equatable {
  const PackBox({
    required this.boxNo,
    this.id,
    this.mark,
    this.cartonTypeId,
    this.cartonType,
    this.ownCase = false,
    this.lengthCm,
    this.widthCm,
    this.heightCm,
    this.tareKg,
    this.estKg,
    this.grossKg,
    this.note,
    this.checkedAt,
    this.checkedByName,
    this.items = const [],
  });

  final int? id;
  final int boxNo;
  final String? mark;
  final int? cartonTypeId;
  final String? cartonType;

  /// The product's own case (メーカーの元箱), not one of ours.
  final bool ownCase;
  final double? lengthCm;
  final double? widthCm;
  final double? heightCm;

  /// The empty box and its packing material.
  final double? tareKg;

  /// Worked out: contents by their weight, plus [tareKg].
  final double? estKg;

  /// Weighed.
  final double? grossKg;
  final String? note;
  final DateTime? checkedAt;
  final String? checkedByName;
  final List<PackItem> items;

  bool get checked => checkedAt != null;

  /// What the papers say it weighs: weighed, else worked out.
  double? get weightKg => grossKg ?? estKg;

  double? get volumeM3 =>
      lengthCm == null || widthCm == null || heightCm == null ? null : lengthCm! * widthCm! * heightCm! / 1000000;

  int get quantity => items.fold(0, (a, i) => a + i.quantity);

  /// HL-3, or 3 with no mark.
  String get label => mark == null || mark!.isEmpty ? '$boxNo' : '$mark-$boxNo';

  String get sizeText => lengthCm == null ? '' : '${_num(lengthCm)} × ${_num(widthCm)} × ${_num(heightCm)}';

  PackBox copyWith({
    int? boxNo,
    int? cartonTypeId,
    String? cartonType,
    bool clearCarton = false,
    bool? ownCase,
    double? lengthCm,
    double? widthCm,
    double? heightCm,
    double? tareKg,
    double? estKg,
    bool clearEst = false,
    double? grossKg,
    bool clearGross = false,
    String? note,
    DateTime? checkedAt,
    String? checkedByName,
    bool clearChecked = false,
    List<PackItem>? items,
  }) =>
      PackBox(
        id: id,
        boxNo: boxNo ?? this.boxNo,
        mark: mark,
        cartonTypeId: clearCarton ? null : (cartonTypeId ?? this.cartonTypeId),
        cartonType: clearCarton ? null : (cartonType ?? this.cartonType),
        ownCase: ownCase ?? this.ownCase,
        lengthCm: lengthCm ?? this.lengthCm,
        widthCm: widthCm ?? this.widthCm,
        heightCm: heightCm ?? this.heightCm,
        tareKg: tareKg ?? this.tareKg,
        estKg: clearEst ? null : (estKg ?? this.estKg),
        grossKg: clearGross ? null : (grossKg ?? this.grossKg),
        note: note ?? this.note,
        checkedAt: clearChecked ? null : (checkedAt ?? this.checkedAt),
        checkedByName: clearChecked ? null : (checkedByName ?? this.checkedByName),
        items: items ?? this.items,
      );

  /// Worked out again from what is in it now: contents by their weight plus
  /// the box; null while a product's weight is not known.
  double? get workedOutKg {
    if (items.isEmpty || items.any((i) => i.unitWeightG == null)) return null;
    return _r3(items.fold(0.0, (a, i) => a + i.weightKg!) + (tareKg ?? 0));
  }

  /// How far the weighed weight is from the worked-out one, as a share
  /// (0.12 = 12%); null without both.
  double? get deviation {
    final e = estKg, g = grossKg;
    if (e == null || g == null || e <= 0) return null;
    return (g - e).abs() / e;
  }

  /// Weighed off by more than [share] and 0.3 kg: something may be missing
  /// or extra.
  bool offBy([double share = 0.1]) {
    final d = deviation;
    return d != null && d > share && (grossKg! - estKg!).abs() > 0.3;
  }

  factory PackBox.fromJson(Map<String, dynamic> j) => PackBox(
        id: _ni(j['id']),
        boxNo: _ni(j['box_no']) ?? 0,
        mark: _s(j['mark']),
        cartonTypeId: _ni(j['carton_type_id']),
        cartonType: _s(j['carton_type']),
        ownCase: j['own_case'] == true,
        lengthCm: _nd(j['length_cm']),
        widthCm: _nd(j['width_cm']),
        heightCm: _nd(j['height_cm']),
        tareKg: _nd(j['tare_kg']),
        estKg: _nd(j['est_kg']),
        grossKg: _nd(j['gross_kg']),
        note: _s(j['note']),
        checkedAt: DateTime.tryParse('${j['checked_at'] ?? ''}')?.toLocal(),
        checkedByName: _s(j['checked_by_name']),
        items: [for (final l in (j['lines'] as List? ?? const []).whereType<Map>()) PackItem.fromJson(l.cast<String, dynamic>())],
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'checked': checked,
        'box_no': boxNo,
        'mark': mark,
        'carton_type_id': cartonTypeId,
        'own_case': ownCase,
        'length_cm': lengthCm,
        'width_cm': widthCm,
        'height_cm': heightCm,
        'tare_kg': tareKg,
        'est_kg': estKg,
        'gross_kg': grossKg,
        'note': note,
        'lines': [for (final i in items) i.toJson()],
      };

  @override
  List<Object?> get props => [id, boxNo, mark, cartonTypeId, ownCase, lengthCm, widthCm, heightCm, estKg, grossKg, checkedAt, items];
}

String _num(double? v) {
  if (v == null) return '';
  return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

/// One row of a shipping list to be packed.
class PackDemand {
  const PackDemand({
    required this.quantity,
    this.fileLineId,
    this.productId,
    this.jan,
    this.code,
    this.name,
    this.maker,
    this.unitWeightG,
    this.mark,
  });

  final int? fileLineId;
  final int? productId;
  final String? jan;
  final String? code;
  final String? name;
  final String? maker;
  final int quantity;
  final double? unitWeightG;

  /// The 注番 group it ships in (BL, HL …).
  final String? mark;

  PackItem item(int q) => PackItem(
        fileLineId: fileLineId,
        productId: productId,
        jan: jan,
        code: code,
        name: name,
        maker: maker,
        quantity: q,
        unitWeightG: unitWeightG,
      );
}

/// The group a 注番 ships in: its letters (BL from "BL  9E"); '' for none.
String packMarkOf(String? orderNumber) =>
    RegExp(r'^[A-Za-z]+').firstMatch((orderNumber ?? '').trim())?.group(0)?.toUpperCase() ?? '';

/// What a carton holds at most: [CartonType.maxLoadKg], else [fallback].
double _maxKg(CartonType t, double fallback) => t.maxLoadKg ?? fallback;

double? _vol(CartonType t) =>
    t.lengthCm == null || t.widthCm == null || t.heightCm == null ? null : t.lengthCm! * t.widthCm! * t.heightCm! / 1000000;

double _tare(CartonType t) => (t.emptyWeightG + t.packingMaterialG) / 1000;

/// The boxes for a shipping list, worked out:
///  1. what fills a product's own case ([casePacks], 入数) goes in its case,
///     one case to a box, at the case's weight;
///  2. the rest goes into our cartons ([cartons], the largest first, then
///     each box the smallest that still holds it), as many as the weight
///     limit (the carton's, else [maxKg]) and 90% of its volume allow — a
///     product's volume known from its case, its weight from the library;
///  3. a product with neither weight nor case to measure by gets a box of
///     its own.
/// Each mark (注番 group) is packed apart and numbered from 1.
List<PackBox> planPacking(
  List<PackDemand> demands, {
  Map<int, CasePack> casePacks = const {},
  List<CartonType> cartons = const [],
  double maxKg = 20,
}) {
  final marks = <String>[];
  for (final d in demands) {
    final m = d.mark ?? '';
    if (!marks.contains(m)) marks.add(m);
  }
  final ours = [for (final t in cartons) if (t.active && _vol(t) != null) t]..sort((a, b) => _vol(a)!.compareTo(_vol(b)!));
  final out = <PackBox>[];
  for (final mark in marks) {
    var no = 0;
    final rest = <(PackDemand, int, double?, double?)>[]; // demand, quantity, m³ per unit, kg per unit
    for (final d in demands.where((d) => (d.mark ?? '') == mark && d.quantity > 0)) {
      final cp = d.productId == null ? null : casePacks[d.productId];
      var left = d.quantity;
      if (cp != null && cp.caseQuantity > 0) {
        final full = left ~/ cp.caseQuantity;
        for (var k = 0; k < full; k++) {
          final kg = cp.grossKg ?? (d.unitWeightG == null ? null : _r3(d.unitWeightG! * cp.caseQuantity / 1000));
          out.add(PackBox(
            boxNo: ++no,
            mark: mark.isEmpty ? null : mark,
            ownCase: true,
            lengthCm: cp.lengthCm,
            widthCm: cp.widthCm,
            heightCm: cp.heightCm,
            estKg: kg,
            items: [d.item(cp.caseQuantity)],
          ));
        }
        left -= full * cp.caseQuantity;
      }
      if (left > 0) {
        final unitVol = cp?.volumeM3 == null ? null : cp!.volumeM3! / cp.caseQuantity;
        final unitKg = d.unitWeightG == null ? null : d.unitWeightG! / 1000;
        rest.add((d, left, unitVol, unitKg));
      }
    }
    if (rest.isEmpty) continue;
    // The biggest first, so the bulky goes in before the small fills gaps.
    rest.sort((a, b) => ((b.$3 ?? 0) * b.$2).compareTo((a.$3 ?? 0) * a.$2));
    final big = ours.isEmpty ? null : ours.last;
    final open = <({List<PackItem> items, double vol, double kg, bool unknown})>[];
    for (final (d, qty, uv, uk) in rest) {
      if ((uv == null && uk == null) || big == null) {
        // Nothing to measure by (or no carton of ours): a box of its own.
        open.add((items: [d.item(qty)], vol: 0, kg: uk == null ? 0 : uk * qty, unknown: uk == null));
        continue;
      }
      final capVol = _vol(big)! * 0.9;
      final capKg = _maxKg(big, maxKg);
      var left = qty;
      while (left > 0) {
        var placed = false;
        for (var i = 0; i < open.length && left > 0; i++) {
          final b = open[i];
          if (b.unknown) continue;
          final byVol = uv == null ? left : ((capVol - b.vol) / uv).floor();
          final byKg = uk == null ? left : ((capKg - b.kg) / uk).floor();
          final n = [left, byVol, byKg].reduce((a, c) => a < c ? a : c);
          if (n <= 0) continue;
          final items = [...b.items];
          final at = items.indexWhere((x) => x.fileLineId == d.fileLineId && x.productId == d.productId && x.code == d.code);
          if (at >= 0) {
            items[at] = items[at].copyWith(quantity: items[at].quantity + n);
          } else {
            items.add(d.item(n));
          }
          open[i] = (items: items, vol: b.vol + (uv ?? 0) * n, kg: b.kg + (uk ?? 0) * n, unknown: uk == null);
          left -= n;
          placed = true;
        }
        if (left > 0 && !placed) {
          open.add((items: const [], vol: 0, kg: 0, unknown: false));
          // A single unit too big or too heavy for the carton still goes in one.
          final byVol = uv == null ? left : (capVol / uv).floor();
          final byKg = uk == null ? left : (capKg / uk).floor();
          final fit = [left, byVol, byKg].reduce((a, c) => a < c ? a : c);
          final n = fit > 0 ? fit : 1;
          open[open.length - 1] = (items: [d.item(n)], vol: (uv ?? 0) * n, kg: (uk ?? 0) * n, unknown: uk == null);
          left -= n;
        }
      }
    }
    for (final b in open) {
      // The smallest of ours that holds it.
      CartonType? t;
      if (big != null && b.vol == 0 && b.unknown) {
        // Nothing to size it by: the usual carton, else the largest.
        t = ours.firstWhere((c) => c.isDefault, orElse: () => big);
      } else if (big != null) {
        t = big;
        for (final c in ours) {
          if (_vol(c)! * 0.9 >= b.vol && _maxKg(c, maxKg) >= b.kg) {
            t = c;
            break;
          }
        }
      }
      final tare = t == null ? null : _tare(t);
      out.add(PackBox(
        boxNo: ++no,
        mark: mark.isEmpty ? null : mark,
        cartonTypeId: t?.id,
        cartonType: t?.name,
        lengthCm: t?.lengthCm,
        widthCm: t?.widthCm,
        heightCm: t?.heightCm,
        tareKg: tare,
        estKg: b.unknown || b.items.any((i) => i.unitWeightG == null) ? null : _r3(b.kg + (tare ?? 0)),
        items: b.items,
      ));
    }
  }
  return out;
}

/// What was packed against what the shipping list asks for, by product:
/// (name, asked, packed), only where they differ.
List<(String, int, int)> packingDifferences(List<PackDemand> demands, List<PackBox> boxes) {
  String key(String? jan, String? code, int? pid) => pid != null ? 'p$pid' : (jan ?? code ?? '?');
  final asked = <String, int>{};
  final packed = <String, int>{};
  final names = <String, String>{};
  for (final d in demands) {
    final k = key(d.jan, d.code, d.productId);
    asked[k] = (asked[k] ?? 0) + d.quantity;
    names[k] = d.name ?? d.code ?? d.jan ?? '?';
  }
  for (final b in boxes) {
    for (final i in b.items) {
      final k = key(i.jan, i.code, i.productId);
      packed[k] = (packed[k] ?? 0) + i.quantity;
      names.putIfAbsent(k, () => i.name ?? i.code ?? i.jan ?? '?');
    }
  }
  return [
    for (final k in {...asked.keys, ...packed.keys})
      if ((asked[k] ?? 0) != (packed[k] ?? 0)) (names[k]!, asked[k] ?? 0, packed[k] ?? 0),
  ];
}
