import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// While the AI reads a file: a sheet of paper with a swarm of pointers
/// going over it line by line, the lines behind them marked as read, and
/// how long it has taken so far. Only to look at — it knows nothing of the
/// reading's real progress. Still when the device asks for less motion.
class ReadingSwarm extends StatefulWidget {
  const ReadingSwarm({super.key, this.height = 240, this.cursors = 18, this.seed = 7});

  final double height;
  final int cursors;
  final int seed;

  @override
  State<ReadingSwarm> createState() => _ReadingSwarmState();
}

class _Cursor {
  _Cursor(this.pos, this.offset, this.color, this.tag);

  Offset pos;
  Offset vel = Offset.zero;

  /// Where in the swarm it likes to be, around the reading point.
  Offset offset;
  final Color color;
  final bool tag;
}

/// The rows of the sheet and the reading point on it.
const _rows = 12;
const _rowSeconds = 1.6;

class _ReadingSwarmState extends State<ReadingSwarm> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  late final math.Random _rnd = math.Random(widget.seed);
  final List<_Cursor> _cursors = [];
  Duration _last = Duration.zero;
  double _t = 0;
  Size _size = Size.zero;

  static const _palette = [
    Color(0xFF2563EB), Color(0xFFDB2777), Color(0xFF059669), Color(0xFFD97706), Color(0xFF7C3AED), Color(0xFF0891B2),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still && _ticker.isActive) _ticker.stop();
    if (!still && !_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _seed(Size size) {
    _cursors.clear();
    for (var i = 0; i < widget.cursors; i++) {
      final a = _rnd.nextDouble() * math.pi * 2, r = 18 + _rnd.nextDouble() * 46;
      _cursors.add(_Cursor(
        Offset(_rnd.nextDouble() * size.width, _rnd.nextDouble() * size.height),
        Offset(math.cos(a) * r, math.sin(a) * r * 0.55),
        _palette[i % _palette.length],
        i % 6 == 0,
      ));
    }
  }

  /// The paper's rectangle in a box of [size].
  static Rect paperOf(Size size) {
    final w = math.min(size.width - 32, 560.0);
    return Rect.fromLTWH((size.width - w) / 2, 14, w, size.height - 40);
  }

  /// Where the reading is at time [t]: along row [row], [along] of the way.
  static ({int row, double along, Offset at}) focusAt(Rect paper, double t) {
    final step = t / _rowSeconds;
    final row = step.floor() % _rows;
    final along = step - step.floor();
    final top = paper.top + 22, gap = (paper.height - 34) / _rows;
    final x = paper.left + 22 + along * (paper.width - 44);
    return (row: row, along: along, at: Offset(x, top + row * gap + gap * 0.35));
  }

  void _tick(Duration now) {
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = now;
    if (_size.isEmpty) return;
    _t += dt;
    final focus = focusAt(paperOf(_size), _t).at;
    for (final c in _cursors) {
      // Toward its place around the reading point, apart from the others,
      // with a little wandering of its own.
      var steer = (focus + c.offset - c.pos) * 3.2;
      for (final o in _cursors) {
        if (identical(o, c)) continue;
        final d = c.pos - o.pos;
        final dist = d.distance;
        if (dist > 0 && dist < 22) steer += d / dist * (22 - dist) * 9;
      }
      steer += Offset(_rnd.nextDouble() - 0.5, _rnd.nextDouble() - 0.5) * 160;
      c.vel = (c.vel + steer * dt) * 0.9;
      final speed = c.vel.distance;
      if (speed > 420) c.vel = c.vel / speed * 420;
      c.pos += c.vel * dt;
      // Now and then a new place in the swarm.
      if (_rnd.nextDouble() < dt * 0.25) {
        final a = _rnd.nextDouble() * math.pi * 2, r = 18 + _rnd.nextDouble() * 46;
        c.offset = Offset(math.cos(a) * r, math.sin(a) * r * 0.55);
      }
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
          _seed(size);
        }
        final secs = _t.floor();
        return Stack(children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: CustomPaint(
                key: const ValueKey('reading-swarm'),
                painter: _SwarmPainter(cursors: _cursors, t: _t, accent: scheme.primary),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 6,
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
  _SwarmPainter({required this.cursors, required this.t, required this.accent});

  final List<_Cursor> cursors;
  final double t;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final paper = _ReadingSwarmState.paperOf(size);
    final focus = _ReadingSwarmState.focusAt(paper, t);
    // The sheet: white paper whatever the app's design.
    canvas.drawRRect(
      RRect.fromRectAndRadius(paper.shift(const Offset(0, 2)), const Radius.circular(6)),
      Paint()..color = const Color(0x22000000),
    );
    canvas.drawRRect(RRect.fromRectAndRadius(paper, const Radius.circular(6)), Paint()..color = Colors.white);
    final top = paper.top + 22, gap = (paper.height - 34) / _rows;
    final bar = Paint()..color = const Color(0xFFE3E6EA);
    final read = Paint()..color = accent.withValues(alpha: 0.12);
    final now = Paint()..color = accent.withValues(alpha: 0.28);
    // A table's rows: a name, a code, figures — different lengths per row.
    const cols = [0.0, 0.42, 0.62, 0.78, 1.0];
    for (var r = 0; r < _rows; r++) {
      final y = top + r * gap;
      final rowRect = Rect.fromLTWH(paper.left + 14, y - 3, paper.width - 28, gap * 0.7 + 6);
      if (r < focus.row) canvas.drawRRect(RRect.fromRectAndRadius(rowRect, const Radius.circular(3)), read);
      if (r == focus.row) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(rowRect.left, rowRect.top, rowRect.width * focus.along, rowRect.height), const Radius.circular(3)),
          now,
        );
      }
      for (var k = 0; k < cols.length - 1; k++) {
        final left = paper.left + 22 + (paper.width - 44) * cols[k];
        final span = (paper.width - 44) * (cols[k + 1] - cols[k]) - 10;
        final fill = 0.45 + 0.5 * ((r * 7 + k * 3) % 5) / 4;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(left, y, span * fill, gap * 0.36), const Radius.circular(2)),
          bar,
        );
      }
    }
    for (final c in cursors) {
      _cursor(canvas, c.pos, c.color, c.tag);
    }
  }

  /// A pointer, tip at [at].
  void _cursor(Canvas canvas, Offset at, Color color, bool tag) {
    final p = Path()
      ..moveTo(at.dx, at.dy)
      ..lineTo(at.dx, at.dy + 16)
      ..lineTo(at.dx + 4.2, at.dy + 12.2)
      ..lineTo(at.dx + 7.4, at.dy + 18.6)
      ..lineTo(at.dx + 9.8, at.dy + 17.4)
      ..lineTo(at.dx + 6.8, at.dy + 11.2)
      ..lineTo(at.dx + 12, at.dy + 11.2)
      ..close();
    canvas.drawPath(p.shift(const Offset(0.8, 1.2)), Paint()..color = const Color(0x33000000));
    canvas.drawPath(p, Paint()..color = color);
    canvas.drawPath(
        p,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
    if (!tag) return;
    final label = TextPainter(
      text: const TextSpan(text: 'AI', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    final box = Rect.fromLTWH(at.dx + 11, at.dy + 15, label.width + 8, label.height + 3);
    canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(4)), Paint()..color = color);
    label.paint(canvas, Offset(box.left + 4, box.top + 1.5));
  }

  @override
  bool shouldRepaint(_SwarmPainter old) => true;
}
