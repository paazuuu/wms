import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/export/save_bytes.dart';
import '../../../core/export/xlsx.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/open_window.dart';
import '../../../l10n/app_localizations.dart';
import '../../product/application/product_providers.dart';
import '../../product/domain/product.dart';
import '../../master_import/data/master_import_repository.dart';
import '../../master_import/domain/master_import.dart' show MasterProblem;
import '../../master_import/presentation/master_import_labels.dart' show masterProblemText;
import '../../stock_import/domain/ai_read_sheet.dart';
import '../../stock_import/domain/stock_file.dart' show fileFingerprint, readStockFile;
import '../../stock_import/presentation/import_view_screen.dart' show OriginalFileView;
import '../../stock_ops/presentation/stock_adjustment_screen.dart'
    show adjustOnHand, adjustProductMatches, adjustProductsProvider;
import '../../outbound/domain/outbound.dart' show ShipDestination;
import '../../outbound/presentation/ship_destinations_screen.dart' show pickDestinationCard;
import '../../warehouse_context/application/warehouse_providers.dart';
import '../../warehouse_context/domain/warehouse.dart' show Warehouse;
import '../data/outbound_file_repository.dart';
import '../data/inbound_proposal_export.dart';
import '../data/outbound_plan_export.dart';
import '../domain/outbound_currency.dart';
import '../domain/outbound_plan.dart';
import '../domain/outbound_sheet.dart';
import 'outbound_calendar_tab.dart';
import 'outbound_file_detail_screen.dart';
import '../../../core/ui/edit_drawer.dart';

/// The shipping list chosen to read (overridden in tests).
final outboundFilePickerProvider = Provider<Future<({String name, Uint8List bytes})?> Function()>((_) => () async {
      final r = await FilePicker.platform
          .pickFiles(withData: true, type: FileType.custom, allowedExtensions: const [
            'xlsx', 'xlsm', 'csv', 'tsv', 'txt', 'pdf', 'png', 'jpg', 'jpeg', 'webp',
          ]);
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

/// What is kept of [p] in the warehouse (出庫予定 and orders, 0201): the
/// library's 引当.
int keptOf(Product p, int? warehouseId) {
  final stock = p.stock;
  if (stock == null) return 0;
  if (warehouseId == null) return stock.reserved;
  for (final w in stock.warehouses) {
    if (w.warehouseId == warehouseId) return w.reserved;
  }
  return 0;
}

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

/// The tone of a row's state, by what it means: fine (green), short of
/// stock (red), needs a product or a choice (amber), nothing to ship (grey).
/// Blue stays for what can be pressed.
Color outboundStatusColor(ColorScheme s, OutboundStatus st) => switch (st) {
      OutboundStatus.ok => s.success,
      OutboundStatus.short => s.error,
      OutboundStatus.unknownJan || OutboundStatus.noJan || OutboundStatus.several => s.warning,
      OutboundStatus.noQuantity => s.onSurfaceVariant,
    };

/// Reads a list, shows each row with what will be done, and ships it — or,
/// as a 代理出荷 ([proxy]), keeps it (and rows typed in) as a record.
/// What a new file changes in a list (0202), by product: rows added, left
/// out, and those whose quantity changed.
typedef OutboundLinesDiff = ({
  List<({String name, int quantity})> added,
  List<({String name, int quantity})> removed,
  List<({String name, int from, int to})> changed,
});

OutboundLinesDiff outboundLinesDiff(List<OutboundFileLine> before, List<OutboundPlanLine> after) {
  String key(int? pid, String? jan, String? code, String? name) => pid != null
      ? 'p$pid'
      : (jan ?? '').isNotEmpty
          ? 'j$jan'
          : (code ?? '').isNotEmpty
              ? 'c${code!.toUpperCase()}'
              : 'n${name ?? ''}';
  final was = <String, int>{}, now = <String, int>{}, names = <String, String>{};
  for (final l in before) {
    if (l.action == 'skip') continue;
    final k = key(l.productId, l.jan, l.code, l.productName);
    was[k] = (was[k] ?? 0) + l.quantity;
    names.putIfAbsent(k, () => l.productName ?? l.code ?? l.jan ?? '?');
  }
  for (final l in after) {
    if (l.action == OutboundAction.skip) continue;
    final jan = l.row.jan.isNotEmpty ? l.row.jan : l.match.jan;
    final k = key(l.match.productId, jan, l.row.code, l.match.name ?? l.row.name);
    now[k] = (now[k] ?? 0) + (l.row.quantity ?? 0);
    names.putIfAbsent(k, () => l.match.name ?? l.row.name ?? l.row.code ?? jan ?? '?');
  }
  return (
    added: [for (final e in now.entries) if (!was.containsKey(e.key)) (name: names[e.key]!, quantity: e.value)],
    removed: [for (final e in was.entries) if (!now.containsKey(e.key)) (name: names[e.key]!, quantity: e.value)],
    changed: [
      for (final e in now.entries)
        if (was.containsKey(e.key) && was[e.key] != e.value) (name: names[e.key]!, from: was[e.key]!, to: e.value),
    ],
  );
}

/// ファイルで差し替える: the import read again for a list not shipped yet.
class OutboundReplaceScreen extends ConsumerWidget {
  const OutboundReplaceScreen({super.key, required this.fileId});

  final int fileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(outboundFileDetailProvider(fileId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.ofReplaceTitle)),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => ref.invalidate(outboundFileDetailProvider(fileId))),
        data: (d) => OutboundImportTab(replace: d.file, replaceLines: d.lines),
      ),
    );
  }
}

class OutboundImportTab extends ConsumerStatefulWidget {
  const OutboundImportTab({super.key, this.proxy = false, this.replace, this.replaceLines = const []});

  final bool proxy;

  /// A list not shipped yet whose rows a new file replaces (0202): its
  /// warehouse is kept, as are its 出荷先カード, day and gross weight.
  final OutboundFileSummary? replace;

  /// Its rows as they are, to show what the new file changes.
  final List<OutboundFileLine> replaceLines;

  @override
  ConsumerState<OutboundImportTab> createState() => _OutboundImportTabState();
}

class _OutboundImportTabState extends ConsumerState<OutboundImportTab> with AutomaticKeepAliveClientMixin {
  /// A list read here stays when another tab of 出荷手配 is opened and this
  /// one is come back to (TabBarView lets go of the tabs out of sight).
  @override
  bool get wantKeepAlive => true;

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

  /// Rows unticked in the table: left out (除外).
  final Set<int> _excluded = {};
  DateTime _shippedOn = DateTime.now();

  /// 出庫予定日 for a planned list: null is 未定 (0197), the day set later.
  DateTime? _plannedOn;

  String _planDayText(AppLocalizations l10n) =>
      _plannedOn == null ? l10n.ofUndecided : DateFormat('y/MM/dd').format(_plannedOn!);

  /// 出庫予定 (0191): registered for a day, shipped when the warehouse
  /// confirms it — the usual way from 出荷手配; else out of stock now.
  bool _planMode = true;

  bool get _planning => _planMode && !_proxy;

  /// The day may be 未定: a planned list (0197) or a 在庫外出荷 (0198).
  bool get _dayOpen => _planning || _proxy;
  OutboundStatus? _filter;

  /// Only the rows that need goods to come in (不足).
  bool _needOnly = false;
  bool _busy = false;
  String? _busyText;

  @override
  void dispose() {
    _destination.dispose();
    _note.dispose();
    _principal.dispose();
    _fx.dispose();
    super.dispose();
  }

  // Each row's price currency (0197): row number → currency and how it was
  // decided; the rate 1 元 in 円 if given.
  Map<int, RowCurrency> _currency = {};
  bool _judging = false;
  final _fx = TextEditingController();

