import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../outbound/presentation/ship_destinations_screen.dart' show pickDestinationCard;
import '../../partners/application/trading_partner_providers.dart';
import '../../partners/domain/trading_partner.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/purchase_request_repository.dart';
import '../domain/purchase_request.dart';
import '../domain/wish_file.dart';
import 'wish_file_tab.dart';

/// The suppliers a request can be addressed to (customers left out).
final requestSuppliersProvider = FutureProvider.autoDispose<List<TradingPartner>>((ref) async {
  final r = await ref.watch(tradingPartnerRepositoryProvider).list(status: 'active');
  return r.when(
    success: (d) => [
      for (final p in d)
        if (p.kind != PartnerKind.customer) p
    ],
    failure: (f) => throw Exception(f.message),
  );
});

/// 入荷希望リスト (0140, 0205): what a customer downstream (or our own plan)
/// would like us to get in — whose wishes (依頼元, a 出荷先カード or typed)
/// and by when (希望時期) — made from 商品マスタ and the stock. The open
/// lists add up in the summary (まとめ). Wishes to our suppliers are kept
/// elsewhere.
///
/// Every product is a row. Rows are chosen the way a spreadsheet does it — a
/// tick each, everything shown, or a range: the first row and, with Shift
/// held (or 範囲選択 on), the last. The chosen rows go into the list, come out
/// of it, or get their quantity from the bulk setting (a percentage of the
/// stock, the same number for all, or up to the maximum stock). Any quantity
/// can be typed by hand, and a product we do not have yet can be added by
/// hand. The supplier is optional. The list is saved to come back to.
///
/// Or read from the customer's own file (0206), on the tab 「ファイルから読み込む」
/// in the way 出庫 reads a shipping list: the rows ticked there are in the
/// list, and the file is kept with it.
class PurchaseRequestScreen extends ConsumerStatefulWidget {
  const PurchaseRequestScreen({super.key, this.requestId});

  /// A saved list to open.
  final int? requestId;

  @override
  ConsumerState<PurchaseRequestScreen> createState() => _PurchaseRequestScreenState();
}

class _PurchaseRequestScreenState extends ConsumerState<PurchaseRequestScreen> {
  int? _id;
  String _number = '';
  int? _supplierId;
  int? _warehouseId;
  bool _warehouseSet = false;
  final _title = TextEditingController();
  final _note = TextEditingController();
  DateTime? _replyBy;

  /// 依頼元 (0205): typed, or a 出荷先カード's name.
  final _customer = TextEditingController();
  int? _destinationId;
  DateTime? _wantedBy;
  String _status = 'draft';

  final Map<String, RequestRow> _rows = {};
  final List<String> _order = [];
  final Map<String, TextEditingController> _qty = {};
  final Set<String> _selected = {};
  String? _anchor;
  bool _rangeMode = false;
  int _manualSeq = 0;

  BulkMode _mode = BulkMode.percentOfStock;
  final _bulkValue = TextEditingController(text: '50');
  BulkRounding _rounding = BulkRounding.up;

  final _search = TextEditingController();
  bool _onlyInList = false;

  bool _loading = true;
  String? _error;
  bool _busy = false;

  /// The list as opened (its kept file, 0206).
  PurchaseRequest? _saved;

  /// The customer's file read on the file tab, kept on 保存 (once).
  WishFileSource? _fileSource;
  bool _fileKept = false;

  /// What the rows the file put in were before it (to put back when the
  /// ticks or the file change), and the rows it added typed in.
  final Map<String, RequestRow> _fileBase = {};
  final Set<String> _fileManual = {};

