import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../data/stock_import_repository.dart';
import '../domain/stock_ledger.dart';
import 'import_view_screen.dart';

/// A month's stock files, by the date each is filed under.
final stockImportMonthProvider =
    FutureProvider.autoDispose.family<List<CalendarImport>, (int, int)>((ref, ym) async {
  final (y, m) = ym;
  final r = await ref.watch(stockImportRepositoryProvider).calendar(DateTime(y, m), DateTime(y, m + 1, 0));
  return switch (r) {
    ApiSuccess(:final data) => data,
    ApiFailure(:final message) => throw Exception(message),
  };
});

/// 取込カレンダー (0148): every stock file on the day it is filed under —
/// the date the document prints, else the day it came in — for the seven
/// years it is kept. A day opens its files; a file opens its reading.
class StockImportCalendarScreen extends ConsumerStatefulWidget {
  const StockImportCalendarScreen({super.key, this.initialMonth});

  final DateTime? initialMonth;

  @override
  ConsumerState<StockImportCalendarScreen> createState() => _StockImportCalendarScreenState();
}

class _StockImportCalendarScreenState extends ConsumerState<StockImportCalendarScreen> {
  late DateTime _month;
  DateTime? _day;

  @override
  void initState() {
    super.initState();
    final m = widget.initialMonth ?? DateTime.now();
    _month = DateTime(m.year, m.month);
  }

  /// The earliest month still kept.
  DateTime get _first {
    final now = DateTime.now();
    return DateTime(now.year - keepYears, now.month);
  }

