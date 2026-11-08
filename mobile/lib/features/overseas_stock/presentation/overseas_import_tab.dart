import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/export/xlsx.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../master_import/data/master_import_repository.dart';
import '../../master_import/domain/master_import.dart' show MasterProblem;
import '../../master_import/presentation/master_import_labels.dart' show masterProblemText;
import '../../outbound_file/domain/outbound_sheet.dart';
import '../../outbound_file/presentation/outbound_file_screen.dart' show outboundColumnLabel;
import '../../stock_import/domain/stock_file.dart' show fileFingerprint, readStockFile;
import '../../stock_import/presentation/import_view_screen.dart' show OriginalFileView;
import '../data/overseas_stock_repository.dart';
import '../domain/overseas_stock.dart';
import 'overseas_widgets.dart';

/// The file a site's stock is read from (overridden in tests).
final overseasFilePickerProvider = Provider<Future<({String name, Uint8List bytes})?> Function()>((_) => pickOverseasFile);

/// 国外の仮想在庫をファイルから (0207), as 出庫 and 入荷希望リスト read
/// theirs: the file and its sheet and columns, the original beside, the rows
/// ticked and checked, then registered as the site's stock on a day. An
/// Excel or CSV is read by its columns — headings not known are judged by
/// the AI; a PDF or a photo is read by the AI.
class OverseasImportTab extends ConsumerStatefulWidget {
  const OverseasImportTab({super.key, required this.site, required this.onDone});

  final OverseasSite site;

  /// Registered: the stock to show.
  final VoidCallback onDone;

  @override
  ConsumerState<OverseasImportTab> createState() => _OverseasImportTabState();
}