  PurchaseRequestRepository get _repo => ref.read(purchaseRequestRepositoryProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    for (final c in [_title, _note, _customer, _bulkValue, _search, ..._qty.values]) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  TextEditingController _c(String key) => _qty.putIfAbsent(key, () => TextEditingController());

  void _put(RequestRow r) {
    if (!_rows.containsKey(r.key)) _order.add(r.key);
    _rows[r.key] = r;
    // The field shows the quantity unless it already says it (as typed).
    final c = _c(r.key);
    if ((int.tryParse(c.text.replaceAll(',', '').trim()) ?? 0) != r.quantity) {
      c.text = r.quantity > 0 ? '${r.quantity}' : '';
    }
  }

  Future<void> _start() async {
    if (widget.requestId != null) {
      final r = await _repo.get(widget.requestId!);
      if (!mounted) return;
      switch (r) {
        case ApiSuccess(:final data):
          _id = data.id;
          _number = data.number;
          _saved = data;
          _supplierId = data.supplierId;
          _warehouseId = data.warehouseId;
          _warehouseSet = true;
          _title.text = data.title ?? '';
          _note.text = data.note ?? '';
          _replyBy = data.replyBy;
          _customer.text = data.customerName ?? '';
          _destinationId = data.destinationId;
          _wantedBy = data.wantedBy;
          _status = data.status;
          for (final l in data.lines) {
            _put(l);
            if (l.manual) _manualSeq++;
          }
        case ApiFailure(:final message):
          setState(() {
            _loading = false;
            _error = message;
          });
          return;
      }
    }
    if (!_warehouseSet) {
      _warehouseId = ref.read(activeWarehouseIdProvider);
      _warehouseSet = true;
    }
    await _loadCandidates();
  }

  /// Every product, with its stock and the supplier's names; what was set
  /// on a row stays.
  Future<void> _loadCandidates() async {
    setState(() => _loading = true);
    final r = await _repo.candidates(warehouseId: _warehouseId, supplierId: _supplierId);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        setState(() {
          for (final c in data) {
            final had = _rows['p${c.productId}'];
            _put(had == null ? RequestRow.fromCandidate(c) : had.refreshedFrom(c));
          }
          _loading = false;
          _error = null;
        });
      case ApiFailure(:final message):
        setState(() {
          _loading = false;
          _error = message;
        });
    }
  }

  List<String> _visible() {
    final q = _search.text.trim().toLowerCase();
    return [
      for (final k in _order)
        if (_rows[k] case final r?)
          if ((!_onlyInList || r.inList) &&
              (q.isEmpty ||
                  '${r.name} ${r.janCode ?? ''} ${r.nameEn ?? ''} ${r.maker ?? ''} ${r.sku ?? ''} ${r.supplierCode ?? ''} ${r.supplierProductName ?? ''}'
                      .toLowerCase()
                      .contains(q)))
            k,
    ];
  }

  // ------------------------------------------------------------ choosing

  void _tapSelect(String key, List<String> visible) {
    final shift = HardwareKeyboard.instance.isShiftPressed;
    setState(() {
      if ((shift || _rangeMode) && _anchor != null && _anchor != key) {
        _selected.addAll(keysBetween(visible, _anchor!, key));
        if (_rangeMode) _anchor = null;
      } else if (_selected.contains(key) && !_rangeMode) {
        _selected.remove(key);
        _anchor = key;
      } else {
        _selected.add(key);
        _anchor = key;
      }
    });
  }

  void _setRow(String key, RequestRow r) => setState(() => _put(r));

  /// Into the list; a row with no quantity gets the bulk setting's (at least 1).
  void _include(Iterable<String> keys) {
    final v = _bulkNumber();
    setState(() {
      for (final k in keys.toList()) {
        final r = _rows[k]!;
        var q = r.quantity;
        if (q <= 0) q = v == null ? 1 : bulkQuantity(r, _mode, v, rounding: _rounding);
        _put(r.copyWith(inList: true, quantity: q <= 0 ? 1 : q));
      }
    });
  }

  void _exclude(Iterable<String> keys) => setState(() {
        for (final k in keys.toList()) {
          _put(_rows[k]!.copyWith(inList: false, quantity: 0));
        }
      });

  double? _bulkNumber() {
    final v = double.tryParse(_bulkValue.text.replaceAll(',', '').replaceAll('%', '').trim());
    return v == null || v < 0 ? null : v;
  }

