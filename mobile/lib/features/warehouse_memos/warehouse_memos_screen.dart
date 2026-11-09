import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/ui/help_tab.dart';
import '../../core/api/api_error_text.dart';
import '../../core/api/api_result.dart';
import '../../core/export/save_bytes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/ui/open_window.dart';
import '../../core/ui/state_views.dart';
import '../../l10n/app_localizations.dart';
import '../stock_import/presentation/stock_import_calendar_screen.dart' show calendarMaxWidth, calendarSideBySide;
import '../warehouse_context/application/warehouse_providers.dart';
import '../warehouse_context/domain/warehouse.dart';
import 'warehouse_memos_repository.dart';
import '../../core/ui/edit_drawer.dart';
import '../../core/ui/popconfirm.dart';

/// What a list asks for: the kind, a warehouse (null, all), a month (the
/// カレンダー's), and words.
typedef MemoAsk = ({MemoKind kind, int? warehouseId, int year, int month, String query});

/// The notes asked for: the カレンダー's of the month, the 掲示板's newest, or
/// — with words — every one of the kind holding them, whatever its day.
final warehouseMemosProvider = FutureProvider.autoDispose.family<List<WarehouseMemo>, MemoAsk>((ref, a) async {
  final repo = ref.watch(warehouseMemosRepositoryProvider);
  final calendarMonth = a.kind == MemoKind.calendar && a.query.trim().isEmpty;
  final r = await repo.list(
    a.kind,
    warehouseId: a.warehouseId,
    from: calendarMonth ? DateTime(a.year, a.month) : null,
    to: calendarMonth ? DateTime(a.year, a.month + 1, 0) : null,
    query: a.query,
  );
  return switch (r) {
    ApiSuccess(:final data) => data,
    ApiFailure(:final message) => throw Exception(message),
  };
});

/// 2026/11/20 (金): the day with its weekday, in the app's language.
String memoDayLabel(AppLocalizations l10n, DateTime d) {
  final w = [l10n.calSun, l10n.calMon, l10n.calTue, l10n.calWed, l10n.calThu, l10n.calFri, l10n.calSat][d.weekday % 7];
  return '${DateFormat('y/MM/dd').format(d)} ($w)';
}

/// Files chosen to put with a note (overridden in tests).
final memoFilePickerProvider = Provider<Future<List<({String name, Uint8List bytes})>> Function()>((_) => () async {
      final r = await FilePicker.platform.pickFiles(withData: true, allowMultiple: true);
      return [
        for (final f in r?.files ?? const <PlatformFile>[])
          if (f.bytes != null) (name: f.name, bytes: f.bytes!),
      ];
    });

/// An empty browser tab for a file (overridden in tests).
final memoTabOpenerProvider = Provider<HtmlTab? Function()>((_) => openHtmlTab);

/// Where a file is saved (overridden in tests).
final memoFileSaverProvider =
    Provider<Future<void> Function(String name, Uint8List bytes)>((_) => (n, b) async => saveBytes(n, b));

/// メモ (0184–0186): notes kept per warehouse, in two —
///  * カレンダー: a note put on a day chosen by hand — goods due, the day's
///    arrangements, how many part-timers came — any day, past or to come;
///  * 掲示板: a note on the board, tied to no day but the one it was written.
/// Both list their notes at once (no day to pick first), are searched by
/// their words, and take files: put in, shown in the browser, saved again.
class WarehouseMemosScreen extends ConsumerStatefulWidget {
  const WarehouseMemosScreen({super.key, this.initialMonth, this.initialTab = 0});

  final DateTime? initialMonth;

  /// 0: カレンダー; 1: 掲示板.
  final int initialTab;

  @override
  ConsumerState<WarehouseMemosScreen> createState() => _WarehouseMemosScreenState();
}

