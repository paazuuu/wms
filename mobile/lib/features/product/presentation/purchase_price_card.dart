import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/time_line_chart.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../partners/domain/trading_partner.dart';
import '../../purchase_request/presentation/purchase_request_screen.dart'
    show requestSuppliersProvider;
import '../data/purchase_price_repository.dart';

/// Who may write a price by hand (0187).
final canRecordPurchasePriceProvider = Provider<bool>((ref) {
  final p =
      ref.watch(authControllerProvider).user?.permissions ?? const <String>[];
  return p.contains('product.manage') ||
      p.contains('inventory.adjust') ||
      p.contains('purchase_order.manage');
});

final _money = NumberFormat('#,##0.##');
String priceText(double? v) => v == null ? '—' : _money.format(v);

/// The series a product's prices are drawn as: the month's average over
/// every supplier, the suppliers bought from most (the rest folded into
/// one), and the shipping lists' prices. Four colors at most.
List<ChartSeries> purchasePriceSeries(
  PurchasePrices data, {
  required List<Color> colors,
  required String averageLabel,
  required String othersLabel,
  required String outboundLabel,
  required String noSupplierLabel,
}) {
  final out = <ChartSeries>[];
  if (data.monthly.isNotEmpty) {
    out.add(ChartSeries(
      id: 'avg',
      label: averageLabel,
      color: colors[0],
      points: [for (final m in data.monthly) ChartPoint(m.month, m.average)],
    ));
  }
  final bought = [
    for (final p in data.points)
      if (p.source != PriceSource.outbound) p
  ];
  final shipped = [
    for (final p in data.points)
      if (p.source == PriceSource.outbound) p
  ];
  final count = <String, int>{};
  final names = <String, String>{};
  for (final p in bought) {
    count[p.supplierKey] = (count[p.supplierKey] ?? 0) + 1;
    names[p.supplierKey] =
        p.supplierName.isEmpty ? noSupplierLabel : p.supplierName;
  }
  final ranked = count.keys.toList()
    ..sort((a, b) => count[b]!.compareTo(count[a]!));
  // Slots 1 and 2 for suppliers (3 too when no shipping list is drawn); the
  // rest share one line.
  final room = shipped.isEmpty ? 3 : 2;
  final own = ranked.length <= room ? ranked : ranked.take(room - 1).toList();
  for (final (i, key) in own.indexed) {
    out.add(ChartSeries(
      id: key,
      label: names[key]!,
      color: colors[1 + i],
      points: [
        for (final p in bought)
          if (p.supplierKey == key) ChartPoint(p.day, p.unitPrice)
      ],
    ));
  }
  if (ranked.length > own.length) {
    out.add(ChartSeries(
      id: 'others',
      label: othersLabel,
      color: colors[1 + own.length],
      points: [
        for (final p in bought)
          if (!own.contains(p.supplierKey)) ChartPoint(p.day, p.unitPrice)
      ],
    ));
  }
  if (shipped.isNotEmpty) {
    out.add(ChartSeries(
      id: 'outbound',
      label: outboundLabel,
      color: colors[3],
      points: [for (final p in shipped) ChartPoint(p.day, p.unitPrice)],
    ));
  }
  return out;
}

/// 仕入れ値の推移 (0187): every time the product was bought, from which
/// supplier and at what price (税抜) — drawn by supplier with the month's
/// average over all of them, the shipping lists' prices beside — then the
/// same as tables: by supplier, by month, each record. A price can be
/// written by hand. Hidden from those who may not see what was paid.
class PurchasePriceCard extends ConsumerWidget {
  const PurchasePriceCard({super.key, required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final async = ref.watch(purchasePricesProvider(productId));
    final canRecord = ref.watch(canRecordPurchasePriceProvider);
    if (async.hasError && '${async.error}'.contains('not permitted')) {
      return const SizedBox.shrink();
    }
    return Card(
      key: const ValueKey('pp-card'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(l10n.ppTitle,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
            if (canRecord)
              TextButton.icon(
                key: const ValueKey('pp-record'),
                onPressed: () => _record(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.ppRecord),
              ),
          ]),
          async.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: LinearProgressIndicator()),
            error: (e, _) => Text(humanizeApiErrorMessage(l10n, '$e'),
                style: TextStyle(color: theme.colorScheme.error)),
            data: (data) => data.isEmpty
                ? Text(l10n.ppEmpty,
                    key: const ValueKey('pp-empty'), style: muted)
                : _PriceBody(
                    productId: productId, data: data, canRecord: canRecord),
          ),
        ]),
      ),
    );
  }

  Future<void> _record(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
        context: context, builder: (_) => _RecordDialog(productId: productId));
    if (ok == true) {
      ref.invalidate(purchasePricesProvider(productId));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.ppSaved)));
    }
  }
}

