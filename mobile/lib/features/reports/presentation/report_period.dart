import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';

/// A report's period: from a day to a day. Whole months most of the time —
/// one month, the last 3/6/12, or a month to a month — any two days when
/// picked by hand.
@immutable
class ReportPeriod {
  const ReportPeriod(this.from, this.to);

  /// One month: its 1st to its last day.
  factory ReportPeriod.month(DateTime m) => ReportPeriod(DateTime(m.year, m.month), DateTime(m.year, m.month + 1, 0));

  /// From the 1st of [from]'s month to the last day of [to]'s.
  factory ReportPeriod.months(DateTime from, DateTime to) =>
      ReportPeriod(DateTime(from.year, from.month), DateTime(to.year, to.month + 1, 0));

  /// The last [n] months up to and including [now]'s.
  factory ReportPeriod.last(int n, {DateTime? now}) {
    final t = now ?? DateTime.now();
    return ReportPeriod.months(DateTime(t.year, t.month - n + 1), t);
  }

  final DateTime from;
  final DateTime to;

  bool get wholeMonths => from.day == 1 && DateTime(to.year, to.month, to.day + 1).day == 1;

  /// One whole month: its 'YYYY-MM'; null otherwise.
  String? get singleMonth => wholeMonths && from.year == to.year && from.month == to.month ? ym(from) : null;

  static String ym(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  /// 2026/11, 2026/09〜2026/11, or 2026/11/03〜2026/11/10.
  String get label {
    final m = DateFormat('y/MM'), d = DateFormat('y/MM/dd');
    if (singleMonth != null) return m.format(from);
    if (wholeMonths) return '${m.format(from)}〜${m.format(to)}';
    return '${d.format(from)}〜${d.format(to)}';
  }

  @override
  bool operator ==(Object other) => other is ReportPeriod && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// The months offered: this one and the 23 before it, newest first.
List<DateTime> reportMonths({DateTime? now, int count = 24}) {
  final t = now ?? DateTime.now();
  return [for (var i = 0; i < count; i++) DateTime(t.year, t.month - i)];
}

/// What the ⋮ menu offers for the period.
enum PeriodChoice { last3, last6, last12, months, days }

List<PopupMenuEntry<Object>> periodMenuItems(AppLocalizations l10n, {bool days = false}) => [
      PopupMenuItem(value: PeriodChoice.last3, key: const ValueKey('rp-last3'), child: Text(l10n.rpLast(3))),
      PopupMenuItem(value: PeriodChoice.last6, key: const ValueKey('rp-last6'), child: Text(l10n.rpLast(6))),
      PopupMenuItem(value: PeriodChoice.last12, key: const ValueKey('rp-last12'), child: Text(l10n.rpLast(12))),
      PopupMenuItem(value: PeriodChoice.months, key: const ValueKey('rp-months'), child: Text(l10n.rpMonths)),
      if (days) PopupMenuItem(value: PeriodChoice.days, key: const ValueKey('rp-days'), child: Text(l10n.rpDays)),
    ];

/// The period [c] stands for, asking for the months or days when it must;
/// null when the person cancels.
Future<ReportPeriod?> choosePeriod(BuildContext context, PeriodChoice c, ReportPeriod? current) async {
  switch (c) {
    case PeriodChoice.last3:
      return ReportPeriod.last(3);
    case PeriodChoice.last6:
      return ReportPeriod.last(6);
    case PeriodChoice.last12:
      return ReportPeriod.last(12);
    case PeriodChoice.months:
      return showDialog<ReportPeriod>(context: context, builder: (_) => _MonthsDialog(current: current));
    case PeriodChoice.days:
      final now = DateTime.now();
      final r = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 5),
        lastDate: DateTime(now.year + 1, 12, 31),
        initialDateRange: current == null ? null : DateTimeRange(start: current.from, end: current.to),
      );
      return r == null ? null : ReportPeriod(r.start, r.end);
  }
}

