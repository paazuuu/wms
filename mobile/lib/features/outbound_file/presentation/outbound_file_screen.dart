import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/export/save_bytes.dart';
import '../../../core/export/xlsx.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/open_window.dart';
import '../../../l10n/app_localizations.dart';
import '../../product/application/product_providers.dart';
import '../../product/domain/product.dart';
import '../../stock_import/domain/stock_file.dart' show fileFingerprint, readStockFile;
import '../../stock_ops/presentation/stock_adjustment_screen.dart'
    show adjustOnHand, adjustProductMatches, adjustProductsProvider;
import '../../outbound/domain/outbound.dart' show ShipDestination;
import '../../outbound/presentation/ship_destinations_screen.dart' show pickDestinationCard;
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/outbound_file_repository.dart';
import '../domain/outbound_plan.dart';
import '../domain/outbound_sheet.dart';
import 'outbound_calendar_tab.dart';
import 'outbound_file_detail_screen.dart';

/// The shipping list chosen to read (overridden in tests).
final outboundFilePickerProvider = Provider<Future<({String name, Uint8List bytes})?> Function()>((_) => () async {
      final r = await FilePicker.platform
          .pickFiles(withData: true, type: FileType.custom, allowedExtensions: const ['xlsx', 'xlsm', 'csv', 'tsv', 'txt']);
      final f = r?.files.firstOrNull;
      return f?.bytes == null ? null : (name: f!.name, bytes: f.bytes!);
    });

/// An empty browser tab for a kept file (overridden in tests).
final outboundTabOpenerProvider = Provider<HtmlTab? Function()>((_) => openHtmlTab);

/// Where a kept file is saved (overridden in tests).
final outboundFileSaverProvider =
    Provider<Future<void> Function(String name, Uint8List bytes)>((_) => (n, b) async => saveBytes(n, b));

final _money = NumberFormat('#,##0.##');
String outboundMoney(double? v) => v == null ? '' : _money.format(v);
String outboundKg(double g) => NumberFormat('#,##0.###').format(g / 1000);

/// 出荷リストで出庫 (0188): the shipping list people already keep, read as it
/// is and taken out of stock — and, on the other tab, every list shipped,
/// by day, with its file (出庫カレンダー).
///
/// [proxy] (代理出荷, 0189): the same list, or rows typed in, kept as a
/// record only — no stock moves, the products need not be in the library.
class OutboundFileScreen extends StatelessWidget {
  const OutboundFileScreen({super.key, this.initialTab = 0, this.proxy = false});

  final int initialTab;
  final bool proxy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(proxy ? l10n.prTitle : l10n.ofTitle),
          bottom: TabBar(tabs: [
            Tab(key: const ValueKey('of-tab-import'), text: proxy ? l10n.prTabRecord : l10n.ofTabImport),
            Tab(key: const ValueKey('of-tab-calendar'), text: proxy ? l10n.prTabList : l10n.ofTabCalendar),
          ]),
        ),
        body: TabBarView(children: [OutboundImportTab(proxy: proxy), OutboundCalendarTab(proxyOnly: proxy)]),
      ),
    );
  }
}

/// A row's state as a 代理出荷 shows it: in the library or not (no stock).
String proxyStatusLabel(AppLocalizations l10n, OutboundPlanLine l) => l.status == OutboundStatus.noQuantity
    ? l10n.ofStNoQty
    : (l.found ? l10n.prStInLibrary : l10n.prStNotInLibrary);

String outboundStatusLabel(AppLocalizations l10n, OutboundStatus s) => switch (s) {
      OutboundStatus.ok => l10n.ofStOk,
      OutboundStatus.short => l10n.ofStShort,
      OutboundStatus.unknownJan => l10n.ofStUnknownJan,
      OutboundStatus.noJan => l10n.ofStNoJan,
      OutboundStatus.several => l10n.ofStSeveral,
      OutboundStatus.noQuantity => l10n.ofStNoQty,
    };

String outboundActionLabel(AppLocalizations l10n, String action) => switch (action) {
      'ship' => l10n.ofActShip,
      'record' => l10n.ofActRecord,
      _ => l10n.ofActSkip,
    };

String outboundColumnLabel(AppLocalizations l10n, OutboundColumn c) => switch (c) {
      OutboundColumn.jan => l10n.ofRoleJan,
      OutboundColumn.quantity => l10n.ofRoleQuantity,
      OutboundColumn.code => l10n.ofRoleCode,
      OutboundColumn.maker => l10n.ofRoleMaker,
      OutboundColumn.name => l10n.ofRoleName,
      OutboundColumn.supplier => l10n.ofRoleSupplier,
      OutboundColumn.unitPrice => l10n.ofRoleUnitPrice,
      OutboundColumn.unitPriceTax => l10n.ofRoleUnitPriceTax,
      OutboundColumn.listPrice => l10n.ofRoleListPrice,
      OutboundColumn.amount => l10n.ofRoleAmount,
      OutboundColumn.taxRate => l10n.ofRoleTaxRate,
      OutboundColumn.orderNumber => l10n.ofRoleOrderNumber,
      OutboundColumn.arrival => l10n.ofRoleArrival,
      OutboundColumn.orderDate => l10n.ofRoleOrderDate,
    };

