import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../shipment/application/sender_profile_controller.dart';
import '../../shipment/presentation/shipment_detail_screen.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/outbound_excel.dart';
import '../data/outbound_repository.dart';
import '../domain/outbound.dart';
import '../domain/pricing.dart';
import 'outbound_downloads.dart';
import 'ship_destinations_screen.dart';

enum _Mode { percent, direct }

/// 出庫の提案 (0139): a shipment worked out from the stock. Choose where it
/// goes (a saved destination, or a new one saved on the way), then either a
/// percentage of every product's stock — of all of it, or of what is free to
/// send — or a quantity typed per product. Nothing goes over what is free.
/// The draft can be downloaded as Excel before anything is saved; once the
/// shipment is made, its sheet is ready to send.
class OutboundProposalScreen extends ConsumerStatefulWidget {
  const OutboundProposalScreen({super.key, this.today});

  /// For tests.
  final DateTime? today;

  @override
  ConsumerState<OutboundProposalScreen> createState() => _OutboundProposalScreenState();
}

class _OutboundProposalScreenState extends ConsumerState<OutboundProposalScreen> {
  int? _warehouseId;
  int? _destinationId;
  ShipDestination? _destination;
  DateTime? _shipDate;
  final _note = TextEditingController();
  final _percent = TextEditingController(text: '10');
  final _search = TextEditingController();
  _Mode _mode = _Mode.percent;
  ProposalBase _base = ProposalBase.onHand;
  ProposalRounding _rounding = ProposalRounding.down;
  final Map<String, TextEditingController> _qty = {};
  final Set<String> _off = {};
  bool _busy = false;
  OutboundCreated? _created;

  // Prices (0142): 出荷単価 per product, how it is set in bulk, and which
  // prices the sheet shows.
  final Map<String, TextEditingController> _price = {};
  PriceMethod _priceMethod = PriceMethod.rate;
  PriceColumn _priceBase = PriceColumn.cost;
  final _priceValue = TextEditingController(text: '1.3');
  final _formula = TextEditingController(text: 'ROUNDUP(原価*1.3, -1)');
  double _priceStep = 1;
  PriceRounding _priceRounding = PriceRounding.nearest;
  final Set<PriceColumn> _sheetColumns = {PriceColumn.ship};

  @override
  void dispose() {
    _note.dispose();
    _percent.dispose();
    _search.dispose();
    _priceValue.dispose();
    _formula.dispose();
    for (final c in [..._qty.values, ..._price.values]) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _pc(String jan) => _price.putIfAbsent(jan, () => TextEditingController());

  double? _shipPrice(String jan) => double.tryParse((_price[jan]?.text ?? '').replaceAll(',', '').replaceAll('¥', '').trim());

  /// The bulk price on [items]: each one's 出荷単価 from its base column by a
  /// rate, a percentage or a formula, rounded as chosen. Products without
  /// the base price (no 原価, say) are left as they are.
  void _applyPrices(List<OutboundStockItem> items) {
    final l10n = AppLocalizations.of(context);
    double? value;
    if (_priceMethod == PriceMethod.formula) {
      final err = priceFormulaError(_formula.text);
      if (err != null) return _snack(l10n.obFormulaError(err));
    } else {
      value = double.tryParse(_priceValue.text.replaceAll('%', '').replaceAll(',', '').trim());
      if (value == null) return _snack(l10n.obPriceValueInvalid);
    }
    var set = 0;
    var skipped = 0;
    setState(() {
      for (final i in items) {
        final v = applyPrice(
          i.prices(ship: _shipPrice(i.janCode)),
          method: _priceMethod,
          base: _priceBase,
          value: value,
          formula: _formula.text,
          step: _priceStep,
          rounding: _priceRounding,
        );
        if (v == null) {
          skipped++;
          continue;
        }
        _pc(i.janCode).text = _priceText(v);
        set++;
      }
    });
    _snack(skipped == 0 ? l10n.obPriceApplied(set) : l10n.obPriceAppliedSkipped(set, skipped));
  }

  static String _priceText(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  TextEditingController _c(String jan) => _qty.putIfAbsent(jan, () => TextEditingController());

  static int _int(String s) => int.tryParse(s.replaceAll(',', '').trim()) ?? 0;

  /// JAN → quantity for the products ticked with a quantity.
  Map<String, int> _lines(List<OutboundStockItem> items) => {
        for (final i in items)
          if (!_off.contains(i.janCode) && _int(_c(i.janCode).text) > 0) i.janCode: _int(_c(i.janCode).text),
      };

  void _propose(List<OutboundStockItem> items) {
    final l10n = AppLocalizations.of(context);
    final p = double.tryParse(_percent.text.replaceAll('%', '').trim());
    if (p == null || p < 0 || p > 100) return _snack(l10n.obPercentInvalid);
    final q = proposeByPercent([for (final i in items) if (!_off.contains(i.janCode)) i], p,
        base: _base, rounding: _rounding);
    setState(() {
      for (final e in q.entries) {
        _c(e.key).text = '${e.value}';
      }
    });
    _snack(l10n.obProposed(q.values.where((v) => v > 0).length, q.values.fold(0, (s, v) => s + v)));
  }

  Future<void> _newDestination() async {
    final d = await showDestinationDialog(context);
    if (d != null && mounted) {
      setState(() {
        _destinationId = d.id;
        _destination = d;
      });
    }
  }

  Future<void> _editDestination() async {
    final current = _destination;
    if (current == null) return;
    final d = await showDestinationDialog(context, existing: current);
    if (d != null && mounted) setState(() => _destination = d);
  }

  Future<void> _pickDate() async {
    final today = widget.today ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _shipDate ?? today,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 2),
    );
    if (d != null) setState(() => _shipDate = d);
  }