  /// In which currency each priced row is written: as the headings say, else
  /// as the AI judges against what it was bought for (our own rule when the
  /// AI cannot be asked).
  Future<void> _judgeCurrency() async {
    final parsed = _parsed;
    final rows = _rows;
    final matches = _matches;
    final priced = [
      for (final (i, row) in rows.indexed)
        if (row.priceEx != null || row.priceTax != null) (row, i < matches.length ? matches[i] : OutboundMatch.none),
    ];
    if (priced.isEmpty) {
      setState(() => _currency = {});
      return;
    }
    final named = parsed == null ? null : currencyInHeadings(parsed.headings);
    if (named != null) {
      setState(() => _currency = {
            for (final (row, _) in priced) row.rowNo: (currency: named, source: CurrencySource.file, confident: true),
          });
      return;
    }
    setState(() => _judging = true);
    final r = await ref.read(priceCurrencyRepositoryProvider).judge([
      for (final (row, m) in priced)
        (
          i: row.rowNo,
          name: m.name ?? row.name,
          maker: row.maker,
          code: row.code,
          priceEx: row.priceEx,
          priceTax: row.priceTax,
          purchaseJpy: m.lastPrice,
        ),
    ], hint: parsed?.headings.where((h) => h.trim().isNotEmpty).join(' / '));
    if (!mounted) return;
    final ai = switch (r) {
      ApiSuccess(:final data) => data,
      ApiFailure() => const <int, (PriceCurrency, bool)>{},
    };
    setState(() {
      _judging = false;
      RowCurrency judged(OutboundRow row, OutboundMatch m) {
        final a = ai[row.rowNo];
        if (a != null) return (currency: a.$1, source: CurrencySource.ai, confident: a.$2);
        return (
          currency: priceLooksLikeCny(row.priceEx ?? row.priceTax, m.lastPrice) ? PriceCurrency.cny : PriceCurrency.jpy,
          source: CurrencySource.guess,
          confident: false,
        );
      }

      _currency = {for (final (row, m) in priced) row.rowNo: judged(row, m)};
    });
  }

