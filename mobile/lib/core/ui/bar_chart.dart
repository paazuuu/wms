import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'time_line_chart.dart' show chartSlot;

/// One bar: its label under the axis, its value, and what its tooltip says.
class BarDatum {
  const BarDatum({required this.label, required this.value, this.tooltip, this.key});

  final String label;
  final double value;
  final String? tooltip;
  final Key? key;
}

/// Bars for one measure over time (a month each), on one axis with zero as
/// the baseline: gains rise in the first chart slot (blue), losses fall in
/// the second (orange) — a pair validated for colour-blind readers. Thin
/// bars with a 4px rounded end, a 2px gap, a quiet grid of three lines, and
/// a tooltip over the whole column. A single series, so the title names it
/// and there is no legend; the numbers are also in the table under it.
class BarChart extends StatelessWidget {
  const BarChart({super.key, required this.bars, required this.format, this.height = 220});

  final List<BarDatum> bars;
  final String Function(double v) format;
  final double height;

  /// A round step for the grid: 1, 2 or 5 × a power of ten.
  static double _nice(double v) {
    if (v <= 0) return 1;
    final p = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    final f = v / p;
    final n = f <= 1 ? 1 : (f <= 2 ? 2 : (f <= 5 ? 5 : 10));
    return n * p;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final axis = theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);
    final hi = bars.fold<double>(0, (a, b) => math.max(a, b.value));
    final lo = bars.fold<double>(0, (a, b) => math.min(a, b.value));
    final step = _nice(math.max(hi, -lo) / 4);
    final top = hi > 0 ? (hi / step).ceil() * step : 0.0;
    final bottom = lo < 0 ? (lo / step).floor() * step : 0.0;
    final span = (top - bottom) == 0 ? 1.0 : top - bottom;
    final ticks = <double>[for (var t = bottom; t <= top + step / 2; t += step) t];
    final up = chartSlot(context, 0);
    final down = chartSlot(context, 1);
    const labelH = 20.0;
    const axisW = 64.0;

    return SizedBox(
      height: height + labelH,
      child: LayoutBuilder(builder: (context, box) {
        final plotW = box.maxWidth - axisW;
        final slot = bars.isEmpty ? 0.0 : plotW / bars.length;
        final barW = math.max(4.0, math.min(28.0, slot - 2 * 2));
        double y(double v) => height - (v - bottom) / span * height;
        return Stack(clipBehavior: Clip.none, children: [
          // The grid and its values, kept quiet.
          for (final t in ticks) ...[
            Positioned(
              left: axisW,
              right: 0,
              top: y(t),
              child: Container(height: t == 0 ? 1.5 : 1, color: t == 0 ? scheme.outline : scheme.outlineVariant),
            ),
            Positioned(
              left: 0,
              width: axisW - 8,
              top: y(t) - 8,
              child: Text(format(t), textAlign: TextAlign.right, style: axis, maxLines: 1),
            ),
          ],
          for (final (i, b) in bars.indexed)
            Positioned(
              left: axisW + i * slot,
              width: slot,
              top: 0,
              height: height + labelH,
              child: Tooltip(
                key: b.key,
                message: b.tooltip ?? '${b.label}: ${format(b.value)}',
                // The whole column answers the pointer, not only the bar.
                child: MouseRegion(
                  cursor: SystemMouseCursors.basic,
                  child: Stack(children: [
                    if (b.value != 0)
                      Positioned(
                        left: (slot - barW) / 2,
                        width: barW,
                        top: b.value > 0 ? y(b.value) : y(0) + 1,
                        height: math.max(1.0, (y(0) - y(b.value)).abs()),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: b.value >= 0 ? up : down,
                            // Round at the data end, square at the baseline.
                            borderRadius: b.value >= 0
                                ? const BorderRadius.vertical(top: Radius.circular(4))
                                : const BorderRadius.vertical(bottom: Radius.circular(4)),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: height + 4,
                      child: Text(b.label, textAlign: TextAlign.center, style: axis, maxLines: 1, overflow: TextOverflow.clip),
                    ),
                  ]),
                ),
              ),
            ),
        ]);
      }),
    );
  }
}
