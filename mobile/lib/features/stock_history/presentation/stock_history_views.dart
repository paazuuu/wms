import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/time_line_chart.dart';
import '../../../l10n/app_localizations.dart';
import '../data/stock_history_repository.dart';
import '../domain/stock_history.dart';

String stockMethodLabel(AppLocalizations l10n, StockMethod m) => switch (m) {
      StockMethod.fileStock => l10n.shFileStock,
      StockMethod.fileMaster => l10n.shFileMaster,
      StockMethod.receipt => l10n.shReceipt,
      StockMethod.adjust => l10n.shAdjust,
      StockMethod.ship => l10n.shShip,
      StockMethod.transfer => l10n.shTransfer,
      StockMethod.other => l10n.shOther,
    };

String stockGroupLabel(AppLocalizations l10n, StockGroup g) => switch (g) {
      StockGroup.file => l10n.sgFile,
      StockGroup.receipt => l10n.sgReceipt,
      StockGroup.adjust => l10n.sgAdjust,
      StockGroup.other => l10n.sgOther,
    };

String _signed(int v) => v > 0 ? '+${NumberFormat.decimalPattern().format(v)}' : NumberFormat.decimalPattern().format(v);

/// The period: the last 30, 90 or 365 days. One row, above what it scopes.
class StockPeriodChips extends ConsumerWidget {
  const StockPeriodChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final days = ref.watch(stockHistoryDaysProvider);
    return Wrap(spacing: AppSpacing.sm, children: [
      for (final d in const [30, 90, 365])
        ChoiceChip(
          key: ValueKey('sh-days-$d'),
          label: Text(l10n.shDays(d)),
          selected: days == d,
          onSelected: (_) => ref.read(stockHistoryDaysProvider.notifier).state = d,
        ),
    ]);
  }
}

/// 在庫の推移 for one product (0145): its stock as a stepped line over the
/// period, a dot where a file added to it, and every change in a table under
/// it — when, how, from which file, how many, and the stock after.
class ProductStockChartCard extends ConsumerWidget {
  const ProductStockChartCard({super.key, required this.productId, this.warehouseId});

  final int productId;
  final int? warehouseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final async = ref.watch(productStockHistoryProvider((productId, warehouseId)));
    final fmt = DateFormat('y/MM/dd HH:mm');
    return Card(
      key: const ValueKey('sh-product'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.shProductTitle, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.sm),
          const StockPeriodChips(),
          const SizedBox(height: AppSpacing.sm),
          async.when(
            loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.md), child: LinearProgressIndicator()),
            error: (e, _) => Text(humanizeApiErrorMessage(l10n, '$e'), style: TextStyle(color: theme.colorScheme.error)),
            data: (h) {
              if (h.events.isEmpty) {
                return Text(l10n.shNoChanges(h.current), key: const ValueKey('sh-product-empty'), style: muted);
              }
              final line = chartSlot(context, 0);
              final fileDot = chartSlot(context, 1);
              final levels = h.levels;
              final series = ChartSeries(
                id: 'stock',
                label: l10n.shStock,
                color: line,
                step: true,
                points: [
                  for (final (at, level, e) in levels) ChartPoint(at, level.toDouble(), marker: e != null && e.method.isFile ? fileDot : null),
                  // Held to today, so the line ends at the stock there is now.
                  ChartPoint(DateTime.now(), h.current.toDouble()),
                ],
              );
              String line1(StockEvent e) => [
                    _signed(e.quantity),
                    stockMethodLabel(l10n, e.method),
                    if (e.fileName != null) e.fileName!,
                    if (e.warehouseName != null) e.warehouseName!,
                  ].join(' · ');
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ChartLegend(series: [series], markers: [(fileDot, l10n.shFromFile)]),
                const SizedBox(height: AppSpacing.sm),
                TimeLineChart(
                  key: const ValueKey('sh-product-chart'),
                  series: [series],
                  endLabels: false,
                  details: (x) => [for (final e in h.events) if (e.at == x) line1(e)],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.shSummary(h.start, h.current), style: muted),
                const Divider(),
                // The same changes as a table, newest first.
                for (final (at, level, e) in levels.reversed)
                  if (e != null)
                    ListTile(
                      key: ValueKey('sh-event-${e.id}'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(e.method.isFile ? Icons.upload_file_outlined : Icons.swap_vert, size: 20),
                      title: Text('${_signed(e.quantity)}　${stockMethodLabel(l10n, e.method)}'),
                      subtitle: Text([
                        fmt.format(at.toLocal()),
                        if (e.fileName != null) e.fileName!,
                        if (e.warehouseName != null) e.warehouseName!,
                      ].join(' · ')),
                      trailing: Text(l10n.shAfter(level), style: theme.textTheme.bodyMedium),
                    ),
              ]);
            },
          ),
        ]),
      ),
    );
  }
}

