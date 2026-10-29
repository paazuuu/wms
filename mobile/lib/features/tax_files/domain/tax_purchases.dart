import 'package:equatable/equatable.dart';

import '../../stock_import/domain/stock_file.dart' show ReadRow, humanRemovedFlag;
import '../../stock_import/domain/stock_ledger.dart' show keptUntil;

/// 税理士用ファイル (0168): one invoice that went into stock — its supplier,
/// 登録番号, number and date, its lines as read and checked, the document's
/// own totals, and where the original is kept.
class TaxPurchase extends Equatable {
  const TaxPurchase({
    required this.importId,
    required this.day,
    this.documentDate,
    this.createdAt,
    this.status,
    this.originalName,
    this.originalPath,
    this.paid = false,
    this.note,
    this.warehouseName,
    this.lines = const [],
    this.documentId,
    this.supplierName,
    this.registrationNumber,
    this.docNumber,
    this.addressee,
    this.docSubtotal,
    this.docTax,
    this.docTotal,
    this.evidencePath,
    this.evidenceName,
    this.evidenceType,
    this.sha256,
  });

  final int importId;

  /// The month it belongs to is this day's: the document's date, else the
  /// day it was taken in.
  final DateTime day;
  final DateTime? documentDate;
  final DateTime? createdAt;
  final String? status;
  final String? originalName;
  final String? originalPath;
  final bool paid;
  final String? note;
  final String? warehouseName;
  final List<ReadRow> lines;
  final int? documentId;
  final String? supplierName;
  final String? registrationNumber;
  final String? docNumber;
  final String? addressee;

  /// As the document itself prints them (null when not read).
  final double? docSubtotal;
  final double? docTax;
  final double? docTotal;

  /// The evidence copy (import-documents) and the import's own original.
  final String? evidencePath;
  final String? evidenceName;
  final String? evidenceType;
  final String? sha256;

  /// Kept until (7 years from the document's date, as the files are).
  DateTime get keptTill => keptUntil(day);

  /// A 適格請求書: a 登録番号 T + 13 digits.
  bool get qualified => RegExp(r'^T\d{13}$').hasMatch((registrationNumber ?? '').replaceAll(RegExp(r'[\s-]'), ''));

