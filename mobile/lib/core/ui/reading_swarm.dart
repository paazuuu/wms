import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// While the AI reads a file: a crowd of named pointers flying all over the
/// box and, between them, drawing the document's frame — the outer box,
/// the heading band, row and column lines, a box for each word — each
/// pointer tracing its own piece in its own colour, then the next. When the
/// page is done it fades and a new one is started. Only to look at: it
/// knows nothing of the reading's real progress. Still (one finished page)
/// when the device asks for less motion.
class ReadingSwarm extends StatefulWidget {
  const ReadingSwarm({super.key, this.height = 260, this.cursors = 16, this.seed = 7});

  final double height;
  final int cursors;
  final int seed;

  @override
  State<ReadingSwarm> createState() => _ReadingSwarmState();
}

/// One piece of the frame: a polyline a pointer traces, and how much of it
/// is drawn.
class _Shape {
  _Shape(this.points, {this.fill = false}) {
    for (var i = 1; i < points.length; i++) {
      length += (points[i] - points[i - 1]).distance;
    }
  }

  final List<Offset> points;
  final bool fill;
  double length = 0;
  double drawn = 0;
  bool taken = false;
  Color? color;

  bool get done => drawn >= length;

  /// The point [d] along it.
  Offset at(double d) {
    var left = d.clamp(0.0, length);
    for (var i = 1; i < points.length; i++) {
      final seg = (points[i] - points[i - 1]).distance;
      if (left <= seg || i == points.length - 1) {
        return Offset.lerp(points[i - 1], points[i], seg == 0 ? 1 : (left / seg).clamp(0.0, 1.0))!;
      }
      left -= seg;
    }
    return points.last;
  }

  /// The part drawn so far.
  Path drawnPath() {
    final p = Path()..moveTo(points.first.dx, points.first.dy);
    var left = drawn.clamp(0.0, length);
    for (var i = 1; i < points.length && left > 0; i++) {
      final seg = (points[i] - points[i - 1]).distance;
      final end = left >= seg ? points[i] : Offset.lerp(points[i - 1], points[i], left / seg)!;
      p.lineTo(end.dx, end.dy);
      left -= seg;
    }
    return p;
  }
}

class _Cursor {
  _Cursor(this.pos, this.color, this.name);

  Offset pos;
  Offset vel = Offset.zero;
  final Color color;
  final String name;
  _Shape? task;
  bool drawing = false;
  Offset? wanderTo;
}

enum _Phase { build, hold, fade }