class _WarehouseMemosScreenState extends ConsumerState<WarehouseMemosScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab)
    ..addListener(() {
      if (mounted) setState(() {});
    });

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
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  MemoKind get _kind => _tabs.index == 0 ? MemoKind.calendar : MemoKind.board;

  int? get _wh => _chosen ? _warehouseId : ref.read(activeWarehouseIdProvider);

  void _refresh() => ref.invalidate(warehouseMemosProvider);

  Future<void> _write({WarehouseMemo? memo}) async {
    final l10n = AppLocalizations.of(context);
    final warehouses = ref.read(warehouseOverviewProvider).valueOrNull?.warehouses ?? const <Warehouse>[];
    if (warehouses.isEmpty) return;
    var wh = memo?.warehouseId ?? _wh ?? warehouses.first.id;
    if (!warehouses.any((w) => w.id == wh)) wh = warehouses.first.id;
    final kind = memo?.kind ?? _kind;
    final now = DateTime.now();
    final got = await showEditDrawer<_Written>(context, builder: (_) => _MemoDialog(
        warehouses: warehouses,
        warehouseId: wh,
        body: memo?.body ?? '',
        editing: memo != null,
        kind: kind,
        date: memo?.day ?? _day ?? DateTime(now.year, now.month, now.day),
      ),
    );
    if (got == null || !mounted) return;
    final repo = ref.read(warehouseMemosRepositoryProvider);
    final r = await repo.save(id: memo?.id, kind: kind, warehouseId: got.warehouseId, body: got.body, date: got.date);
    if (!mounted) return;
    // Files chosen while writing go with it.
    var filesFailed = 0;
    if (r case ApiSuccess(data: final id)) {
      for (final f in got.files) {
        final up = await repo.addFile(id, f.name, f.bytes);
        if (up is ApiFailure) filesFailed++;
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(switch (r) {
      ApiSuccess() when filesFailed > 0 => l10n.wmFilesFailed(filesFailed),
      ApiSuccess() => memo == null ? l10n.wmSaved : l10n.wmChanged,
      ApiFailure(:final message) => humanizeApiErrorMessage(l10n, message),
    })));
    // A calendar note: its month shown, so it is seen where it went.
    if (r is ApiSuccess && kind == MemoKind.calendar && got.date != null) {
      setState(() => _month = DateTime(got.date!.year, got.date!.month));
    }
    _refresh();
  }

  Future<void> _remove(WarehouseMemo memo) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showPopconfirm(
      context,
      title: l10n.wmRemoveQ,
      message: memo.body,
      okLabel: l10n.wmRemove,
      okKey: const ValueKey('wm-remove-go'),
      danger: true,
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

  Future<void> _addFiles(WarehouseMemo memo) async {
    final l10n = AppLocalizations.of(context);
    final files = await ref.read(memoFilePickerProvider)();
    if (files.isEmpty || !mounted) return;
    final repo = ref.read(warehouseMemosRepositoryProvider);
    var failed = 0;
    for (final f in files) {
      if (await repo.addFile(memo.id, f.name, f.bytes) is ApiFailure) failed++;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failed > 0 ? l10n.wmFilesFailed(failed) : l10n.wmFilesAdded(files.length))));
    _refresh();
  }

  /// A file shown as the browser shows it, in a new tab — opened from the
  /// click, before anything is awaited. Where there are no tabs, a picture
  /// is shown here and anything else saved.
  Future<void> _view(MemoFile f) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final tab = ref.read(memoTabOpenerProvider)();
    final r = await ref.read(warehouseMemosRepositoryProvider).fileBytes(f);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        if (tab != null) {
          tab.showBytes(data, f.contentType);
        } else if (f.isImage) {
          await showDialog<void>(
            context: context,
            builder: (c) => Dialog(
              key: const ValueKey('wm-file-view'),
              insetPadding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(
                  title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(c)),
                ),
                Flexible(child: InteractiveViewer(maxScale: 6, child: Image.memory(data, fit: BoxFit.contain))),
              ]),
            ),
          );
        } else {
          await ref.read(memoFileSaverProvider)(f.name, data);
        }
      case ApiFailure(:final message):
        tab?.close();
        messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
  }

  Future<void> _download(MemoFile f) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final r = await ref.read(warehouseMemosRepositoryProvider).fileBytes(f);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        await ref.read(memoFileSaverProvider)(f.name, data);
        messenger.showSnackBar(SnackBar(content: Text(l10n.wmFileSaved(f.name))));
      case ApiFailure(:final message):
        messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
  }

  Future<void> _removeFile(MemoFile f) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showPopconfirm(
      context,
      title: l10n.wmFileRemoveQ(f.name),
      okLabel: l10n.wmRemove,
      okKey: const ValueKey('wm-file-remove-go'),
      danger: true,
    );
    if (ok != true || !mounted) return;
    final r = await ref.read(warehouseMemosRepositoryProvider).removeFile(f.id);
    if (!mounted) return;
    if (r case ApiFailure(:final message)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
    _refresh();
  }

  Widget _card(WarehouseMemo m, bool showWarehouse) => _MemoCard(
        memo: m,
        showWarehouse: showWarehouse,
        query: _query,
        onEdit: () => _write(memo: m),
        onRemove: () => _remove(m),
        onAddFiles: () => _addFiles(m),
        onView: _view,
        onDownload: _download,
        onRemoveFile: _removeFile,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final warehouses = ref.watch(warehouseOverviewProvider).valueOrNull?.warehouses ?? const <Warehouse>[];
    final active = ref.watch(activeWarehouseIdProvider);
    final wh = _chosen ? _warehouseId : active;

    final top = Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_kind == MemoKind.calendar ? l10n.wmIntroCalendar : l10n.wmIntroBoard, style: muted),
        const SizedBox(height: AppSpacing.sm),
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
        TextField(
          key: const ValueKey('wm-search'),
          controller: _search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            labelText: l10n.wmSearch,
            border: const OutlineInputBorder(),
            isDense: true,
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
      ]),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.wmTitle),
        bottom: TabBar(controller: _tabs, tabs: [
          HelpTab(
              help: l10n.wmHelpCalendar,
              child: Tab(key: const ValueKey('wm-tab-calendar'), icon: const Icon(Icons.calendar_month_outlined), text: l10n.wmTabCalendar)),
          HelpTab(
              help: l10n.wmHelpBoard,
              child: Tab(key: const ValueKey('wm-tab-board'), icon: const Icon(Icons.push_pin_outlined), text: l10n.wmTabBoard)),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('wm-new'),
        onPressed: warehouses.isEmpty ? null : () => _write(),
        icon: const Icon(Icons.edit_note),
        label: Text(_kind == MemoKind.calendar ? l10n.wmWriteCalendar : l10n.wmWriteBoard),
      ),
      body: Column(children: [
        top,
        Expanded(
          child: TabBarView(controller: _tabs, children: [
            _calendarView(context, wh),
            _boardView(context, wh),
          ]),
        ),
      ]),
    );
  }

  Widget _calendarView(BuildContext context, int? wh) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final searching = _query.trim().isNotEmpty;
    final async = ref.watch(warehouseMemosProvider(
        (kind: MemoKind.calendar, warehouseId: wh, year: _month.year, month: _month.month, query: _query)));
    final memos = async.valueOrNull ?? const <WarehouseMemo>[];
    final byDay = <DateTime, int>{};
    for (final m in memos) {
      byDay[m.day] = (byDay[m.day] ?? 0) + 1;
    }
    final day = _day;
    final shown = searching || day == null ? memos : [for (final m in memos) if (m.day == day) m];
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= calendarSideBySide;
      final calendar = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: calendarMaxWidth),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            IconButton(
              key: const ValueKey('wm-prev'),
              tooltip: l10n.calPrev,
              onPressed: () => setState(() {
                _month = DateTime(_month.year, _month.month - 1);
                _day = null;
              }),
              icon: const Icon(Icons.chevron_left),
            ),
            Text('${l10n.calYear(_month.year)} ${l10n.calMonth(_month.month)}',
                key: const ValueKey('wm-month'), style: theme.textTheme.titleMedium),
            // Days to come too: goods due, the arrangements ahead.
            IconButton(
              key: const ValueKey('wm-next'),
              tooltip: l10n.calNext,
              onPressed: () => setState(() {
                _month = DateTime(_month.year, _month.month + 1);
                _day = null;
              }),
              icon: const Icon(Icons.chevron_right),
            ),
            const Spacer(),
            TextButton(
              key: const ValueKey('wm-today'),
              onPressed: () => setState(() {
                _month = DateTime(now.year, now.month);
                _day = today;
              }),
              child: Text(l10n.calToday),
            ),
          ]),
          if (searching) Padding(padding: const EdgeInsets.only(bottom: AppSpacing.xs), child: Text(l10n.wmSearchAllDays, style: muted)),
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
        if (!searching && day != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('wm-show-month'),
              onPressed: () => setState(() => _day = null),
              child: Text(l10n.wmShowMonth),
            ),
          ),
        if (async.isLoading && memos.isEmpty) const LoadingView(),
        if (async.hasError) ErrorStateView(message: humanizeApiErrorMessage(l10n, '${async.error}'), onRetry: _refresh),
        if (!async.isLoading && !async.hasError && shown.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(searching ? l10n.wmNoneFound : l10n.wmNone, key: const ValueKey('wm-none'), textAlign: TextAlign.center),
          ),
        // By day, the earliest first: a date heading over each day's notes.
        for (final (i, m) in shown.indexed) ...[
          if (i == 0 || shown[i - 1].day != m.day)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: 2),
              child: Text(memoDayLabel(l10n, m.day),
                  key: ValueKey('wm-day-head-${m.day.day}'),
                  style: theme.textTheme.labelLarge?.copyWith(
                      color: m.day == today ? theme.colorScheme.primary : null, fontWeight: FontWeight.w700)),
            ),
          _card(m, wh == null),
        ],
        const SizedBox(height: 80),
      ];
      if (wide) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SizedBox(width: calendarMaxWidth, child: calendar),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: ListView(key: const ValueKey('wm-list'), padding: const EdgeInsets.all(AppSpacing.md), children: list)),
        ]);
      }
      return ListView(
        key: const ValueKey('wm-list'),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [Center(child: calendar), const SizedBox(height: AppSpacing.md), ...list],
      );
    });
  }

  Widget _boardView(BuildContext context, int? wh) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final searching = _query.trim().isNotEmpty;
    final async = ref.watch(warehouseMemosProvider((kind: MemoKind.board, warehouseId: wh, year: 0, month: 0, query: _query)));
    final memos = async.valueOrNull ?? const <WarehouseMemo>[];
    return ListView(
      key: const ValueKey('wm-board'),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(searching ? l10n.wmFound(_query, memos.length) : l10n.wmBoardList(memos.length),
            key: const ValueKey('wm-board-title'), style: theme.textTheme.titleSmall),
        if (async.isLoading && memos.isEmpty) const LoadingView(),
        if (async.hasError) ErrorStateView(message: humanizeApiErrorMessage(l10n, '${async.error}'), onRetry: _refresh),
        if (!async.isLoading && !async.hasError && memos.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(searching ? l10n.wmNoneFound : l10n.wmNoneBoard, key: const ValueKey('wm-none-board'), textAlign: TextAlign.center),
          ),
        for (final m in memos) _card(m, wh == null),
        const SizedBox(height: 80),
      ],
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
    required this.onAddFiles,
    required this.onView,
    required this.onDownload,
    required this.onRemoveFile,
  });

  final WarehouseMemo memo;
  final bool showWarehouse;
  final String query;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback onAddFiles;
  final ValueChanged<MemoFile> onView;
  final ValueChanged<MemoFile> onDownload;
  final ValueChanged<MemoFile> onRemoveFile;

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

  String _size(int? b) => b == null
      ? ''
      : b >= 1024 * 1024
          ? '${(b / 1024 / 1024).toStringAsFixed(1)} MB'
          : '${(b / 1024).ceil()} KB';

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
                  if (memo.kind == MemoKind.board && memo.createdAt != null) l10n.wmPostedAt(at.format(memo.createdAt!)),
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
              if (memo.updatedAt case final u?) Text(l10n.wmUpdated(at.format(u), memo.updatedByName ?? ''), style: muted),
              // Its files: seen in the browser, saved, taken away.
              for (final f in memo.files)
                Row(key: ValueKey('wm-file-${f.id}'), children: [
                  Icon(f.isImage ? Icons.image_outlined : Icons.attach_file, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      onTap: () => onView(f),
                      child: Text(
                        [f.name, if (f.size != null) _size(f.size)].join('  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary, decoration: TextDecoration.underline),
                      ),
                    ),
                  ),
                  IconButton(
                    key: ValueKey('wm-file-view-${f.id}'),
                    tooltip: l10n.wmFileView,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    onPressed: () => onView(f),
                  ),
                  IconButton(
                    key: ValueKey('wm-file-dl-${f.id}'),
                    tooltip: l10n.wmFileDownload,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.download_outlined, size: 18),
                    onPressed: () => onDownload(f),
                  ),
                  IconButton(
                    key: ValueKey('wm-file-remove-${f.id}'),
                    tooltip: l10n.wmRemove,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => onRemoveFile(f),
                  ),
                ]),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: ValueKey('wm-add-files-${memo.id}'),
                  onPressed: onAddFiles,
                  icon: const Icon(Icons.attach_file, size: 18),
                  label: Text(l10n.wmAddFiles),
                ),
              ),
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

