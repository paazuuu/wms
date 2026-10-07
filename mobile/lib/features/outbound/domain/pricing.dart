import 'dart:math' as math;

/// A price a shipment line can show or be worked out from (0142).
enum PriceColumn {
  /// 原価: the supplier term in force, else the last purchase price.
  cost('cost'),

  /// 定価.
  list('list'),

  /// 販売価格: the product's selling price.
  sell('sell'),

  /// 出荷単価: the price this shipment goes out at (after a rate, a
  /// percentage or a formula).
  ship('ship');

  const PriceColumn(this.wire);
  final String wire;

  static PriceColumn? fromWire(String? v) => values.where((c) => c.wire == v).firstOrNull;
}

/// How a bulk price is set.
enum PriceMethod {
  /// 掛け率: base × rate (0.7 = 7掛け).
  rate,

  /// ％: base ± a percentage (+20 = 20% up, -10 = 10% off).
  percent,

  /// 式: a formula, Excel-like, over 原価・定価・販売価格・出荷単価・基準.
  formula,
}

enum PriceRounding { down, nearest, up }

/// The prices one line has to work from.
class PriceInputs {
  const PriceInputs({this.cost, this.list, this.sell, this.ship});

  final double? cost;
  final double? list;
  final double? sell;
  final double? ship;

  double? of(PriceColumn c) => switch (c) {
        PriceColumn.cost => cost,
        PriceColumn.list => list,
        PriceColumn.sell => sell,
        PriceColumn.ship => ship,
      };
}

/// [v] rounded to [step] (1, 10, 100 … or 0.01) in [direction].
double roundPrice(double v, double step, PriceRounding direction) {
  if (step <= 0) return v;
  // A hair of floating point must not push 120.0000001 up to 130.
  final q = v / step;
  final r = switch (direction) {
    PriceRounding.down => (q + 1e-9).floorToDouble(),
    PriceRounding.nearest => q.roundToDouble(),
    PriceRounding.up => (q - 1e-9).ceilToDouble(),
  };
  final out = r * step;
  // Keep cents tidy (0.1 + 0.2 and friends).
  return double.parse(out.toStringAsFixed(step < 1 ? 2 : 0));
}

/// The price [method] gives one line, or null when what it needs is
/// missing (no 原価 for a product, say). Never negative.
double? applyPrice(
  PriceInputs p, {
  required PriceMethod method,
  required PriceColumn base,
  double? value,
  String? formula,
  double step = 1,
  PriceRounding rounding = PriceRounding.nearest,
}) {
  final b = p.of(base);
  final double? raw = switch (method) {
    PriceMethod.rate => b == null || value == null ? null : b * value,
    PriceMethod.percent => b == null || value == null ? null : b * (1 + value / 100),
    PriceMethod.formula => formula == null ? null : evaluatePriceFormula(formula, p, base: b),
  };
  if (raw == null || raw.isNaN || raw.isInfinite) return null;
  return roundPrice(math.max(raw, 0), step, rounding);
}

/// A formula over a line's prices, Excel-like:
///   * numbers, + - * / ( ), × ÷, and 20% as 0.2; a leading = is fine;
///   * names: 原価 (cost), 定価 (list), 販売価格 (sell), 出荷単価 (ship),
///     基準 (base, x) — the base column chosen;
///   * ROUND(x, n), ROUNDUP(x, n), ROUNDDOWN(x, n) as in Excel (n = -1 for
///     tens), CEILING(x, step), FLOOR(x, step), MIN(…), MAX(…), ABS(x).
/// Null when a name it uses has no value for the line. Throws
/// [FormatException] for a formula that does not read.
double? evaluatePriceFormula(String formula, PriceInputs p, {double? base}) =>
    _Parser(formula, {
      '原価': p.cost, 'cost': p.cost,
      '定価': p.list, 'list': p.list,
      '販売価格': p.sell, '売価': p.sell, 'sell': p.sell,
      '出荷単価': p.ship, 'ship': p.ship, '現在': p.ship,
      '基準': base, 'base': base, 'x': base,
    }).parse();

/// Checks [formula] reads, without any line.
String? priceFormulaError(String formula) {
  try {
    evaluatePriceFormula(formula, const PriceInputs(cost: 1, list: 1, sell: 1, ship: 1), base: 1);
    return null;
  } on FormatException catch (e) {
    return e.message;
  }
}

class _Missing implements Exception {
  const _Missing();
}

class _Parser {
  _Parser(String source, this.vars) : s = _normalise(source);

  final String s;
  final Map<String, double?> vars;
  int i = 0;

