import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/api/api_error_text.dart';
import '../../core/api/api_result.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/ui/state_views.dart';
import '../../l10n/app_localizations.dart';
import '../stock_import/presentation/stock_import_calendar_screen.dart' show calendarMaxWidth, calendarSideBySide;
import '../warehouse_context/application/warehouse_providers.dart';
import '../warehouse_context/domain/warehouse.dart';
import 'warehouse_memos_repository.dart';

/// What the screen asks for: a warehouse (null, all), a month, and words.
typedef MemoAsk = ({int? warehouseId, int year, int month, String query});

/// The notes asked for: the month's, or — with words — every one holding
/// them, whatever its day.
final warehouseMemosProvider = FutureProvider.autoDispose.family<List<WarehouseMemo>, MemoAsk>((ref, a) async {
  final repo = ref.watch(warehouseMemosRepositoryProvider);
  final r = a.query.trim().isEmpty
      ? await repo.list(warehouseId: a.warehouseId, from: DateTime(a.year, a.month), to: DateTime(a.year, a.month + 1, 0))
      : await repo.list(warehouseId: a.warehouseId, query: a.query);
  return switch (r) {
    ApiSuccess(:final data) => data,
    ApiFailure(:final message) => throw Exception(message),
  };
});

/// メモ (0184): notes kept per warehouse — what to remember there, what
/// happened, what to tell the next shift. Written on the day (the day is
/// the one it was written), seen again from the calendar by that day, and
/// found by its words. In the menu where 棚入れ was.
class WarehouseMemosScreen extends ConsumerStatefulWidget {
  const WarehouseMemosScreen({super.key, this.initialMonth});

  final DateTime? initialMonth;

  @override
  ConsumerState<WarehouseMemosScreen> createState() => _WarehouseMemosScreenState();
}

class _WarehouseMemosScreenState extends ConsumerState<WarehouseMemosScreen> {
  /// null until chosen: the active warehouse, else all.
  int? _warehouseId;
  bool _chosen = false;
  late DateTime _month;
  DateTime? _day;
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    final m = widget.initialMonth ?? DateTime.now();
    _month = DateTime(m.year, m.month);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int? get _wh => _chosen ? _warehouseId : ref.read(activeWarehouseIdProvider);

  void _refresh() => ref.invalidate(warehouseMemosProvider);