class _PriceBody extends ConsumerStatefulWidget {
  const _PriceBody(
      {required this.productId, required this.data, required this.canRecord});

  final int productId;
  final PurchasePrices data;
  final bool canRecord;

  @override
  ConsumerState<_PriceBody> createState() => _PriceBodyState();
}

class _PriceBodyState extends ConsumerState<_PriceBody> {
  bool _all = false;

  String _sourceLabel(AppLocalizations l10n, PriceSource s) => switch (s) {
        PriceSource.receipt => l10n.ppSourceReceipt,
        PriceSource.manual => l10n.ppSourceManual,
        PriceSource.outbound => l10n.ppSourceOutbound,
      };

  Future<void> _withdraw(PricePoint p) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final r =
        await ref.read(purchasePriceRepositoryProvider).withdraw(p.entryId!);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess():
        ref.invalidate(purchasePricesProvider(widget.productId));
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.ppWithdrawn)));
      case ApiFailure(:final message):
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
              SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final head = theme.textTheme.titleSmall;
    final day = DateFormat('y/MM/dd');
    final data = widget.data;
    final series = purchasePriceSeries(
      data,
      colors: [for (var i = 0; i < 4; i++) chartSlot(context, i)],
      averageLabel: l10n.ppMonthlyAvg,
      othersLabel: l10n.ppOthers,
      outboundLabel: l10n.ppOutbound,
      noSupplierLabel: l10n.ppNoSupplier,
    );
    final points = data.points.reversed.toList();
    final shown = _all ? points : points.take(10).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ChartLegend(series: series),
      const SizedBox(height: AppSpacing.sm),
      TimeLineChart(
        key: const ValueKey('pp-chart'),
        series: series,
        formatY: priceText,
        details: (x) => [
          for (final p in data.points)
            if (p.day == x)
              '${p.supplierName.isEmpty ? l10n.ppNoSupplier : p.supplierName} ${priceText(p.unitPrice)}',
        ],
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(l10n.ppTaxNote, style: muted),
      const Divider(),
      Text(l10n.ppBySupplier, style: head),
      for (final s in data.suppliers)
        ListTile(
          key: ValueKey('pp-supplier-${s.supplierKey}'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.storefront_outlined, size: 20),
          title:
              Text(s.supplierName.isEmpty ? l10n.ppNoSupplier : s.supplierName),
          subtitle: Text(l10n.ppSupplierRow(
              priceText(s.lastPrice),
              s.lastDay == null ? '—' : day.format(s.lastDay!),
              priceText(s.average),
              s.count)),
        ),
      if (data.monthly.isNotEmpty) ...[
        const Divider(),
        Text(l10n.ppMonthly, style: head),
        for (final m in data.monthly.reversed.take(12))
          ListTile(
            key: ValueKey('pp-month-${m.month.year}-${m.month.month}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(DateFormat('y/MM').format(m.month)),
            trailing: Text(
                l10n.ppMonthRow(priceText(m.average), priceText(m.min),
                    priceText(m.max), m.quantity),
                style: theme.textTheme.bodySmall),
          ),
      ],
      const Divider(),
      Text(l10n.ppHistory, style: head),
      for (final p in shown)
        ListTile(
          key: ValueKey('pp-point-${p.id}'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
              '${priceText(p.unitPrice)}（${priceText(p.unitPriceTax)}）  ${p.supplierName.isEmpty ? l10n.ppNoSupplier : p.supplierName}'),
          subtitle: Text([
            day.format(p.day),
            _sourceLabel(l10n, p.source),
            if (p.quantity != null) '× ${p.quantity}',
            if (p.fileName != null) p.fileName!,
            if (p.note != null) p.note!,
          ].join(' · ')),
          trailing: p.entryId != null && widget.canRecord
              ? IconButton(
                  key: ValueKey('pp-withdraw-${p.entryId}'),
                  tooltip: l10n.ppWithdraw,
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: () => _withdraw(p),
                )
              : null,
        ),
      if (points.length > shown.length)
        TextButton(
          key: const ValueKey('pp-more'),
          onPressed: () => setState(() => _all = true),
          child: Text(l10n.ppMore(points.length - shown.length)),
        ),
    ]);
  }
}

