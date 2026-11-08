import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/time_line_chart.dart';
import '../../../l10n/app_localizations.dart';
import '../data/overseas_stock_repository.dart';
import '../domain/overseas_trend.dart';
import 'overseas_widgets.dart';

/// 推移・分析 (0209): for a product, or all of a maker's, the site's stock
/// over time — each shipment adds, each count the partner gives sets it —
/// and what was used between counts, by period and by month, to see the
/// seasons and how fast things go.
class OverseasTrendView extends ConsumerStatefulWidget {
  const OverseasTrendView({super.key, required this.siteId});

  final int siteId;

  @override
  ConsumerState<OverseasTrendView> createState() => _OverseasTrendViewState();
}

class _OverseasTrendViewState extends ConsumerState<OverseasTrendView> {
  bool _byMaker = false;
  String? _key;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final async = ref.watch(overseasEventsProvider(widget.siteId));
    return async.when(
      loading: () => LoadingView(message: l10n.loading),
      error: (e, _) => ErrorStateView(
          message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => ref.invalidate(overseasEventsProvider(widget.siteId))),
      data: (ev) {
        final products = ev.products();
        if (products.isEmpty) return EmptyStateView(icon: Icons.show_chart, title: l10n.osTrendEmpty);
        // The most shipped first.
        final shipped = <String, num>{};
        for (final s in ev.shipments) {
          for (final l in s.lines) {
            final k = _byMaker ? (l.maker ?? '') : overseasKeyOf(l);
            shipped[k] = (shipped[k] ?? 0) + l.quantity;
          }
        }
        final choices = _byMaker
            ? [for (final m in ev.makers()) (key: m, label: m)]
            : [for (final e in products.entries) (key: e.key, label: e.value.label)];
        choices.sort((a, b) => (shipped[b.key] ?? 0).compareTo(shipped[a.key] ?? 0));
        final q = _search.text.trim().toLowerCase();
        final shown = [for (final c in choices) if (q.isEmpty || '${c.label} ${c.key}'.toLowerCase().contains(q)) c];
        final key = choices.any((c) => c.key == _key) ? _key! : (choices.isEmpty ? null : choices.first.key);
        final trend = key == null
            ? const OverseasTrend()
            : overseasTrend(ev, (l) => _byMaker ? l.maker == key : overseasKeyOf(l) == key);
        final label = key == null ? '' : choices.firstWhere((c) => c.key == key).label;
        final day = DateFormat('y/MM/dd');
        return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
          Text(l10n.osTrendHelp, style: muted),
          const SizedBox(height: AppSpacing.sm),
          Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SegmentedButton<bool>(
              key: const ValueKey('os-trend-mode'),
              segments: [
                ButtonSegment(value: false, label: Text(l10n.osByProduct)),
                ButtonSegment(value: true, label: Text(l10n.osByMaker)),
              ],
              selected: {_byMaker},
              onSelectionChanged: (v) => setState(() {
                _byMaker = v.first;
                _key = null;
              }),
            ),
            SizedBox(
              width: 320,
              child: TextField(
                key: const ValueKey('os-trend-search'),
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.osSearch, isDense: true),
              ),
            ),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [
            for (final c in shown.take(40))
              ChoiceChip(
                key: ValueKey('os-trend-${c.key}'),
                label: Text(c.label),
                selected: c.key == key,
                onSelected: (_) => setState(() => _key = c.key),
              ),
          ]),
          const SizedBox(height: AppSpacing.md),
          Text(label, key: const ValueKey('os-trend-title'), style: theme.textTheme.titleMedium),
          if (trend.points.isNotEmpty)
            TimeLineChart(
              key: const ValueKey('os-trend-chart'),
              series: [
                ChartSeries(
                  id: 'stock',
                  label: l10n.osColEstimate,
                  color: chartSlot(context, 0),
                  step: true,
                  points: [
                    for (final p in trend.points)
                      ChartPoint(p.day, p.stock.toDouble(), marker: p.report ? chartSlot(context, 1) : null),
                  ],
                ),
              ],
              formatY: (v) => overseasQty(v),
              details: (x) => [
                for (final s in ev.shipments)
                  if (DateUtils.isSameDay(s.day, x)) l10n.osShippedOn(s.fileName ?? ''),
                for (final r in ev.reports)
                  if (DateUtils.isSameDay(r.day, x)) l10n.osReportedOn(r.fileName ?? ''),
              ],
            ),
          Text(l10n.osTrendLegend, style: muted),
          const SizedBox(height: AppSpacing.md),
          // What was used between counts.
          Text(l10n.osPeriods, style: theme.textTheme.titleSmall),
          if (trend.periods.isEmpty)
            Text(l10n.osPeriodsNone, key: const ValueKey('os-periods-none'), style: muted)
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                key: const ValueKey('os-periods'),
                headingRowHeight: 36,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 40,
                columns: [
                  DataColumn(label: Text(l10n.osPeriod)),
                  DataColumn(label: Text(l10n.osColStart), numeric: true),
                  DataColumn(label: Text(l10n.osColShippedIn), numeric: true),
                  DataColumn(label: Text(l10n.osColEnd), numeric: true),
                  DataColumn(label: Text(l10n.osColUsed), numeric: true),
                  DataColumn(label: Text(l10n.osColPerMonth), numeric: true),
                ],
                rows: [
                  for (final p in trend.periods)
                    DataRow(cells: [
                      DataCell(Text('${day.format(p.from)} → ${day.format(p.to)}')),
                      DataCell(Text(overseasQty(p.start))),
                      DataCell(Text(overseasQty(p.shipped))),
                      DataCell(Text(overseasQty(p.end))),
                      DataCell(Text(overseasQty(p.used),
                          style: TextStyle(color: p.used < 0 ? theme.colorScheme.error : null, fontWeight: FontWeight.w700))),
                      DataCell(Text(p.perMonth == null ? '—' : overseasQty(p.perMonth!.round()))),
                    ]),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.osMonthly, style: theme.textTheme.titleSmall),
          if (trend.months.isNotEmpty) ...[
            TimeLineChart(
              key: const ValueKey('os-monthly-chart'),
              height: 180,
              series: [
                ChartSeries(
                  id: 'used',
                  label: l10n.osColUsed,
                  color: chartSlot(context, 2),
                  points: [
                    for (final e in trend.months.entries)
                      ChartPoint(DateTime.parse('${e.key}-01'), e.value.toDouble()),
                  ],
                ),
              ],
              formatY: (v) => overseasQty(v.round()),
            ),
            Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.xs, children: [
              for (final e in trend.months.entries)
                Text('${e.key}: ${overseasQty(e.value.round())}', key: ValueKey('os-month-${e.key}')),
            ]),
          ] else
            Text(l10n.osPeriodsNone, style: muted),
        ]);
      },
    );
  }
}
