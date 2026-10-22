import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

/// The chart colors, in their fixed order (slot 1, 2, 3, 4): blue, orange,
/// aqua, yellow. Validated as a set for colour-blind separation on the light
/// and dark surfaces; a series keeps its slot whatever else is shown, and a
/// fifth kind of thing is folded into "other" rather than given a new hue.
/// Two of the light steps sit below 3:1 on white, which is why every chart
/// here also labels its lines and has a table under it.
Color chartSlot(BuildContext context, int slot) {
  const light = [Color(0xFF2A78D6), Color(0xFFEB6834), Color(0xFF1BAF7A), Color(0xFFEDA100)];
  const dark = [Color(0xFF3987E5), Color(0xFFD95926), Color(0xFF199E70), Color(0xFFC98500)];
  final list = Theme.of(context).brightness == Brightness.dark ? dark : light;
  return list[slot.clamp(0, list.length - 1)];
}

/// One point of a series. [marker] draws a dot of that color on it (an
/// event worth seeing, such as stock from a file).
class ChartPoint {
  const ChartPoint(this.x, this.y, {this.marker});

  final DateTime x;
  final double y;
  final Color? marker;
}

class ChartSeries {
  const ChartSeries({required this.id, required this.label, required this.color, required this.points, this.step = false});

  final String id;
  final String label;
  final Color color;

  /// In time order.
  final List<ChartPoint> points;

  /// A level that holds until it changes (a stock), drawn flat then up or
  /// down, rather than as a slope between two counts.
  final bool step;

  /// The value at [x]: the last point at or before it.
  double? valueAt(DateTime x) {
    double? v;
    for (final p in points) {
      if (p.x.isAfter(x)) break;
      v = p.y;
    }
    return v;
  }
}

/// A line chart over time: hairline grid, 2px lines, the series' names at
/// their ends, and a crosshair that finds the nearest date under the pointer
/// (or finger) with every series' value there. [details] adds lines to that
/// readout for a date (what happened then). The data is meant to be in a
/// table beside it too: the readout enhances, it never holds the only copy.
class TimeLineChart extends StatefulWidget {
  const TimeLineChart({
    super.key,
    required this.series,
    this.height = 220,
    this.formatY,
    this.details,
    this.endLabels = true,
  });

  final List<ChartSeries> series;
  final double height;
  final String Function(double v)? formatY;
  final List<String> Function(DateTime x)? details;
  final bool endLabels;

  @override
  State<TimeLineChart> createState() => _TimeLineChartState();
}

class _TimeLineChartState extends State<TimeLineChart> {
  DateTime? _at;

  static const _left = 48.0;
  static const _top = 8.0;
  static const _bottom = 24.0;

  double get _right => widget.endLabels && widget.series.length > 1 ? 96 : 16;

  List<DateTime> get _xs {
    final s = <DateTime>{for (final c in widget.series) for (final p in c.points) p.x}.toList()..sort();
    return s;
  }

  String _fmt(double v) => widget.formatY?.call(v) ?? NumberFormat.decimalPattern().format(v.round());

  void _pick(Offset local, double width) {
    final xs = _xs;
    if (xs.isEmpty) return;
    final (x0, x1) = (xs.first, xs.last);
    final span = math.max(1, x1.difference(x0).inMilliseconds);
    final t = ((local.dx - _left) / math.max(1, width - _left - _right)).clamp(0.0, 1.0);
    final target = x0.add(Duration(milliseconds: (span * t).round()));
    var best = xs.first;
    for (final x in xs) {
      if ((x.difference(target).inMilliseconds).abs() < (best.difference(target).inMilliseconds).abs()) best = x;
    }
    if (best != _at) setState(() => _at = best);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final xs = _xs;
    return LayoutBuilder(builder: (context, c) {
      final width = c.maxWidth;
      final at = _at;
      final painter = _ChartPainter(
        series: widget.series,
        xs: xs,
        at: at,
        left: _left,
        right: _right,
        top: _top,
        bottom: _bottom,
        grid: scheme.outlineVariant,
        ink: scheme.onSurfaceVariant,
        strong: scheme.onSurface,
        surface: theme.cardColor,
        label: theme.textTheme.labelSmall ?? const TextStyle(fontSize: 11),
        formatY: _fmt,
        endLabels: widget.endLabels && widget.series.length > 1,
      );
      final readout = at == null
          ? null
          : _Readout(
              at: at,
              rows: [
                for (final s in widget.series)
                  if (s.valueAt(at) case final v?) (s.color, _fmt(v), s.label),
              ],
              details: widget.details?.call(at) ?? const [],
            );
      final atX = at == null || xs.length < 2
          ? null
          : _left +
              (width - _left - _right) *
                  (at.difference(xs.first).inMilliseconds / math.max(1, xs.last.difference(xs.first).inMilliseconds));
      return MouseRegion(
        onHover: (e) => _pick(e.localPosition, width),
        onExit: (_) => setState(() => _at = null),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _pick(d.localPosition, width),
          onHorizontalDragUpdate: (d) => _pick(d.localPosition, width),
          child: SizedBox(
            height: widget.height,
            width: width,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(child: CustomPaint(painter: painter)),
              if (readout != null && atX != null)
                Positioned(
                  top: 0,
                  // Beside the crosshair, on whichever side has room.
                  left: atX < width / 2 ? atX + 12 : null,
                  right: atX >= width / 2 ? width - atX + 12 : null,
                  child: readout,
                ),
            ]),
          ),
        ),
      );
    });
  }
}

