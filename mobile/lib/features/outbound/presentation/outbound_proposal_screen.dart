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

  @override
  void dispose() {
    _note.dispose();
    _percent.dispose();
    _search.dispose();
    for (final c in _qty.values) {
      c.dispose();
    }
    super.dispose();
  }

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
            janCode: i.janCode, name: i.name, quantity: q, nameEn: i.nameEn, maker: i.maker, productCode: i.sku, unit: i.unit),
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
          destinationId: _destinationId,
          shipDate: _shipDateText,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          proposal: {
            'mode': _mode.name,
            if (_mode == _Mode.percent) ...{'percent': _percent.text.trim(), 'base': _base.name, 'rounding': _rounding.name},
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
                included: !_off.contains(i.janCode),
                onIncluded: (v) => setState(() => v ? _off.remove(i.janCode) : _off.add(i.janCode)),
                onChanged: () => setState(() {}),
              ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.obSummary(lines.length, total), key: const ValueKey('ob-summary'), style: theme.textTheme.titleSmall),
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

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    super.key,
    required this.item,
    required this.qty,
    required this.included,
    required this.onIncluded,
    required this.onChanged,
  });

  final OutboundStockItem item;
  final TextEditingController qty;
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
            ]),
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
