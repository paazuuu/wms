import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/export/xlsx.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../outbound/presentation/outbound_downloads.dart' show saveFileProvider;
import '../../outbound_file/domain/outbound_sheet.dart';
import '../../outbound_file/presentation/outbound_file_screen.dart' show outboundColumnLabel, outboundFilePickerProvider;
import '../../stock_import/domain/stock_file.dart' show fileFingerprint, readStockFile;
import '../../stock_import/presentation/import_view_screen.dart' show OriginalFileView;
import '../data/purchase_request_repository.dart';
import '../domain/purchase_request.dart';
import '../domain/wish_file.dart';

/// The customer's file read, to keep with the list once it is saved (0206).
class WishFileSource {
  const WishFileSource({required this.name, required this.bytes, this.sheetName, this.columns = const {}});

  final String name;
  final Uint8List bytes;
  final String? sheetName;
  final Map<String, String> columns;

  Map<String, dynamic> toFile(String storagePath) => {
        'file_name': name,
        'storage_path': storagePath,
        'file_size': bytes.length,
        'fingerprint': fileFingerprint(bytes),
        'sheet_name': sheetName,
        'columns': columns,
      };
}

/// 入荷希望リストをファイルから (0206): the customer's own list read as the
/// 出荷明細 is in 出庫 — the file, its sheet and columns, the original beside
/// the table, each row matched to the library by JAN or 品番 and ticked to go
/// in. A row not in the library goes in as a product typed by hand. What is
/// ticked is in the list at once ([onApply]); the list's 保存 keeps it, and
/// the file with it ([onFile]).
class WishFileTab extends ConsumerStatefulWidget {
  const WishFileTab({
    super.key,
    required this.library,
    required this.onApply,
    required this.onFile,
    this.loading = false,
    this.saved,
  });

  /// The products of 商品マスタ (rows of the list, p<product id>).
  final Map<String, RequestRow> library;
  final bool loading;

  /// A saved list's file, to look at again.
  final PurchaseRequest? saved;
  final ValueChanged<WishFileApplied> onApply;
  final ValueChanged<WishFileSource?> onFile;

  @override
  ConsumerState<WishFileTab> createState() => _WishFileTabState();
}

enum _Filter { found, fresh, several }