String outboundMatchedLabel(AppLocalizations l10n, OutboundMatchedBy by) => switch (by) {
      OutboundMatchedBy.jan => l10n.ofMatchedJan,
      OutboundMatchedBy.barcode => l10n.ofMatchedBarcode,
      OutboundMatchedBy.code => l10n.ofMatchedCode,
      OutboundMatchedBy.picked => l10n.ofMatchedPicked,
      _ => '',
    };

/// The tone of a row's state: what needs a look stands out.
Color outboundStatusColor(ColorScheme s, OutboundStatus st) => switch (st) {
      OutboundStatus.ok => s.primary,
      OutboundStatus.short || OutboundStatus.several => s.error,
      OutboundStatus.noQuantity => s.onSurfaceVariant,
      _ => s.tertiary,
    };

/// Reads a list, shows each row with what will be done, and ships it — or,
/// as a 代理出荷 ([proxy]), keeps it (and rows typed in) as a record.
class OutboundImportTab extends ConsumerStatefulWidget {
  const OutboundImportTab({super.key, this.proxy = false});

  final bool proxy;

  @override
  ConsumerState<OutboundImportTab> createState() => _OutboundImportTabState();
}

class _OutboundImportTabState extends ConsumerState<OutboundImportTab> {
  final _destination = TextEditingController();
  final _note = TextEditingController();
  final _principal = TextEditingController();
  ({String name, Uint8List bytes})? _file;

  /// The 出荷先カード chosen (0190): its name fills 出荷先.
  ShipDestination? _card;

  /// 代理出荷's rows typed in, after the file's.
  final List<OutboundRow> _manual = [];
  List<XlsxSheetRows> _sheets = const [];
  int _sheet = 0;
  Map<OutboundColumn, int>? _columns;
  OutboundSheet? _parsed;
  List<OutboundMatch> _matches = const [];
  bool _matching = false;
  String? _matchError;
  final Map<int, OutboundMatch> _picked = {};
  final Map<int, OutboundAction> _chosen = {};
  DateTime _shippedOn = DateTime.now();

  /// 出庫予定 (0191): registered for a day, shipped when the warehouse
  /// confirms it — the usual way from 出荷手配; else out of stock now.
  bool _planMode = true;

  bool get _planning => _planMode && !_proxy;
  OutboundStatus? _filter;
  int _limit = 100;
  bool _busy = false;
  String? _busyText;

  @override
  void dispose() {
    _destination.dispose();
    _note.dispose();
    _principal.dispose();
    super.dispose();
  }

  bool get _proxy => widget.proxy;

  /// The rows to post: the file's (when it can be read) and those typed in.
  List<OutboundRow> get _rows => [if (_parsed?.usable ?? false) ..._parsed!.rows, ..._manual];

  /// Typed-in rows numbered after the file's.
  void _renumber() {
    var n = [for (final r in (_parsed?.usable ?? false) ? _parsed!.rows : const <OutboundRow>[]) r.rowNo]
        .fold(0, (a, b) => a > b ? a : b);
    for (var i = 0; i < _manual.length; i++) {
      final r = _manual[i];
      _manual[i] = OutboundRow(
        rowNo: ++n,
        jan: r.jan,
        janRaw: r.janRaw,
        quantity: r.quantity,
        code: r.code,
        maker: r.maker,
        name: r.name,
        unitPriceTax: r.unitPriceTax,
        raw: r.raw,
      );
    }
  }

  Future<void> _pickCard() async {
    final d = await pickDestinationCard(context);
    if (d == null || !mounted) return;
    setState(() {
      _card = d;
      _destination.text = d.name;
    });
  }

  Future<void> _addRow() async {
    final row = await showDialog<OutboundRow>(context: context, builder: (_) => const _ManualRowDialog());
    if (row == null || !mounted) return;
    setState(() {
      _manual.add(row);
      _picked.clear();
      _chosen.clear();
      _renumber();
    });
    await _match();
  }

  Future<void> _removeRow(OutboundPlanLine l) async {
    setState(() {
      _manual.removeWhere((r) => r.rowNo == l.row.rowNo);
      _picked.clear();
      _chosen.clear();
      _renumber();
    });
    await _match();
  }