  /// The bulk setting on [keys]: their quantities set, and in the list when
  /// above zero.
  void _applyBulk(Iterable<String> keys) {
    final l10n = AppLocalizations.of(context);
    final v = _bulkNumber();
    if (_mode != BulkMode.upToMax && v == null) return _snack(l10n.prBulkInvalid);
    var n = 0;
    setState(() {
      for (final k in keys.toList()) {
        final r = _rows[k]!;
        final q = bulkQuantity(r, _mode, v ?? 0, rounding: _rounding);
        _put(r.copyWith(inList: q > 0, quantity: q));
        if (q > 0) n++;
      }
    });
    _snack(l10n.prBulkApplied(n));
  }

  Future<void> _addManual() async {
    final row = await showDialog<RequestRow>(context: context, builder: (_) => _ManualRowDialog(seq: _manualSeq + 1));
    if (row == null || !mounted) return;
    _manualSeq++;
    setState(() => _put(row));
  }

  /// The file tab's ticks: the rows it put in before are put back as they
  /// were, then its products get their quantities and its rows not in the
  /// library go in typed in.
  void _applyFile(WishFileApplied a) => setState(() {
        for (final k in _fileManual) {
          _rows.remove(k);
          _order.remove(k);
          _selected.remove(k);
        }
        _fileManual.clear();
        for (final r in _fileBase.values) {
          _put(r);
        }
        _fileBase.clear();
        for (final e in a.quantities.entries) {
          final r = _rows[e.key];
          if (r == null) continue;
          _fileBase[e.key] = r;
          _put(r.copyWith(inList: e.value > 0, quantity: e.value));
        }
        for (final m in a.manual) {
          _put(m);
          _fileManual.add(m.key);
        }
      });

  void _setFile(WishFileSource? f) {
    _fileSource = f;
    _fileKept = false;
  }

  /// The file read kept with list [id] (0206).
  Future<void> _keepFile(int id) async {
    final l10n = AppLocalizations.of(context);
    final f = _fileSource;
    if (f == null || _fileKept) return;
    final up = await _repo.upload(f.name, f.bytes);
    if (!mounted) return;
    switch (up) {
      case ApiSuccess(data: final path):
        final set = await _repo.setFile(id, f.toFile(path));
        if (!mounted) return;
        if (set case ApiFailure(:final message)) return _snack(l10n.wlFileNotKept(humanizeApiErrorMessage(l10n, message)));
        _fileKept = true;
      case ApiFailure(:final message):
        _snack(l10n.wlFileNotKept(humanizeApiErrorMessage(l10n, message)));
    }
  }

  // ------------------------------------------------------------ out

  List<RequestRow> get _lines => [
        for (final k in _order)
          if (_rows[k] case final r? when r.inList && r.quantity > 0) r,
      ];

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final lines = _lines;
    if (lines.isEmpty) return _snack(l10n.prNothing);
    setState(() => _busy = true);
    final r = await _repo.save(
      id: _id,
      supplierId: _supplierId,
      warehouseId: _warehouseId,
      title: _title.text.trim().isEmpty ? null : _title.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      replyBy: _replyBy,
      lines: lines,
      settings: {'mode': _mode.name, 'value': _bulkValue.text.trim(), 'rounding': _rounding.name},
      customerName: _customer.text.trim().isEmpty ? null : _customer.text.trim(),
      destinationId: _destinationId,
      wantedBy: _wantedBy,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess(:final data):
        setState(() {
          _id = data.id;
          _number = data.number;
        });
        _snack(l10n.prSaved(data.number, data.lines, data.units));
        await _keepFile(data.id);
        ref.invalidate(purchaseRequestsProvider);
        ref.invalidate(wishSummaryProvider);
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  Future<void> _pickWantedBy() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _wantedBy ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (d != null) setState(() => _wantedBy = d);
  }