class _WishFileTabState extends ConsumerState<WishFileTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  ({String name, Uint8List bytes})? _file;
  List<XlsxSheetRows> _sheets = const [];
  int _sheet = 0;
  Map<OutboundColumn, int>? _columns;
  OutboundSheet? _parsed;
  final Map<int, String> _picked = {};
  final Set<int> _excluded = {};
  _Filter? _filter;
  bool _columnsOpen = false;
  bool _showOriginal = true;

  void _snack(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
  }

  List<WishFileLine> get _lines =>
      _parsed == null ? const [] : matchWishRows(_parsed!.rows, widget.library.values, picked: _picked);

  /// What is ticked goes into the list.
  void _apply() => widget.onApply(applyWishFile(_lines, _excluded));

  void _source() {
    final f = _file;
    final p = _parsed;
    widget.onFile(f == null
        ? null
        : WishFileSource(
            name: f.name,
            bytes: f.bytes,
            sheetName: p?.sheetName,
            columns: {
              for (final e in (p?.columnsWire ?? const <String, String>{}).entries)
                if (wishColumns.any((c) => c.wire == e.key)) e.key: e.value,
            },
          ));
  }

  Future<void> _pick() async {
    final l10n = AppLocalizations.of(context);
    final f = await ref.read(outboundFilePickerProvider)();
    if (f == null || !mounted) return;
    List<XlsxSheetRows> sheets;
    try {
      final lower = f.name.toLowerCase();
      sheets = lower.endsWith('.xlsx') || lower.endsWith('.xlsm')
          ? readXlsxSheets(f.bytes)
          : [(name: f.name, rows: readStockFile(f.name, f.bytes))];
    } on FormatException {
      _snack(l10n.ofReadFailed);
      return;
    }
    setState(() {
      _file = f;
      _sheets = sheets;
      _sheet = pickOutboundSheet(sheets);
      _columns = null;
      _picked.clear();
      _excluded.clear();
      _filter = null;
    });
    _read();
  }

  void _read() {
    if (_sheets.isEmpty) return;
    final s = _sheets[_sheet];
    final parsed = parseOutboundSheet(s.name, s.rows, columns: _columns);
    setState(() {
      _parsed = parsed;
      _columns ??= Map.of(parsed.columns);
    });
    _apply();
    _source();
  }

  void _include(Iterable<int> rows, bool on) {
    setState(() => on ? _excluded.removeAll(rows) : _excluded.addAll(rows));
    _apply();
  }

  Future<void> _pickProduct(WishFileLine l) async {
    final key = await showDialog<String>(
      context: context,
      builder: (_) => _PickLibraryDialog(
        rowNo: l.row.rowNo,
        initial: l.row.code ?? l.row.name ?? (l.row.jan.isEmpty ? '' : l.row.jan),
        library: widget.library.values.toList(),
      ),
    );
    if (key == null || !mounted) return;
    setState(() {
      _picked[l.row.rowNo] = key;
      _excluded.remove(l.row.rowNo);
    });
    _apply();
  }

  // ------------------------------------------------------------ saved file

  Future<Uint8List?> _savedBytes() async {
    final l10n = AppLocalizations.of(context);
    final path = widget.saved?.storagePath;
    if (path == null) return null;
    final r = await ref.read(purchaseRequestRepositoryProvider).fileBytes(path);
    if (!mounted) return null;
    switch (r) {
      case ApiSuccess(:final data):
        return data;
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
        return null;
    }
  }

  Future<void> _viewSaved() async {
    final name = widget.saved?.fileName ?? '';
    final bytes = await _savedBytes();
    if (bytes == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(name)),
        body: OriginalFileView(key: const ValueKey('wl-saved-original'), fileName: name, bytes: bytes),
      ),
    ));
  }

  Future<void> _downloadSaved() async {
    final bytes = await _savedBytes();
    if (bytes == null) return;
    await ref.read(saveFileProvider)(widget.saved?.fileName ?? 'wish.xlsx', bytes);
  }

  // ------------------------------------------------------------ build

  static const _dense = ButtonStyle(
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: WidgetStatePropertyAll(TextStyle(
        fontFamily: AppFonts.sans, fontFamilyFallback: AppFonts.fallback, fontSize: 14, fontWeight: FontWeight.w600)),
  );

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
    final parsed = _parsed;
    final lines = _lines;
    final applied = applyWishFile(lines, _excluded);
    int count(WishRowStatus s) => lines.where((l) => l.status == s).length;
    final shown = [
      for (final l in lines)
        if (switch (_filter) {
          null => true,
          _Filter.found => l.status == WishRowStatus.found,
          _Filter.fresh => l.status == WishRowStatus.notInLibrary,
          _Filter.several => l.status == WishRowStatus.several,
        })
          l,
    ];
    final saved = widget.saved;

    final main = LayoutBuilder(
      builder: (context, viewport) => ListView(
        key: const ValueKey('wl-file-list'),
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
        children: [
          if (_file == null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l10n.wlFileIntro, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    key: const ValueKey('wl-file-pick'),
                    onPressed: _pick,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(l10n.ofPick),
                  ),
                ]),
              ),
            ),
            if (saved?.storagePath != null)
              Card(
                key: const ValueKey('wl-saved-file'),
                child: ListTile(
                  leading: const Icon(Icons.attach_file),
                  title: Text(l10n.wlSavedFile(saved!.fileName ?? '')),
                  subtitle: saved.sheetName == null ? null : Text('${l10n.ofSheet}: ${saved.sheetName}', style: muted),
                  trailing: Wrap(spacing: AppSpacing.xs, children: [
                    TextButton.icon(
                      key: const ValueKey('wl-saved-view'),
                      onPressed: _viewSaved,
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: Text(l10n.wlSavedFileView),
                    ),
                    TextButton.icon(
                      key: const ValueKey('wl-saved-download'),
                      onPressed: _downloadSaved,
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: Text(l10n.wlSavedFileDownload),
                    ),
                  ]),
                ),
              ),
          ] else
            _fileBar(l10n, parsed, muted),
          if (parsed != null && _columnsOpen) _columnsPanel(l10n, parsed, muted),
          if (parsed != null && !parsed.usable)
            Text(l10n.ofNotUsable, key: const ValueKey('wl-not-usable'), style: TextStyle(color: scheme.error)),
          if (parsed != null && parsed.rows.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            if (widget.loading && widget.library.isEmpty)
              Row(children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: AppSpacing.sm),
                Text(l10n.ofMatching),
              ])
            else ...[
              Text(l10n.wlFileSummary(lines.length, applied.rows, applied.units, applied.manual.length),
                  key: const ValueKey('wl-file-summary'), style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
                ChoiceChip(
                  key: const ValueKey('wl-filter-all'),
                  label: Text(l10n.ofFilterAll(lines.length)),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
                ChoiceChip(
                  key: const ValueKey('wl-filter-found'),
                  label: Text(l10n.wlFilterFound(count(WishRowStatus.found))),
                  selected: _filter == _Filter.found,
                  onSelected: (v) => setState(() => _filter = v ? _Filter.found : null),
                ),
                ChoiceChip(
                  key: const ValueKey('wl-filter-new'),
                  label: Text(l10n.wlFilterNew(count(WishRowStatus.notInLibrary))),
                  selected: _filter == _Filter.fresh,
                  onSelected: (v) => setState(() => _filter = v ? _Filter.fresh : null),
                ),
                if (count(WishRowStatus.several) > 0)
                  ChoiceChip(
                    key: const ValueKey('wl-filter-several'),
                    label: Text(l10n.wlFilterSeveral(count(WishRowStatus.several))),
                    selected: _filter == _Filter.several,
                    onSelected: (v) => setState(() => _filter = v ? _Filter.several : null),
                  ),
              ]),
              const SizedBox(height: AppSpacing.sm),
              _WishTable(
                height: viewport.maxHeight - AppSpacing.md,
                lines: shown,
                library: widget.library,
                excluded: _excluded,
                onInclude: _include,
                onPick: _pickProduct,
              ),
            ],
          ],
        ],
      ),
    );

    // On a PC the file read beside the table, as in 出庫.
    final file = _file;
    if (file == null || _sheets.isEmpty || !_showOriginal) return main;
    final out = {
      for (final l in lines)
        if (_excluded.contains(l.row.rowNo) || l.quantity <= 0) l.row.rowNo
    };
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 1100) return main;
      return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: (box.maxWidth * 0.3).clamp(320.0, 560.0),
          child: Column(
            key: const ValueKey('wl-original'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.xs, 0),
                child: Row(children: [
                  Expanded(
                    child: Text([file.name, if (_sheets.length > 1) _sheets[_sheet].name].join(' · '),
                        style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    key: const ValueKey('wl-original-hide'),
                    tooltip: l10n.ofOriginalHide,
                    icon: const Icon(Icons.close_fullscreen, size: 18),
                    onPressed: () => setState(() => _showOriginal = false),
                  ),
                ]),
              ),
              if (out.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Text(l10n.wlOriginalLegend(out.length), style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
                ),
              Expanded(
                child: OriginalFileView(
                    fileName: file.name, bytes: file.bytes, sheetRows: _sheets[_sheet].rows, leftOut: out),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: main),
      ]);
    });
  }

  /// The file read, on one line: choose again, its name, the sheet, where
  /// its headings are, the columns, the original beside.
  Widget _fileBar(AppLocalizations l10n, OutboundSheet? parsed, TextStyle? muted) {
    final theme = Theme.of(context);
    return Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
      OutlinedButton.icon(
        key: const ValueKey('wl-file-pick'),
        style: _dense,
        onPressed: _pick,
        icon: const Icon(Icons.upload_file_outlined, size: 18),
        label: Text(l10n.ofPickAgain),
      ),
      Text(_file!.name, key: const ValueKey('wl-file-name'), style: theme.textTheme.titleSmall),
      if (parsed != null && _sheets.length > 1)
        DropdownButton<int>(
          key: ValueKey('wl-sheet-$_sheet'),
          value: _sheet,
          isDense: true,
          underline: const SizedBox.shrink(),
          items: [
            for (final (i, s) in _sheets.indexed)
              DropdownMenuItem(value: i, child: Text('${l10n.ofSheet}: ${s.name}', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _sheet = v;
              _columns = null;
              _picked.clear();
              _excluded.clear();
            });
            _read();
          },
        ),
      if (parsed != null && parsed.headerRow >= 0) Text(l10n.ofHeaderRow(parsed.headerRow + 1), style: muted),
      if (parsed != null && parsed.janGuessed)
        Tooltip(
          message: l10n.ofJanGuessed,
          child: Icon(Icons.info_outline, size: 16, color: theme.colorScheme.onSurfaceVariant),
        ),
      if (parsed != null)
        Tooltip(
          message: [
            for (final c in wishColumns)
              if (parsed.columns[c] != null) '${outboundColumnLabel(l10n, c)} = ${_colName(parsed, parsed.columns[c]!)}',
          ].join('\n'),
          child: TextButton.icon(
            key: const ValueKey('wl-columns'),
            style: _dense,
            onPressed: () => setState(() => _columnsOpen = !_columnsOpen),
            icon: Icon(_columnsOpen ? Icons.expand_less : Icons.view_column_outlined, size: 18),
            label: Text(l10n.ofColumns),
          ),
        ),
      if (!_showOriginal)
        TextButton.icon(
          key: const ValueKey('wl-original-show'),
          style: _dense,
          onPressed: () => setState(() => _showOriginal = true),
          icon: const Icon(Icons.vertical_split_outlined, size: 18),
          label: Text(l10n.ofOriginalShow),
        ),
    ]);
  }

  /// 列の割り当て: each field and the column it is read from, to choose again.
  Widget _columnsPanel(AppLocalizations l10n, OutboundSheet parsed, TextStyle? muted) {
    final width = [for (final r in _sheets[_sheet].rows.take(30)) r.length].fold(parsed.headings.length, (a, b) => a > b ? a : b);
    return Card(
      key: const ValueKey('wl-columns-panel'),
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.ofColumnsHint, style: muted),
          const SizedBox(height: AppSpacing.sm),
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
            for (final c in wishColumns)
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<int>(
                  key: ValueKey('wl-col-${c.wire}-${parsed.columns[c] ?? -1}'),
                  initialValue: parsed.columns[c] ?? -1,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: outboundColumnLabel(l10n, c), isDense: true),
                  items: [
                    DropdownMenuItem(value: -1, child: Text(l10n.ofColNone)),
                    for (var i = 0; i < width; i++)
                      DropdownMenuItem(value: i, child: Text(_colName(parsed, i), overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) {
                    final next = Map.of(_columns ?? parsed.columns);
                    if (v == null || v < 0) {
                      next.remove(c);
                    } else {
                      next[c] = v;
                    }
                    setState(() {
                      _columns = next;
                      _picked.clear();
                      _excluded.clear();
                    });
                    _read();
                  },
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}

String wishStatusLabel(AppLocalizations l10n, WishRowStatus s) => switch (s) {
      WishRowStatus.found => l10n.wlStFound,
      WishRowStatus.notInLibrary => l10n.wlStNew,
      WishRowStatus.several => l10n.wlStSeveral,
      WishRowStatus.noQuantity => l10n.wlStNoQty,
    };

/// The rows read, as in 出庫: 行, 対象, 状態, 商品, JAN, 品番, メーカー, 希望数,
/// 在庫.
class _WishTable extends StatefulWidget {
  const _WishTable({
    this.height,
    required this.lines,
    required this.library,
    required this.excluded,
    required this.onInclude,
    required this.onPick,
  });

  final double? height;
  final List<WishFileLine> lines;
  final Map<String, RequestRow> library;
  final Set<int> excluded;
  final void Function(Iterable<int> rowNos, bool include) onInclude;
  final void Function(WishFileLine) onPick;

  @override
  State<_WishTable> createState() => _WishTableState();
}

class _WishTableState extends State<_WishTable> {
  final _across = ScrollController();
  static const _widths = [52.0, 44.0, 150.0, 280.0, 128.0, 128.0, 110.0, 80.0, 80.0];
  static const _allAtOnce = 40;

  @override
  void dispose() {
    _across.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final head = theme.textTheme.labelMedium;
    final small = theme.textTheme.bodySmall;
    Widget cell(int i, Widget child, {bool end = false}) => Container(
          width: _widths[i],
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          alignment: end ? Alignment.centerRight : Alignment.centerLeft,
          child: child,
        );
    final width = _widths.fold(0.0, (a, w) => a + w);
    final lines = widget.lines;
    bool on(WishFileLine l) => !widget.excluded.contains(l.row.rowNo) && l.quantity > 0;
    final counted = [for (final l in lines) if (l.quantity > 0) l];
    final included = counted.where(on).length;
    final headers = [
      l10n.ofColRow, '', l10n.ofColStatus, l10n.ofColProduct, l10n.ofRoleJan, l10n.ofRoleCode, l10n.ofRoleMaker,
      l10n.wlColWish, l10n.ofColStock,
    ];
    final header = Container(
      color: scheme.surfaceContainerHighest,
      child: Row(children: [
        for (final (i, h) in headers.indexed)
          i == 1
              ? cell(
                  1,
                  Tooltip(
                    message: l10n.ofIncludeAll,
                    child: Checkbox(
                      key: const ValueKey('wl-include-all'),
                      tristate: true,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      value: included == counted.length ? true : (included == 0 ? false : null),
                      onChanged: counted.isEmpty
                          ? null
                          : (_) => widget.onInclude([for (final l in counted) l.row.rowNo], included != counted.length),
                    ),
                  ))
              : cell(i, Text(h, style: head), end: i >= 7),
      ]),
    );

    Widget row(WishFileLine l) {
      final out = !on(l);
      final ours = l.key == null ? null : widget.library[l.key];
      final st = l.status;
      final color = switch (st) {
        WishRowStatus.found => scheme.success,
        WishRowStatus.notInLibrary => scheme.tertiary,
        WishRowStatus.several => scheme.warning,
        WishRowStatus.noQuantity => scheme.onSurfaceVariant,
      };
      return Container(
        key: ValueKey('wl-row-${l.row.rowNo}'),
        decoration: BoxDecoration(
          color: out ? scheme.surfaceContainerLow : null,
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Opacity(
          opacity: out ? 0.55 : 1,
          child: Row(children: [
            cell(0, Text('${l.row.rowNo}', style: small)),
            cell(
              1,
              Checkbox(
                key: ValueKey('wl-include-${l.row.rowNo}'),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                value: !out,
                onChanged: l.quantity <= 0 ? null : (v) => widget.onInclude([l.row.rowNo], v ?? false),
              ),
            ),
            cell(
              2,
              Text(wishStatusLabel(l10n, st),
                  key: ValueKey('wl-status-${l.row.rowNo}'),
                  style: small?.copyWith(color: color, fontWeight: FontWeight.w600)),
            ),
            cell(
              3,
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                if (ours != null)
                  Text(ours.name, key: ValueKey('wl-name-${l.row.rowNo}'), maxLines: 2, overflow: TextOverflow.ellipsis)
                else if (l.row.name != null)
                  Text(l.row.name!, maxLines: 2, overflow: TextOverflow.ellipsis, style: small),
                if (l.by == WishMatchedBy.code || l.by == WishMatchedBy.picked)
                  Text(l.by == WishMatchedBy.code ? l10n.wlMatchedCode : l10n.wlMatchedPicked,
                      style: small?.copyWith(color: scheme.onSurfaceVariant)),
                // Not found, or found by 品番 only: one of ours may be chosen.
                if (l.by != WishMatchedBy.jan)
                  TextButton.icon(
                    key: ValueKey('wl-pick-${l.row.rowNo}'),
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 28),
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    onPressed: () => widget.onPick(l),
                    icon: const Icon(Icons.search, size: 16),
                    label: Text(l10n.ofPickProduct),
                  ),
              ]),
            ),
            cell(4, Text(l.row.jan.isNotEmpty ? l.row.jan : l.row.janRaw, style: small)),
            cell(5, Text(l.row.code ?? '', style: small, maxLines: 1, overflow: TextOverflow.ellipsis)),
            cell(6, Text(l.row.maker ?? ours?.maker ?? '', style: small, maxLines: 1, overflow: TextOverflow.ellipsis)),
            cell(7, Text(l.quantity > 0 ? '${l.quantity}' : '—', key: ValueKey('wl-qty-${l.row.rowNo}'), style: theme.textTheme.titleSmall),
                end: true),
            cell(8, Text(ours?.onHand == null ? '—' : '${ours!.onHand}', style: small), end: true),
          ]),
        ),
      );
    }

    final Widget body;
    if (lines.length <= _allAtOnce) {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [header, for (final l in lines) row(l)]);
    } else {
      final height = (widget.height ?? MediaQuery.sizeOf(context).height * 0.72).clamp(360.0, 2000.0);
      body = SizedBox(
        width: width,
        height: height,
        child: Column(children: [
          header,
          Expanded(child: ListView.builder(itemCount: lines.length, itemBuilder: (_, i) => row(lines[i]))),
        ]),
      );
    }
    return Scrollbar(
      controller: _across,
      thumbVisibility: true,
      child: SingleChildScrollView(
        key: const ValueKey('wl-table'),
        controller: _across,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 12),
        child: body,
      ),
    );
  }
}

