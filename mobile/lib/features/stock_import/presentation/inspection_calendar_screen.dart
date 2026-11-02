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
import 'stock_import_calendar_screen.dart' show calendarMaxWidth, calendarSideBySide;
import 'stock_inspection_screen.dart';

/// A month's inspections, by the day lines were checked in (Japan time).
final inspectionMonthProvider = FutureProvider.autoDispose.family<List<InspectionDay>, (int, int)>((ref, ym) async {
  final (y, m) = ym;
  final r = await ref.watch(stockImportRepositoryProvider).inspectionCalendar(DateTime(y, m), DateTime(y, m + 1, 0));
  return switch (r) {
    ApiSuccess(:final data) => data,
    ApiFailure(:final message) => throw Exception(message),
  };
});

/// 検品履歴カレンダー (0179): the days stock files were inspected — stamped
/// by the system as each line is checked in, never typed. A day lists what
/// was checked in: which file, how many lines and units, by whom, at what
/// time, and the delivery notes kept with it. A file opens its inspection
/// (to see the notes again, or take a line back).
class InspectionCalendarScreen extends ConsumerStatefulWidget {
  const InspectionCalendarScreen({super.key, this.initialMonth});

  final DateTime? initialMonth;

  @override
  ConsumerState<InspectionCalendarScreen> createState() => _InspectionCalendarScreenState();
}

class _InspectionCalendarScreenState extends ConsumerState<InspectionCalendarScreen> {
  late DateTime _month;
  DateTime? _day;