  /// 依頼元 from a 出荷先カード.
  Future<void> _pickCard() async {
    final d = await pickDestinationCard(context);
    if (d == null || !mounted) return;
    setState(() {
      _customer.text = d.name;
      _destinationId = d.id;
    });
  }

  /// 完了 (out of the summary) or open again.
  Future<void> _setStatus(String status) async {
    final l10n = AppLocalizations.of(context);
    final id = _id;
    if (id == null) return;
    final r = await _repo.setStatus(id, status);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess():
        setState(() => _status = status);
        ref.invalidate(purchaseRequestsProvider);
        ref.invalidate(wishSummaryProvider);
        _snack(status == 'closed' ? l10n.wlClosed : l10n.wlReopened);
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final warehouses = ref.watch(warehouseOverviewProvider).valueOrNull?.warehouses ?? const [];
    final visible = _visible();
    final lines = _lines;
    final units = lines.fold<int>(0, (s, l) => s + l.quantity);
    final selected = _selected.where(_rows.containsKey).toList();

    final settings = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l10n.wlIntro, style: muted),
      const SizedBox(height: AppSpacing.sm),
      Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: 300,
          child: TextField(
            key: const ValueKey('pr-customer'),
            controller: _customer,
            onChanged: (_) => _destinationId = null,
            decoration: InputDecoration(
              labelText: l10n.wlCustomer,
              hintText: l10n.wlCustomerHint,
              isDense: true,
              suffixIcon: IconButton(
                key: const ValueKey('pr-customer-card'),
                tooltip: l10n.wlCustomerCard,
                icon: const Icon(Icons.contact_mail_outlined),
                onPressed: _pickCard,
              ),
            ),
          ),
        ),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<int?>(
            key: ValueKey('pr-warehouse-${warehouses.length}-$_warehouseId'),
            initialValue: warehouses.any((w) => w.id == _warehouseId) ? _warehouseId : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.prStockOf, isDense: true),
            items: [
              DropdownMenuItem<int?>(value: null, child: Text(l10n.prAllWarehouses)),
              for (final w in warehouses) DropdownMenuItem<int?>(value: w.id, child: Text(w.name)),
            ],
            onChanged: (v) {
              setState(() => _warehouseId = v);
              _loadCandidates();
            },
          ),
        ),
        SizedBox(
          width: 260,
          child: TextField(
            key: const ValueKey('pr-title'),
            controller: _title,
            decoration: InputDecoration(labelText: l10n.prTitleField, isDense: true),
          ),
        ),
        OutlinedButton.icon(
          key: const ValueKey('pr-wanted-by'),
          onPressed: _pickWantedBy,
          icon: const Icon(Icons.event_outlined, size: 18),
          label: Text(_wantedBy == null ? l10n.wlWantedBy : l10n.wlWantedByIs(DateFormat('y/MM/dd').format(_wantedBy!))),
        ),
        SizedBox(
          width: 320,
          child: TextField(
            key: const ValueKey('pr-note'),
            controller: _note,
            decoration: InputDecoration(labelText: l10n.obDestNote, isDense: true),
          ),
        ),
      ]),
    ]);

    final header = <Widget>[
      // The bulk setting.
      Text(l10n.prBulkTitle, style: theme.textTheme.titleMedium),
      const SizedBox(height: AppSpacing.xs),
      Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SegmentedButton<BulkMode>(
          key: const ValueKey('pr-mode'),
          segments: [
            ButtonSegment(value: BulkMode.percentOfStock, label: Text(l10n.prModePercent)),
            ButtonSegment(value: BulkMode.fixed, label: Text(l10n.prModeFixed)),
            ButtonSegment(value: BulkMode.upToMax, label: Text(l10n.prModeMax)),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() => _mode = s.first),
        ),
        if (_mode != BulkMode.upToMax)
          SizedBox(
            width: 110,
            child: TextField(
              key: const ValueKey('pr-bulk-value'),
              controller: _bulkValue,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _mode == BulkMode.fixed ? l10n.prBulkQty : l10n.obPercent,
                suffixText: _mode == BulkMode.fixed ? null : '%',
                isDense: true,
              ),
            ),
          ),
        if (_mode == BulkMode.percentOfStock)
          DropdownButton<BulkRounding>(
            key: const ValueKey('pr-rounding'),
            value: _rounding,
            items: [
              DropdownMenuItem(value: BulkRounding.up, child: Text(l10n.obRoundUp)),
              DropdownMenuItem(value: BulkRounding.nearest, child: Text(l10n.obRoundNearest)),
              DropdownMenuItem(value: BulkRounding.down, child: Text(l10n.obRoundDown)),
            ],
            onChanged: (v) => setState(() => _rounding = v ?? _rounding),
          ),
        FilledButton.tonal(
          key: const ValueKey('pr-apply-selected'),
          onPressed: selected.isEmpty ? null : () => _applyBulk(selected),
          child: Text(l10n.prApplySelected(selected.length)),
        ),
        OutlinedButton(
          key: const ValueKey('pr-apply-visible'),
          onPressed: visible.isEmpty ? null : () => _applyBulk(visible),
          child: Text(l10n.prApplyVisible(visible.length)),
        ),
      ]),
      Text(
          switch (_mode) {
            BulkMode.percentOfStock => l10n.prModePercentHint,
            BulkMode.fixed => l10n.prModeFixedHint,
            BulkMode.upToMax => l10n.prModeMaxHint,
          },
          style: muted),
      const SizedBox(height: AppSpacing.md),

      // Finding and choosing rows.
      Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: 320,
          child: TextField(
            key: const ValueKey('pr-search'),
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.obSearch, isDense: true),
          ),
        ),
        FilterChip(
          key: const ValueKey('pr-only-list'),
          label: Text(l10n.prOnlyInList),
          selected: _onlyInList,
          onSelected: (v) => setState(() => _onlyInList = v),
        ),
        FilterChip(
          key: const ValueKey('pr-range'),
          avatar: const Icon(Icons.linear_scale, size: 18),
          label: Text(l10n.prRangeMode),
          selected: _rangeMode,
          onSelected: (v) => setState(() {
            _rangeMode = v;
            _anchor = null;
          }),
        ),
        TextButton(
          key: const ValueKey('pr-select-all'),
          onPressed: () => setState(() => _selected.addAll(visible)),
          child: Text(l10n.prSelectVisible),
        ),
        TextButton.icon(
          key: const ValueKey('pr-add-manual'),
          onPressed: _addManual,
          icon: const Icon(Icons.add, size: 18),
          label: Text(l10n.prAddManual),
        ),
      ]),
      Text(_rangeMode ? l10n.prRangeHint : l10n.prShiftHint, style: muted),
      if (selected.isNotEmpty)
        Card(
          key: const ValueKey('pr-selection-bar'),
          color: theme.colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(l10n.prSelectedCount(selected.length), style: theme.textTheme.titleSmall),
                  FilledButton.icon(
                    key: const ValueKey('pr-include'),
                    onPressed: () => _include(selected),
                    icon: const Icon(Icons.playlist_add, size: 18),
                    label: Text(l10n.prInclude),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('pr-exclude'),
                    onPressed: () => _exclude(selected),
                    icon: const Icon(Icons.playlist_remove, size: 18),
                    label: Text(l10n.prExclude),
                  ),
                  TextButton(
                    key: const ValueKey('pr-clear-selection'),
                    onPressed: () => setState(() {
                      _selected.clear();
                      _anchor = null;
                    }),
                    child: Text(l10n.prClearSelection),
                  ),
                ]),
          ),
        ),
      const SizedBox(height: AppSpacing.sm),
    ];

    final library = CustomScrollView(key: const ValueKey('wl-library'), slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          sliver: SliverList(delegate: SliverChildListDelegate(header)),
        ),
        if (_loading && _rows.isEmpty)
          SliverToBoxAdapter(child: LoadingView(message: l10n.loading))
        else if (_error != null && _rows.isEmpty)
          SliverToBoxAdapter(
            child: ErrorStateView(message: humanizeApiErrorMessage(l10n, _error!), onRetry: _loadCandidates),
          )
        else if (visible.isEmpty)
          // The empty state scrolls itself, so it needs the space left
          // rather than an unbounded box.
          SliverFillRemaining(child: EmptyStateView(icon: Icons.inventory_2_outlined, title: l10n.prNoRows))
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            sliver: SliverList.builder(
              itemCount: visible.length,
              itemBuilder: (_, i) {
                final k = visible[i];
                return _RowTile(
                  key: ValueKey('pr-row-$k'),
                  row: _rows[k]!,
                  qty: _c(k),
                  selected: _selected.contains(k),
                  anchor: _anchor == k,
                  onSelect: () => _tapSelect(k, visible),
                  onToggleList: () => _rows[k]!.inList ? _exclude([k]) : _include([k]),
                  onQty: (q) => _setRow(k, _rows[k]!.copyWith(quantity: q, inList: q > 0)),
                );
              },
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
      ]);

    return DefaultTabController(
      length: 2,
      // A new list starts from the customer's file, as 出庫 does; a saved one
      // opens on its rows.
      initialIndex: widget.requestId == null ? 0 : 1,
      child: Scaffold(
      appBar: AppBar(
        title: Text(_number.isEmpty ? l10n.featPurchaseRequest : '${l10n.featPurchaseRequest} $_number'),
        actions: [
          if (_id != null)
            TextButton.icon(
              key: const ValueKey('pr-close'),
              onPressed: () => _setStatus(_status == 'closed' ? 'draft' : 'closed'),
              icon: Icon(_status == 'closed' ? Icons.replay : Icons.task_alt),
              label: Text(_status == 'closed' ? l10n.wlReopen : l10n.wlClose),
            ),
        ],
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          child: settings,
        ),
        TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
          Tab(key: const ValueKey('wl-tab-file'), icon: const Icon(Icons.upload_file_outlined, size: 20), text: l10n.wlTabFile),
          Tab(key: const ValueKey('wl-tab-library'), icon: const Icon(Icons.inventory_2_outlined, size: 20), text: l10n.wlTabLibrary),
        ]),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(children: [
            WishFileTab(
              library: {
                for (final e in _rows.entries)
                  if (e.value.productId != null) e.key: e.value,
              },
              loading: _loading,
              saved: _saved,
              onApply: _applyFile,
              onFile: _setFile,
            ),
            library,
          ]),
        ),
      ]),
      bottomNavigationBar: Material(
        elevation: 3,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(l10n.obSummary(lines.length, units),
                      key: const ValueKey('pr-summary'), style: theme.textTheme.titleSmall),
                  FilledButton.icon(
                    key: const ValueKey('pr-save'),
                    onPressed: _busy || lines.isEmpty ? null : _save,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: Text(l10n.prSave),
                  ),
                ]),
          ),
        ),
      ),
      ),
    );
  }
}