  String? get _shipDateText => _shipDate == null ? null : DateFormat('y-MM-dd').format(_shipDate!);

  List<OutboundSheetLine> _sheetLines(List<OutboundStockItem> items) {
    final lines = _lines(items);
    return [
      for (final i in items)
        if (lines[i.janCode] case final q?)
          OutboundSheetLine(
            janCode: i.janCode,
            name: i.name,
            quantity: q,
            nameEn: i.nameEn,
            maker: i.maker,
            productCode: i.sku,
            unit: i.unit,
            unitPrice: _shipPrice(i.janCode),
            costPrice: i.costPrice,
            listPrice: i.listPrice,
            sellPrice: i.sellPrice,
          ),
    ];
  }

  Future<void> _draft(List<OutboundStockItem> items) async {
    final l10n = AppLocalizations.of(context);
    final lines = _sheetLines(items);
    if (lines.isEmpty) return _snack(l10n.obNothing);
    final bytes = buildShipmentSheetXlsx(
      number: '',
      to: _destination,
      lines: lines,
      sender: ref.read(senderProfileControllerProvider),
      shipDate: _shipDateText,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      priceColumns: _sheetColumns.toList(),
    );
    await ref.read(saveFileProvider)(shipmentSheetFileName('', _destination?.name), bytes);
    if (mounted) _snack(l10n.obExcelSaved);
  }