  void _go(DateTime m) {
    final now = DateTime.now();
    if (m.isBefore(_first) || m.isAfter(DateTime(now.year, now.month))) return;
    setState(() {
      _month = DateTime(m.year, m.month);
      _day = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final key = (_month.year, _month.month);
    final month = ref.watch(stockImportMonthProvider(key));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final years = [for (var y = now.year; y >= now.year - keepYears; y--) y];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.calTitle),
        actions: [
          TextButton(
            key: const ValueKey('cal-today'),
            onPressed: () => setState(() {
              _month = DateTime(now.year, now.month);
              _day = today;
            }),
            child: Text(l10n.calToday),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(children: [
            IconButton(
              key: const ValueKey('cal-prev'),
              tooltip: l10n.calPrev,
              onPressed: DateTime(_month.year, _month.month - 1).isBefore(_first) ? null : () => _go(DateTime(_month.year, _month.month - 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            DropdownButton<int>(
              key: const ValueKey('cal-year'),
              value: _month.year,
              items: [for (final y in years) DropdownMenuItem(value: y, child: Text(l10n.calYear(y)))],
              onChanged: (y) => y == null ? null : _go(DateTime(y, y == now.year && _month.month > now.month ? now.month : _month.month)),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(l10n.calMonth(_month.month), key: const ValueKey('cal-month'), style: theme.textTheme.titleLarge),
            IconButton(
              key: const ValueKey('cal-next'),
              tooltip: l10n.calNext,
              onPressed: DateTime(_month.year, _month.month + 1).isAfter(DateTime(now.year, now.month))
                  ? null
                  : () => _go(DateTime(_month.year, _month.month + 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ]),
          Text(l10n.calKept(keepYears), style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          month.when(
            loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: LoadingView()),
            error: (e, _) => SizedBox(
              height: 240,
              child: ErrorStateView(
                message: humanizeApiErrorMessage(l10n, '$e'),
                onRetry: () => ref.invalidate(stockImportMonthProvider(key)),
              ),
            ),
            data: (items) {
              final byDay = <DateTime, List<CalendarImport>>{};
              for (final i in items) {
                byDay.putIfAbsent(i.day, () => []).add(i);
              }
              final day = _day;
              final shown = day == null ? items : (byDay[day] ?? const <CalendarImport>[]);
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _MonthGrid(
                  month: _month,
                  byDay: byDay,
                  selected: day,
                  today: today,
                  onDay: (d) => setState(() => _day = _day == d ? null : d),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  day == null ? l10n.calMonthList(items.length) : l10n.calDayList(DateFormat('y/MM/dd').format(day), shown.length),
                  key: const ValueKey('cal-list-title'),
                  style: theme.textTheme.titleSmall,
                ),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(l10n.calNone, key: const ValueKey('cal-none'), textAlign: TextAlign.center),
                  ),
                for (final i in shown) _CalendarTile(item: i),
              ]);
            },
          ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.byDay, required this.selected, required this.today, required this.onDay});

  final DateTime month;
  final Map<DateTime, List<CalendarImport>> byDay;
  final DateTime? selected;
  final DateTime today;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final days = DateTime(month.year, month.month + 1, 0).day;
    // Sunday first, as Japanese calendars are.
    final lead = DateTime(month.year, month.month).weekday % 7;
    final weekdays = [l10n.calSun, l10n.calMon, l10n.calTue, l10n.calWed, l10n.calThu, l10n.calFri, l10n.calSat];
    final cells = <Widget>[
      for (final (i, w) in weekdays.indexed)
        Center(
          child: Text(w,
              style: theme.textTheme.labelSmall?.copyWith(
                  color: i == 0 ? scheme.error : (i == 6 ? scheme.primary : scheme.onSurfaceVariant))),
        ),
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var d = 1; d <= days; d++)
        () {
          final date = DateTime(month.year, month.month, d);
          final items = byDay[date] ?? const <CalendarImport>[];
          final isSel = selected == date;
          final waiting = items.any((i) => i.awaiting);
          final unpaid = items.any((i) => !i.paid && !i.undone);
          return InkWell(
            key: ValueKey('cal-day-$d'),
            borderRadius: BorderRadius.circular(8),
            onTap: () => onDay(date),
            child: Container(
              decoration: BoxDecoration(
                color: isSel ? scheme.primaryContainer : (items.isNotEmpty ? scheme.surfaceContainerHighest : null),
                borderRadius: BorderRadius.circular(8),
                border: date == today ? Border.all(color: scheme.primary) : null,
              ),
              padding: const EdgeInsets.all(4),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('$d', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: items.isNotEmpty ? FontWeight.bold : null)),
                if (items.isNotEmpty)
                  Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                    Text(l10n.calCount(items.length), key: ValueKey('cal-count-$d'), style: theme.textTheme.labelSmall),
                    if (waiting) Icon(Icons.pending_actions_outlined, size: 12, color: scheme.tertiary),
                    if (unpaid) Icon(Icons.payments_outlined, size: 12, color: scheme.error),
                  ]),
              ]),
            ),
          );
        }(),
    ];
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.3,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: cells,
    );
  }
}

class _CalendarTile extends StatelessWidget {
  const _CalendarTile({required this.item});

  final CalendarImport item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final n = NumberFormat.decimalPattern();
    final status = item.undone
        ? l10n.ivUndone
        : item.awaiting
            ? l10n.miStatusAwaiting
            : l10n.calIn(item.lines, n.format(item.change));
    return Card(
      key: ValueKey('cal-item-${item.id}'),
      child: ListTile(
        leading: Icon(item.awaiting ? Icons.pending_actions_outlined : Icons.description_outlined),
        title: Text(l10n.siFile(item.id, item.fileName ?? '')),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text([
            DateFormat('y/MM/dd').format(item.day),
            if (item.warehouseName case final w?) w,
            status,
          ].join(' · ')),
          if ((item.note ?? '').isNotEmpty)
            Text(item.note!, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
        ]),
        trailing: Chip(
          key: ValueKey('cal-paid-${item.id}'),
          label: Text(item.paid ? l10n.calPaid : l10n.calUnpaid),
          backgroundColor: item.paid ? theme.colorScheme.secondaryContainer : theme.colorScheme.errorContainer,
          visualDensity: VisualDensity.compact,
        ),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ImportViewScreen(importId: item.id))),
      ),
    );
  }
}