  Future<void> _write({WarehouseMemo? memo}) async {
    final l10n = AppLocalizations.of(context);
    final warehouses = ref.read(warehouseOverviewProvider).valueOrNull?.warehouses ?? const <Warehouse>[];
    if (warehouses.isEmpty) return;
    var wh = memo?.warehouseId ?? _wh ?? warehouses.first.id;
    if (!warehouses.any((w) => w.id == wh)) wh = warehouses.first.id;
    final got = await showDialog<(int, String)>(
      context: context,
      builder: (_) => _MemoDialog(warehouses: warehouses, warehouseId: wh, body: memo?.body ?? '', editing: memo != null),
    );
    if (got == null || !mounted) return;
    final (chosenWh, text) = got;
    final r = await ref.read(warehouseMemosRepositoryProvider).save(id: memo?.id, warehouseId: chosenWh, body: text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(switch (r) {
      ApiSuccess() => memo == null ? l10n.wmSaved : l10n.wmChanged,
      ApiFailure(:final message) => humanizeApiErrorMessage(l10n, message),
    })));
    if (r is ApiSuccess && memo == null) {
      // Written today: today's page.
      final now = DateTime.now();
      setState(() {
        _month = DateTime(now.year, now.month);
        _day = DateTime(now.year, now.month, now.day);
      });
    }
    _refresh();
  }

  Future<void> _remove(WarehouseMemo memo) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.wmRemoveQ),
        content: Text(memo.body, maxLines: 6, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l10n.actionCancel)),
          FilledButton(
              key: const ValueKey('wm-remove-go'), onPressed: () => Navigator.pop(d, true), child: Text(l10n.wmRemove)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final r = await ref.read(warehouseMemosRepositoryProvider).remove(memo.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(switch (r) {
      ApiSuccess() => l10n.wmRemoved,
      ApiFailure(:final message) => humanizeApiErrorMessage(l10n, message),
    })));
    _refresh();
  }

  void _go(DateTime m) => setState(() {
        _month = DateTime(m.year, m.month);
        _day = null;
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final warehouses = ref.watch(warehouseOverviewProvider).valueOrNull?.warehouses ?? const <Warehouse>[];
    final active = ref.watch(activeWarehouseIdProvider);
    final wh = _chosen ? _warehouseId : active;
    final async = ref.watch(warehouseMemosProvider((warehouseId: wh, year: _month.year, month: _month.month, query: _query)));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final searching = _query.trim().isNotEmpty;

    final top = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l10n.wmIntro, style: muted),
      const SizedBox(height: AppSpacing.sm),
      // Which warehouse's notes.
      Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [
        ChoiceChip(
          key: const ValueKey('wm-wh-all'),
          label: Text(l10n.wmAllWarehouses),
          selected: wh == null,
          onSelected: (_) => setState(() {
            _chosen = true;
            _warehouseId = null;
          }),
        ),
        for (final w in warehouses)
          ChoiceChip(
            key: ValueKey('wm-wh-${w.id}'),
            label: Text(w.name),
            selected: wh == w.id,
            onSelected: (_) => setState(() {
              _chosen = true;
              _warehouseId = w.id;
            }),
          ),
      ]),
      const SizedBox(height: AppSpacing.sm),
      // Found by its words, whatever its day.
      TextField(
        key: const ValueKey('wm-search'),
        controller: _search,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          labelText: l10n.wmSearch,
          border: const OutlineInputBorder(),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  key: const ValueKey('wm-search-clear'),
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _search.clear();
                    _query = '';
                  }),
                ),
        ),
        onSubmitted: (v) => setState(() {
          _query = v.trim();
          _day = null;
        }),
        onChanged: (v) {
          if (v.trim().isEmpty && _query.isNotEmpty) setState(() => _query = '');
        },
      ),
    ]);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.wmTitle), actions: [
        TextButton(
          key: const ValueKey('wm-today'),
          onPressed: () => setState(() {
            _month = DateTime(now.year, now.month);
            _day = today;
          }),
          child: Text(l10n.calToday),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('wm-new'),
        onPressed: warehouses.isEmpty ? null : () => _write(),
        icon: const Icon(Icons.edit_note),
        label: Text(l10n.wmWrite),
      ),
      body: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= calendarSideBySide;
        final memos = async.valueOrNull ?? const <WarehouseMemo>[];
        final byDay = <DateTime, int>{};
        for (final m in memos) {
          byDay[m.day] = (byDay[m.day] ?? 0) + 1;
        }
        final day = _day;
        final shown = searching || day == null ? memos : [for (final m in memos) if (m.day == day) m];
        final calendar = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: calendarMaxWidth),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              IconButton(
                key: const ValueKey('wm-prev'),
                tooltip: l10n.calPrev,
                onPressed: () => _go(DateTime(_month.year, _month.month - 1)),
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${l10n.calYear(_month.year)} ${l10n.calMonth(_month.month)}',
                  key: const ValueKey('wm-month'), style: theme.textTheme.titleMedium),
              IconButton(
                key: const ValueKey('wm-next'),
                tooltip: l10n.calNext,
                onPressed: DateTime(_month.year, _month.month + 1).isAfter(DateTime(now.year, now.month))
                    ? null
                    : () => _go(DateTime(_month.year, _month.month + 1)),
                icon: const Icon(Icons.chevron_right),
              ),
            ]),
            if (searching)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(l10n.wmSearchAllDays, style: muted),
              ),
            _MemoGrid(
              month: _month,
              byDay: searching ? const {} : byDay,
              selected: day,
              today: today,
              onDay: (d) => setState(() => _day = _day == d ? null : d),
            ),
          ]),
        );
        final list = <Widget>[
          Text(
            searching
                ? l10n.wmFound(_query, shown.length)
                : day == null
                    ? l10n.wmMonthList(shown.length)
                    : l10n.wmDayList(DateFormat('y/MM/dd').format(day), shown.length),
            key: const ValueKey('wm-list-title'),
            style: theme.textTheme.titleSmall,
          ),
          if (async.isLoading && memos.isEmpty) const LoadingView(),
          if (async.hasError)
            ErrorStateView(message: humanizeApiErrorMessage(l10n, '${async.error}'), onRetry: _refresh),
          if (!async.isLoading && !async.hasError && shown.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(searching ? l10n.wmNoneFound : l10n.wmNone,
                  key: const ValueKey('wm-none'), textAlign: TextAlign.center),
            ),
          for (final m in shown)
            _MemoCard(
              memo: m,
              showWarehouse: wh == null,
              query: _query,
              onEdit: () => _write(memo: m),
              onRemove: () => _remove(m),
            ),
          const SizedBox(height: 80),
        ];
        if (wide) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: calendarMaxWidth,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  top,
                  const SizedBox(height: AppSpacing.md),
                  calendar,
                ]),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: ListView(padding: const EdgeInsets.all(AppSpacing.md), children: list)),
          ]);
        }
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [top, const SizedBox(height: AppSpacing.md), Center(child: calendar), const SizedBox(height: AppSpacing.md), ...list],
        );
      }),
    );
  }
}

class _MemoGrid extends StatelessWidget {
  const _MemoGrid({required this.month, required this.byDay, required this.selected, required this.today, required this.onDay});

