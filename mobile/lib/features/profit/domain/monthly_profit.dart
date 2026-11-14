/// 月ごとの収益 (0211): one product's month — what it sold for, what it was
/// bought for, and what could not be priced.
class ProfitRow {
  const ProfitRow({
    required this.month,
    this.productId,
    this.jan,
    required this.name,
    this.maker,
    required this.quantity,
    required this.revenue,
    required this.revenueCosted,
    required this.cost,
    this.qtyNoCost = 0,
    this.qtyNoPrice = 0,
    this.kind = 'stock',
    this.fee = 0,
    this.freight = 0,
  });

  /// 'YYYY-MM'.
  final String month;
  final int? productId;
  final String? jan;
  final String name;
  final String? maker;
  final int quantity;

  /// All that was sold, in yen.
  final double revenue;

  /// The part of [revenue] whose purchase price is known: what [cost] is
  /// set against.
  final double revenueCosted;
  final double cost;

  /// Shipped without a known purchase price: left out of the profit.
  final int qtyNoCost;

  /// Shipped in a currency with no rate: left out of the yen.
  final int qtyNoPrice;

  /// stock: out of our warehouse; proxy: 在庫外出荷 — our goods shipped
  /// from another company's warehouse for a fee (0213).
  final String kind;

  /// This row's share of the fee paid for shipping its list (委託手数料).
  final double fee;

  /// This row's share of the list's 輸送費 (0214), shared out the same way.
  final double freight;

  bool get proxy => kind == 'proxy';

  double get profit => revenueCosted - cost - fee - freight;

  /// How this row is told apart from others: the product, or its JAN or name.
  String get key => productId != null ? 'p$productId' : 'n${jan ?? name}';

  factory ProfitRow.fromJson(Map<String, dynamic> j) {
    double d(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
    int i(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
    return ProfitRow(
      month: '${j['month']}',
      productId: j['product_id'] == null ? null : i(j['product_id']),
      jan: j['jan_code'] as String?,
      name: (j['product_name'] as String?) ?? (j['jan_code'] as String?) ?? '—',
      maker: j['maker'] as String?,
      quantity: i(j['quantity']),
      revenue: d(j['revenue']),
      revenueCosted: d(j['revenue_costed']),
      cost: d(j['cost']),
      qtyNoCost: i(j['qty_no_cost']),
      qtyNoPrice: i(j['qty_no_price']),
      kind: (j['kind'] as String?) ?? 'stock',
      fee: d(j['fee']),
      freight: d(j['freight']),
    );
  }
}

/// A month's totals over the rows that pass the filter.
class ProfitMonth {
  ProfitMonth(this.month);

  final String month;
  int quantity = 0;
  double revenue = 0;
  double revenueCosted = 0;
  double cost = 0;
  int qtyNoCost = 0;
  double revenueNoCost = 0;
  int qtyNoPrice = 0;

  /// 委託手数料 paid for 在庫外出荷: a cost of the profit.
  double fee = 0;

  /// 輸送費 (0214): a cost of the profit too.
  double freight = 0;

  /// The purchase cost, the fee and the freight together.
  double get costAll => cost + fee + freight;

  /// The profit of what left our warehouse, and of 在庫外出荷 (after the fee
  /// and the freight).
  double profitStock = 0;
  double profitProxy = 0;

  double get profit => revenueCosted - cost - fee - freight;

  /// Profit over what it was set against; null with nothing priced.
  double? get margin => revenueCosted == 0 ? null : profit / revenueCosted;

  void add(ProfitRow r) {
    quantity += r.quantity;
    revenue += r.revenue;
    revenueCosted += r.revenueCosted;
    cost += r.cost;
    qtyNoCost += r.qtyNoCost;
    revenueNoCost += r.revenue - r.revenueCosted;
    qtyNoPrice += r.qtyNoPrice;
    fee += r.fee;
    freight += r.freight;
    if (r.proxy) {
      profitProxy += r.profit;
    } else {
      profitStock += r.profit;
    }
  }
}

/// The months from [from] to [to] ('YYYY-MM'), each present even when
/// nothing shipped, so the bars keep their places.
List<String> monthsBetween(DateTime from, DateTime to) {
  final out = <String>[];
  var y = from.year, m = from.month;
  while (y < to.year || (y == to.year && m <= to.month)) {
    out.add('$y-${m.toString().padLeft(2, '0')}');
    m++;
    if (m > 12) {
      m = 1;
      y++;
    }
  }
  return out;
}

/// The months over [rows] that pass [keep], in [months]' order.
List<ProfitMonth> profitByMonth(List<String> months, Iterable<ProfitRow> rows, bool Function(ProfitRow) keep) {
  final by = {for (final m in months) m: ProfitMonth(m)};
  for (final r in rows) {
    if (!keep(r)) continue;
    by[r.month]?.add(r);
  }
  return [for (final m in months) by[m]!];
}

/// Products over the period with their totals, the most profitable first.
List<({ProfitRow first, ProfitMonth total})> profitByProduct(Iterable<ProfitRow> rows, bool Function(ProfitRow) keep) {
  final by = <String, ({ProfitRow first, ProfitMonth total})>{};
  for (final r in rows) {
    if (!keep(r)) continue;
    final e = by.putIfAbsent(r.key, () => (first: r, total: ProfitMonth('')));
    e.total.add(r);
  }
  final list = by.values.toList()..sort((a, b) => b.total.profit.compareTo(a.total.profit));
  return list;
}