/// What the dialog gives back: the warehouse, the words, the カレンダー's day,
/// and files chosen to go with a new note.
typedef _Written = ({int warehouseId, String body, DateTime? date, List<({String name, Uint8List bytes})> files});

/// Writing or editing a note: the warehouse, the day (カレンダー), the words,
/// and files.
class _MemoDialog extends ConsumerStatefulWidget {
  const _MemoDialog({
    required this.warehouses,
    required this.warehouseId,
    required this.body,
    required this.editing,
    required this.kind,
    required this.date,
  });

  final List<Warehouse> warehouses;
  final int warehouseId;
  final String body;
  final bool editing;
  final MemoKind kind;
  final DateTime date;

  @override
  ConsumerState<_MemoDialog> createState() => _MemoDialogState();
}

class _MemoDialogState extends ConsumerState<_MemoDialog> {
  late int _wh = widget.warehouseId;
  late DateTime _date = widget.date;
  late final _body = TextEditingController(text: widget.body);
  final List<({String name, Uint8List bytes})> _files = [];

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null && mounted) setState(() => _date = DateTime(d.year, d.month, d.day));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final calendar = widget.kind == MemoKind.calendar;
    return EditDrawer(
      title: Text(widget.editing
          ? l10n.wmEdit
          : calendar
              ? l10n.wmWriteCalendar
              : l10n.wmWriteBoard),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            DropdownButtonFormField<int>(
              key: const ValueKey('wm-warehouse'),
              initialValue: _wh,
              decoration: InputDecoration(labelText: l10n.sfWarehouse),
              items: [for (final w in widget.warehouses) DropdownMenuItem(value: w.id, child: Text(w.name))],
              onChanged: (v) => setState(() => _wh = v ?? _wh),
            ),
            // The カレンダー's day, chosen by hand: past or to come.
            if (calendar) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                key: const ValueKey('wm-date'),
                onPressed: _pickDate,
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(l10n.wmDate(memoDayLabel(l10n, _date))),
              ),
            ],
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
                hintText: calendar ? l10n.wmBodyHintCalendar : l10n.wmBodyHintBoard,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            // Files to go with a new note (an existing one takes them on its card).
            if (!widget.editing) ...[
              for (final f in _files)
                Row(children: [
                  const Icon(Icons.attach_file, size: 16),
                  Expanded(child: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _files.remove(f)),
                  ),
                ]),
              TextButton.icon(
                key: const ValueKey('wm-dialog-files'),
                onPressed: () async {
                  final picked = await ref.read(memoFilePickerProvider)();
                  if (mounted) setState(() => _files.addAll(picked));
                },
                icon: const Icon(Icons.attach_file, size: 18),
                label: Text(l10n.wmAddFiles),
              ),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('wm-save'),
          onPressed: _body.text.trim().isEmpty
              ? null
              : () => Navigator.pop<_Written>(context,
                  (warehouseId: _wh, body: _body.text.trim(), date: calendar ? _date : null, files: List.of(_files))),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