  final DateTime month;
  final Map<DateTime, int> byDay;
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
                style: theme.textTheme.labelSmall?.copyWith(
                    color: i == 0 ? scheme.error : (i == 6 ? scheme.primary : scheme.onSurfaceVariant))),
          ),
        for (var i = 0; i < lead; i++) const SizedBox.shrink(),
        for (var d = 1; d <= days; d++)
          () {
            final date = DateTime(month.year, month.month, d);
            final n = byDay[date] ?? 0;
            return InkWell(
              key: ValueKey('wm-day-$d'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => onDay(date),
              child: Container(
                decoration: BoxDecoration(
                  color: selected == date
                      ? scheme.primaryContainer
                      : (n > 0 ? scheme.secondaryContainer.withValues(alpha: 0.6) : null),
                  borderRadius: BorderRadius.circular(8),
                  border: date == today ? Border.all(color: scheme.primary) : null,
                ),
                padding: const EdgeInsets.all(2),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('$d', style: theme.textTheme.bodySmall?.copyWith(fontWeight: n > 0 ? FontWeight.bold : null)),
                  if (n > 0)
                    Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.sticky_note_2_outlined, size: 11, color: scheme.primary),
                      Text('$n', key: ValueKey('wm-count-$d'), style: theme.textTheme.labelSmall),
                    ]),
                ]),
              ),
            );
          }(),
      ],
    );
  }
}

class _MemoCard extends StatelessWidget {
  const _MemoCard({
    required this.memo,
    required this.showWarehouse,
    required this.query,
    required this.onEdit,
    required this.onRemove,
  });

  final WarehouseMemo memo;
  final bool showWarehouse;
  final String query;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  /// The memo with the words searched for marked.
  TextSpan _marked(String text, String q, TextStyle? base, Color mark) {
    if (q.trim().isEmpty) return TextSpan(text: text, style: base);
    final lower = text.toLowerCase();
    final needle = q.trim().toLowerCase();
    final spans = <TextSpan>[];
    var at = 0;
    while (true) {
      final i = lower.indexOf(needle, at);
      if (i < 0) break;
      if (i > at) spans.add(TextSpan(text: text.substring(at, i)));
      spans.add(TextSpan(text: text.substring(i, i + needle.length), style: TextStyle(backgroundColor: mark)));
      at = i + needle.length;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return TextSpan(style: base, children: spans);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final at = DateFormat('y/MM/dd HH:mm');
    return Card(
      key: ValueKey('wm-memo-${memo.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                [
                  if (memo.createdAt case final c?) at.format(c) else DateFormat('y/MM/dd').format(memo.day),
                  if (showWarehouse && memo.warehouseName != null) memo.warehouseName!,
                  if (memo.createdByName case final b?) b,
                ].join(' · '),
                key: ValueKey('wm-meta-${memo.id}'),
                style: muted,
              ),
              const SizedBox(height: 4),
              SelectableText.rich(
                _marked(memo.body, query, theme.textTheme.bodyMedium, theme.colorScheme.tertiaryContainer),
                key: ValueKey('wm-body-${memo.id}'),
              ),
              if (memo.updatedAt case final u?)
                Text(l10n.wmUpdated(at.format(u), memo.updatedByName ?? ''), style: muted),
            ]),
          ),
          PopupMenuButton<String>(
            key: ValueKey('wm-more-${memo.id}'),
            tooltip: l10n.siMore,
            icon: const Icon(Icons.more_horiz),
            onSelected: (v) => v == 'edit' ? onEdit() : onRemove(),
            itemBuilder: (_) => [
              PopupMenuItem(key: ValueKey('wm-edit-${memo.id}'), value: 'edit', child: Text(l10n.wmEdit)),
              PopupMenuItem(key: ValueKey('wm-remove-${memo.id}'), value: 'remove', child: Text(l10n.wmRemove)),
            ],
          ),
        ]),
      ),
    );
  }
}

/// Writing or changing a note: the warehouse and the words. Pops (warehouse,
/// words) on 保存.
class _MemoDialog extends StatefulWidget {
  const _MemoDialog({required this.warehouses, required this.warehouseId, required this.body, required this.editing});

  final List<Warehouse> warehouses;
  final int warehouseId;
  final String body;
  final bool editing;

  @override
  State<_MemoDialog> createState() => _MemoDialogState();
}

class _MemoDialogState extends State<_MemoDialog> {
  late int _wh = widget.warehouseId;
  late final _body = TextEditingController(text: widget.body);

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.editing ? l10n.wmEdit : l10n.wmWrite),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<int>(
              key: const ValueKey('wm-warehouse'),
              initialValue: _wh,
              decoration: InputDecoration(labelText: l10n.sfWarehouse),
              items: [for (final w in widget.warehouses) DropdownMenuItem(value: w.id, child: Text(w.name))],
              onChanged: (v) => setState(() => _wh = v ?? _wh),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('wm-body'),
              controller: _body,
              autofocus: true,
              minLines: 4,
              maxLines: 10,
              maxLength: 4000,
              decoration: InputDecoration(
                labelText: l10n.wmBody,
                hintText: l10n.wmBodyHint,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('wm-save'),
          onPressed: _body.text.trim().isEmpty ? null : () => Navigator.pop(context, (_wh, _body.text.trim())),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