  static String _normalise(String v) {
    var t = v.trim();
    if (t.startsWith('=') || t.startsWith('＝')) t = t.substring(1);
    const wide = '０１２３４５６７８９．＋－＊／（），％';
    const narrow = '0123456789.+-*/(),%';
    final b = StringBuffer();
    for (final ch in t.split('')) {
      final k = wide.indexOf(ch);
      b.write(switch (ch) {
        '×' => '*',
        '÷' => '/',
        '−' => '-',
        _ => k >= 0 ? narrow[k] : ch,
      });
    }
    return b.toString();
  }

  double? parse() {
    try {
      final v = _expr();
      _space();
      if (i < s.length) throw FormatException('unexpected "${s[i]}"');
      return v;
    } on _Missing {
      return null;
    }
  }

  void _space() {
    while (i < s.length && (s[i] == ' ' || s[i] == '　')) {
      i++;
    }
  }

  bool _eat(String c) {
    _space();
    if (i < s.length && s[i] == c) {
      i++;
      return true;
    }
    return false;
  }

  double _expr() {
    var v = _term();
    while (true) {
      if (_eat('+')) {
        v += _term();
      } else if (_eat('-')) {
        v -= _term();
      } else {
        return v;
      }
    }
  }

  double _term() {
    var v = _unary();
    while (true) {
      if (_eat('*')) {
        v *= _unary();
      } else if (_eat('/')) {
        final d = _unary();
        if (d == 0) throw const FormatException('division by zero');
        v /= d;
      } else {
        return v;
      }
    }
  }

  double _unary() {
    if (_eat('-')) return -_unary();
    if (_eat('+')) return _unary();
    return _postfix();
  }

  double _postfix() {
    var v = _atom();
    while (_eat('%')) {
      v /= 100;
    }
    return v;
  }

  double _atom() {
    _space();
    if (i >= s.length) throw const FormatException('the formula ends too soon');
    if (_eat('(')) {
      final v = _expr();
      if (!_eat(')')) throw const FormatException('a ) is missing');
      return v;
    }
    final c = s[i];
    if (RegExp(r'[0-9.]').hasMatch(c)) {
      final start = i;
      while (i < s.length && RegExp(r'[0-9.]').hasMatch(s[i])) {
        i++;
      }
      final n = double.tryParse(s.substring(start, i));
      if (n == null) throw FormatException('"${s.substring(start, i)}" is not a number');
      return n;
    }
    final start = i;
    while (i < s.length && !RegExp(r'[\s+\-*/(),%　]').hasMatch(s[i])) {
      i++;
    }
    final name = s.substring(start, i);
    if (name.isEmpty) throw FormatException('unexpected "$c"');
    _space();
    if (i < s.length && s[i] == '(') {
      i++;
      final args = <double>[];
      if (!_eat(')')) {
        do {
          args.add(_expr());
        } while (_eat(','));
        if (!_eat(')')) throw const FormatException('a ) is missing');
      }
      return _call(name.toUpperCase(), args);
    }
    final key = vars.keys.where((k) => k.toLowerCase() == name.toLowerCase()).firstOrNull;
    if (key == null) throw FormatException('unknown name "$name"');
    final v = vars[key];
    if (v == null) throw const _Missing();
    return v;
  }

  double _call(String f, List<double> a) {
    double arg(int n, [double? or]) {
      if (n < a.length) return a[n];
      if (or != null) return or;
      throw FormatException('$f needs more numbers');
    }

    double digits(double x, double n, double Function(double) how) {
      final m = math.pow(10, n).toDouble();
      return how(x * m) / m;
    }

    return switch (f) {
      'ROUND' => digits(arg(0), arg(1, 0), (v) => v.roundToDouble()),
      'ROUNDUP' => digits(arg(0), arg(1, 0), (v) => v < 0 ? (v - 1e-9).floorToDouble() : (v - 1e-9).ceilToDouble()),
      'ROUNDDOWN' => digits(arg(0), arg(1, 0), (v) => v < 0 ? (v + 1e-9).ceilToDouble() : (v + 1e-9).floorToDouble()),
      'CEILING' => roundPrice(arg(0), arg(1, 1), PriceRounding.up),
      'FLOOR' => roundPrice(arg(0), arg(1, 1), PriceRounding.down),
      'MIN' when a.isNotEmpty => a.reduce(math.min),
      'MAX' when a.isNotEmpty => a.reduce(math.max),
      'ABS' => arg(0).abs(),
      _ => throw FormatException('unknown function "$f"'),
    };
  }
}