class _OverseasImportTabState extends ConsumerState<OverseasImportTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  ({String name, Uint8List bytes})? _file;
  List<XlsxSheetRows> _sheets = const [];
  int _sheet = 0;
  Map<OutboundColumn, int>? _columns;
  OutboundSheet? _parsed;

  /// The rows the AI read (a PDF, a photo).
  List<OverseasLine>? _aiLines;
  bool _aiBusy = false;
  String? _aiError;
  int? _aiColumns;
  final Set<int> _excluded = {};
  final Map<int, num> _qty = {};
  DateTime _asOf = DateUtils.dateOnly(DateTime.now());
  bool _columnsOpen = false;
  bool _showOriginal = true;
  bool _busy = false;

  void _snack(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
  }

  bool get _byAi => _aiLines != null;

  List<OverseasLine> get _lines => [
        for (final l in _aiLines ?? (_parsed == null ? const <OverseasLine>[] : overseasLinesFromSheet(_parsed!)))
          _qty.containsKey(l.rowNo) ? l.withQuantity(_qty[l.rowNo]!) : l,
      ];

  List<OverseasLine> get _chosen => [for (final l in _lines) if (!_excluded.contains(l.rowNo)) l];

  Future<void> _pick() async {
    final l10n = AppLocalizations.of(context);
    final f = await ref.read(overseasFilePickerProvider)();
    if (f == null || !mounted) return;
    setState(() {
      _file = f;
      _sheets = const [];
      _parsed = null;
      _columns = null;
      _aiLines = null;
      _aiError = null;
      _aiColumns = null;
      _excluded.clear();
      _qty.clear();
    });
    if (!overseasReadsAsSheet(f.name)) return _readByAi();
    List<XlsxSheetRows> sheets;
    try {
      final lower = f.name.toLowerCase();
      sheets = lower.endsWith('.xlsx') || lower.endsWith('.xlsm')
          ? readXlsxSheets(f.bytes)
          : [(name: f.name, rows: readStockFile(f.name, f.bytes))];
    } on FormatException {
      return _snack(l10n.ofReadFailed);
    }
    setState(() {
      _sheets = sheets;
      _sheet = pickOutboundSheet(sheets);
    });
    _read();
    // Headings not known: the AI says what they are.
    if (_parsed != null && !_parsed!.usable) await _judgeColumns();
  }

  void _read() {
    if (_sheets.isEmpty) return;
    final s = _sheets[_sheet];
    final parsed = parseOutboundSheet(s.name, s.rows, columns: _columns);
    setState(() {
      _parsed = parsed;
      _columns ??= Map.of(parsed.columns);
      _excluded.clear();
      _qty.clear();
    });
  }

  /// The sheet's headings judged by the AI (and the headings learned).
  Future<void> _judgeColumns() async {
    final l10n = AppLocalizations.of(context);
    final rows = _sheets[_sheet].rows;
    final parsed = _parsed;
    if (parsed == null || rows.isEmpty) return;
    final head = parsed.headerRow >= 0 ? parsed.headerRow : 0;
    final headers = rows[head];
    setState(() => _aiBusy = true);
    final r = await ref.read(masterImportRepositoryProvider).mapColumns(headers, rows.skip(head + 1).take(5).toList());
    if (!mounted) return;
    setState(() => _aiBusy = false);
    switch (r) {
      case ApiSuccess(:final data):
        final next = Map.of(_columns ?? parsed.columns);
        var n = 0;
        for (final m in data) {
          final c = overseasColumnOfField(m.field);
          if (c == null || m.index < 0 || next.containsKey(c)) continue;
          next[c] = m.index;
          n++;
        }
        setState(() {
          _columns = next;
          _aiColumns = n;
        });
        _read();
        _snack(l10n.osAiColumnsDone(n));
      case ApiFailure(:final message):
        _snack(l10n.osAiFailed(humanizeApiErrorMessage(l10n, message)));
    }
  }

  /// A PDF or a photo: the AI reads its rows (nothing booked).
  Future<void> _readByAi() async {
    final l10n = AppLocalizations.of(context);
    final f = _file!;
    setState(() => _aiBusy = true);
    final r = await ref.read(masterImportRepositoryProvider).read(f.name, f.bytes, keepRows: true);
    if (!mounted) return;
    setState(() {
      _aiBusy = false;
      switch (r) {
        case ApiSuccess(:final data):
          _aiLines = overseasLinesFromAi(data.lines);
          if (data.aiFailure != null && data.lines.isEmpty) {
            _aiError = masterProblemText(l10n, MasterProblem('ai_unavailable', value: data.aiFailure));
          }
        case ApiFailure(:final message):
          _aiLines = const [];
          _aiError = humanizeApiErrorMessage(l10n, message);
      }
    });
  }

  Future<void> _pickAsOf() async {
    final now = DateTime.now();
    final d = await showDatePicker(
        context: context, initialDate: _asOf, firstDate: DateTime(now.year - 3), lastDate: DateTime(now.year + 1));
    if (d != null) setState(() => _asOf = d);
  }

  Future<void> _editQty(OverseasLine l) async {
    final q = await showOverseasQtyDialog(context, l.quantity);
    if (q != null) setState(() => _qty[l.rowNo ?? -1] = q);
  }

  Future<void> _register() async {
    final l10n = AppLocalizations.of(context);
    final f = _file;
    final lines = _chosen;
    if (f == null || lines.isEmpty) return;
    final repo = ref.read(overseasStockRepositoryProvider);
    setState(() => _busy = true);
    String? path;
    final up = await repo.upload(widget.site.id, f.name, f.bytes);
    if (up case ApiSuccess(:final data)) path = data;
    final parsed = _parsed;
    final r = await repo.import(
      siteId: widget.site.id,
      asOf: _asOf,
      lines: lines,
      readBy: _byAi ? 'ai' : 'sheet',
      fileName: f.name,
      storagePath: path,
      fileSize: f.bytes.length,
      fingerprint: fileFingerprint(f.bytes),
      sheetName: _byAi ? null : parsed?.sheetName,
      columns: _byAi || parsed == null
          ? null
          : {
              for (final e in parsed.columnsWire.entries)
                if (overseasColumns.any((c) => c.wire == e.key)) e.key: e.value,
            },
    );
    if (!mounted) return;
    // What was read, kept as Excel beside the file (0208).
    if (r case ApiSuccess(data: final id)) {
      final reading = buildXlsxBook([
        XlsxSheet(
          name: l10n.rdSuffix,
          headers: [
            l10n.ofColRow, l10n.wlReadIncluded, l10n.ofRoleJan, l10n.ofRoleCode, l10n.osColName, l10n.ofRoleMaker,
            l10n.osColQty, l10n.miFieldUnit,
          ],
          rows: [
            for (final l in _lines)
              [
                l.rowNo, _excluded.contains(l.rowNo) ? '' : '○', l.jan ?? '', l.code ?? '', l.name ?? '', l.maker ?? '',
                l.quantity, l.unit ?? '',
              ],
          ],
        ),
      ]);
      final name = '${f.name.replaceAll(RegExp(r'\.[^.]+$'), '')}_${l10n.rdSuffix}.xlsx';
      final up = await repo.upload(widget.site.id, name, Uint8List.fromList(reading));
      final kept = switch (up) {
        ApiSuccess(:final data) => await repo.setReadPath(id, data),
        ApiFailure(:final message) => ApiFailure<bool>(message: message),
      };
      if (kept case ApiFailure(:final message)) _snack(l10n.rdNotKept(humanizeApiErrorMessage(l10n, message)));
      if (!mounted) return;
    }
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess():
        _snack(l10n.osRegistered(widget.site.name, lines.length));
        setState(() {
          _file = null;
          _sheets = const [];
          _parsed = null;
          _aiLines = null;
          _excluded.clear();
          _qty.clear();
        });
        widget.onDone();
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  String _colName(OutboundSheet parsed, int i) => i < parsed.headings.length && parsed.headings[i].trim().isNotEmpty
      ? '${columnLetters(i)}: ${parsed.headings[i].trim()}'
      : columnLetters(i);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final file = _file;
    final parsed = _parsed;
    final lines = _lines;
    final chosen = _chosen;
    final units = chosen.fold<num>(0, (a, l) => a + l.quantity);

    final main = Column(children: [
      Expanded(
        child: ListView(
          key: const ValueKey('os-import-list'),
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            if (file == null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l10n.osImportIntro, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      key: const ValueKey('os-pick'),
                      onPressed: _pick,
                      icon: const Icon(Icons.upload_file_outlined),
                      label: Text(l10n.osPick),
                    ),
                  ]),
                ),
              )
            else
              Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                OutlinedButton.icon(
                  key: const ValueKey('os-pick'),
                  onPressed: _busy ? null : _pick,
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: Text(l10n.ofPickAgain),
                ),
                Text(file.name, key: const ValueKey('os-file-name'), style: theme.textTheme.titleSmall),
                Chip(
                  key: const ValueKey('os-read-by'),
                  avatar: Icon(_byAi ? Icons.auto_awesome : Icons.table_chart_outlined, size: 16),
                  label: Text(_byAi ? l10n.osReadByAi : l10n.osReadBySheet),
                ),
                if (parsed != null && _sheets.length > 1)
                  DropdownButton<int>(
                    key: ValueKey('os-sheet-$_sheet'),
                    value: _sheet,
                    isDense: true,
                    items: [
                      for (final (i, s) in _sheets.indexed)
                        DropdownMenuItem(value: i, child: Text('${l10n.ofSheet}: ${s.name}', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _sheet = v;
                        _columns = null;
                      });
                      _read();
                    },
                  ),
                if (parsed != null && parsed.headerRow >= 0) Text(l10n.ofHeaderRow(parsed.headerRow + 1), style: muted),
                if (parsed != null)
                  TextButton.icon(
                    key: const ValueKey('os-columns'),
                    onPressed: () => setState(() => _columnsOpen = !_columnsOpen),
                    icon: Icon(_columnsOpen ? Icons.expand_less : Icons.view_column_outlined, size: 18),
                    label: Text(l10n.ofColumns),
                  ),
                if (parsed != null)
                  TextButton.icon(
                    key: const ValueKey('os-ai-columns'),
                    onPressed: _aiBusy ? null : _judgeColumns,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: Text(l10n.osAiColumns),
                  ),
                if (_aiColumns != null) Text(l10n.osAiColumnsDone(_aiColumns!), style: muted),
                if (!_showOriginal)
                  TextButton.icon(
                    key: const ValueKey('os-original-show'),
                    onPressed: () => setState(() => _showOriginal = true),
                    icon: const Icon(Icons.vertical_split_outlined, size: 18),
                    label: Text(l10n.ofOriginalShow),
                  ),
              ]),
            if (parsed != null && _columnsOpen)
              Card(
                key: const ValueKey('os-columns-panel'),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                    for (final c in overseasColumns)
                      SizedBox(
                        width: 200,
                        child: DropdownButtonFormField<int>(
                          key: ValueKey('os-col-${c.wire}-${parsed.columns[c] ?? -1}'),
                          initialValue: parsed.columns[c] ?? -1,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: outboundColumnLabel(l10n, c), isDense: true),
                          items: [
                            DropdownMenuItem(value: -1, child: Text(l10n.ofColNone)),
                            for (var i = 0; i < [parsed.headings.length, ..._sheets[_sheet].rows.take(20).map((r) => r.length)].reduce((a, b) => a > b ? a : b); i++)
                              DropdownMenuItem(value: i, child: Text(_colName(parsed, i), overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) {
                            final next = Map.of(_columns ?? parsed.columns);
                            v == null || v < 0 ? next.remove(c) : next[c] = v;
                            setState(() => _columns = next);
                            _read();
                          },
                        ),
                      ),
                  ]),
                ),
              ),
            if (_aiBusy)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: AppSpacing.sm),
                  Text(l10n.osAiReading),
                ]),
              ),
            if (_aiError != null)
              Text(l10n.osAiFailed(_aiError!), key: const ValueKey('os-ai-error'), style: TextStyle(color: scheme.error)),
            if (parsed != null && !parsed.usable && !_aiBusy)
              Text(l10n.ofNotUsable, style: TextStyle(color: scheme.error)),
            if (file != null && lines.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                OutlinedButton.icon(
                  key: const ValueKey('os-as-of'),
                  onPressed: _pickAsOf,
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text(l10n.osAsOfIs(DateFormat('y/MM/dd').format(_asOf))),
                ),
                Text(l10n.osRows(lines.length, chosen.length, overseasQty(units)),
                    key: const ValueKey('os-rows'), style: theme.textTheme.titleSmall),
              ]),
              const SizedBox(height: AppSpacing.sm),
              OverseasLinesTable(
                lines: lines,
                excluded: _excluded,
                onInclude: (rows, on) => setState(() => on ? _excluded.removeAll(rows) : _excluded.addAll(rows)),
                onQty: _editQty,
              ),
            ],
          ],
        ),
      ),
      if (file != null && lines.isNotEmpty)
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: scheme.outlineVariant))),
            child: Row(children: [
              Expanded(child: Text(widget.site.name, style: theme.textTheme.bodyMedium)),
              if (_busy)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              else
                FilledButton.icon(
                  key: const ValueKey('os-register'),
                  onPressed: chosen.isEmpty ? null : _register,
                  icon: const Icon(Icons.inventory_outlined, size: 18),
                  label: Text(l10n.osRegister(chosen.length)),
                ),
            ]),
          ),
        ),
    ]);

    if (file == null || !_showOriginal) return main;
    final out = {for (final l in lines) if (_excluded.contains(l.rowNo) && l.rowNo != null) l.rowNo!};
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 1100) return main;
      return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: (box.maxWidth * 0.32).clamp(320.0, 600.0),
          child: Column(key: const ValueKey('os-original'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.xs, 0),
              child: Row(children: [
                Expanded(child: Text(file.name, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                IconButton(
                  key: const ValueKey('os-original-hide'),
                  tooltip: l10n.ofOriginalHide,
                  icon: const Icon(Icons.close_fullscreen, size: 18),
                  onPressed: () => setState(() => _showOriginal = false),
                ),
              ]),
            ),
            Expanded(
              child: OriginalFileView(
                fileName: file.name,
                bytes: file.bytes,
                sheetRows: _sheets.isEmpty ? null : _sheets[_sheet].rows,
                leftOut: out,
              ),
            ),
          ]),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: main),
      ]);
    });
  }
}
