import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/virtual_stock_providers.dart';
import '../domain/virtual_stock.dart';

DateTime _monthStart(DateTime d) => DateTime(d.year, d.month);
DateTime _monthEnd(DateTime d) => DateTime(d.year, d.month + 1, 0);
String _ym(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

/// A rough figure for what sits in a warehouse abroad (0088).
///
/// Goods sent across the border leave real stock the moment they ship (0087),
/// because few people know what that warehouse ships out afterwards. This is
/// the separate, virtual view: what arrived from Japan, what someone typed in,
/// and — month by month over a chosen range — how the figure moved. A count
/// typed in resets it; the gap it closes is shown as its own number, which is
/// mostly what left the warehouse without anyone recording it.
class VirtualStockScreen extends ConsumerStatefulWidget {
  const VirtualStockScreen({super.key});

  @override
  ConsumerState<VirtualStockScreen> createState() => _VirtualStockScreenState();
}

class _VirtualStockScreenState extends ConsumerState<VirtualStockScreen> {
  int? _warehouseId;
  late DateTime _fromMonth = _monthStart(DateTime(DateTime.now().year, DateTime.now().month - 2));
  late DateTime _toMonth = _monthStart(DateTime.now());

  VirtualSummaryKey? get _key => _warehouseId == null
      ? null
      : (warehouseId: _warehouseId!, from: _fromMonth, to: _monthEnd(_toMonth));

  List<DateTime> get _monthChoices {
    final now = DateTime.now();
    return [for (var i = 0; i < 24; i++) DateTime(now.year, now.month - i)];
  }

  void _refresh() {
    final key = _key;
    if (key != null) ref.invalidate(virtualStockSummaryProvider(key));
  }

  Future<void> _record({VirtualProduct? product}) async {
    final l10n = AppLocalizations.of(context);
    final id = _warehouseId;
    if (id == null) return;
    final draft = await showDialog<_EntryDraft>(
      context: context,
      builder: (_) => _EntryDialog(janCode: product?.janCode, productName: product?.productName),
    );
    if (draft == null || !mounted) return;
    final result = await ref.read(virtualStockRepositoryProvider).record(
          warehouseId: id,
          janCode: draft.janCode,
          type: draft.type,
          quantity: draft.quantity,
          occurredOn: draft.date,
          note: draft.note,
        );
    if (!mounted) return;
    result.when(
      success: (_) {
        _refresh();
        _snack(l10n.virtualRecorded);
      },
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  void _snack(String message, {bool danger = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: danger ? Theme.of(context).colorScheme.error : null,
      ));
  }

  Future<void> _history(VirtualProduct product) async {
    final id = _warehouseId;
    if (id == null) return;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _HistorySheet(warehouseId: id, product: product),
    );
    if (changed == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final warehouses = ref.watch(virtualWarehousesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.virtualTitle)),
      floatingActionButton: _warehouseId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _record(),
              icon: const Icon(Icons.edit_note),
              label: Text(l10n.virtualRecord),
            ),
      body: warehouses.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(virtualWarehousesProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyStateView(
              icon: Icons.public_off,
              title: l10n.virtualNoWarehouse,
              message: l10n.virtualNoWarehouseBody,
            );
          }
          _warehouseId ??= list.first.id;
          final key = _key!;
          final summary = ref.watch(virtualStockSummaryProvider(key));
          return ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
            children: [
              Text(l10n.virtualExplain, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.md),
              if (list.length > 1)
                DropdownButtonFormField<int>(
                  initialValue: _warehouseId,
                  decoration: InputDecoration(labelText: l10n.virtualWarehouse),
                  items: [
                    for (final w in list)
                      DropdownMenuItem(value: w.id, child: Text('${w.name}（${w.countryCode}）')),
                  ],
                  onChanged: (v) => setState(() => _warehouseId = v),
                ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<DateTime>(
                      key: const ValueKey('virtual-from'),
                      initialValue: _fromMonth,
                      decoration: InputDecoration(labelText: l10n.virtualFromMonth),
                      items: [
                        for (final m in _monthChoices)
                          DropdownMenuItem(value: m, child: Text(_ym(m))),
                      ],
                      onChanged: (v) => setState(() {
                        _fromMonth = v ?? _fromMonth;
                        if (_toMonth.isBefore(_fromMonth)) _toMonth = _fromMonth;
                      }),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: DropdownButtonFormField<DateTime>(
                      key: ValueKey('virtual-to-${_ym(_toMonth)}'),
                      initialValue: _toMonth,
                      decoration: InputDecoration(labelText: l10n.virtualToMonth),
                      items: [
                        for (final m in _monthChoices)
                          if (!m.isBefore(_fromMonth))
                            DropdownMenuItem(value: m, child: Text(_ym(m))),
                      ],
                      onChanged: (v) => setState(() => _toMonth = v ?? _toMonth),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ...summary.when(
                loading: () => [const Center(child: CircularProgressIndicator())],
                error: (e, _) => [
                  ErrorStateView(message: '$e', onRetry: _refresh),
                ],
                data: (s) => [
                  _FiguresCard(title: l10n.virtualRangeTotal(_ym(_fromMonth), _ym(_toMonth)), figures: s.totals),
                  const SizedBox(height: AppSpacing.md),
                  if (s.months.length > 1) ...[
                    Text(l10n.virtualByMonth, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    _MonthTable(months: s.months),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Text(l10n.virtualByProduct, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  if (s.products.isEmpty)
                    Text(l10n.virtualEmpty, style: Theme.of(context).textTheme.bodySmall),
                  for (final p in s.products)
                    _ProductCard(
                      product: p,
                      onTap: () => _history(p),
                      onRecord: () => _record(product: p),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FiguresCard extends StatelessWidget {
  const _FiguresCard({required this.title, required this.figures});

  final String title;
  final VirtualFigures figures;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final nf = NumberFormat.decimalPattern();
    Widget figure(String label, int value, {bool strong = false, bool signed = false}) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  maxLines: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  signed && value > 0 ? '+${nf.format(value)}' : nf.format(value),
                  style: (strong ? theme.textTheme.titleLarge : theme.textTheme.titleMedium)
                      ?.copyWith(fontFamily: AppFonts.mono, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                figure(l10n.virtualOpening, figures.opening),
                figure(l10n.virtualArrived, figures.arrived, signed: true),
                figure(l10n.virtualAdjusted, figures.adjusted, signed: true),
                figure(l10n.virtualCountDiff, figures.countDiff, signed: true),
                figure(l10n.virtualClosing, figures.closing, strong: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthTable extends StatelessWidget {
  const _MonthTable({required this.months});

  final List<VirtualMonth> months;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nf = NumberFormat.decimalPattern();
    String s(int v, {bool signed = false}) => signed && v > 0 ? '+${nf.format(v)}' : nf.format(v);
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: AppSpacing.lg,
          columns: [
            DataColumn(label: Text(l10n.virtualMonth)),
            DataColumn(label: Text(l10n.virtualOpening), numeric: true),
            DataColumn(label: Text(l10n.virtualArrived), numeric: true),
            DataColumn(label: Text(l10n.virtualAdjusted), numeric: true),
            DataColumn(label: Text(l10n.virtualCountDiff), numeric: true),
            DataColumn(label: Text(l10n.virtualClosing), numeric: true),
          ],
          rows: [
            for (final m in months)
              DataRow(cells: [
                DataCell(Text(m.month)),
                DataCell(Text(s(m.figures.opening))),
                DataCell(Text(s(m.figures.arrived, signed: true))),
                DataCell(Text(s(m.figures.adjusted, signed: true))),
                DataCell(Text(s(m.figures.countDiff, signed: true))),
                DataCell(Text(s(m.figures.closing))),
              ]),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onTap, required this.onRecord});

  final VirtualProduct product;
  final VoidCallback onTap;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final nf = NumberFormat.decimalPattern();
    final df = DateFormat('yyyy-MM-dd');
    final f = product.figures;
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(product.productName.isNotEmpty ? product.productName : product.janCode),
        subtitle: Text([
          product.janCode,
          l10n.virtualProductLine(f.opening, f.arrived, f.adjusted + f.countDiff),
          if (product.lastCountOn != null)
            l10n.virtualLastCount(df.format(product.lastCountOn!), product.lastCounted ?? 0),
        ].join('\n')),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(nf.format(f.closing),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontFamily: AppFonts.mono, fontWeight: FontWeight.w600)),
            IconButton(
              tooltip: l10n.virtualRecord,
              icon: const Icon(Icons.edit_note),
              onPressed: onRecord,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistorySheet extends ConsumerWidget {
  const _HistorySheet({required this.warehouseId, required this.product});

  final int warehouseId;
  final VirtualProduct product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final df = DateFormat('yyyy-MM-dd');
    final key = (warehouseId: warehouseId, productId: product.productId);
    final async = ref.watch(virtualStockHistoryProvider(key));

    String label(VirtualStockEntry e) => switch (e.type) {
          VirtualEntryType.exportIn =>
            l10n.virtualEntryExport(e.quantity, e.transferNumber ?? ''),
          VirtualEntryType.count => l10n.virtualEntryCount(e.countedQuantity ?? 0),
          VirtualEntryType.adjust =>
            l10n.virtualEntryAdjust(e.quantity > 0 ? '+${e.quantity}' : '${e.quantity}'),
        };

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            ListTile(
              title: Text(product.productName, style: theme.textTheme.titleMedium),
              subtitle: Text(l10n.virtualHistory),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (entries) => ListView(
                  children: [
                    for (final e in entries)
                      ListTile(
                        dense: true,
                        title: Text(label(e)),
                        subtitle: Text([
                          df.format(e.occurredOn),
                          l10n.virtualBalanceThatDay(e.balanceThatDay),
                          if (e.note != null) e.note!,
                        ].join(' · ')),
                        trailing: e.isManual
                            ? IconButton(
                                tooltip: l10n.actionDelete,
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  final result = await ref
                                      .read(virtualStockRepositoryProvider)
                                      .delete(e.id);
                                  if (!context.mounted) return;
                                  result.when(
                                    success: (_) {
                                      ref.invalidate(virtualStockHistoryProvider(key));
                                      Navigator.pop(context, true);
                                    },
                                    failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                humanizeApiErrorMessage(l10n, f.message)))),
                                  );
                                },
                              )
                            : null,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryDraft {
  const _EntryDraft({
    required this.janCode,
    required this.type,
    required this.quantity,
    required this.date,
    this.note,
  });

  final String janCode;
  final VirtualEntryType type;
  final int quantity;
  final DateTime date;
  final String? note;
}

/// A count ("there are N now") or a known change (+/-), for one product.
class _EntryDialog extends StatefulWidget {
  const _EntryDialog({this.janCode, this.productName});

  final String? janCode;
  final String? productName;

  @override
  State<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<_EntryDialog> {
  late final _jan = TextEditingController(text: widget.janCode ?? '');
  final _qty = TextEditingController();
  final _note = TextEditingController();
  VirtualEntryType _type = VirtualEntryType.count;
  DateTime _date = DateTime.now();
  bool _out = true;

  @override
  void dispose() {
    _jan.dispose();
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  int? get _quantity {
    final v = int.tryParse(_qty.text.trim());
    if (v == null) return null;
    if (_type == VirtualEntryType.count) return v >= 0 ? v : null;
    if (v <= 0) return null;
    return _out ? -v : v;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final df = DateFormat('yyyy-MM-dd');
    final valid = _jan.text.trim().isNotEmpty && _quantity != null;
    return AlertDialog(
      title: Text(widget.productName ?? l10n.virtualRecord),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<VirtualEntryType>(
              segments: [
                ButtonSegment(value: VirtualEntryType.count, label: Text(l10n.virtualTypeCount)),
                ButtonSegment(value: VirtualEntryType.adjust, label: Text(l10n.virtualTypeAdjust)),
              ],
              selected: {_type},
              onSelectionChanged: (v) => setState(() => _type = v.first),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(_type == VirtualEntryType.count ? l10n.virtualTypeCountHint : l10n.virtualTypeAdjustHint,
                style: Theme.of(context).textTheme.bodySmall),
            if (widget.janCode == null)
              TextField(
                key: const ValueKey('virtual-jan'),
                controller: _jan,
                decoration: InputDecoration(labelText: l10n.adjJan),
                onChanged: (_) => setState(() {}),
              ),
            if (_type == VirtualEntryType.adjust)
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  ChoiceChip(
                    label: Text(l10n.virtualAdjustOut),
                    selected: _out,
                    onSelected: (_) => setState(() => _out = true),
                  ),
                  ChoiceChip(
                    label: Text(l10n.virtualAdjustIn),
                    selected: !_out,
                    onSelected: (_) => setState(() => _out = false),
                  ),
                ],
              ),
            TextField(
              key: const ValueKey('virtual-qty'),
              controller: _qty,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: _type == VirtualEntryType.count
                    ? l10n.virtualCountedQuantity
                    : l10n.virtualAdjustQuantity,
              ),
              onChanged: (_) => setState(() {}),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.virtualDate),
              subtitle: Text(df.format(_date)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(DateTime.now().year - 3),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            TextField(
              controller: _note,
              decoration: InputDecoration(labelText: l10n.virtualNote),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: !valid
              ? null
              : () => Navigator.pop(
                    context,
                    _EntryDraft(
                      janCode: _jan.text.trim(),
                      type: _type,
                      quantity: _quantity!,
                      date: _date,
                      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
                    ),
                  ),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