  void _snack(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
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
      _chosen.clear();
      _filter = null;
      _limit = 100;
    });
    await _read();
  }

  Future<void> _read() async {
    if (_sheets.isEmpty) return;
    final s = _sheets[_sheet];
    final parsed = parseOutboundSheet(s.name, s.rows, columns: _columns);
    setState(() {
      _parsed = parsed;
      _columns ??= Map.of(parsed.columns);
      _matches = const [];
      _matchError = null;
      _renumber();
    });
    await _match();
  }

  Future<void> _match() async {
    final rows = _rows;
    final warehouseId = ref.read(writeWarehouseIdProvider);
    if (rows.isEmpty || warehouseId == null) {
      setState(() => _matches = const []);
      return;
    }
    setState(() => _matching = true);
    final r = await ref.read(outboundFileRepositoryProvider).match([
      for (final row in rows) {'jan': row.jan.isEmpty ? null : row.jan, 'code': row.code, 'maker': row.maker},
    ], warehouseId);
    if (!mounted) return;
    setState(() {
      _matching = false;
      switch (r) {
        case ApiSuccess(:final data):
          _matches = data;
        case ApiFailure(:final message):
          _matchError = humanizeApiErrorMessage(AppLocalizations.of(context), message);
      }
    });
  }

  List<OutboundPlanLine> get _plan => planOutbound(_rows, _matches, picked: _picked, chosen: _chosen, proxy: _proxy);

  Future<void> _pickProduct(OutboundPlanLine line) async {
    final warehouseId = ref.read(writeWarehouseIdProvider);
    final p = await showDialog<Product>(
      context: context,
      builder: (_) => _PickProductDialog(rowNo: line.row.rowNo, initial: line.row.code ?? line.row.name ?? ''),
    );
    if (p == null || !mounted) return;
    setState(() {
      _picked[line.row.rowNo] = OutboundMatch(
        matchedBy: OutboundMatchedBy.picked,
        productId: p.id,
        jan: p.janCode,
        name: p.name,
        maker: p.maker,
        sku: p.sku,
        unitWeightG: p.unitWeightG,
        onHand: adjustOnHand(p, warehouseId),
      );
      _chosen.remove(line.row.rowNo);
    });
  }

  Future<void> _post() async {
    final l10n = AppLocalizations.of(context);
    final warehouseId = ref.read(writeWarehouseIdProvider);
    final file = _file;
    final parsed = _parsed;
    if (warehouseId == null) {
      _snack(l10n.adjNeedsWarehouse);
      return;
    }
    if (file == null && _manual.isEmpty) return;
    final plan = _plan;
    final t = OutboundPlanTotals.of(plan);
    if (t.ship + t.record == 0) {
      _snack(l10n.ofErrNoLines);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(_proxy ? l10n.prPostConfirmTitle : (_planning ? l10n.ofPostPlan : l10n.ofPostConfirmTitle)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_proxy
              ? l10n.prPostConfirmBody(t.record, _recordedQty(plan))
              : _planning
                  ? l10n.ofPlanConfirmBody(t.ship + t.record, _recordedQty(plan), DateFormat('y/MM/dd').format(_shippedOn))
                  : l10n.ofPostConfirmBody(t.ship, t.shipped, t.record, t.skip)),
          if (t.short > 0 && !_planning) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.ofPostShortWarn(t.shortRows, t.short), style: TextStyle(color: Theme.of(c).colorScheme.error)),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.actionCancel)),
          FilledButton(
              key: const ValueKey('of-post-ok'),
              onPressed: () => Navigator.pop(c, true),
              child: Text(_proxy ? l10n.prPost : (_planning ? l10n.ofPostPlan : l10n.ofPost))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _busyText = l10n.ofUploading;
    });
    final repo = ref.read(outboundFileRepositoryProvider);
    String? path;
    if (file != null) {
      final up = await repo.upload(warehouseId, file.name, file.bytes);
      if (!mounted) return;
      switch (up) {
        case ApiSuccess(:final data):
          path = data;
        case ApiFailure(:final message):
          setState(() => _busy = false);
          _snack(humanizeApiErrorMessage(l10n, message));
          return;
      }
    }
    String? text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    Future<ApiResult<int>> send(bool again) => repo.post(
          warehouseId: warehouseId,
          shippedOn: _shippedOn,
          fileName: file?.name ?? l10n.prManualName,
          lines: [for (final l in plan) l.toPost()],
          storagePath: path,
          byteSize: file?.bytes.length,
          fingerprint: file == null ? null : fileFingerprint(file.bytes),
          sheetName: parsed?.sheetName,
          destination: text(_destination),
          note: text(_note),
          columns: parsed?.columnsWire,
          allowDuplicate: again,
          proxy: _proxy,
          principal: _proxy ? text(_principal) : null,
          plan: _planning,
        );
    var r = await send(false);
    if (!mounted) return;
    if (r case ApiFailure(:final message) when message.contains('outbound_duplicate')) {
      setState(() => _busy = false);
      final again = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          content: Text(l10n.ofDuplicateQ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.actionCancel)),
            FilledButton(
                key: const ValueKey('of-dup-again'), onPressed: () => Navigator.pop(c, true), child: Text(l10n.ofDuplicateAgain)),
          ],
        ),
      );
      if (!mounted) return;
      if (again != true) return;
      setState(() => _busy = true);
      r = await send(true);
      if (!mounted) return;
    }
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess(:final data):
        final card = _card;
        if (card?.id != null) {
          final set = await repo.setDestination(data, card!.id);
          if (set case ApiFailure(:final message)) _snack(humanizeApiErrorMessage(l10n, message));
        }
        if (!mounted) return;
        ref.invalidate(outboundFilesProvider);
        ref.invalidate(productListProvider);
        ref.invalidate(adjustProductsProvider);
        _snack(_proxy
            ? l10n.prPostDone(t.record)
            : _planning
                ? l10n.ofPlanDone(DateFormat('y/MM/dd').format(_shippedOn))
                : l10n.ofPostDone(t.shipped));
        setState(() {
          _file = null;
          _sheets = const [];
          _parsed = null;
          _matches = const [];
          _manual.clear();
          _picked.clear();
          _chosen.clear();
          _destination.clear();
          _note.clear();
          _principal.clear();
          _card = null;
        });
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => OutboundFileDetailScreen(fileId: data)));
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  int _recordedQty(List<OutboundPlanLine> plan) =>
      plan.fold(0, (a, l) => a + (l.action == OutboundAction.skip ? 0 : (l.row.quantity ?? 0)));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final parsed = _parsed;
    final hasRows = _rows.isNotEmpty;
    final plan = _plan;
    final totals = OutboundPlanTotals.of(plan);
    final shown = [for (final l in plan) if (_filter == null || l.status == _filter) l];
    final noWarehouse = ref.watch(writeWarehouseIdProvider) == null;

    return Column(children: [
      Expanded(
        child: ListView(
          key: const ValueKey('of-import-list'),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_proxy ? l10n.prIntro : l10n.ofIntro, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    FilledButton.icon(
                      key: const ValueKey('of-pick'),
                      onPressed: _busy ? null : _pick,
                      icon: const Icon(Icons.upload_file_outlined),
                      label: Text(_file == null ? l10n.ofPick : l10n.ofPickAgain),
                    ),
                    if (_proxy)
                      OutlinedButton.icon(
                        key: const ValueKey('pr-add-row'),
                        onPressed: _busy ? null : _addRow,
                        icon: const Icon(Icons.add),
                        label: Text(l10n.prAddRow),
                      ),
                    if (_file != null) Text(_file!.name, key: const ValueKey('of-file-name'), style: theme.textTheme.titleSmall),
                  ]),
                  if (noWarehouse) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(l10n.adjNeedsWarehouse, style: TextStyle(color: scheme.error)),
                  ],
                ]),
              ),
            ),
            if (parsed != null) ...[
              const SizedBox(height: AppSpacing.md),
              _sheetAndColumns(l10n, parsed, muted),
              if (!parsed.usable) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.ofNotUsable, key: const ValueKey('of-not-usable'), style: TextStyle(color: scheme.error)),
              ],
            ],
            if (parsed != null || hasRows) ...[
              const SizedBox(height: AppSpacing.md),
              _settings(l10n),
              const SizedBox(height: AppSpacing.md),
              if (!hasRows)
                const SizedBox.shrink()
              else if (_matching)
                Row(children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: AppSpacing.sm),
                  Text(l10n.ofMatching),
                ])
              else if (_matchError != null)
                Text(_matchError!, style: TextStyle(color: scheme.error))
              else ...[
                if (_proxy)
                  Text(l10n.prSummary(totals.rows, totals.record, totals.skip, _recordedQty(plan)),
                      key: const ValueKey('of-summary'), style: theme.textTheme.titleSmall)
                else ...[
                  _summary(l10n, totals),
                  const SizedBox(height: AppSpacing.sm),
                  _filters(l10n, totals),
                  const SizedBox(height: AppSpacing.sm),
                  _help(l10n),
                ],
                const SizedBox(height: AppSpacing.sm),
                _OutboundPlanTable(
                  lines: shown.take(_limit).toList(),
                  proxy: _proxy,
                  manual: {for (final r in _manual) r.rowNo},
                  onAction: (l, a) => setState(() => _chosen[l.row.rowNo] = a),
                  onPick: _pickProduct,
                  onRemove: _removeRow,
                ),
                if (shown.length > _limit)
                  TextButton(
                    key: const ValueKey('of-more'),
                    onPressed: () => setState(() => _limit += 200),
                    child: Text(l10n.ppMore(shown.length - _limit)),
                  ),
              ],
            ],
          ],
        ),
      ),
      if (hasRows && !_matching && _matchError == null)
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: scheme.outlineVariant))),
            child: Row(children: [
              Expanded(
                child: Text(
                  _proxy
                      ? l10n.prSummary(totals.rows, totals.record, totals.skip, _recordedQty(plan))
                      : [
                          l10n.ofSummaryShip(totals.shipped),
                          if (totals.short > 0) l10n.ofSummaryShort(totals.short, totals.shortRows),
                        ].join(' · '),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              if (_busy) ...[
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: AppSpacing.sm),
                if (_busyText != null) Text(_busyText!, style: muted),
              ] else
                FilledButton.icon(
                  key: const ValueKey('of-post'),
                  onPressed: noWarehouse ? null : _post,
                  icon: Icon(_proxy
                      ? Icons.edit_note_outlined
                      : (_planning ? Icons.event_available_outlined : Icons.outbox_outlined)),
                  label: Text(_proxy ? l10n.prPost : (_planning ? l10n.ofPostPlan : l10n.ofPost)),
                ),
            ]),
          ),
        ),
    ]);
  }

  Widget _sheetAndColumns(AppLocalizations l10n, OutboundSheet parsed, TextStyle? muted) {
    final headings = parsed.headings;
    final width = [for (final r in _sheets[_sheet].rows.take(30)) r.length].fold(headings.length, (a, b) => a > b ? a : b);
    String colName(int i) => i < headings.length && headings[i].trim().isNotEmpty
        ? '${columnLetters(i)}: ${headings[i].trim()}'
        : columnLetters(i);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (_sheets.length > 1)
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<int>(
                  key: ValueKey('of-sheet-$_sheet'),
                  initialValue: _sheet,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.ofSheet, isDense: true),
                  items: [
                    for (final (i, s) in _sheets.indexed)
                      DropdownMenuItem(value: i, child: Text(s.name, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _sheet = v;
                      _columns = null;
                      _picked.clear();
                      _chosen.clear();
                    });
                    _read();
                  },
                ),
              ),
            if (parsed.headerRow >= 0) Text(l10n.ofHeaderRow(parsed.headerRow + 1), style: muted),
            if (parsed.janGuessed) Text(l10n.ofJanGuessed, key: const ValueKey('of-jan-guessed'), style: muted),
          ]),
          ExpansionTile(
            key: const ValueKey('of-columns'),
            tilePadding: EdgeInsets.zero,
            title: Text(l10n.ofColumns),
            subtitle: Text(
              [
                for (final c in OutboundColumn.values)
                  if (parsed.columns[c] != null) '${outboundColumnLabel(l10n, c)}=${colName(parsed.columns[c]!)}',
              ].join('  '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: muted,
            ),
            children: [
              Align(alignment: Alignment.centerLeft, child: Text(l10n.ofColumnsHint, style: muted)),
              const SizedBox(height: AppSpacing.sm),
              Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.sm, children: [
                for (final c in OutboundColumn.values)
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<int>(
                      key: ValueKey('of-col-${c.wire}-${parsed.columns[c] ?? -1}'),
                      initialValue: parsed.columns[c] ?? -1,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: outboundColumnLabel(l10n, c), isDense: true),
                      items: [
                        DropdownMenuItem(value: -1, child: Text(l10n.ofColNone)),
                        for (var i = 0; i < width; i++)
                          DropdownMenuItem(value: i, child: Text(colName(i), overflow: TextOverflow.ellipsis)),
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
                          _chosen.clear();
                        });
                        _read();
                      },
                    ),
                  ),
              ]),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _settings(AppLocalizations l10n) => Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (!_proxy)
            SegmentedButton<bool>(
              key: const ValueKey('of-mode'),
              segments: [
                ButtonSegment(
                    value: true, icon: const Icon(Icons.event_available_outlined), label: Text(l10n.ofModePlan)),
                ButtonSegment(value: false, icon: const Icon(Icons.outbox_outlined), label: Text(l10n.ofModeNow)),
              ],
              selected: {_planMode},
              onSelectionChanged: (v) => setState(() => _planMode = v.first),
            ),
          OutlinedButton.icon(
            key: const ValueKey('of-shipped-on'),
            icon: const Icon(Icons.event_outlined, size: 18),
            label: Text('${_planning ? l10n.ofPlannedOn : l10n.ofShippedOn}: ${DateFormat('y/MM/dd').format(_shippedOn)}'),
            onPressed: () async {
              final d = await showDatePicker(
                  context: context, initialDate: _shippedOn, firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (d != null) setState(() => _shippedOn = d);
            },
          ),
          if (_proxy)
            SizedBox(
              width: 220,
              child: TextField(
                key: const ValueKey('pr-principal'),
                controller: _principal,
                decoration: InputDecoration(labelText: l10n.prPrincipal, isDense: true),
              ),
            ),
          if (_card == null)
            OutlinedButton.icon(
              key: const ValueKey('of-pick-card'),
              icon: const Icon(Icons.contact_mail_outlined, size: 18),
              label: Text(l10n.ofPickCard),
              onPressed: _pickCard,
            )
          else
            InputChip(
              key: const ValueKey('of-card'),
              avatar: const Icon(Icons.contact_mail_outlined, size: 18),
              label: Text(l10n.ofCardChosen(_card!.name)),
              onPressed: _pickCard,
              onDeleted: () => setState(() => _card = null),
              deleteButtonTooltipMessage: l10n.ofCardClear,
            ),
          SizedBox(
            width: 220,
            child: TextField(
              key: const ValueKey('of-destination'),
              controller: _destination,
              decoration: InputDecoration(labelText: l10n.ofDestination, isDense: true),
            ),
          ),
          SizedBox(
            width: 260,
            child: TextField(
              key: const ValueKey('of-note'),
              controller: _note,
              decoration: InputDecoration(labelText: l10n.ofNote, isDense: true),
            ),
          ),
          if (_planning)
            Text(l10n.ofModePlanHint,
                key: const ValueKey('of-plan-hint'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      );

  Widget _summary(AppLocalizations l10n, OutboundPlanTotals t) {
    final theme = Theme.of(context);
    return Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.xs, children: [
      Text(l10n.ofSummary(t.rows, t.ship, t.record, t.skip), key: const ValueKey('of-summary'), style: theme.textTheme.titleSmall),
      Text(l10n.ofSummaryShip(t.shipped)),
      if (t.short > 0)
        Text(l10n.ofSummaryShort(t.short, t.shortRows),
            key: const ValueKey('of-summary-short'), style: TextStyle(color: theme.colorScheme.error)),
      if (t.amount > 0) Text(l10n.ofSummaryAmount(outboundMoney(t.amount))),
      if (t.weightG > 0) Text(l10n.ofSummaryWeight(outboundKg(t.weightG))),
    ]);
  }

  Widget _filters(AppLocalizations l10n, OutboundPlanTotals t) => Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
        ChoiceChip(
          key: const ValueKey('of-filter-all'),
          label: Text(l10n.ofFilterAll(t.rows)),
          selected: _filter == null,
          onSelected: (_) => setState(() {
            _filter = null;
            _limit = 100;
          }),
        ),
        for (final s in OutboundStatus.values)
          if ((t.byStatus[s] ?? 0) > 0)
            ChoiceChip(
              key: ValueKey('of-filter-${s.name}'),
              label: Text('${outboundStatusLabel(l10n, s)} ${t.byStatus[s]}'),
              selected: _filter == s,
              onSelected: (_) => setState(() {
                _filter = _filter == s ? null : s;
                _limit = 100;
              }),
            ),
      ]);

  Widget _help(AppLocalizations l10n) {
    final style = Theme.of(context).textTheme.bodySmall;
    return ExpansionTile(
      key: const ValueKey('of-help'),
      tilePadding: EdgeInsets.zero,
      leading: const Icon(Icons.help_outline),
      title: Text(l10n.ofHelpTitle),
      childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
      children: [
        for (final t in [l10n.ofHelpNoJan, l10n.ofHelpUnknown, l10n.ofHelpShort, l10n.ofHelpSeveral])
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Align(alignment: Alignment.centerLeft, child: Text('・$t', style: style)),
          ),
      ],
    );
  }
}

