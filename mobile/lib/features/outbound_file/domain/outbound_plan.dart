import '../data/outbound_file_repository.dart';
import 'outbound_sheet.dart';

/// What a row is, before anything is posted.
enum OutboundStatus {
  /// Its product is known and there is stock enough.
  ok,

  /// Its product is known; the stock is less than the row asks for.
  short,

  /// A JAN not in the 商品ライブラリー.
  unknownJan,

  /// No JAN, and no product has its 品番.
  noJan,

  /// Its 品番 fits more than one product: one has to be chosen.
  several,

  /// No quantity to ship.
  noQuantity,
}

/// What is done with a row.
enum OutboundAction {
  /// Taken out of stock (as much as there is).
  ship,

  /// Kept with the list, no stock moved.
  record,

  /// Left out.
  skip;

  String get wire => name;
}

/// One row as it will be posted: what it is, what will be done, how many go
/// out and how many are short.
class OutboundPlanLine {
  const OutboundPlanLine({
    required this.row,
    required this.match,
    required this.status,
    required this.action,
    required this.shipped,
    required this.short,
    this.stockBefore,
  });

  final OutboundRow row;
  final OutboundMatch match;
  final OutboundStatus status;
  final OutboundAction action;

  /// What leaves the stock (ship only).
  final int shipped;

  /// What the stock could not cover (ship only).
  final int short;

  /// The stock left for this row, after the rows above it.
  final int? stockBefore;

  bool get found => match.productId != null;

  double? get weightG => match.unitWeightG == null ? null : match.unitWeightG! * (row.quantity ?? 0);

  OutboundPostLine toPost() => OutboundPostLine(
        rowNo: row.rowNo,
        action: action.wire,
        productId: match.productId,
        jan: row.jan.isNotEmpty ? row.jan : (row.janRaw.isEmpty ? null : row.janRaw),
        productName: match.name ?? row.name,
        maker: row.maker,
        code: row.code,
        supplier: row.supplier,
        quantity: row.quantity,
        unitPrice: row.priceEx,
        unitPriceTax: row.priceTax,
        taxRate: row.taxRate == null ? null : row.rate,
        listPrice: row.listPrice,
        amount: row.total,
        orderNumber: row.orderNumber,
        arrival: row.arrival,
        orderDate: row.orderDate,
        matchedBy: match.matchedBy.name,
        raw: row.raw,
      );
}

/// What a row is, from its product (if any) and the stock left for it.
OutboundStatus outboundStatusOf(OutboundRow row, OutboundMatch m, int? stockLeft) {
  if ((row.quantity ?? 0) <= 0) return OutboundStatus.noQuantity;
  if (m.productId != null) return (stockLeft ?? 0) < row.quantity! ? OutboundStatus.short : OutboundStatus.ok;
  if (m.matchedBy == OutboundMatchedBy.several) return OutboundStatus.several;
  return row.jan.isNotEmpty ? OutboundStatus.unknownJan : OutboundStatus.noJan;
}

/// What is done with a row unless chosen otherwise: what can go out goes
/// out; a row with no product is kept as a record; one with nothing to ship,
/// left out.
OutboundAction defaultOutboundAction(OutboundStatus s) => switch (s) {
      OutboundStatus.ok || OutboundStatus.short => OutboundAction.ship,
      OutboundStatus.noQuantity => OutboundAction.skip,
      _ => OutboundAction.record,
    };

/// The list, row by row in order. [picked] replaces a row's product (chosen
/// by hand); [chosen] its action. The same product on several rows takes
/// from one stock: a row lower down has what the rows above left.
///
/// [proxy] (代理出荷, 0189): nothing is taken out of stock — every row is a
/// record (or left out), whatever its product and stock.
List<OutboundPlanLine> planOutbound(
  List<OutboundRow> rows,
  List<OutboundMatch> matches, {
  Map<int, OutboundMatch> picked = const {},
  Map<int, OutboundAction> chosen = const {},
  bool proxy = false,
}) {
  final left = <int, int>{};
  final out = <OutboundPlanLine>[];
  for (final (i, row) in rows.indexed) {
    final m = picked[row.rowNo] ?? (i < matches.length ? matches[i] : OutboundMatch.none);
    final pid = m.productId;
    if (pid != null) left.putIfAbsent(pid, () => m.onHand ?? 0);
    final stock = pid == null ? null : left[pid];
    final status = outboundStatusOf(row, m, stock);
    var action = chosen[row.rowNo] ??
        (proxy && status != OutboundStatus.noQuantity ? OutboundAction.record : defaultOutboundAction(status));
    // Nothing to take out of stock without a product, nor in a 代理出荷.
    if (action == OutboundAction.ship && (pid == null || proxy)) action = OutboundAction.record;
    var shipped = 0, short = 0;
    if (action == OutboundAction.ship) {
      final q = row.quantity ?? 0;
      shipped = q < (stock ?? 0) ? q : (stock ?? 0);
      if (shipped < 0) shipped = 0;
      short = q - shipped;
      left[pid!] = (stock ?? 0) - shipped;
    }
    out.add(OutboundPlanLine(
      row: row,
      match: m,
      status: status,
      action: action,
      shipped: shipped,
      short: short,
      stockBefore: stock,
    ));
  }
  return out;
}

/// The list's totals as shown before posting.
class OutboundPlanTotals {
  const OutboundPlanTotals({
    required this.rows,
    required this.ship,
    required this.record,
    required this.skip,
    required this.shortRows,
    required this.shipped,
    required this.short,
    required this.amount,
    required this.weightG,
    required this.byStatus,
  });

  factory OutboundPlanTotals.of(List<OutboundPlanLine> lines) {
    var amount = 0.0, weight = 0.0;
    final by = <OutboundStatus, int>{};
    for (final l in lines) {
      by[l.status] = (by[l.status] ?? 0) + 1;
      if (l.action != OutboundAction.skip) amount += l.row.total ?? 0;
      if (l.action == OutboundAction.ship && l.match.unitWeightG != null) weight += l.match.unitWeightG! * l.shipped;
    }
    return OutboundPlanTotals(
      rows: lines.length,
      ship: lines.where((l) => l.action == OutboundAction.ship).length,
      record: lines.where((l) => l.action == OutboundAction.record).length,
      skip: lines.where((l) => l.action == OutboundAction.skip).length,
      shortRows: lines.where((l) => l.short > 0).length,
      shipped: lines.fold(0, (a, l) => a + l.shipped),
      short: lines.fold(0, (a, l) => a + l.short),
      amount: amount,
      weightG: weight,
      byStatus: by,
    );
  }

  final int rows;
  final int ship;
  final int record;
  final int skip;
  final int shortRows;
  final int shipped;
  final int short;
  final double amount;
  final double weightG;
  final Map<OutboundStatus, int> byStatus;
}