/// 在庫の推移 for the whole library (0145): units added over the period by
/// how they came in — files, receipts, corrections and counts, the rest — as
/// running totals, then every file that changed stock: when, which file, how,
/// how many products and units, by whom.
class LibraryInflowView extends ConsumerWidget {
  const LibraryInflowView({super.key, this.warehouseId, this.warehouseName, this.header});

  final int? warehouseId;
  final String? warehouseName;

  /// Above the library's figures: one product's own 推移, when there is room
  /// for it here.
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final async = ref.watch(libraryInflowProvider(warehouseId));
    final fmt = DateFormat('y/MM/dd HH:mm');
    final n = NumberFormat.decimalPattern();
    return ListView(
      key: const ValueKey('sh-library'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (header case final h?) h,
        Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
          const StockPeriodChips(),
          Text(warehouseName ?? l10n.shAllWarehouses, style: muted),
        ]),
        const SizedBox(height: AppSpacing.md),
        async.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => ErrorStateView(
            message: humanizeApiErrorMessage(l10n, '$e'),
            onRetry: () => ref.invalidate(libraryInflowProvider(warehouseId)),
          ),
          data: (inflow) {
            final totals = inflow.totals;
            final lines = inflow.cumulative(DateTime.now());
            final series = [
              for (final g in StockGroup.values)
                if (lines[g] case final pts?)
                  ChartSeries(
                    id: g.name,
                    label: stockGroupLabel(l10n, g),
                    color: chartSlot(context, g.slot),
                    // A running total rises on the day stock came in, not before.
                    step: true,
                    points: [for (final (d, v) in pts) ChartPoint(d, v.toDouble())],
                  ),
            ];
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // The headline: how much came in, by how.
              Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.sm, children: [
                for (final g in StockGroup.values)
                  Card(
                    key: ValueKey('sh-total-${g.name}'),
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(stockGroupLabel(l10n, g), style: muted),
                        Text(l10n.shUnits(n.format(totals[g] ?? 0)),
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
              ]),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.shLibraryChartTitle, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              if (series.isEmpty)
                Text(l10n.shLibraryEmpty, key: const ValueKey('sh-library-empty'), style: muted)
              else ...[
                if (series.length > 1) ChartLegend(series: series),
                const SizedBox(height: AppSpacing.sm),
                TimeLineChart(
                  key: const ValueKey('sh-library-chart'),
                  series: series,
                  height: 240,
                  details: (x) => [
                    for (final f in inflow.files)
                      if (DateUtils.isSameDay(f.at.toLocal(), x))
                        '${f.fileName ?? '#${f.importId}'}: ${l10n.shFileLine(f.products, n.format(f.units))}',
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text(l10n.shFilesTitle(inflow.files.length), style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              if (inflow.files.isEmpty) Text(l10n.shNoFiles, style: muted),
              for (final f in inflow.files)
                Card(
                  key: ValueKey('sh-file-${f.importId}'),
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    leading: const Icon(Icons.upload_file_outlined),
                    title: Text(f.fileName ?? '#${f.importId}', maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text([
                      fmt.format(f.at.toLocal()),
                      stockMethodLabel(l10n, f.method),
                      if (f.warehouseName != null) f.warehouseName!,
                      if (f.by != null) f.by!,
                    ].join(' · ')),
                    trailing: Text(l10n.shFileLine(f.products, _signed(f.units)), style: theme.textTheme.bodyMedium),
                  ),
                ),
            ]);
          },
        ),
      ],
    );
  }
}