  /// 価格の通貨: what the rows are in (円 69 · 元 3), and a menu to put them
  /// all in one; one row is changed by tapping its price.
  Widget _currencyButton(AppLocalizations l10n) {
    final counts = <PriceCurrency, int>{};
    for (final c in _currency.values) {
      counts[c.currency] = (counts[c.currency] ?? 0) + 1;
    }
    final what = counts.length == 1
        ? counts.keys.single.mark
        : [for (final c in PriceCurrency.values) if ((counts[c] ?? 0) > 0) '${c.mark} ${counts[c]}'].join(' · ');
    // Rows not in 円, or the AI unsure: the button asks for a look.
    final look = counts.keys.any((c) => c != PriceCurrency.jpy) || _currency.values.any((c) => !c.confident);
    final warn = Theme.of(context).colorScheme.warning;
    return OutlinedButton.icon(
      key: const ValueKey('of-currency-button'),
      style: look
          ? _dense.copyWith(
              foregroundColor: WidgetStatePropertyAll(warn), side: WidgetStatePropertyAll(BorderSide(color: warn)))
          : _dense,
      onPressed: _judging ? null : _openCurrency,
      icon: _judging
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.currency_exchange, size: 18),
      label: Text(_judging ? l10n.ofCurrencyJudging : l10n.ofCurrencyButton(what)),
    );
  }

  void _setCurrency(int rowNo, PriceCurrency c) =>
      setState(() => _currency[rowNo] = (currency: c, source: CurrencySource.manual, confident: true));

  void _setAllCurrency(PriceCurrency c) => setState(() => _currency = {
        for (final k in _currency.keys) k: (currency: c, source: CurrencySource.manual, confident: true),
      });

  bool get _proxy => widget.replace?.proxy ?? widget.proxy;

  bool get _replacing => widget.replace != null;

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
    final row = await showEditDrawer<OutboundRow>(context, builder: (_) => const _ManualRowDialog());
    if (row == null || !mounted) return;
    setState(() {
      _manual.add(row);
      _picked.clear();
      _chosen.clear();
      _excluded.clear();
      _renumber();
    });
    await _match();
  }

  Future<void> _removeRow(OutboundPlanLine l) async {
    setState(() {
      _manual.removeWhere((r) => r.rowNo == l.row.rowNo);
      _picked.clear();
      _chosen.clear();
      _excluded.clear();
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

  /// The file was a PDF or a photo, read by the AI (its rows made a sheet).
  bool _aiRead = false;
  bool _aiReading = false;

  /// A PDF or a photo: the AI reads its rows (import-plan, nothing booked),
  /// made into a sheet read as an Excel is.
  Future<List<XlsxSheetRows>?> _readByAi(({String name, Uint8List bytes}) f) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _aiReading = true);
    final r = await ref.read(masterImportRepositoryProvider).read(f.name, f.bytes, keepRows: true);
    if (!mounted) return null;
    setState(() => _aiReading = false);
    switch (r) {
      case ApiSuccess(:final data):
        if (data.lines.isEmpty) {
          _snack(l10n.rdAiFailed(data.aiFailure == null
              ? l10n.ofNotUsable
              : masterProblemText(l10n, MasterProblem('ai_unavailable', value: data.aiFailure))));
          return null;
        }
        return [aiReadAsSheet(data.lines)];
      case ApiFailure(:final message):
        _snack(l10n.rdAiFailed(humanizeApiErrorMessage(l10n, message)));
        return null;
    }
  }

  Future<void> _pick() async {
    final l10n = AppLocalizations.of(context);
    final f = await ref.read(outboundFilePickerProvider)();
    if (f == null || !mounted) return;
    List<XlsxSheetRows> sheets;
    final byAi = !readsAsSheet(f.name);
    if (byAi) {
      final read = await _readByAi(f);
      if (read == null || !mounted) return;
      sheets = read;
    } else {
      try {
        final lower = f.name.toLowerCase();
        sheets = lower.endsWith('.xlsx') || lower.endsWith('.xlsm')
            ? readXlsxSheets(f.bytes)
            : [(name: f.name, rows: readStockFile(f.name, f.bytes))];
      } on FormatException {
        _snack(l10n.ofReadFailed);
        return;
      }
    }
    setState(() {
      _aiRead = byAi;
      _file = f;
      _sheets = sheets;
      _sheet = pickOutboundSheet(sheets);
      _columns = null;
      _picked.clear();
      _chosen.clear();
      _excluded.clear();
      _filter = null;
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
    final warehouseId = _warehouseId;
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
    if (r is ApiSuccess) await _judgeCurrency();
  }

  /// The warehouse chosen here when the app's own is 「すべての倉庫」: a list
  /// is checked against one warehouse's stock and goes out of one.
  int? _warehouseHere;

  /// Where the list is checked and goes out: the app's warehouse, else the
  /// one chosen here.
  int? get _warehouseId => widget.replace?.warehouseId ?? ref.read(writeWarehouseIdProvider) ?? _warehouseHere;

  /// One warehouse chosen on this screen: the rows are checked against it.
  Widget _warehousePicker(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final warehouses = ref.watch(warehouseOverviewProvider).valueOrNull?.warehouses ?? const <Warehouse>[];
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.warehouse_outlined, size: 18, color: theme.colorScheme.warning),
      const SizedBox(width: AppSpacing.xs),
      Text(l10n.ofPickWarehouse, style: TextStyle(color: theme.colorScheme.warning, fontWeight: FontWeight.w600)),
      const SizedBox(width: AppSpacing.sm),
      DropdownButton<int>(
        key: const ValueKey('of-warehouse'),
        value: _warehouseHere,
        isDense: true,
        hint: Text(l10n.ofPickWarehouseHint),
        items: [for (final w in warehouses) DropdownMenuItem(value: w.id, child: Text(w.name))],
        onChanged: (v) {
          setState(() => _warehouseHere = v);
          _match();
        },
      ),
    ]);
  }

  List<OutboundPlanLine> get _plan => planOutbound(_rows, _matches,
      picked: _picked, chosen: {..._chosen, for (final r in _excluded) r: OutboundAction.skip}, proxy: _proxy);

  Future<void> _pickProduct(OutboundPlanLine line) async {
    final warehouseId = _warehouseId;
    final p = await showDialog<Product>(
      context: context,
      builder: (_) => OutboundPickProductDialog(
          rowNo: line.row.rowNo, initial: line.row.code ?? line.row.name ?? '', warehouseId: warehouseId),
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
        kept: keptOf(p, warehouseId),
      );
      _chosen.remove(line.row.rowNo);
    });
  }

  Future<void> _post() async {
    final l10n = AppLocalizations.of(context);
    final warehouseId = _warehouseId;
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
    // 出庫 now needs its 出荷先カード (0210); a planned list can have it later.
    if (!_proxy && !_planning && _card?.id == null) {
      _snack(l10n.ofPostNeedsCard);
      await _pickCard();
      if (!mounted || _card?.id == null) return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(_proxy ? l10n.prPostConfirmTitle : (_planning ? l10n.ofPostPlan : l10n.ofPostConfirmTitle)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_proxy
              ? l10n.prPostConfirmBody(t.record, _recordedQty(plan))
              : _planning
                  ? l10n.ofPlanConfirmBody(t.ship + t.record, _recordedQty(plan), _planDayText(l10n))
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
          shippedOn: _dayOpen ? (_plannedOn ?? DateTime.now()) : _shippedOn,
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
          destinationId: _card?.id,
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
        // 未定: the day it was sent with means nothing until one is set.
        if (_dayOpen && _plannedOn == null) {
          final u = await repo.markUndecided(data);
          if (u case ApiFailure(:final message)) _snack(humanizeApiErrorMessage(l10n, message));
        }
        // Each row's currency, kept for the profit and loss later (0197).
        await _saveCurrency(data);
        // What was read, kept as Excel beside the file (0208).
        await _keepRead(data, warehouseId, plan);
        final card = _card;
        // 出庫 now took its card in the same step.
        if (card?.id != null && (_proxy || _planning)) {
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
                ? l10n.ofPlanDone(_planDayText(l10n))
                : l10n.ofPostDone(t.shipped));
        setState(() {
          _file = null;
          _sheets = const [];
          _parsed = null;
          _matches = const [];
          _manual.clear();
          _picked.clear();
          _chosen.clear();
          _excluded.clear();
          _destination.clear();
          _note.clear();
          _principal.clear();
          _plannedOn = null;
          _currency = {};
          _card = null;
        });
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => OutboundFileDetailScreen(fileId: data)));
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  /// Each row's currency and the rate, written to list [id] (0197).
  Future<void> _saveCurrency(int id) async {
    if (_currency.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final counts = <PriceCurrency, int>{};
    for (final c in _currency.values) {
      counts[c.currency] = (counts[c.currency] ?? 0) + 1;
    }
    final main = counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    final c = await ref.read(outboundFileRepositoryProvider).setCurrency(
      id,
      [
        for (final e in _currency.entries)
          {'row_no': e.key, 'currency': e.value.currency.wire, 'source': e.value.source.wire},
      ],
      currency: main.wire,
      fxCnyJpy: double.tryParse(_fx.text.trim()),
    );
    if (c case ApiFailure(:final message)) _snack(humanizeApiErrorMessage(l10n, message));
  }

  /// What list is being replaced, and what stays as it is.
  Widget _replaceBanner(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final f = widget.replace!;
    return Card(
      key: const ValueKey('of-replace-banner'),
      color: scheme.secondaryContainer,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(children: [
          Icon(Icons.published_with_changes_outlined, color: scheme.onSecondaryContainer),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(l10n.ofReplaceBanner(f.fileName, f.lineCount, f.quantityTotal),
                style: TextStyle(color: scheme.onSecondaryContainer)),
          ),
        ]),
      ),
    );
  }

  /// The list's rows replaced by those read here, once what changes has been
  /// seen: added, left out and changed in quantity.
  Future<void> _replaceRows() async {
    final l10n = AppLocalizations.of(context);
    final target = widget.replace!;
    final file = _file;
    final parsed = _parsed;
    final plan = _plan;
    final t = OutboundPlanTotals.of(plan);
    if (t.ship + t.record == 0) {
      _snack(l10n.ofErrNoLines);
      return;
    }
    final diff = outboundLinesDiff(widget.replaceLines, plan);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) {
        final theme = Theme.of(c);
        Widget part(String title, List<String> rows, Color color, String key) => Column(
              key: ValueKey(key),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.sm),
                Text(title, style: theme.textTheme.titleSmall?.copyWith(color: color)),
                for (final r in rows.take(12)) Text(r, style: theme.textTheme.bodySmall),
                if (rows.length > 12) Text(l10n.ppMore(rows.length - 12), style: theme.textTheme.bodySmall),
              ],
            );
        return AlertDialog(
          key: const ValueKey('of-replace-dialog'),
          title: Text(l10n.ofReplaceQ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l10n.ofReplaceSummary(diff.added.length, diff.removed.length, diff.changed.length)),
                if (diff.added.isNotEmpty)
                  part(l10n.ofReplaceAdded, [for (final x in diff.added) '${x.name} × ${x.quantity}'],
                      theme.colorScheme.success, 'of-replace-added'),
                if (diff.removed.isNotEmpty)
                  part(l10n.ofReplaceRemoved, [for (final x in diff.removed) '${x.name} × ${x.quantity}'],
                      theme.colorScheme.error, 'of-replace-removed'),
                if (diff.changed.isNotEmpty)
                  part(l10n.ofReplaceChanged, [for (final x in diff.changed) '${x.name}: ${x.from} → ${x.to}'],
                      theme.colorScheme.primary, 'of-replace-changed'),
                const SizedBox(height: AppSpacing.md),
                Text(l10n.ofReplaceKeeps, style: theme.textTheme.bodySmall),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.actionCancel)),
            FilledButton(key: const ValueKey('of-replace-ok'), onPressed: () => Navigator.pop(c, true), child: Text(l10n.ofReplaceDo)),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _busyText = l10n.ofUploading;
    });
    final repo = ref.read(outboundFileRepositoryProvider);
    String? path;
    if (file != null) {
      final up = await repo.upload(target.warehouseId, file.name, file.bytes);
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
    final r = await repo.replaceLines(
      target.id,
      lines: [for (final l in plan) l.toPost()],
      fileName: file?.name ?? target.fileName,
      storagePath: path,
      byteSize: file?.bytes.length,
      fingerprint: file == null ? null : fileFingerprint(file.bytes),
      sheetName: parsed?.sheetName,
      columns: parsed?.columnsWire,
    );
    if (!mounted) return;
    switch (r) {
      case ApiSuccess():
        await _saveCurrency(target.id);
        await _keepRead(target.id, target.warehouseId, plan);
        if (!mounted) return;
        setState(() => _busy = false);
        ref.invalidate(outboundFilesProvider);
        ref.invalidate(outboundUndecidedProvider);
        ref.invalidate(outboundFileDetailProvider(target.id));
        ref.invalidate(productListProvider);
        ref.invalidate(adjustProductsProvider);
        Navigator.of(context).pop(true);
      case ApiFailure(:final message):
        setState(() => _busy = false);
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  int _recordedQty(List<OutboundPlanLine> plan) =>
      plan.fold(0, (a, l) => a + (l.action == OutboundAction.skip ? 0 : (l.row.quantity ?? 0)));

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final parsed = _parsed;
    final hasRows = _rows.isNotEmpty;
    final plan = _plan;
    final totals = OutboundPlanTotals.of(plan);
    final shown = [for (final l in plan) if ((_filter == null || l.status == _filter) && (!_needOnly || l.need > 0)) l];
    final appWarehouse = ref.watch(writeWarehouseIdProvider);
    final noWarehouse = !_replacing && appWarehouse == null && _warehouseHere == null;
    // The app's warehouse changed: the rows are checked against the new one.
    ref.listen<int?>(writeWarehouseIdProvider, (prev, next) {
      if (prev != next && _rows.isNotEmpty) _match();
    });

    final main = Column(children: [
      Expanded(
        child: LayoutBuilder(
          builder: (context, viewport) => ListView(
          key: const ValueKey('of-import-list'),
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
          children: [
            // Lists with no day yet (未定): where they are made, to be given
            // one — not on the 出庫カレンダー, which holds days set.
            if (_file == null && _manual.isEmpty && !_replacing) OutboundUndecidedCard(kind: _proxy ? 'proxy' : 'stock'),
            if (_replacing) _replaceBanner(l10n),
            if (_aiReading)
              Padding(
                key: const ValueKey('of-ai-reading'),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: AppSpacing.sm),
                  Text(l10n.rdAiReading),
                ]),
              ),
            // Nothing read yet: what this is for, and the way in.
            if (_file == null && _manual.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_replacing ? l10n.ofReplaceIntro : (_proxy ? l10n.prIntro : l10n.ofIntro),
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.sm, children: [
                      FilledButton.icon(
                        key: const ValueKey('of-pick'),
                        onPressed: _busy ? null : _pick,
                        icon: const Icon(Icons.upload_file_outlined),
                        label: Text(l10n.ofPick),
                      ),
                      if (_proxy && !_replacing)
                        OutlinedButton.icon(
                          key: const ValueKey('pr-add-row'),
                          onPressed: _busy ? null : _addRow,
                          icon: const Icon(Icons.add),
                          label: Text(l10n.prAddRow),
                        ),
                    ]),
                    if (appWarehouse == null && !_replacing) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _warehousePicker(l10n),
                    ],
                  ]),
                ),
              )
            else
              // Read: the file, its sheet and columns on one line, so the
              // rows below have the room.
              _fileBar(l10n, parsed, muted, noWarehouse),
            if (parsed != null && _columnsOpen) _columnsPanel(l10n, parsed, muted),
            if (parsed != null && !parsed.usable)
              Text(l10n.ofNotUsable, key: const ValueKey('of-not-usable'), style: TextStyle(color: scheme.error)),
            if (parsed != null || hasRows) ...[
              const SizedBox(height: AppSpacing.sm),
              // Replacing: the day, 出荷先 and the rest stay as the list has them.
              if (!_replacing) _settings(l10n),
              const SizedBox(height: AppSpacing.sm),
              if (!hasRows)
                const SizedBox.shrink()
              else if (noWarehouse)
                // Not checked yet: without a warehouse every row would look
                // unregistered and nothing could be registered.
                Card(
                  key: const ValueKey('of-needs-warehouse'),
                  color: scheme.warningContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(children: [
                      Icon(Icons.warehouse_outlined, color: scheme.onWarningContainer),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(l10n.ofNeedsWarehouseBody,
                            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onWarningContainer)),
                      ),
                    ]),
                  ),
                )
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
                  Wrap(spacing: AppSpacing.md, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text(l10n.prSummary(totals.rows, totals.record, totals.skip, _recordedQty(plan)),
                        key: const ValueKey('of-summary'), style: theme.textTheme.titleSmall),
                    // The rows typed in, as an Excel file (在庫外出荷 only).
                    Tooltip(
                      message: l10n.ofTableDownloadHelp,
                      child: TextButton.icon(
                        key: const ValueKey('of-table-download'),
                        style: _dense,
                        onPressed: () => _downloadTable(plan),
                        icon: const Icon(Icons.download_outlined, size: 18),
                        label: Text(l10n.ofTableDownload),
                      ),
                    ),
                  ])
                else ...[
                  _summary(l10n, totals),
                  const SizedBox(height: AppSpacing.xs),
                  _filters(l10n, totals),
                ],
                const SizedBox(height: AppSpacing.sm),
                _OutboundPlanTable(
                  // Scrolled to, the table takes the whole height.
                  height: viewport.maxHeight - AppSpacing.md,
                  fx: _fxRate,
                  lines: shown,
                  proxy: _proxy,
                  manual: {for (final r in _manual) r.rowNo},
                  onInclude: (rows, v) => setState(() => v ? _excluded.removeAll(rows) : _excluded.addAll(rows)),
                  onPick: _pickProduct,
                  onRemove: _removeRow,
                  currency: _currency,
                  onCurrency: _setCurrency,
                ),
              ],
            ],
          ],
          ),
        ),
      ),
      if (hasRows && !_matching && _matchError == null && !noWarehouse)
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
                          if (totals.need > 0) l10n.ofSummaryNeed(totals.need, totals.needRows),
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
                  onPressed: noWarehouse ? null : (_replacing ? _replaceRows : _post),
                  icon: Icon(_replacing
                      ? Icons.published_with_changes_outlined
                      : _proxy
                          ? Icons.edit_note_outlined
                          : (_planning ? Icons.event_available_outlined : Icons.outbox_outlined)),
                  label: Text(_replacing
                      ? l10n.ofReplaceDo
                      : (_proxy ? l10n.prPost : (_planning ? l10n.ofPostPlan : l10n.ofPost))),
                ),
            ]),
          ),
        ),
    ]);
    // On a PC the file read beside the table, as in 発注's 読み取り結果の確認.
    final file = _file;
    if (file == null || _sheets.isEmpty || !_showOriginal) return main;
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 1100) return main;
      return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(width: (box.maxWidth * 0.3).clamp(320.0, 560.0), child: _originalPane(l10n, file, plan)),
        const VerticalDivider(width: 1),
        Expanded(child: main),
      ]);
    });
  }

  /// Show the file read beside the table (a PC's width).
  bool _showOriginal = true;
  Object? _paneKey;
  Widget? _pane;

  /// The sheet read, as it is, the rows not matched to a product of ours in
  /// red. Made again only when the sheet or those rows change: a sheet of
  /// hundreds of rows is not laid out again on every tick.
  Widget _originalPane(AppLocalizations l10n, ({String name, Uint8List bytes}) file, List<OutboundPlanLine> plan) {
    final rows = _sheets[_sheet].rows;
    final out = [
      for (final l in plan)
        if (!l.found && l.action != OutboundAction.skip && l.status != OutboundStatus.noQuantity) l.row.rowNo
    ];
    final key = (identityHashCode(rows), out.join(','), file.name, l10n.localeName);
    if (key == _paneKey && _pane != null) return _pane!;
    _paneKey = key;
    final theme = Theme.of(context);
    return _pane = Column(
      key: const ValueKey('of-original'),
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
              key: const ValueKey('of-original-hide'),
              tooltip: l10n.ofOriginalHide,
              icon: const Icon(Icons.close_fullscreen, size: 18),
              onPressed: () => setState(() => _showOriginal = false),
            ),
          ]),
        ),
        if (out.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(l10n.ofOriginalLegend(out.length),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
          ),
        Expanded(
          // A PDF or a photo read by the AI is shown as it is.
          child: _aiRead
              ? OriginalFileView(fileName: file.name, bytes: file.bytes)
              : OriginalFileView(fileName: file.name, bytes: file.bytes, sheetRows: rows, leftOut: out.toSet()),
        ),
      ],
    );
  }

  /// Buttons and fields of the top, small: the rows are what is looked at.
  static const _dense = ButtonStyle(
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: WidgetStatePropertyAll(TextStyle(
        fontFamily: AppFonts.sans, fontFamilyFallback: AppFonts.fallback, fontSize: 14, fontWeight: FontWeight.w600)),
  );

  static const _denseField = EdgeInsets.symmetric(horizontal: 10, vertical: 8);

  /// 列の割り当て shown under the file line.
  bool _columnsOpen = false;

  String _colName(OutboundSheet parsed, int i) => i < parsed.headings.length && parsed.headings[i].trim().isNotEmpty
      ? '${columnLetters(i)}: ${parsed.headings[i].trim()}'
      : columnLetters(i);

  /// The file read, on one line: choose again, its name, the sheet, where
  /// its headings are, the columns (a tap opens them), the original beside.
  Widget _fileBar(AppLocalizations l10n, OutboundSheet? parsed, TextStyle? muted, bool noWarehouse) {
    final theme = Theme.of(context);
    return Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
      Tooltip(
        message: _proxy ? l10n.prIntro : l10n.ofIntro,
        child: OutlinedButton.icon(
          key: const ValueKey('of-pick'),
          style: _dense,
          onPressed: _busy ? null : _pick,
          icon: const Icon(Icons.upload_file_outlined, size: 18),
          label: Text(l10n.ofPickAgain),
        ),
      ),
      if (_proxy)
        OutlinedButton.icon(
          key: const ValueKey('pr-add-row'),
          style: _dense,
          onPressed: _busy ? null : _addRow,
          icon: const Icon(Icons.add, size: 18),
          label: Text(l10n.prAddRow),
        ),
      if (_file != null) Text(_file!.name, key: const ValueKey('of-file-name'), style: theme.textTheme.titleSmall),
      if (_aiRead)
        Chip(
          key: const ValueKey('of-read-by-ai'),
          avatar: const Icon(Icons.auto_awesome, size: 16),
          label: Text(l10n.rdByAi),
        ),
      if (parsed != null && _sheets.length > 1)
        DropdownButton<int>(
          key: ValueKey('of-sheet-$_sheet'),
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
              _chosen.clear();
              _excluded.clear();
            });
            _read();
          },
        ),
      if (parsed != null && parsed.headerRow >= 0) Text(l10n.ofHeaderRow(parsed.headerRow + 1), style: muted),
      if (parsed != null && parsed.janGuessed)
        Tooltip(
          message: l10n.ofJanGuessed,
          child: Icon(Icons.info_outline, key: const ValueKey('of-jan-guessed'), size: 16, color: theme.colorScheme.onSurfaceVariant),
        ),
      if (parsed != null)
        Tooltip(
          // What each column was taken for, without taking a line.
          message: [
            for (final c in OutboundColumn.values)
              if (parsed.columns[c] != null) '${outboundColumnLabel(l10n, c)} = ${_colName(parsed, parsed.columns[c]!)}',
          ].join('\n'),
          child: TextButton.icon(
            key: const ValueKey('of-columns'),
            style: _dense,
            onPressed: () => setState(() => _columnsOpen = !_columnsOpen),
            icon: Icon(_columnsOpen ? Icons.expand_less : Icons.view_column_outlined, size: 18),
            label: Text(l10n.ofColumns),
          ),
        ),
      if (_file != null && !_showOriginal)
        TextButton.icon(
          key: const ValueKey('of-original-show'),
          style: _dense,
          onPressed: () => setState(() => _showOriginal = true),
          icon: const Icon(Icons.vertical_split_outlined, size: 18),
          label: Text(l10n.ofOriginalShow),
        ),
      if (ref.watch(writeWarehouseIdProvider) == null && !_replacing) _warehousePicker(l10n),
    ]);
  }

  /// 列の割り当て: each field and the column it is read from, to choose again.
  Widget _columnsPanel(AppLocalizations l10n, OutboundSheet parsed, TextStyle? muted) {
    final width = [for (final r in _sheets[_sheet].rows.take(30)) r.length].fold(parsed.headings.length, (a, b) => a > b ? a : b);
    return Card(
      key: const ValueKey('of-columns-panel'),
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.ofColumnsHint, style: muted),
          const SizedBox(height: AppSpacing.sm),
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
            for (final c in OutboundColumn.values)
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<int>(
                  key: ValueKey('of-col-${c.wire}-${parsed.columns[c] ?? -1}'),
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
                      _chosen.clear();
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

  Widget _settings(AppLocalizations l10n) => Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (!_proxy)
            SegmentedButton<bool>(
              key: const ValueKey('of-mode'),
              style: _dense,
              segments: [
                ButtonSegment(
                    value: true, icon: const Icon(Icons.event_available_outlined), label: Text(l10n.ofModePlan)),
                ButtonSegment(value: false, icon: const Icon(Icons.outbox_outlined), label: Text(l10n.ofModeNow)),
              ],
              selected: {_planMode},
              onSelectionChanged: (v) => setState(() => _planMode = v.first),
            ),
          if (_dayOpen) ...[
            // 出庫予定日 (or a 在庫外出荷's 出庫日): 未定 until known; set
            // here or later.
            // 未定 said plainly: amber, with what it means on the pointer.
            Tooltip(
              message: _plannedOn == null ? l10n.ofUndecidedButtonHint : '',
              child: OutlinedButton.icon(
              key: const ValueKey('of-shipped-on'),
              style: _plannedOn == null
                  ? _dense.copyWith(
                      foregroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.warning),
                      side: WidgetStatePropertyAll(BorderSide(color: Theme.of(context).colorScheme.warning)))
                  : _dense,
              icon: Icon(_plannedOn == null ? Icons.event_busy_outlined : Icons.event_outlined, size: 18),
              label: Text('${_proxy ? l10n.ofShippedOn : l10n.ofPlannedOn}: ${_planDayText(l10n)}'),
              onPressed: () async {
                final d = await showDatePicker(
                    context: context,
                    initialDate: _plannedOn ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100));
                if (d != null) setState(() => _plannedOn = d);
              },
            ),
            ),
            if (_plannedOn != null)
              TextButton(
                key: const ValueKey('of-planned-clear'),
                style: _dense,
                onPressed: () => setState(() => _plannedOn = null),
                child: Text(l10n.ofBackToUndecided),
              ),
          ] else
            OutlinedButton.icon(
              key: const ValueKey('of-shipped-on'),
              style: _dense,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text('${l10n.ofShippedOn}: ${DateFormat('y/MM/dd').format(_shippedOn)}'),
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
                decoration: InputDecoration(labelText: l10n.prPrincipal, isDense: true, contentPadding: _denseField),
              ),
            ),
          if (_card == null)
            Tooltip(
              message: !_proxy && !_planning ? l10n.ofCardRequiredHint : '',
              child: OutlinedButton.icon(
                key: const ValueKey('of-pick-card'),
                style: _dense,
                icon: Icon(Icons.contact_mail_outlined,
                    size: 18, color: !_proxy && !_planning ? Theme.of(context).colorScheme.error : null),
                label: Text(!_proxy && !_planning ? '${l10n.ofPickCard} *' : l10n.ofPickCard),
                onPressed: _pickCard,
              ),
            )
          else
            InputChip(
              key: const ValueKey('of-card'),
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.contact_mail_outlined, size: 18),
              label: Text(l10n.ofCardChosen(_card!.name)),
              onPressed: _pickCard,
              onDeleted: () => setState(() => _card = null),
              deleteButtonTooltipMessage: l10n.ofCardClear,
            ),
          SizedBox(
            width: 180,
            child: TextField(
              key: const ValueKey('of-destination'),
              controller: _destination,
              decoration: InputDecoration(labelText: l10n.ofDestination, isDense: true, contentPadding: _denseField),
            ),
          ),
          SizedBox(
            width: 200,
            child: TextField(
              key: const ValueKey('of-note'),
              controller: _note,
              decoration: InputDecoration(labelText: l10n.ofNote, isDense: true, contentPadding: _denseField),
            ),
          ),
          // The prices' currency, where it is seen: all at once here, one
          // row by tapping its price.
          if (_currency.isNotEmpty) _currencyButton(l10n),
          // What 出庫予定 means, on the pointer: not a line of its own.
          if (_planning)
            Tooltip(
              message: l10n.ofModePlanHint,
              child: Icon(Icons.info_outline,
                  key: const ValueKey('of-plan-hint'), size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
        ],
      );

  String get _proposalTitle => _file?.name ?? AppLocalizations.of(context).prManualName;

  List<InboundNeed> get _needs => inboundNeeds(_plan, (s) => outboundStatusLabel(AppLocalizations.of(context), s));

  /// 入荷の提案 in a new tab (opened from the click, so the browser lets it).
  Future<void> _openProposal() async {
    final html = inboundProposalHtml(_needs, title: _proposalTitle);
    final tab = ref.read(outboundTabOpenerProvider)();
    if (tab != null) {
      tab.show(html);
    } else {
      await ref.read(outboundFileSaverProvider)('入荷の提案.html', Uint8List.fromList(utf8.encode(html)));
    }
  }

  Future<void> _downloadProposal() async {
    final l10n = AppLocalizations.of(context);
    final base = _proposalTitle.replaceAll(RegExp(r'\.[^.]+$'), '');
    final name = '入荷の提案_$base.xlsx';
    await ref.read(outboundFileSaverProvider)(name, buildInboundProposalXlsx(_needs, title: _proposalTitle));
    _snack(l10n.ofFileSaved(name));
  }

  /// The reading of the file — every row with what was found for it — as
  /// an Excel file.
  Uint8List _readXlsx(List<OutboundPlanLine> plan) {
    final l10n = AppLocalizations.of(context);
    return buildOutboundPlanXlsx(
      plan,
      statusLabel: (l) => _proxy ? proxyStatusLabel(l10n, l) : outboundStatusLabel(l10n, l.status),
      currency: _currency,
      proxy: _proxy,
      title: _file?.name,
      sheet: _parsed?.sheetName,
    );
  }

  /// What was read from the file, saved as Excel beside it (0208), to be
  /// downloaded again from the list. A list typed in has no file to read.
  Future<void> _keepRead(int id, int warehouseId, List<OutboundPlanLine> plan) async {
    final l10n = AppLocalizations.of(context);
    final file = _file;
    if (file == null) return;
    final repo = ref.read(outboundFileRepositoryProvider);
    final name = '${file.name.replaceAll(RegExp(r'\.[^.]+$'), '')}_${l10n.rdSuffix}.xlsx';
    final up = await repo.upload(warehouseId, name, _readXlsx(plan));
    final r = switch (up) {
      ApiSuccess(:final data) => await repo.setReadPath(id, data),
      ApiFailure(:final message) => ApiFailure<bool>(message: message),
    };
    if (r case ApiFailure(:final message)) {
      if (mounted) _snack(l10n.rdNotKept(humanizeApiErrorMessage(l10n, message)));
    }
  }

  /// The table as it stands — the file read, improved, or the rows typed
  /// in — as an Excel file.
  Future<void> _downloadTable(List<OutboundPlanLine> plan) async {
    final l10n = AppLocalizations.of(context);
    final day = DateFormat('yyyyMMdd').format(DateTime.now());
    final base = _file == null
        ? '${_proxy ? l10n.obHubProxy : l10n.ofTitle}_$day'
        : '${_file!.name.replaceAll(RegExp(r'\.[^.]+$'), '')}_${l10n.ofImprovedSuffix}';
    final name = '$base.xlsx';
    await ref.read(outboundFileSaverProvider)(name, _readXlsx(plan));
    _snack(l10n.ofFileSaved(name));
  }

  Widget _summary(AppLocalizations l10n, OutboundPlanTotals t) {
    final theme = Theme.of(context);
    return Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
      Text(l10n.ofSummary(t.rows, t.ship, t.record, t.skip), key: const ValueKey('of-summary'), style: theme.textTheme.titleSmall),
      Text(l10n.ofSummaryShip(t.shipped)),
      // 不足: what must come in for the list to ship (入荷), every row the
      // stock cannot cover — not found ones whole.
      if (t.need > 0)
        Text(l10n.ofSummaryNeed(t.need, t.needRows),
            key: const ValueKey('of-summary-short'), style: TextStyle(color: theme.colorScheme.error)),
      if (t.need > 0) ...[
        FilledButton.tonalIcon(
          key: const ValueKey('of-proposal-open'),
          style: _dense,
          onPressed: _openProposal,
          icon: const Icon(Icons.open_in_new, size: 18),
          label: Text(l10n.ofProposalOpen),
        ),
        OutlinedButton.icon(
          key: const ValueKey('of-proposal-download'),
          style: _dense,
          onPressed: _downloadProposal,
          icon: const Icon(Icons.download_outlined, size: 18),
          label: Text(l10n.ofProposalDownload),
        ),
      ],
      if (t.amount > 0) Text(l10n.ofSummaryAmount(_amountText())),
      if (t.weightG > 0) Text(l10n.ofSummaryWeight(outboundKg(t.weightG))),

    ]);
  }

  /// The total by currency: 42,937,549 円 · 1,234 元.
  String _amountText() {
    final by = <PriceCurrency, double>{};
    for (final l in _plan) {
      final v = l.row.total;
      if (v == null || l.action == OutboundAction.skip) continue;
      final c = _currency[l.row.rowNo]?.currency ?? PriceCurrency.jpy;
      by[c] = (by[c] ?? 0) + v;
    }
    final base = by.length <= 1 && (by.keys.firstOrNull ?? PriceCurrency.jpy) == PriceCurrency.jpy
        ? outboundMoney(by[PriceCurrency.jpy] ?? 0)
        : [for (final e in by.entries) '${outboundMoney(e.value)} ${e.key.mark}'].join(' · ');
    // With the rate, the total in the other currency too.
    final fx = _fxRate;
    if (fx == null) return base;
    final jpy = by[PriceCurrency.jpy] ?? 0, cny = by[PriceCurrency.cny] ?? 0;
    return cny > 0
        ? '$base（≈ ${outboundMoney(jpy + cny * fx)} 円）'
        : '$base（≈ ${outboundMoney(jpy / fx)} 元）';
  }

  /// 1 元 in 円, when given.
  double? get _fxRate {
    final v = double.tryParse(_fx.text.trim().replaceAll(',', ''));
    return v == null || v <= 0 ? null : v;
  }

  /// 価格の通貨: what the AI made of the prices, every row put in one
  /// currency, and the rate (1 元 in 円) that shows each price in the other
  /// currency too. Closed with 確定.
  Future<void> _openCurrency() => showDialog<void>(
        context: context,
        builder: (c) => StatefulBuilder(builder: (c, set) {
          final l10n = AppLocalizations.of(c);
          final theme = Theme.of(c);
          final cny = _currency.values.where((x) => x.currency == PriceCurrency.cny).length;
          final unsure = _currency.values.where((x) => !x.confident).length;
          void all(PriceCurrency cur) {
            _setAllCurrency(cur);
            set(() {});
          }

          return AlertDialog(
            key: const ValueKey('of-currency'),
            title: Text(l10n.ofCurrencyTitle),
            content: SizedBox(
              width: 460,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l10n.ofCurrencyFound(cny, _currency.length), style: theme.textTheme.titleSmall),
                if (unsure > 0) Text(l10n.ofCurrencyUnsure(unsure), style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSpacing.md),
                Text(l10n.ofCurrencyAllRows, style: theme.textTheme.labelLarge),
                const SizedBox(height: AppSpacing.xs),
                Wrap(spacing: AppSpacing.sm, children: [
                  for (final (cur, label) in [
                    (PriceCurrency.jpy, l10n.ofCurrencyAllJpy),
                    (PriceCurrency.cny, l10n.ofCurrencyAllCny),
                    (PriceCurrency.usd, l10n.ofCurrencyAllUsd),
                  ])
                    OutlinedButton(
                      key: ValueKey('of-currency-all-${cur.wire}'),
                      style: _dense,
                      onPressed: () => all(cur),
                      child: Text(label),
                    ),
                ]),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: 200,
                  child: TextField(
                    key: const ValueKey('of-fx'),
                    controller: _fx,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: l10n.ofFxLabel, isDense: true, suffixText: '円', contentPadding: _denseField),
                    onChanged: (_) {
                      setState(() {});
                      set(() {});
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(l10n.ofFxHint, style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.ofCurrencyRowHint, style: theme.textTheme.bodySmall),
              ]),
            ),
            actions: [
              FilledButton(key: const ValueKey('of-currency-ok'), onPressed: () => Navigator.pop(c), child: Text(l10n.ofCurrencyDone)),
            ],
          );
        }),
      );

  Widget _filters(AppLocalizations l10n, OutboundPlanTotals t) =>
      Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
        ChoiceChip(
          key: const ValueKey('of-filter-all'),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          label: Text(l10n.ofFilterAll(t.rows)),
          selected: _filter == null,
          onSelected: (_) => setState(() {
            _filter = null;
          }),
        ),
        if (t.needRows > 0)
          FilterChip(
            key: const ValueKey('of-filter-need'),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            label: Text(l10n.ofFilterNeed(t.needRows)),
            selected: _needOnly,
            onSelected: (v) => setState(() {
              _needOnly = v;
            }),
          ),
        for (final s in OutboundStatus.values)
          if ((t.byStatus[s] ?? 0) > 0)
            ChoiceChip(
              key: ValueKey('of-filter-${s.name}'),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              label: Text('${outboundStatusLabel(l10n, s)} ${t.byStatus[s]}'),
              selected: _filter == s,
              onSelected: (_) => setState(() {
                _filter = _filter == s ? null : s;
              }),
            ),
        // JANがない行・在庫と合わない行の扱い: a tap away, not a line.
        IconButton(
          key: const ValueKey('of-help'),
          visualDensity: VisualDensity.compact,
          tooltip: l10n.ofHelpTitle,
          icon: const Icon(Icons.help_outline, size: 20),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (c) => AlertDialog(
              title: Text(l10n.ofHelpTitle),
              content: SizedBox(
                width: 520,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final t in [l10n.ofHelpNoJan, l10n.ofHelpUnknown, l10n.ofHelpShort, l10n.ofHelpSeveral])
                    Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('・$t')),
                ]),
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(l10n.close))],
            ),
          ),
        ),
      ]);
}