  Future<void> _create(List<OutboundStockItem> items) async {
    final l10n = AppLocalizations.of(context);
    final wh = _warehouseId;
    final lines = _lines(items);
    if (wh == null) return _snack(l10n.miChooseWarehouse);
    if (_destinationId == null) return _snack(l10n.obNeedDestination);
    if (lines.isEmpty) return _snack(l10n.obNothing);
    for (final i in items) {
      final q = lines[i.janCode];
      if (q != null && q > i.free) return _snack(l10n.obOverFree(i.name, i.free));
    }
    setState(() => _busy = true);
    final r = await ref.read(outboundRepositoryProvider).create(
          warehouseId: wh,
          lines: lines,
          prices: {
            for (final jan in lines.keys)
              if (_shipPrice(jan) case final p?) jan: p,
          },
          snapshots: {
            for (final i in items)
              if (lines.containsKey(i.janCode)) i.janCode: {'cost': i.costPrice, 'list': i.listPrice, 'sell': i.sellPrice},
          },
          destinationId: _destinationId,
          shipDate: _shipDateText,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          proposal: {
            'mode': _mode.name,
            if (_mode == _Mode.percent) ...{'percent': _percent.text.trim(), 'base': _base.name, 'rounding': _rounding.name},
            'price_columns': [for (final c in PriceColumn.values) if (_sheetColumns.contains(c)) c.wire],
            'pricing': {
              'method': _priceMethod.name,
              'base': _priceBase.wire,
              'value': _priceValue.text.trim(),
              if (_priceMethod == PriceMethod.formula) 'formula': _formula.text.trim(),
              'step': _priceStep,
              'rounding': _priceRounding.name,
            },
          },
        );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess(:final data):
        setState(() => _created = data);
        ref.invalidate(outboundStockProvider(wh));
        ref.invalidate(shipDestinationsProvider);
        _snack(l10n.obCreated(data.shipmentNumber, data.lines, data.units));
      case ApiFailure(:final message):
        final over = RegExp(r'over_free:(\d+):(\d+)').firstMatch(message);
        if (over != null) {
          final name = items.where((i) => i.janCode == over.group(1)).firstOrNull?.name ?? over.group(1)!;
          ref.invalidate(outboundStockProvider(wh));
          return _snack(l10n.obOverFree(name, int.parse(over.group(2)!)));
        }
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    _warehouseId ??= ref.watch(writeWarehouseIdProvider);
    final warehouses = ref.watch(warehouseOverviewProvider).valueOrNull?.warehouses ?? const [];
    final whName = warehouses.where((w) => w.id == _warehouseId).firstOrNull?.name;
    final dests = ref.watch(shipDestinationsProvider).valueOrNull ?? const <ShipDestination>[];
    final wh = _warehouseId;
    final stockAsync = wh == null ? null : ref.watch(outboundStockProvider(wh));
    final items = stockAsync?.valueOrNull ?? const <OutboundStockItem>[];
    final q = _search.text.trim().toLowerCase();
    final shown = q.isEmpty
        ? items
        : [
            for (final i in items)
              if ('${i.name} ${i.janCode} ${i.nameEn ?? ''} ${i.maker ?? ''} ${i.sku ?? ''}'.toLowerCase().contains(q)) i,
          ];
    final lines = _lines(items);
    final total = lines.values.fold(0, (s, v) => s + v);
    final amount = lines.entries.fold<double>(0, (s, e) => s + (_shipPrice(e.key) ?? 0) * e.value);
    final shipping = [for (final i in items) if (lines.containsKey(i.janCode)) i];
    final created = _created;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.featOutboundProposal),
        actions: [
          IconButton(
            key: const ValueKey('ob-stock-excel'),
            tooltip: l10n.obStockExcel,
            icon: const Icon(Icons.download_outlined),
            onPressed: () => downloadStockList(context, ref, warehouseId: wh, warehouseName: whName),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(l10n.obIntro, style: muted),
          const SizedBox(height: AppSpacing.md),
          if (created != null) ...[
            Card(
              key: const ValueKey('ob-created'),
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l10n.obCreated(created.shipmentNumber, created.lines, created.units), style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                    FilledButton.icon(
                      key: const ValueKey('ob-sheet'),
                      onPressed: () => downloadShipmentSheet(context, ref, created.id),
                      icon: const Icon(Icons.grid_on_outlined, size: 18),
                      label: Text(l10n.obSheetExcel),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('ob-open'),
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ShipmentDetailScreen(shipmentId: created.id))),
                      icon: const Icon(Icons.local_shipping_outlined, size: 18),
                      label: Text(l10n.obOpenShipment),
                    ),
                    TextButton(
                      key: const ValueKey('ob-again'),
                      onPressed: () => setState(() {
                        _created = null;
                        for (final c in _qty.values) {
                          c.clear();
                        }
                      }),
                      child: Text(l10n.obAnother),
                    ),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          // Where from, where to.
          if (warehouses.length > 1 || wh == null)
            DropdownButtonFormField<int>(
              key: const ValueKey('ob-warehouse'),
              initialValue: warehouses.any((w) => w.id == wh) ? wh : null,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.miWarehouse),
              items: [for (final w in warehouses) DropdownMenuItem(value: w.id, child: Text(w.name))],
              onChanged: (v) => setState(() => _warehouseId = v),
            ),
          Text(l10n.obDestination, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                key: ValueKey('ob-dest-${dests.length}-$_destinationId'),
                initialValue: dests.any((d) => d.id == _destinationId) ? _destinationId : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.obChooseDestination, isDense: true),
                items: [
                  for (final d in dests)
                    DropdownMenuItem(value: d.id, child: Text([d.name, if (d.department != null) d.department!].join(' '))),
                ],
                onChanged: (v) => setState(() {
                  _destinationId = v;
                  _destination = dests.where((d) => d.id == v).firstOrNull;
                }),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              key: const ValueKey('ob-dest-new'),
              tooltip: l10n.obDestNew,
              icon: const Icon(Icons.add_location_alt_outlined),
              onPressed: _newDestination,
            ),
            if (_destination != null)
              IconButton(
                key: const ValueKey('ob-dest-edit'),
                tooltip: l10n.obDestEdit,
                icon: const Icon(Icons.edit_location_alt_outlined),
                onPressed: _editDestination,
              ),
          ]),
          if (_destination case final d?)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                [
                  if (d.department != null) d.department!,
                  if (d.contactName != null) l10n.obDestAttn(d.contactName!),
                  if (d.addressLine.isNotEmpty) d.addressLine,
                  if (d.phone != null) 'TEL ${d.phone}',
                ].join(' · '),
                key: const ValueKey('ob-dest-summary'),
                style: muted,
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
            OutlinedButton.icon(
              key: const ValueKey('ob-date'),
              onPressed: _pickDate,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(_shipDateText == null ? l10n.obShipDate : l10n.obShipDateIs(_shipDateText!)),
            ),
            SizedBox(
              width: 320,
              child: TextField(
                key: const ValueKey('ob-note'),
                controller: _note,
                decoration: InputDecoration(labelText: l10n.obDestNote, isDense: true),
              ),
            ),
          ]),
          const SizedBox(height: AppSpacing.lg),

          // How much.
          Text(l10n.obHowMuch, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          SegmentedButton<_Mode>(
            key: const ValueKey('ob-mode'),
            segments: [
              ButtonSegment(value: _Mode.percent, icon: const Icon(Icons.percent, size: 18), label: Text(l10n.obModePercent)),
              ButtonSegment(value: _Mode.direct, icon: const Icon(Icons.edit_outlined, size: 18), label: Text(l10n.obModeDirect)),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_mode == _Mode.percent)
            Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(
                width: 110,
                child: TextField(
                  key: const ValueKey('ob-percent'),
                  controller: _percent,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: l10n.obPercent, suffixText: '%', isDense: true),
                ),
              ),
              SegmentedButton<ProposalBase>(
                key: const ValueKey('ob-base'),
                segments: [
                  ButtonSegment(value: ProposalBase.onHand, label: Text(l10n.obBaseOnHand)),
                  ButtonSegment(value: ProposalBase.free, label: Text(l10n.obBaseFree)),
                ],
                selected: {_base},
                onSelectionChanged: (s) => setState(() => _base = s.first),
              ),
              DropdownButton<ProposalRounding>(
                key: const ValueKey('ob-rounding'),
                value: _rounding,
                items: [
                  DropdownMenuItem(value: ProposalRounding.down, child: Text(l10n.obRoundDown)),
                  DropdownMenuItem(value: ProposalRounding.nearest, child: Text(l10n.obRoundNearest)),
                  DropdownMenuItem(value: ProposalRounding.up, child: Text(l10n.obRoundUp)),
                ],
                onChanged: (v) => setState(() => _rounding = v ?? _rounding),
              ),
              FilledButton.icon(
                key: const ValueKey('ob-propose'),
                onPressed: items.isEmpty ? null : () => _propose(items),
                icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
                label: Text(l10n.obPropose),
              ),
            ])
          else
            Text(l10n.obDirectHint, style: muted),
          Text(l10n.obCapNote, style: muted),
          const SizedBox(height: AppSpacing.lg),

          // Prices (0142).
          Text(l10n.obPriceTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<PriceColumn>(
                key: const ValueKey('ob-price-base'),
                initialValue: _priceBase,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.obPriceBase, isDense: true),
                items: [
                  for (final c in PriceColumn.values) DropdownMenuItem(value: c, child: Text(_baseLabel(l10n, c))),
                ],
                onChanged: (v) => setState(() => _priceBase = v ?? _priceBase),
              ),
            ),
            SegmentedButton<PriceMethod>(
              key: const ValueKey('ob-price-method'),
              segments: [
                ButtonSegment(value: PriceMethod.rate, label: Text(l10n.obPriceRate)),
                ButtonSegment(value: PriceMethod.percent, label: Text(l10n.obPricePercent)),
                ButtonSegment(value: PriceMethod.formula, label: Text(l10n.obPriceFormula)),
              ],
              selected: {_priceMethod},
              onSelectionChanged: (v) => setState(() => _priceMethod = v.first),
            ),
            if (_priceMethod == PriceMethod.formula)
              SizedBox(
                width: 340,
                child: TextField(
                  key: const ValueKey('ob-price-formula'),
                  controller: _formula,
                  style: const TextStyle(fontFamily: 'monospace'),
                  decoration: InputDecoration(labelText: l10n.obPriceFormula, isDense: true, prefixText: '= '),
                ),
              )
            else
              SizedBox(
                width: 130,
                child: TextField(
                  key: const ValueKey('ob-price-value'),
                  controller: _priceValue,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: InputDecoration(
                    labelText: _priceMethod == PriceMethod.rate ? l10n.obPriceRate : l10n.obPricePercent,
                    suffixText: _priceMethod == PriceMethod.percent ? '%' : '×',
                    isDense: true,
                  ),
                ),
              ),
            DropdownButton<double>(
              key: const ValueKey('ob-price-step'),
              value: _priceStep,
              items: [
                DropdownMenuItem(value: 0.01, child: Text(l10n.obStepCent)),
                DropdownMenuItem(value: 1, child: Text(l10n.obStep(1))),
                DropdownMenuItem(value: 10, child: Text(l10n.obStep(10))),
                DropdownMenuItem(value: 100, child: Text(l10n.obStep(100))),
              ],
              onChanged: (v) => setState(() => _priceStep = v ?? _priceStep),
            ),
            DropdownButton<PriceRounding>(
              key: const ValueKey('ob-price-rounding'),
              value: _priceRounding,
              items: [
                DropdownMenuItem(value: PriceRounding.down, child: Text(l10n.obRoundDown)),
                DropdownMenuItem(value: PriceRounding.nearest, child: Text(l10n.obRoundNearest)),
                DropdownMenuItem(value: PriceRounding.up, child: Text(l10n.obRoundUp)),
              ],
              onChanged: (v) => setState(() => _priceRounding = v ?? _priceRounding),
            ),
            FilledButton.tonal(
              key: const ValueKey('ob-price-apply'),
              onPressed: shipping.isEmpty ? null : () => _applyPrices(shipping),
              child: Text(l10n.obPriceApplyShipping(shipping.length)),
            ),
            OutlinedButton(
              key: const ValueKey('ob-price-apply-all'),
              onPressed: shown.isEmpty ? null : () => _applyPrices(shown),
              child: Text(l10n.obPriceApplyShown(shown.length)),
            ),
          ]),
          Text(switch (_priceMethod) {
            PriceMethod.rate => l10n.obPriceRateHint,
            PriceMethod.percent => l10n.obPricePercentHint,
            PriceMethod.formula => l10n.obPriceFormulaHint,
          }, style: muted),
          const SizedBox(height: AppSpacing.sm),
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(l10n.obSheetColumns, style: theme.textTheme.labelLarge),
            for (final c in PriceColumn.values)
              FilterChip(
                key: ValueKey('ob-col-${c.wire}'),
                label: Text(_columnLabel(l10n, c)),
                selected: _sheetColumns.contains(c),
                onSelected: (v) => setState(() => v ? _sheetColumns.add(c) : _sheetColumns.remove(c)),
              ),
          ]),
          const SizedBox(height: AppSpacing.md),

          // The products.
          TextField(
            key: const ValueKey('ob-search'),
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.obSearch, isDense: true),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (wh == null)
            Text(l10n.miChooseWarehouse, style: muted)
          else if (stockAsync!.isLoading && items.isEmpty)
            LoadingView(message: l10n.loading)
          else if (stockAsync.hasError)
            ErrorStateView(
              message: humanizeApiErrorMessage(l10n, '${stockAsync.error}'),
              onRetry: () => ref.invalidate(outboundStockProvider(wh)),
            )
          else if (items.isEmpty)
            EmptyStateView(icon: Icons.inventory_2_outlined, title: l10n.obNoStock)
          else
            for (final i in shown)
              _ItemCard(
                key: ValueKey('ob-item-${i.janCode}'),
                item: i,
                qty: _c(i.janCode),
                price: _pc(i.janCode),
                included: !_off.contains(i.janCode),
                onIncluded: (v) => setState(() => v ? _off.remove(i.janCode) : _off.add(i.janCode)),
                onChanged: () => setState(() {}),
              ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.obSummary(lines.length, total), key: const ValueKey('ob-summary'), style: theme.textTheme.titleSmall),
          if (amount > 0)
            Text(l10n.obAmountTotal(NumberFormat('#,##0.##').format(amount)),
                key: const ValueKey('ob-amount'), style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
            OutlinedButton.icon(
              key: const ValueKey('ob-draft'),
              onPressed: lines.isEmpty ? null : () => _draft(items),
              icon: const Icon(Icons.grid_on_outlined, size: 18),
              label: Text(l10n.obDraftExcel),
            ),
            FilledButton.icon(
              key: const ValueKey('ob-create'),
              onPressed: _busy || lines.isEmpty ? null : () => _create(items),
              icon: const Icon(Icons.local_shipping_outlined, size: 18),
              label: Text(l10n.obCreate(lines.length)),
            ),
          ]),
        ],
      ),
    );
  }
}