/// The rows across, as in the 発注 table: what each is, what will be done,
/// its product, codes, quantity, stock, what goes out and is short, prices,
/// weight.
class _OutboundPlanTable extends StatefulWidget {
  const _OutboundPlanTable({
    required this.lines,
    required this.onAction,
    required this.onPick,
    this.proxy = false,
    this.manual = const {},
    this.onRemove,
  });

  final List<OutboundPlanLine> lines;
  final void Function(OutboundPlanLine, OutboundAction) onAction;
  final void Function(OutboundPlanLine) onPick;

  /// 代理出荷: no stock columns, no shipping.
  final bool proxy;

  /// The rows typed in (by row number): these can be removed.
  final Set<int> manual;
  final void Function(OutboundPlanLine)? onRemove;

  @override
  State<_OutboundPlanTable> createState() => _OutboundPlanTableState();
}

class _OutboundPlanTableState extends State<_OutboundPlanTable> {
  final _across = ScrollController();

  static const _widths = [52.0, 104.0, 118.0, 250.0, 128.0, 128.0, 96.0, 104.0, 72.0, 72.0, 72.0, 64.0, 80.0, 80.0, 100.0, 112.0, 84.0, 96.0];

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
    // 代理出荷: no stock, nothing taken out, nothing short.
    final hidden = widget.proxy ? const {9, 10, 11} : const <int>{};
    Widget cell(int i, Widget child, {bool end = false}) => hidden.contains(i)
        ? const SizedBox.shrink()
        : Container(
            width: _widths[i],
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            alignment: end ? Alignment.centerRight : Alignment.centerLeft,
            child: child,
          );
    final headers = [
      l10n.ofColRow, l10n.ofColStatus, l10n.ofColAction, l10n.ofColProduct, l10n.ofRoleJan, l10n.ofRoleCode,
      l10n.ofRoleMaker, l10n.ofRoleSupplier, l10n.ofRoleQuantity, l10n.ofColStock, l10n.ofColShip, l10n.ofColShort,
      l10n.ofColPriceEx, l10n.ofColPriceTax, l10n.ofRoleAmount, l10n.ofColLastPrice, l10n.ofColWeight, l10n.ofRoleOrderNumber,
    ];
    const ends = {8, 9, 10, 11, 12, 13, 14, 15, 16};
    return Scrollbar(
      controller: _across,
      thumbVisibility: true,
      child: SingleChildScrollView(
        key: const ValueKey('of-table'),
        controller: _across,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            color: scheme.surfaceContainerHighest,
            child: Row(children: [for (final (i, h) in headers.indexed) cell(i, Text(h, style: head), end: ends.contains(i))]),
          ),
          for (final l in widget.lines)
            Container(
              key: ValueKey('of-row-${l.row.rowNo}'),
              decoration: BoxDecoration(
                color: l.action == OutboundAction.skip ? scheme.surfaceContainerLow : null,
                border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
              ),
              child: Row(children: [
                cell(
                  0,
                  widget.manual.contains(l.row.rowNo)
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('${l.row.rowNo}', style: small),
                          InkWell(
                            key: ValueKey('pr-remove-${l.row.rowNo}'),
                            onTap: () => widget.onRemove?.call(l),
                            child: Tooltip(
                              message: l10n.prRemoveRow,
                              child: Icon(Icons.close, size: 16, color: scheme.error),
                            ),
                          ),
                        ])
                      : Text('${l.row.rowNo}', style: small),
                ),
                cell(
                  1,
                  Text(widget.proxy ? proxyStatusLabel(l10n, l) : outboundStatusLabel(l10n, l.status),
                      key: ValueKey('of-status-${l.row.rowNo}'),
                      style: small?.copyWith(
                          color: widget.proxy
                              ? (l.found ? scheme.primary : scheme.onSurfaceVariant)
                              : outboundStatusColor(scheme, l.status),
                          fontWeight: FontWeight.w600)),
                ),
                cell(
                  2,
                  PopupMenuButton<OutboundAction>(
                    key: ValueKey('of-action-${l.row.rowNo}'),
                    onSelected: (a) => widget.onAction(l, a),
                    itemBuilder: (_) => [
                      for (final a in OutboundAction.values)
                        if (a != OutboundAction.ship || (l.found && !widget.proxy))
                          PopupMenuItem(
                            key: ValueKey('of-action-${l.row.rowNo}-${a.wire}'),
                            value: a,
                            child: Text(outboundActionLabel(l10n, a.wire)),
                          ),
                    ],
                    child: Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(outboundActionLabel(l10n, l.action.wire), style: small),
                      avatar: Icon(
                        switch (l.action) {
                          OutboundAction.ship => Icons.outbox_outlined,
                          OutboundAction.record => Icons.edit_note_outlined,
                          OutboundAction.skip => Icons.block_outlined,
                        },
                        size: 16,
                      ),
                    ),
                  ),
                ),
                cell(
                  3,
                  Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    if (l.match.name != null)
                      Text(l.match.name!, key: ValueKey('of-name-${l.row.rowNo}'), maxLines: 2, overflow: TextOverflow.ellipsis)
                    else if (l.row.name != null)
                      Text(l.row.name!, maxLines: 2, overflow: TextOverflow.ellipsis, style: small),
                    if (l.found && l.match.matchedBy != OutboundMatchedBy.jan)
                      Text(outboundMatchedLabel(l10n, l.match.matchedBy), style: small?.copyWith(color: scheme.onSurfaceVariant)),
                    if ((!l.found && l.status != OutboundStatus.noQuantity) || l.match.matchedBy == OutboundMatchedBy.picked)
                      TextButton.icon(
                        key: ValueKey('of-pick-${l.row.rowNo}'),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                        onPressed: () => widget.onPick(l),
                        icon: const Icon(Icons.search, size: 16),
                        label: Text(l10n.ofPickProduct),
                      ),
                  ]),
                ),
                cell(
                  4,
                  Text(l.match.jan ?? (l.row.jan.isNotEmpty ? l.row.jan : l.row.janRaw),
                      style: small?.copyWith(color: l.row.janInvalid ? scheme.error : null)),
                ),
                cell(5, Text(l.row.code ?? l.match.sku ?? '', style: small, maxLines: 2, overflow: TextOverflow.ellipsis)),
                cell(6, Text(l.row.maker ?? l.match.maker ?? '', style: small, maxLines: 1, overflow: TextOverflow.ellipsis)),
                cell(7, Text(l.row.supplier ?? '', style: small, maxLines: 1, overflow: TextOverflow.ellipsis)),
                cell(8, Text('${l.row.quantity ?? ''}', style: theme.textTheme.titleSmall), end: true),
                cell(9, Text(l.stockBefore == null ? '—' : '${l.stockBefore}', style: small), end: true),
                cell(
                  10,
                  Text(l.action == OutboundAction.ship ? '${l.shipped}' : '—',
                      key: ValueKey('of-ship-${l.row.rowNo}'), style: theme.textTheme.titleSmall),
                  end: true,
                ),
                cell(
                  11,
                  Text(l.short > 0 ? '${l.short}' : '',
                      key: ValueKey('of-short-${l.row.rowNo}'), style: small?.copyWith(color: scheme.error, fontWeight: FontWeight.w700)),
                  end: true,
                ),
                cell(12, Text(outboundMoney(l.row.priceEx), style: small), end: true),
                cell(13, Text(outboundMoney(l.row.priceTax), style: small), end: true),
                cell(14, Text(outboundMoney(l.row.total), style: small), end: true),
                cell(
                  15,
                  Text(outboundMoney(l.match.lastPrice),
                      style: small?.copyWith(
                          color: l.match.lastPrice != null && l.row.priceEx != null && (l.row.priceEx! - l.match.lastPrice!).abs() > 0.009
                              ? scheme.tertiary
                              : null)),
                  end: true,
                ),
                cell(16, Text(l.weightG == null ? '' : '${outboundKg(l.weightG!)} kg', style: small), end: true),
                cell(17, Text(l.row.orderNumber ?? '', style: small, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ),
        ]),
      ),
    );
  }
}