/// One product: chosen or not, in the list or not, its stock and its
/// quantity.
class _RowTile extends StatelessWidget {
  const _RowTile({
    super.key,
    required this.row,
    required this.qty,
    required this.selected,
    required this.anchor,
    required this.onSelect,
    required this.onToggleList,
    required this.onQty,
  });

  final RequestRow row;
  final TextEditingController qty;
  final bool selected;
  final bool anchor;
  final VoidCallback onSelect;
  final VoidCallback onToggleList;
  final ValueChanged<int> onQty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final levels = [
      if (row.onHand != null) l10n.prOnHand(row.onHand!),
      if (row.reorderPoint != null) l10n.prReorder(row.reorderPoint!),
      if (row.maxStock != null) l10n.prMax(row.maxStock!),
    ];
    return Card(
      color: row.inList ? scheme.primaryContainer.withValues(alpha: 0.45) : null,
      shape: anchor
          ? RoundedRectangleBorder(
              side: BorderSide(color: scheme.primary, width: 2), borderRadius: BorderRadius.circular(12))
          : null,
      child: InkWell(
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
          child: Row(children: [
            Checkbox(key: ValueKey('pr-select-${row.key}'), value: selected, onChanged: (_) => onSelect()),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(row.name, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis)),
                  if (row.manual) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Text(l10n.prManualTag, style: theme.textTheme.labelSmall?.copyWith(color: scheme.tertiary)),
                  ],
                ]),
                Text(
                  [
                    if (row.janCode != null) 'JAN ${row.janCode}',
                    if (row.maker != null) row.maker!,
                    if (row.sku != null) row.sku!,
                    if (row.supplierCode != null || row.supplierProductName != null)
                      l10n.prTheirs([row.supplierCode, row.supplierProductName].whereType<String>().join(' ')),
                  ].join(' · '),
                  style: muted,
                  overflow: TextOverflow.ellipsis,
                ),
                if (levels.isNotEmpty)
                  Text(levels.join(' ・ '), key: ValueKey('pr-levels-${row.key}'), style: theme.textTheme.bodySmall),
              ]),
            ),
            SizedBox(
              width: 92,
              child: TextField(
                key: ValueKey('pr-qty-${row.key}'),
                controller: qty,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.end,
                onChanged: (v) => onQty(int.tryParse(v.replaceAll(',', '').trim()) ?? 0),
                decoration: InputDecoration(labelText: l10n.prQty, isDense: true),
              ),
            ),
            IconButton(
              key: ValueKey('pr-toggle-${row.key}'),
              tooltip: row.inList ? l10n.prExclude : l10n.prInclude,
              icon: Icon(row.inList ? Icons.remove_circle_outline : Icons.add_circle_outline,
                  color: row.inList ? scheme.error : scheme.primary),
              onPressed: onToggleList,
            ),
          ]),
        ),
      ),
    );
  }
}