/// The period on screen in the room of one field: the month to pick from
/// when it is one month (or none), else what was chosen — 3 months, a span,
/// days — with a cross to go back to [reset].
class ReportPeriodField extends StatelessWidget {
  const ReportPeriodField({
    super.key,
    required this.period,
    required this.onChanged,
    this.allowNone = false,
    this.width = 200,
  });

  /// Null: no period (everything), when [allowNone].
  final ReportPeriod? period;
  final ValueChanged<ReportPeriod?> onChanged;
  final bool allowNone;
  final double width;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = period;
    final single = p?.singleMonth;
    if (p != null && single == null) {
      // A span: shown as what it is, cleared back to one field.
      return ConstrainedBox(
        constraints: BoxConstraints(minWidth: width),
        child: InputDecorator(
          decoration: InputDecoration(labelText: l10n.rpPeriod, isDense: true),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.date_range_outlined, size: 18),
            const SizedBox(width: AppSpacing.xs),
            Text(p.label, key: const ValueKey('rp-span')),
            const SizedBox(width: AppSpacing.xs),
            InkWell(
              key: const ValueKey('rp-span-clear'),
              onTap: () => onChanged(allowNone ? null : ReportPeriod.month(DateTime.now())),
              child: Tooltip(message: l10n.rpClear, child: const Icon(Icons.close, size: 18)),
            ),
          ]),
        ),
      );
    }
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String?>(
        key: ValueKey('rp-month-$single'),
        initialValue: single,
        isExpanded: true,
        decoration: InputDecoration(labelText: l10n.rpPeriod, isDense: true),
        items: [
          if (allowNone) DropdownMenuItem(value: null, child: Text(l10n.rpAll)),
          for (final m in reportMonths())
            DropdownMenuItem(value: ReportPeriod.ym(m), child: Text(DateFormat('y/MM').format(m))),
        ],
        onChanged: (v) => onChanged(v == null
            ? null
            : ReportPeriod.month(DateTime(int.parse(v.substring(0, 4)), int.parse(v.substring(5))))),
      ),
    );
  }
}

class _MonthsDialog extends StatefulWidget {
  const _MonthsDialog({this.current});

  final ReportPeriod? current;

  @override
  State<_MonthsDialog> createState() => _MonthsDialogState();
}

class _MonthsDialogState extends State<_MonthsDialog> {
  late final _months = reportMonths().reversed.toList();
  late String _from = ReportPeriod.ym(widget.current?.from ?? _months[_months.length - 3]);
  late String _to = ReportPeriod.ym(widget.current?.to ?? _months.last);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    DateTime parse(String v) => DateTime(int.parse(v.substring(0, 4)), int.parse(v.substring(5)));
    final values = [for (final m in _months) ReportPeriod.ym(m)];
    if (!values.contains(_from)) _from = values.first;
    if (!values.contains(_to)) _to = values.last;
    Widget pick(String key, String label, String value, ValueChanged<String> set) => SizedBox(
          width: 170,
          child: DropdownButtonFormField<String>(
            key: ValueKey(key),
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(labelText: label, isDense: true),
            items: [for (final v in values) DropdownMenuItem(value: v, child: Text(v.replaceFirst('-', '/')))],
            onChanged: (v) => v == null ? null : setState(() => set(v)),
          ),
        );
    final ok = _from.compareTo(_to) <= 0;
    return AlertDialog(
      title: Text(l10n.rpMonths),
      content: Wrap(spacing: AppSpacing.md, crossAxisAlignment: WrapCrossAlignment.center, children: [
        pick('rp-from', l10n.rpFromMonth, _from, (v) => _from = v),
        const Text('〜'),
        pick('rp-to', l10n.rpToMonth, _to, (v) => _to = v),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('rp-months-ok'),
          onPressed: ok ? () => Navigator.pop(context, ReportPeriod.months(parse(_from), parse(_to))) : null,
          child: Text(l10n.rpApply),
        ),
      ],
    );
  }
}