class _ReadingSwarmState extends State<ReadingSwarm> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  late final math.Random _rnd = math.Random(widget.seed);
  final List<_Cursor> _cursors = [];
  List<_Shape> _shapes = [];
  Duration _last = Duration.zero;
  double _t = 0;
  double _phaseT = 0;
  _Phase _phase = _Phase.build;
  Size _size = Size.zero;

  static const _palette = [
    Color(0xFF2563EB), Color(0xFFDB2777), Color(0xFF059669), Color(0xFFD97706),
    Color(0xFF7C3AED), Color(0xFF0891B2), Color(0xFFDC2626), Color(0xFF65A30D),
  ];
  static const _names = ['AI', 'JAN', '品番', '数量', '単価', '金額', 'メーカー', '識別', '日付', '合計', '品名', '確認'];
  static const _drawSpeed = 340.0, _flySpeed = 900.0;

  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_still && _ticker.isActive) _ticker.stop();
    if (!_still && !_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _start(Size size) {
    _cursors.clear();
    for (var i = 0; i < widget.cursors; i++) {
      _cursors.add(_Cursor(
        Offset(_rnd.nextDouble() * size.width, _rnd.nextDouble() * size.height),
        _palette[i % _palette.length],
        _names[i % _names.length],
      ));
    }
    _shapes = _layout(size);
    _phase = _Phase.build;
    _phaseT = 0;
    if (_still) {
      for (final s in _shapes) {
        s
          ..drawn = s.length
          ..taken = true
          ..color = _palette[_rnd.nextInt(_palette.length)];
      }
    }
  }

  /// A page's frame, a little different each time: its pieces in the order
  /// they are drawn — outline, heading band, lines, then the words.
  List<_Shape> _layout(Size size) {
    List<Offset> rect(Rect r) => [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft, r.topLeft];
    final area = Rect.fromLTWH(18, 14, size.width - 36, size.height - 38);
    final shapes = <_Shape>[];
    // Title and date at the top.
    shapes.add(_Shape(rect(Rect.fromLTWH(area.left, area.top, area.width * (0.22 + _rnd.nextDouble() * 0.1), 14)), fill: true));
    shapes.add(_Shape(rect(Rect.fromLTWH(area.right - area.width * 0.16, area.top, area.width * 0.16, 14))));
    final table = Rect.fromLTRB(area.left, area.top + 26, area.right, area.bottom);
    shapes.add(_Shape(rect(table)));
    final head = Rect.fromLTWH(table.left, table.top, table.width, 18);
    shapes.add(_Shape(rect(head), fill: true));
    final rows = 5 + _rnd.nextInt(3);
    final rowH = (table.height - head.height) / rows;
    for (var r = 1; r < rows; r++) {
      final y = head.bottom + r * rowH;
      shapes.add(_Shape([Offset(table.left, y), Offset(table.right, y)]));
    }
    final weights = [2.8, 1.5, 1.0, 1.0, 1.2, 0.8];
    final sum = weights.fold<double>(0, (a, b) => a + b);
    final xs = <double>[table.left];
    for (final w in weights) {
      xs.add(xs.last + table.width * w / sum);
    }
    for (var c = 1; c < xs.length - 1; c++) {
      shapes.add(_Shape([Offset(xs[c], table.top), Offset(xs[c], table.bottom)]));
    }
    // A box round each word, row by row.
    for (var r = -1; r < rows; r++) {
      final top = r < 0 ? head.top + 5 : head.bottom + r * rowH + rowH / 2 - 4;
      for (var c = 0; c < xs.length - 1; c++) {
        final cell = xs[c + 1] - xs[c];
        final w = cell * (0.35 + _rnd.nextDouble() * 0.5);
        final left = c == 0 || c == 1 ? xs[c] + 6 : xs[c + 1] - 6 - w;
        shapes.add(_Shape(rect(Rect.fromLTWH(left, top, w, 8)), fill: r < 0 || _rnd.nextDouble() < 0.25));
      }
    }
    return shapes;
  }

  Offset _anywhere() => Offset(_rnd.nextDouble() * _size.width, _rnd.nextDouble() * _size.height);

  /// Toward [target] at [speed], curving a little as it goes.
  void _fly(_Cursor c, Offset target, double speed, double dt, int i) {
    var d = target - c.pos;
    final dist = d.distance;
    if (dist < 0.5) return;
    d = d / dist;
    final bend = math.sin(_t * 2.6 + i) * 0.55;
    final dir = Offset(d.dx * math.cos(bend) - d.dy * math.sin(bend), d.dx * math.sin(bend) + d.dy * math.cos(bend));
    final want = dir * math.min(speed, dist * 6);
    c.vel += (want - c.vel) * math.min(1.0, dt * 7);
    c.pos += c.vel * dt;
  }

  void _tick(Duration now) {
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = now;
    if (_size.isEmpty) return;
    _t += dt;
    _phaseT += dt;
    var next = 0;
    for (final (i, c) in _cursors.indexed) {
      if (_phase == _Phase.build && c.task == null) {
        while (next < _shapes.length && _shapes[next].taken) {
          next++;
        }
        if (next < _shapes.length) {
          c.task = _shapes[next]
            ..taken = true
            ..color = c.color;
          c.drawing = false;
        }
      }
      final s = c.task;
      if (s != null && !c.drawing) {
        _fly(c, s.at(0), _flySpeed, dt, i);
        if ((c.pos - s.at(0)).distance < 6) c.drawing = true;
      } else if (s != null) {
        s.drawn += _drawSpeed * dt;
        c.pos = s.at(s.drawn);
        c.vel = Offset.zero;
        if (s.done) c.task = null;
      } else {
        // Nothing to draw: about the whole box.
        final to = c.wanderTo ??= _anywhere();
        _fly(c, to, _flySpeed * 0.6, dt, i);
        if ((c.pos - to).distance < 10) c.wanderTo = null;
      }
    }
    switch (_phase) {
      case _Phase.build when _shapes.every((s) => s.done):
        _phase = _Phase.hold;
        _phaseT = 0;
      case _Phase.hold when _phaseT > 1.4:
        _phase = _Phase.fade;
        _phaseT = 0;
      case _Phase.fade when _phaseT > 0.8:
        _shapes = _layout(_size);
        _phase = _Phase.build;
        _phaseT = 0;
      default:
        break;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, widget.height);
        if (size != _size) {
          _size = size;
          _start(size);
        }
        final secs = _t.floor();
        final fade = _phase == _Phase.fade ? (1 - _phaseT / 0.8).clamp(0.0, 1.0) : 1.0;
        return Stack(children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CustomPaint(
                  key: const ValueKey('reading-swarm'),
                  painter: _SwarmPainter(
                    shapes: _shapes,
                    cursors: _still ? const [] : _cursors,
                    fade: fade,
                    settled: _phase != _Phase.build,
                    ink: scheme.onSurfaceVariant,
                    // The app's own type, so the names read in Japanese too.
                    labelStyle: (Theme.of(context).textTheme.labelSmall ?? const TextStyle())
                        .copyWith(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 4,
            child: Text(
              '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}',
              key: const ValueKey('reading-swarm-time'),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ]);
      }),
    );
  }
}