/// A product we do not have in 商品マスタ, typed by hand.
class _ManualRowDialog extends StatefulWidget {
  const _ManualRowDialog({required this.seq});

  final int seq;

  @override
  State<_ManualRowDialog> createState() => _ManualRowDialogState();
}

class _ManualRowDialogState extends State<_ManualRowDialog> {
  late final Map<String, TextEditingController> _c = {
    for (final k in const ['name', 'jan', 'maker', 'code', 'qty', 'unit', 'note']) k: TextEditingController(),
  };
  String? _error;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _v(String k) {
    final t = _c[k]!.text.trim();
    return t.isEmpty ? null : t;
  }

  void _ok() {
    final l10n = AppLocalizations.of(context);
    final name = _v('name');
    final qty = int.tryParse((_v('qty') ?? '').replaceAll(',', ''));
    if (name == null || qty == null || qty <= 0) {
      setState(() => _error = l10n.prManualNeed);
      return;
    }
    Navigator.pop(
      context,
      RequestRow(
        key: 'm${widget.seq}',
        name: name,
        janCode: _v('jan'),
        maker: _v('maker'),
        sku: _v('code'),
        unit: _v('unit'),
        note: _v('note'),
        quantity: qty,
        inList: true,
        manual: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget f(String k, String label, {TextInputType? type}) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: TextField(
            key: ValueKey('pm-$k'),
            controller: _c[k],
            keyboardType: type,
            decoration: InputDecoration(labelText: label, isDense: true),
          ),
        );
    return AlertDialog(
      title: Text(l10n.prAddManual),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            f('name', l10n.prManualName),
            f('jan', l10n.miFieldJan, type: TextInputType.number),
            Row(children: [
              Expanded(child: f('maker', l10n.miFieldMaker)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: f('code', l10n.miFieldCode)),
            ]),
            Row(children: [
              Expanded(child: f('qty', l10n.prQty, type: TextInputType.number)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: f('unit', l10n.miFieldUnit)),
            ]),
            f('note', l10n.obDestNote),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(key: const ValueKey('pm-ok'), onPressed: _ok, child: Text(l10n.prAddManualOk)),
      ],
    );
  }
}