/// One of our products chosen for a row: by its name, maker, JAN or 品番.
class _PickLibraryDialog extends StatefulWidget {
  const _PickLibraryDialog({required this.rowNo, required this.initial, required this.library});

  final int rowNo;
  final String initial;
  final List<RequestRow> library;

  @override
  State<_PickLibraryDialog> createState() => _PickLibraryDialogState();
}

class _PickLibraryDialogState extends State<_PickLibraryDialog> {
  late final _search = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final words = _search.text.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final shown = [
      for (final r in widget.library)
        if (r.productId != null &&
            words.every('${r.name} ${r.maker ?? ''} ${r.janCode ?? ''} ${r.sku ?? ''}'.toLowerCase().contains))
          r,
    ].take(50).toList();
    return AlertDialog(
      key: const ValueKey('wl-pick-dialog'),
      title: Text(l10n.ofPickProductTitle(widget.rowNo)),
      content: SizedBox(
        width: 460,
        height: 420,
        child: Column(children: [
          TextField(
            key: const ValueKey('wl-pick-search'),
            controller: _search,
            autofocus: true,
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.ofPickSearch),
            onChanged: (_) => setState(() {}),
          ),
          Expanded(
            child: ListView(children: [
              for (final r in shown)
                ListTile(
                  key: ValueKey('wl-pick-${r.key}'),
                  dense: true,
                  title: Text(r.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text([r.maker ?? '', r.janCode ?? '', r.sku ?? ''].where((s) => s.isNotEmpty).join(' · ')),
                  trailing: r.onHand == null ? null : Text(l10n.prOnHand(r.onHand!)),
                  onTap: () => Navigator.pop(context, r.key),
                ),
            ]),
          ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel))],
    );
  }
}