/// The rows across, as in the 発注 table: what each is, what will be done,
/// its product, codes, quantity, stock, what goes out and is short, prices,
/// weight.
class _OutboundPlanTable extends StatefulWidget {
  const _OutboundPlanTable({
    this.height,
    this.fx,
    required this.lines,
    required this.onInclude,
    required this.onPick,
    this.proxy = false,
    this.manual = const {},
    this.onRemove,
    this.currency = const {},
    this.onCurrency,
  });

  /// The height a long table scrolls in (the space below the top).
  final double? height;

  /// 1 元 in 円, when given: each price shown in the other currency too.
  final double? fx;

  /// Each row's price currency (0197), changed by a tap on its price.
  final Map<int, RowCurrency> currency;
  final void Function(int rowNo, PriceCurrency c)? onCurrency;

  final List<OutboundPlanLine> lines;

  /// Rows ticked (true) or unticked (除外) by their row numbers.
  final void Function(Iterable<int> rowNos, bool include) onInclude;
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

  // 行, 対象 (the tick), 状態, 対応, 商品, JAN, 品番, メーカー, 仕入先, 数量, 在庫,
  // 出庫数, 不足, 税抜, 税込, 合計, 前回の仕入れ値, 総重量, 注番.
  static const _widths = [
    52.0, 44.0, 104.0, 132.0, 250.0, 128.0, 128.0, 96.0, 104.0, 72.0, 72.0, 112.0, 80.0, 80.0, 80.0, 100.0, 112.0, 84.0, 96.0
  ];