String _columnLabel(AppLocalizations l10n, PriceColumn c) => switch (c) {
      PriceColumn.cost => l10n.obColCost,
      PriceColumn.list => l10n.obColList,
      PriceColumn.sell => l10n.obColSell,
      PriceColumn.ship => l10n.obColShip,
    };

String _money(double? v) => v == null ? '—' : NumberFormat('#,##0.##').format(v);

String _baseLabel(AppLocalizations l10n, PriceColumn c) =>
    c == PriceColumn.ship ? l10n.obBaseShip : _columnLabel(l10n, c);

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    super.key,
    required this.item,
    required this.qty,
    required this.price,
    required this.included,
    required this.onIncluded,
    required this.onChanged,
  });

  final OutboundStockItem item;
  final TextEditingController qty;

  /// 出荷単価 (0142).
  final TextEditingController price;
  final bool included;
  final ValueChanged<bool> onIncluded;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final q = int.tryParse(qty.text.replaceAll(',', '').trim()) ?? 0;
    final over = q > item.free;
    final share = item.onHand == 0 ? 0.0 : q * 100 / item.onHand;
    final shipPrice = double.tryParse(price.text.replaceAll(',', '').trim());
    final loss = shipPrice != null && item.costPrice != null && shipPrice < item.costPrice!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: Row(children: [
          Checkbox(key: ValueKey('ob-check-${item.janCode}'), value: included, onChanged: (v) => onIncluded(v ?? false)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name, style: theme.textTheme.titleSmall),
              Text(['JAN ${item.janCode}', if (item.nameEn != null) item.nameEn!, if (item.maker != null) item.maker!].join(' · '),
                  style: muted),
              Text(
                l10n.obStockLine(item.onHand, item.reserved, item.inOpen, item.free),
                key: ValueKey('ob-stock-${item.janCode}'),
                style: theme.textTheme.bodySmall,
              ),
              Text(
                l10n.obPricesLine(_money(item.costPrice), _money(item.listPrice), _money(item.sellPrice)),
                key: ValueKey('ob-prices-${item.janCode}'),
                style: muted,
              ),
              if (loss)
                Text(l10n.obBelowCost, key: ValueKey('ob-loss-${item.janCode}'),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ]),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 104,
            child: TextField(
              key: ValueKey('ob-price-${item.janCode}'),
              controller: price,
              enabled: included,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.end,
              onChanged: (_) => onChanged(),
              decoration: InputDecoration(labelText: l10n.obColShip, isDense: true, prefixText: '¥'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 96,
            child: TextField(
              key: ValueKey('ob-qty-${item.janCode}'),
              controller: qty,
              enabled: included,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.end,
              onChanged: (_) => onChanged(),
              decoration: InputDecoration(
                labelText: l10n.obQty,
                isDense: true,
                errorText: over ? l10n.obOverShort(item.free) : null,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          SizedBox(
            width: 64,
            child: q == 0
                ? const SizedBox.shrink()
                : StatusPill(
                    tone: over ? StatusTone.danger : StatusTone.info,
                    label: '${share.toStringAsFixed(share >= 10 || share == share.roundToDouble() ? 0 : 1)}%',
                    dense: true,
                  ),
          ),
        ]),
      ),
    );
  }
}