  @override
  void initState() {
    super.initState();
    final m = widget.initialMonth ?? DateTime.now();
    _month = DateTime(m.year, m.month);
  }

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
    final month = ref.watch(inspectionMonthProvider(key));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final prev = DateTime(_month.year, _month.month - 1);
    final next = DateTime(_month.year, _month.month + 1);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.icTitle),
        actions: [
          TextButton(
            key: const ValueKey('ic-today'),
            onPressed: () => setState(() {
              _month = DateTime(now.year, now.month);
              _day = today;
            }),
            child: Text(l10n.calToday),
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= calendarSideBySide;
        final nav = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconButton(
              key: const ValueKey('ic-prev'),
              tooltip: l10n.calPrev,
              onPressed: prev.isBefore(_first) ? null : () => _go(prev),
              icon: const Icon(Icons.chevron_left),
            ),
            Text('${l10n.calYear(_month.year)} ${l10n.calMonth(_month.month)}',
                key: const ValueKey('ic-month'), style: theme.textTheme.titleMedium),
            IconButton(
              key: const ValueKey('ic-next'),
              tooltip: l10n.calNext,
              onPressed: next.isAfter(DateTime(now.year, now.month)) ? null : () => _go(next),
              icon: const Icon(Icons.chevron_right),
            ),
          ]),
          Text(l10n.icIntro, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
        ]);
        return month.when(
          loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: LoadingView()),
          error: (e, _) => ErrorStateView(
            message: humanizeApiErrorMessage(l10n, '$e'),
            onRetry: () => ref.invalidate(inspectionMonthProvider(key)),
          ),
          data: (items) {
            final byDay = <DateTime, List<InspectionDay>>{};
            for (final i in items) {
              byDay.putIfAbsent(i.day, () => []).add(i);
            }
            final day = _day;
            final shown = day == null ? items.reversed.toList() : (byDay[day] ?? const <InspectionDay>[]);
            final calendar = ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: calendarMaxWidth),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                nav,
                _Grid(
                  month: _month,
                  byDay: byDay,
                  selected: day,
                  today: today,
                  onDay: (d) => setState(() => _day = _day == d ? null : d),
                ),
              ]),
            );
            final list = <Widget>[
              Text(
                day == null
                    ? l10n.icMonthList(items.length)
                    : l10n.icDayList(DateFormat('y/MM/dd').format(day), shown.length),
                key: const ValueKey('ic-list-title'),
                style: theme.textTheme.titleSmall,
              ),
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(l10n.icNone, key: const ValueKey('ic-none'), textAlign: TextAlign.center),
                ),
              for (final i in shown) _Tile(item: i),
            ];
            if (wide) {
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: SizedBox(width: calendarMaxWidth, child: calendar)),
                const VerticalDivider(width: 1),
                Expanded(child: ListView(padding: const EdgeInsets.all(AppSpacing.md), children: list)),
              ]);
            }
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [Center(child: calendar), const SizedBox(height: AppSpacing.md), ...list],
            );
          },
        );
      }),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid(
      {required this.month, required this.byDay, required this.selected, required this.today, required this.onDay});

  final DateTime month;
  final Map<DateTime, List<InspectionDay>> byDay;
  final DateTime? selected;
  final DateTime today;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = DateTime(month.year, month.month).weekday % 7;
    final weekdays = [l10n.calSun, l10n.calMon, l10n.calTue, l10n.calWed, l10n.calThu, l10n.calFri, l10n.calSat];
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.15,
      mainAxisSpacing: 3,
      crossAxisSpacing: 3,
      children: [
        for (final (i, w) in weekdays.indexed)
          Center(
            child: Text(w,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: i == 0 ? scheme.error : (i == 6 ? scheme.primary : scheme.onSurfaceVariant))),
          ),
        for (var i = 0; i < lead; i++) const SizedBox.shrink(),
        for (var d = 1; d <= days; d++)
          () {
            final date = DateTime(month.year, month.month, d);
            final items = byDay[date] ?? const <InspectionDay>[];
            final lines = items.fold<int>(0, (s, i) => s + i.lines);
            return InkWell(
              key: ValueKey('ic-day-$d'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => onDay(date),
              child: Container(
                decoration: BoxDecoration(
                  color: selected == date
                      ? scheme.primaryContainer
                      : (items.isNotEmpty ? scheme.secondaryContainer.withValues(alpha: 0.6) : null),
                  borderRadius: BorderRadius.circular(8),
                  border: date == today ? Border.all(color: scheme.primary) : null,
                ),
                padding: const EdgeInsets.all(2),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('$d',
                      style:
                          theme.textTheme.bodySmall?.copyWith(fontWeight: items.isNotEmpty ? FontWeight.bold : null)),
                  if (items.isNotEmpty)
                    Text(l10n.icDayLines(lines), key: ValueKey('ic-count-$d'), style: theme.textTheme.labelSmall),
                ]),
              ),
            );
          }(),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item});

  final InspectionDay item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final n = NumberFormat.decimalPattern();
    final hm = DateFormat('HH:mm');
    final when = [
      DateFormat('y/MM/dd').format(item.day),
      if (item.firstAt case final f?)
        item.lastAt == null || hm.format(item.lastAt!) == hm.format(f)
            ? hm.format(f)
            : '${hm.format(f)}〜${hm.format(item.lastAt!)}',
    ].join(' ');
    return Card(
      key: ValueKey('ic-item-${item.importId}-${DateFormat('yyyyMMdd').format(item.day)}'),
      child: ListTile(
        leading: Icon(item.allDone ? Icons.fact_check : Icons.fact_check_outlined,
            color: item.allDone ? theme.colorScheme.primary : theme.colorScheme.tertiary),
        title: Text(l10n.siFile(item.importId, item.fileName ?? '')),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.icStamped(when), key: ValueKey('ic-when-${item.importId}')),
          Text(
            [
              l10n.icChecked(item.lines, n.format(item.units), item.lineCount),
              if (item.by case final b?) b,
              if (item.warehouseName case final w?) w,
            ].join(' · '),
            key: ValueKey('ic-what-${item.importId}'),
          ),
          if (item.documents > 0)
            Text(l10n.icNotes(item.documents),
                key: ValueKey('ic-notes-${item.importId}'), style: theme.textTheme.bodySmall),
        ]),
        trailing: Text(item.allDone ? l10n.icAllDone : l10n.icSomeLeft,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: item.allDone ? theme.colorScheme.primary : theme.colorScheme.tertiary)),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => StockInspectionDetailScreen(importId: item.importId, day: item.day))),
      ),
    );
  }
}