  /// Up to this many rows are laid out at once; more scroll in a box of
  /// their own, built as they come into view (a list of 700 rows built
  /// whole froze the page on every change).
  static const _allAtOnce = 40;

  @override
  void dispose() {
    _across.dispose();
    super.dispose();
  }

  /// A price with its currency when not 円; a tap switches 円 ⇄ 元.
  Widget _price(OutboundPlanLine l, double? v, TextStyle? small, ColorScheme scheme) {
    if (v == null) return const SizedBox.shrink();
    final c = widget.currency[l.row.rowNo];
    final cur = c?.currency ?? PriceCurrency.jpy;
    final text = Text(
      cur == PriceCurrency.jpy ? outboundMoney(v) : '${outboundMoney(v)} ${cur.mark}',
      style: cur == PriceCurrency.jpy ? small : small?.copyWith(color: scheme.tertiary, fontWeight: FontWeight.w700),
    );
    // With a rate, the price in the other currency under it.
    final fx = widget.fx;
    final shown = fx == null || cur == PriceCurrency.usd
        ? text
        : Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            text,
            Text(
              cur == PriceCurrency.cny ? '≈ ${outboundMoney(v * fx)} 円' : '≈ ${outboundMoney(v / fx)} 元',
              key: ValueKey('of-fx-${l.row.rowNo}-${v.hashCode}'),
              style: small?.copyWith(color: scheme.onSurfaceVariant, fontSize: 11),
            ),
          ]);
    if (c == null || widget.onCurrency == null) return shown;
    return Tooltip(
      message: AppLocalizations.of(context).ofCurrencyCellHint,
      child: InkWell(
        key: ValueKey('of-cur-${l.row.rowNo}-${v.hashCode}'),
        onTap: () => widget.onCurrency!(l.row.rowNo, cur == PriceCurrency.jpy ? PriceCurrency.cny : PriceCurrency.jpy),
        child: shown,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final head = theme.textTheme.labelMedium;
    final small = theme.textTheme.bodySmall;
    // 代理出荷: no stock, nothing taken out, nothing short. 仕入先 is ours to
    // know, not the shipping side's: kept with the list, not shown (8).
    // 対応 (3) is no column of its own: a found product is taken out of
    // stock, anything else waits for goods to come in (不足); the tick says
    // whether a row goes at all.
    final hidden = widget.proxy ? const {3, 8, 10, 11, 12} : const {3, 8};
    Widget cell(int i, Widget child, {bool end = false}) => hidden.contains(i)
        ? const SizedBox.shrink()
        : Container(
            width: _widths[i],
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            alignment: end ? Alignment.centerRight : Alignment.centerLeft,
            child: child,
          );
    final width = [for (final (i, w) in _widths.indexed) if (!hidden.contains(i)) w].fold(0.0, (a, w) => a + w);
    final lines = widget.lines;
    final included = lines.where((l) => l.action != OutboundAction.skip).length;
    final headers = [
      l10n.ofColRow, '', l10n.ofColStatus, l10n.ofColAction, l10n.ofColProduct, l10n.ofRoleJan, l10n.ofRoleCode,
      l10n.ofRoleMaker, l10n.ofRoleSupplier, l10n.ofRoleQuantity, l10n.ofColStock, l10n.ofColCanShip, l10n.ofColShort,
      l10n.ofColPriceEx, l10n.ofColPriceTax, l10n.ofRoleAmount, l10n.ofColLastPrice, l10n.ofColWeight, l10n.ofRoleOrderNumber,
    ];
    const ends = {9, 10, 11, 12, 13, 14, 15, 16, 17};
    final header = Container(
      color: scheme.surfaceContainerHighest,
      child: Row(children: [
        for (final (i, h) in headers.indexed)
          i == 1
              // Every row shown ticked or unticked at once.
              ? cell(
                  1,
                  Tooltip(
                    message: l10n.ofIncludeAll,
                    child: Checkbox(
                      key: const ValueKey('of-include-all'),
                      tristate: true,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      value: included == lines.length ? true : (included == 0 ? false : null),
                      onChanged: (_) => widget.onInclude([for (final l in lines) l.row.rowNo], included != lines.length),
                    ),
                  ))
              : cell(i, Text(h, style: head), end: ends.contains(i)),
      ]),
    );

    Widget row(OutboundPlanLine l) {
      final out = l.action == OutboundAction.skip;
      return Container(
        key: ValueKey('of-row-${l.row.rowNo}'),
        decoration: BoxDecoration(
          color: out ? scheme.surfaceContainerLow : null,
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Opacity(
          opacity: out ? 0.55 : 1,
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
            // Ticked: the row goes with the list. Unticked: left out (除外).
            cell(
              1,
              Checkbox(
                key: ValueKey('of-include-${l.row.rowNo}'),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                value: !out,
                onChanged: (v) => widget.onInclude([l.row.rowNo], v ?? false),
              ),
            ),
            cell(
              2,
              Text(widget.proxy ? proxyStatusLabel(l10n, l) : outboundStatusLabel(l10n, l.status),
                  key: ValueKey('of-status-${l.row.rowNo}'),
                  style: small?.copyWith(
                      color: widget.proxy
                          ? (l.found ? scheme.primary : scheme.onSurfaceVariant)
                          : outboundStatusColor(scheme, l.status),
                      fontWeight: FontWeight.w600)),
            ),
            cell(
              4,
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                if (l.match.name != null)
                  Text(l.match.name!, key: ValueKey('of-name-${l.row.rowNo}'), maxLines: 2, overflow: TextOverflow.ellipsis)
                else if (l.row.name != null)
                  Text(l.row.name!, maxLines: 2, overflow: TextOverflow.ellipsis, style: small),
                if (l.found && l.match.matchedBy != OutboundMatchedBy.jan)
                  Text(outboundMatchedLabel(l10n, l.match.matchedBy), style: small?.copyWith(color: scheme.onSurfaceVariant)),
                // A row with no JAN (or a 品番 fitting several products) may
                // still be one of ours: chosen here. A JAN not in the library
                // is a product to register first, nothing to choose.
                if (l.status == OutboundStatus.noJan ||
                    l.status == OutboundStatus.several ||
                    l.match.matchedBy == OutboundMatchedBy.picked)
                  TextButton.icon(
                    key: ValueKey('of-pick-${l.row.rowNo}'),
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
            cell(
              5,
              Text(l.match.jan ?? (l.row.jan.isNotEmpty ? l.row.jan : l.row.janRaw),
                  style: small?.copyWith(color: l.row.janInvalid ? scheme.error : null)),
            ),
            cell(6, Text(l.row.code ?? l.match.sku ?? '', style: small, maxLines: 2, overflow: TextOverflow.ellipsis)),
            cell(7, Text(l.row.maker ?? l.match.maker ?? '', style: small, maxLines: 1, overflow: TextOverflow.ellipsis)),
            cell(8, Text(l.row.supplier ?? '', style: small, maxLines: 1, overflow: TextOverflow.ellipsis)),
            cell(9, Text('${l.row.quantity ?? ''}', style: theme.textTheme.titleSmall), end: true),
            // 在庫: a product of ours shows what is held (0 when none); one
            // not in the library has no stock to speak of — —, and all of
            // it is short.
            cell(
              10,
              l.stockBefore != null
                  ? ((l.match.kept ?? 0) > 0
                      // Some is kept by 出庫予定 already: what is left shown, the keep below.
                      ? Tooltip(
                          message: l10n.ofKeptHint(l.match.onHand ?? 0, l.match.kept!),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                            Text('${l.stockBefore}', key: ValueKey('of-stock-${l.row.rowNo}'), style: small),
                            Text(l10n.ofKeptShort(l.match.kept!),
                                key: ValueKey('of-kept-${l.row.rowNo}'),
                                style: small?.copyWith(color: theme.colorScheme.tertiary, fontSize: 11)),
                          ]),
                        )
                      : Text('${l.stockBefore}', key: ValueKey('of-stock-${l.row.rowNo}'), style: small))
                  : (out
                      ? Text('—', style: small)
                      : Tooltip(
                          message: l10n.ofStockZeroHint,
                          child: Text('—', key: ValueKey('of-stock-${l.row.rowNo}'), style: small),
                        )),
              end: true,
            ),
            // 在庫から出せる数: what the stock gives of the row's 数量 (the
            // file's number); — where there is no stock of ours.
            cell(
              11,
              Text(l.action == OutboundAction.ship ? '${l.shipped}' : '—',
                  key: ValueKey('of-ship-${l.row.rowNo}'), style: theme.textTheme.titleSmall),
              end: true,
            ),
            // 不足 (入荷が必要): what the stock cannot cover — a row not
            // found in the library is short in full.
            cell(
              12,
              l.need > 0
                  ? Container(
                      key: ValueKey('of-need-${l.row.rowNo}'),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(8)),
                      child: Text('${l.need}',
                          key: ValueKey('of-short-${l.row.rowNo}'),
                          style: small?.copyWith(color: scheme.onErrorContainer, fontWeight: FontWeight.w700)),
                    )
                  : Text('', key: ValueKey('of-short-${l.row.rowNo}')),
              end: true,
            ),
            cell(13, _price(l, l.row.priceEx, small, scheme), end: true),
            cell(14, _price(l, l.row.priceTax, small, scheme), end: true),
            cell(15, _price(l, l.row.total, small, scheme), end: true),
            cell(
              16,
              Text(outboundMoney(l.match.lastPrice),
                  style: small?.copyWith(
                      color: l.match.lastPrice != null && l.row.priceEx != null && (l.row.priceEx! - l.match.lastPrice!).abs() > 0.009
                          ? scheme.tertiary
                          : null)),
              end: true,
            ),
            cell(17, Text(l.weightG == null ? '' : '${outboundKg(l.weightG!)} kg', style: small), end: true),
            cell(18, Text(l.row.orderNumber ?? '', style: small, maxLines: 1, overflow: TextOverflow.ellipsis)),
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
          Expanded(
            child: ListView.builder(
              key: const ValueKey('of-table-rows'),
              itemCount: lines.length,
              itemBuilder: (_, i) => row(lines[i]),
            ),
          ),
        ]),
      );
    }
    return Scrollbar(
      controller: _across,
      thumbVisibility: true,
      child: SingleChildScrollView(
        key: const ValueKey('of-table'),
        controller: _across,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 12),
        child: body,
      ),
    );
  }
}

/// A product chosen for a row by hand: found by its name, maker, JAN or 品番.
class OutboundPickProductDialog extends ConsumerStatefulWidget {
  const OutboundPickProductDialog({super.key, required this.rowNo, required this.initial, this.warehouseId, this.title});

  final int rowNo;
  final String initial;

  /// In place of 「行 N の商品を選ぶ」 (a product added to a list, 0202).
  final String? title;

  /// Whose stock is shown beside each product.
  final int? warehouseId;

  @override
  ConsumerState<OutboundPickProductDialog> createState() => OutboundPickProductDialogState();
}

class OutboundPickProductDialogState extends ConsumerState<OutboundPickProductDialog> {
  late final _search = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final warehouseId = widget.warehouseId ?? ref.watch(writeWarehouseIdProvider);
    final all = ref.watch(adjustProductsProvider).valueOrNull ?? const <Product>[];
    final shown = [for (final p in all) if (adjustProductMatches(p, _search.text)) p].take(50).toList();
    return AlertDialog(
      key: const ValueKey('of-pick-dialog'),
      title: Text(widget.title ?? l10n.ofPickProductTitle(widget.rowNo)),
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
    return EditDrawer(
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