class _Readout extends StatelessWidget {
  const _Readout({required this.at, required this.rows, required this.details});

  final DateTime at;
  final List<(Color, String, String)> rows;
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Material(
        key: const ValueKey('chart-readout'),
        elevation: 3,
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(DateFormat('y/MM/dd HH:mm').format(at.toLocal()), style: muted),
            for (final (color, value, label) in rows)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 12, height: 2, color: color),
                const SizedBox(width: 6),
                Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                Flexible(child: Text(label, style: muted, overflow: TextOverflow.ellipsis)),
              ]),
            for (final d in details) Text(d, style: theme.textTheme.bodySmall),
          ]),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.series,
    required this.xs,
    required this.at,
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    required this.grid,
    required this.ink,
    required this.strong,
    required this.surface,
    required this.label,
    required this.formatY,
    required this.endLabels,
  });

  final List<ChartSeries> series;
  final List<DateTime> xs;
  final DateTime? at;
  final double left, right, top, bottom;
  final Color grid, ink, strong, surface;
  final TextStyle label;
  final String Function(double) formatY;
  final bool endLabels;

  /// A round top for the axis: 1, 2 or 5 times a power of ten.
  static double _nice(double v) {
    if (v <= 0) return 1;
    final p = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    for (final m in [1, 2, 5, 10]) {
      if (v <= m * p) return m * p;
    }
    return 10 * p;
  }

  void _text(Canvas canvas, String s, Offset at, {TextAlign align = TextAlign.left, Color? color}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: label.copyWith(color: color ?? ink)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 120);
    final dx = switch (align) { TextAlign.right => at.dx - tp.width, TextAlign.center => at.dx - tp.width / 2, _ => at.dx };
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    if (w <= 0 || h <= 0) return;
    final values = [for (final s in series) for (final p in s.points) p.y];
    final lo = values.isEmpty ? 0.0 : math.min(0.0, values.reduce(math.min));
    final hi = _nice(values.isEmpty ? 1.0 : math.max(1.0, values.reduce(math.max)));
    double y(double v) => top + h - (v - lo) / (hi - lo) * h;
    final x0 = xs.isEmpty ? DateTime.now() : xs.first;
    final spanMs = xs.length < 2 ? 1 : math.max(1, xs.last.difference(x0).inMilliseconds);
    double x(DateTime t) => xs.length < 2 ? left + w / 2 : left + w * (t.difference(x0).inMilliseconds / spanMs);

    // Grid and its values: four hairlines, recessive.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final v = lo + (hi - lo) * i / 4;
      final gy = y(v);
      canvas.drawLine(Offset(left, gy), Offset(left + w, gy), gridPaint);
      _text(canvas, formatY(v), Offset(left - 6, gy), align: TextAlign.right);
    }
    // Dates: the first, the middle, the last.
    if (xs.isNotEmpty) {
      final f = DateFormat('MM/dd');
      final ty = top + h + bottom / 2 + 2;
      _text(canvas, f.format(xs.first.toLocal()), Offset(left, ty));
      if (xs.length > 2) {
        final mid = x0.add(Duration(milliseconds: spanMs ~/ 2));
        _text(canvas, f.format(mid.toLocal()), Offset(left + w / 2, ty), align: TextAlign.center);
      }
      if (xs.length > 1) _text(canvas, f.format(xs.last.toLocal()), Offset(left + w, ty), align: TextAlign.right);
    }

    // The crosshair, under the lines.
    if (at case final a?) {
      canvas.drawLine(Offset(x(a), top), Offset(x(a), top + h), Paint()
        ..color = ink.withValues(alpha: 0.6)
        ..strokeWidth = 1);
    }

    for (final s in series) {
      if (s.points.isEmpty) continue;
      final path = Path()..moveTo(x(s.points.first.x), y(s.points.first.y));
      for (var i = 1; i < s.points.length; i++) {
        final p = s.points[i];
        if (s.step) path.lineTo(x(p.x), y(s.points[i - 1].y));
        path.lineTo(x(p.x), y(p.y));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
      // Markers: 10px, with a 2px ring of the surface so they read where
      // they sit on the line.
      for (final p in s.points) {
        if (p.marker case final m?) {
          final c = Offset(x(p.x), y(p.y));
          canvas.drawCircle(c, 7, Paint()..color = surface);
          canvas.drawCircle(c, 5, Paint()..color = m);
        }
      }
      if (endLabels) {
        final last = s.points.last;
        final e = Offset(x(last.x), y(last.y));
        canvas.drawLine(e + const Offset(6, 0), e + const Offset(16, 0), Paint()
          ..color = s.color
          ..strokeWidth = 2);
        _text(canvas, s.label, e + const Offset(20, 0), color: strong);
      }
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.series != series || old.at != at || old.grid != grid || old.surface != surface;
}

/// The chart's legend: a short line of each series' color and its name, in
/// text ink. [extra] adds keys for markers.
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.series, this.markers = const []});

  final List<ChartSeries> series;
  final List<(Color, String)> markers;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Wrap(spacing: 16, runSpacing: 4, children: [
      for (final s in series)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 16, height: 2, color: s.color),
          const SizedBox(width: 6),
          Text(s.label, style: style),
        ]),
      for (final (c, l) in markers)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(l, style: style),
        ]),
    ]);
  }
}