/// A product chosen for a row by hand: found by its name, maker, JAN or 品番.
class _PickProductDialog extends ConsumerStatefulWidget {
  const _PickProductDialog({required this.rowNo, required this.initial});

  final int rowNo;
  final String initial;

  @override
  ConsumerState<_PickProductDialog> createState() => _PickProductDialogState();
}

class _PickProductDialogState extends ConsumerState<_PickProductDialog> {
  late final _search = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final warehouseId = ref.watch(writeWarehouseIdProvider);
    final all = ref.watch(adjustProductsProvider).valueOrNull ?? const <Product>[];
    final shown = [for (final p in all) if (adjustProductMatches(p, _search.text)) p].take(50).toList();
    return AlertDialog(
      key: const ValueKey('of-pick-dialog'),
      title: Text(l10n.ofPickProductTitle(widget.rowNo)),
      content: SizedBox(
        width: 460,
        height: 420,
        child: Column(children: [
          TextField(
            key: const ValueKey('of-pick-search'),
            controller: _search,
            autofocus: true,
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.ofPickSearch),
            onChanged: (_) => setState(() {}),
          ),
          Expanded(
            child: ListView(children: [
              for (final p in shown)
                ListTile(
                  key: ValueKey('of-pick-${p.janCode}'),
                  dense: true,
                  title: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text([p.maker ?? '', p.janCode, p.sku ?? ''].where((s) => s.isNotEmpty).join(' · ')),
                  trailing: Text(l10n.adjOnHand(adjustOnHand(p, warehouseId))),
                  onTap: () => Navigator.pop(context, p),
                ),
            ]),
          ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel))],
    );
  }
}