  factory TaxPurchase.fromJson(Map<String, dynamic> j) {
    final doc = (j['document'] as Map?)?.cast<String, dynamic>() ?? const {};
    final totals = (doc['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    double? n(Object? v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
    DateTime? d(Object? v) => v == null ? null : DateTime.tryParse('$v');
    final day = d(j['day']) ?? DateTime(2000);
    return TaxPurchase(
      importId: (j['id'] as num).toInt(),
      day: DateTime(day.year, day.month, day.day),
      documentDate: d(j['document_date']),
      createdAt: d(j['created_at'])?.toLocal(),
      status: j['status'] as String?,
      originalName: j['original_name'] as String?,
      originalPath: j['original_path'] as String?,
      paid: j['paid'] == true,
      note: j['note'] as String?,
      warehouseName: j['warehouse_name'] as String?,
      lines: [
        for (final r in (j['read_lines'] as List? ?? const []).whereType<Map>()) ReadRow.fromJson(r.cast<String, dynamic>()),
      ],
      documentId: (doc['id'] as num?)?.toInt(),
      supplierName: doc['supplier_name'] as String?,
      registrationNumber: doc['registration_number'] as String?,
      docNumber: doc['doc_number'] as String?,
      addressee: doc['addressee'] as String?,
      docSubtotal: n(totals['doc_subtotal']),
      docTax: n(totals['doc_tax']),
      docTotal: n(totals['doc_total']),
      evidencePath: doc['storage_path'] as String?,
      evidenceName: doc['file_name'] as String?,
      evidenceType: doc['content_type'] as String?,
      sha256: doc['sha256'] as String?,
    );
  }

  /// The lines that count: every row read but those a person left out, and
  /// rows with nothing priced.
  List<TaxLine> get taxLines => [
        for (final r in lines)
          if (!r.flags.contains(humanRemovedFlag))
            if (TaxLine.of(r) case final l?) l,
      ];

  /// 税抜・消費税 by rate: the tax worked out once per rate on the invoice
  /// (適格請求書の端数処理: 1請求書・税率ごとに1回、切り捨て) — or, when the
  /// invoice is all at one rate and prints its tax, that tax.
  Map<int, ({double net, double tax})> get byRate {
    final net = <int, double>{};
    for (final l in taxLines) {
      net[l.rate] = (net[l.rate] ?? 0) + l.net;
    }
    final out = <int, ({double net, double tax})>{};
    for (final e in net.entries) {
      final worked = (e.value * e.key / 100).floorToDouble();
      final tax = net.length == 1 && docTax != null ? docTax! : worked;
      out[e.key] = (net: e.value.roundToDouble(), tax: tax);
    }
    return out;
  }

  double get net => byRate.values.fold(0, (s, x) => s + x.net);
  double get tax => byRate.values.fold(0, (s, x) => s + x.tax);
  double get gross => net + tax;

  /// The figures against the document's own: null when it printed none.
  bool? get agrees {
    if (docTotal == null && docSubtotal == null) return null;
    if (docTotal != null && (docTotal! - gross).abs() > 1) return false;
    if (docSubtotal != null && (docSubtotal! - net).abs() > 1) return false;
    return true;
  }

  /// What to look at before it goes to the accountant.
  List<String> get doubts => [
        if (!qualified) 'no_registration',
        if (agrees == false) 'totals',
        if (taxLines.isEmpty) 'no_amounts',
        if (documentDate == null) 'no_date',
      ];

  @override
  List<Object?> get props => [importId, day, lines, supplierName, registrationNumber, docTotal, paid];
}

/// One line's money: 税抜 (as the invoice prices it), the rate, and the tax
/// and 税込 for reference (the invoice's tax is worked out per rate, above).
class TaxLine extends Equatable {
  const TaxLine({
    required this.row,
    required this.quantity,
    required this.net,
    required this.rate,
    this.unitNet,
    this.unitGross,
  });

  final ReadRow row;
  final double quantity;
  final double net;
  final int rate;
  final double? unitNet;
  final double? unitGross;

  double get tax => net * rate / 100;
  double get gross => net + tax;

  static double? _num(String v) {
    final t = v.replaceAll(RegExp(r'[,，\s¥￥円]'), '');
    return t.isEmpty ? null : double.tryParse(t);
  }

  /// 8% (軽減税率), 0% (非課税・不課税・免税), else 10%.
  static int rateOf(String v) {
    final t = v.replaceAll(RegExp(r'\s'), '');
    if (t.isEmpty) return 10;
    if (RegExp(r'軽減|※|\*|^8|8%|０?\.0?8|0\.08').hasMatch(t)) return 8;
    if (RegExp(r'非課税|不課税|免税|^0%?$|対象外').hasMatch(t)) return 0;
    final n = double.tryParse(t.replaceAll('%', ''));
    if (n == null) return 10;
    final pct = n < 1 ? n * 100 : n;
    return pct.round() == 8 ? 8 : (pct.round() == 0 ? 0 : 10);
  }

  /// The line from a row read, or null when it carries no price at all.
  static TaxLine? of(ReadRow r) {
    final q = _num(r.quantity) ?? 0;
    final rate = rateOf(r.ledger.taxRate);
    final unitNet = _num(r.ledger.unitPrice);
    final unitGross = _num(r.ledger.unitPriceTax);
    final amount = _num(r.ledger.amount);
    double? net;
    if (amount != null && (unitNet != null || unitGross == null)) {
      net = amount;
    } else if (unitNet != null) {
      net = q * unitNet;
    } else if (unitGross != null || amount != null) {
      // Only 税込 is printed: the 税抜 worked back from it.
      final gross = amount ?? q * unitGross!;
      net = gross * 100 / (100 + rate);
    }
    if (net == null) return null;
    return TaxLine(row: r, quantity: q, net: net, rate: rate, unitNet: unitNet, unitGross: unitGross);
  }

  @override
  List<Object?> get props => [row, quantity, net, rate];
}

/// A month's purchases and its totals.
class TaxMonth extends Equatable {
  const TaxMonth({required this.month, required this.purchases});

  /// The first day of the month.
  final DateTime month;
  final List<TaxPurchase> purchases;

  double get net => purchases.fold(0, (s, p) => s + p.net);
  double get tax => purchases.fold(0, (s, p) => s + p.tax);
  double get gross => purchases.fold(0, (s, p) => s + p.gross);
  int get doubtful => purchases.where((p) => p.doubts.isNotEmpty).length;

  /// The month's files are kept until 7 years after its last day.
  DateTime get keptTill => keptUntil(DateTime(month.year, month.month + 1, 0));

  /// The latest import in it: when the file last changed.
  DateTime? get updatedAt => purchases
      .map((p) => p.createdAt)
      .whereType<DateTime>()
      .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);

  static List<TaxMonth> group(List<TaxPurchase> all) {
    final by = <DateTime, List<TaxPurchase>>{};
    for (final p in all) {
      by.putIfAbsent(DateTime(p.day.year, p.day.month), () => []).add(p);
    }
    return [
      for (final e in by.entries.toList()..sort((a, b) => b.key.compareTo(a.key))) TaxMonth(month: e.key, purchases: e.value),
    ];
  }

  @override
  List<Object?> get props => [month, purchases];
}