class _SwarmPainter extends CustomPainter {
  _SwarmPainter({
    required this.shapes,
    required this.cursors,
    required this.fade,
    required this.settled,
    required this.ink,
    required this.labelStyle,
  });

  final TextStyle labelStyle;

  final List<_Shape> shapes;
  final List<_Cursor> cursors;
  final double fade;

  /// The page is finished: its lines settle into one quiet colour.
  final bool settled;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in shapes) {
      if (s.drawn <= 0) continue;
      final color = settled ? ink : (s.color ?? ink);
      if (s.done && s.fill && s.points.length == 5) {
        canvas.drawRect(
          Rect.fromPoints(s.points[0], s.points[2]),
          Paint()..color = color.withValues(alpha: 0.16 * fade),
        );
      }
      canvas.drawPath(
        s.drawnPath(),
        Paint()
          ..color = color.withValues(alpha: (settled ? 0.55 : 0.9) * fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    for (final c in cursors) {
      _cursor(canvas, c);
    }
  }

  /// A pointer, tip at its position, with its name beside it.
  void _cursor(Canvas canvas, _Cursor c) {
    final at = c.pos;
    final p = Path()
      ..moveTo(at.dx, at.dy)
      ..lineTo(at.dx, at.dy + 16)
      ..lineTo(at.dx + 4.2, at.dy + 12.2)
      ..lineTo(at.dx + 7.4, at.dy + 18.6)
      ..lineTo(at.dx + 9.8, at.dy + 17.4)
      ..lineTo(at.dx + 6.8, at.dy + 11.2)
      ..lineTo(at.dx + 12, at.dy + 11.2)
      ..close();
    canvas.drawPath(p.shift(const Offset(0.8, 1.2)), Paint()..color = const Color(0x40000000));
    canvas.drawPath(p, Paint()..color = c.color);
    canvas.drawPath(
        p,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
    final label = TextPainter(
      text: TextSpan(text: c.name, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final box = Rect.fromLTWH(at.dx + 11, at.dy + 15, label.width + 10, label.height + 4);
    canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(5)), Paint()..color = c.color);
    label.paint(canvas, Offset(box.left + 5, box.top + 2));
  }

  @override
  bool shouldRepaint(_SwarmPainter old) => true;
}