/// A 代理出荷 row typed in: what it is (a name, JAN or 品番), how many, at
/// what price.
class _ManualRowDialog extends StatefulWidget {
  const _ManualRowDialog();

  @override
  State<_ManualRowDialog> createState() => _ManualRowDialogState();
}

class _ManualRowDialogState extends State<_ManualRowDialog> {
  final _name = TextEditingController();
  final _jan = TextEditingController();
  final _code = TextEditingController();
  final _maker = TextEditingController();
  final _qty = TextEditingController();
  final _price = TextEditingController();
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _jan, _code, _maker, _qty, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  void _add() {
    final l10n = AppLocalizations.of(context);
    String? t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final qty = int.tryParse(_qty.text.trim());
    if (t(_name) == null && t(_jan) == null && t(_code) == null) {
      setState(() => _error = l10n.prErrWhat);
      return;
    }
    if (qty == null || qty <= 0) {
      setState(() => _error = l10n.prErrQty);
      return;
    }
    final price = double.tryParse(_price.text.trim().replaceAll(',', ''));
    Navigator.pop(
      context,
      OutboundRow(
        rowNo: 0,
        jan: normalizeOutboundJan(_jan.text),
        janRaw: _jan.text.trim(),
        quantity: qty,
        code: t(_code),
        maker: t(_maker),
        name: t(_name),
        unitPriceTax: price,
        raw: {
          for (final (k, c) in [(l10n.prName, _name), (l10n.ofRoleJan, _jan), (l10n.ofRoleCode, _code), (l10n.ofRoleMaker, _maker)])
            if (t(c) != null) k: t(c)!,
          l10n.ofRoleQuantity: '$qty',
          if (price != null) l10n.ofRoleUnitPriceTax: _price.text.trim(),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget field(String key, TextEditingController c, String label, {TextInputType? type}) => TextField(
          key: ValueKey(key),
          controller: c,
          keyboardType: type,
          decoration: InputDecoration(labelText: label),
        );
    return AlertDialog(
      key: const ValueKey('pr-row-dialog'),
      title: Text(l10n.prAddRowTitle),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            field('pr-row-name', _name, l10n.prName),
            field('pr-row-jan', _jan, l10n.ofRoleJan, type: TextInputType.number),
            field('pr-row-code', _code, l10n.ofRoleCode),
            field('pr-row-maker', _maker, l10n.ofRoleMaker),
            field('pr-row-qty', _qty, l10n.ofRoleQuantity, type: TextInputType.number),
            field('pr-row-price', _price, l10n.ofRoleUnitPriceTax, type: const TextInputType.numberWithOptions(decimal: true)),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(key: const ValueKey('pr-row-add'), onPressed: _add, child: Text(l10n.prAddRow)),
      ],
    );
  }
}