/// A price written by hand: supplier (from the list, or a name), 税抜 price,
/// tax rate, quantity, day, note.
class _RecordDialog extends ConsumerStatefulWidget {
  const _RecordDialog({required this.productId});

  final int productId;

  @override
  ConsumerState<_RecordDialog> createState() => _RecordDialogState();
}

class _RecordDialogState extends ConsumerState<_RecordDialog> {
  final _price = TextEditingController();
  final _rate = TextEditingController(text: '10');
  final _qty = TextEditingController();
  final _name = TextEditingController();
  final _note = TextEditingController();
  int? _supplierId;
  bool _other = false;
  DateTime _day = DateTime.now();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _price.dispose();
    _rate.dispose();
    _qty.dispose();
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final price = double.tryParse(_price.text.trim().replaceAll(',', ''));
    if (price == null || price < 0) {
      setState(() => _error = l10n.ppErrPrice);
      return;
    }
    if (_supplierId == null && _name.text.trim().isEmpty) {
      setState(() => _error = l10n.ppErrSupplier);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await ref.read(purchasePriceRepositoryProvider).record(
          productId: widget.productId,
          unitPrice: price,
          pricedOn: _day,
          supplierId: _other ? null : _supplierId,
          supplierName: _other ? _name.text.trim() : null,
          taxRate: double.tryParse(_rate.text.trim()) ?? 10,
          quantity: int.tryParse(_qty.text.trim()),
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        );
    if (!mounted) return;
    switch (r) {
      case ApiSuccess():
        Navigator.pop(context, true);
      case ApiFailure(:final message):
        setState(() {
          _busy = false;
          _error = humanizeApiErrorMessage(l10n, message);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final suppliers = ref.watch(requestSuppliersProvider).valueOrNull ??
        const <TradingPartner>[];
    return AlertDialog(
      key: const ValueKey('pp-dialog'),
      title: Text(l10n.ppRecord),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<int?>(
                  key: const ValueKey('pp-supplier'),
                  initialValue: _other ? -1 : _supplierId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.ppSupplier),
                  items: [
                    for (final s in suppliers)
                      DropdownMenuItem<int?>(
                          value: s.id,
                          child: Text(s.name, overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem<int?>(
                        value: -1, child: Text(l10n.ppSupplierOther)),
                  ],
                  onChanged: (v) => setState(() {
                    _other = v == -1;
                    _supplierId = v == -1 ? null : v;
                  }),
                ),
                if (_other || suppliers.isEmpty)
                  TextField(
                    key: const ValueKey('pp-supplier-name'),
                    controller: _name,
                    decoration: InputDecoration(labelText: l10n.ppSupplierName),
                    onChanged: (_) => _other = true,
                  ),
                TextField(
                  key: const ValueKey('pp-price'),
                  controller: _price,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                  ],
                  decoration: InputDecoration(labelText: l10n.ppPriceEx),
                ),
                Row(children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('pp-rate'),
                      controller: _rate,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: l10n.ppTaxRate),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('pp-qty'),
                      controller: _qty,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(labelText: l10n.ppQty),
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  key: const ValueKey('pp-date'),
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text(
                      '${l10n.ppDate}: ${DateFormat('y/MM/dd').format(_day)}'),
                  onPressed: () async {
                    final d = await showDatePicker(
                        context: context,
                        initialDate: _day,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100));
                    if (d != null) setState(() => _day = d);
                  },
                ),
                TextField(
                  key: const ValueKey('pp-note'),
                  controller: _note,
                  decoration: InputDecoration(labelText: l10n.ppNote),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
              ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('pp-save'),
          onPressed: _busy ? null : _save,
          child: Text(l10n.ppSave),
        ),
      ],
    );
  }
}
