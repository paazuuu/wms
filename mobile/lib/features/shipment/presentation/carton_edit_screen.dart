import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../application/shipment_providers.dart';
import '../domain/carton.dart';
import '../domain/shipment.dart';
import 'shipment_status_ui.dart';

/// Pack a carton: record parcels against it one at a time (0076/0079). Each
/// call to `pack_carton_item` *adds* a parcel rather than declaring a final
/// state — the same additive shape `record_pick_item` has on the picking
/// side — bounded by what the whole shipment still has left to pack
/// ([PackableLine.unpacked]), not by what this carton alone was asked to
/// hold. Reads through [shipmentPackingProvider], which — unlike the
/// `shipments` edge function's embedded cartons — joins each parcel's lot
/// code and serial number, because that identity is §17's whole point.
class CartonEditScreen extends ConsumerStatefulWidget {
  const CartonEditScreen({
    super.key,
    required this.shipment,
    required this.carton,
  });

  final Shipment shipment;
  final Carton carton;

  @override
  ConsumerState<CartonEditScreen> createState() => _CartonEditScreenState();
}

class _CartonEditScreenState extends ConsumerState<CartonEditScreen> {
  bool _busy = false;

  int get _planId => widget.shipment.id;
  int get _cartonId => widget.carton.id;

  void _snack(String message, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: danger ? Theme.of(context).colorScheme.error : null,
      ));
  }

  void _refresh() {
    ref.invalidate(shipmentPackingProvider(_planId));
    ref.invalidate(shipmentDetailProvider(_planId));
    ref.invalidate(shipmentsListProvider);
  }

  Future<void> _rename(Carton carton) async {
    final l10n = AppLocalizations.of(context);
    final label = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: carton.label ?? ''),
    );
    if (label == null || !mounted) return;

    setState(() => _busy = true);
    final result = await ref
        .read(shipmentRepositoryProvider)
        .setCartonLabel(_cartonId, label.isEmpty ? null : label);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) => _refresh(),
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  Future<void> _addParcel(PackableLine line) async {
    final l10n = AppLocalizations.of(context);
    final draft = await showDialog<_ParcelDraft>(
      context: context,
      builder: (_) => _PackDialog(line: line),
    );
    if (draft == null || !mounted) return;

    setState(() => _busy = true);
    final result = await ref.read(shipmentRepositoryProvider).packCartonItem(
          _cartonId,
          quantity: draft.quantity,
          janCode: line.janCode,
          lotCode: draft.lotCode,
          serialNumber: draft.serialNumber,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) => _refresh(),
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  Future<void> _removeItem(CartonItem item) async {
    final l10n = AppLocalizations.of(context);
    final id = item.id;
    if (id == null) return;
    setState(() => _busy = true);
    final result =
        await ref.read(shipmentRepositoryProvider).removeCartonItem(id);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) => _refresh(),
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(shipmentPackingProvider(_planId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cartonEditTitle)),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(shipmentPackingProvider(_planId)),
        ),
        data: (packing) {
          final carton = packing.cartons.firstWhere(
            (c) => c.id == _cartonId,
            orElse: () => widget.carton,
          );
          return _body(context, l10n, packing, carton);
        },
      ),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n,
      ShipmentPacking packing, Carton carton) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ui = CartonStatusUi.of(l10n, carton.status);
    final title = carton.label == null || carton.label!.isEmpty
        ? l10n.cartonNoLabel(carton.cartonNo)
        : '${l10n.cartonNoLabel(carton.cartonNo)} · ${carton.label}';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            StatusPill(tone: ui.tone, label: ui.label, dense: true),
            IconButton(
              tooltip: l10n.cartonRenameAction,
              icon: const Icon(Icons.edit_outlined),
              onPressed: _busy ? null : () => _rename(carton),
            ),
          ],
        ),
        if (!carton.isOpen) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.cartonMustReopenToEdit,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        ],
        const SizedBox(height: AppSpacing.lg),
        for (final line in packing.lines)
          _PackableLineCard(
            line: line,
            canAdd: carton.isOpen && !_busy && line.unpacked > 0,
            onAdd: () => _addParcel(line),
          ),
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.cartonContentsSection, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        if (carton.items.isEmpty)
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(l10n.cartonContentsEmpty,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < carton.items.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _CartonItemRow(
                    item: carton.items[i],
                    onRemove: carton.isOpen && !_busy
                        ? () => _removeItem(carton.items[i])
                        : null,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _PackableLineCard extends StatelessWidget {
  const _PackableLineCard({
    required this.line,
    required this.canAdd,
    required this.onAdd,
  });

  final PackableLine line;
  final bool canAdd;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = line.unpacked <= 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      line.productName.isEmpty ? line.janCode : line.productName,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(l10n.packProgress(line.packed, line.packable),
                          style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: AppFonts.mono,
                              color: scheme.onSurfaceVariant)),
                      if (!done) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Text(l10n.cartonUnpackedCount(line.unpacked),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (done)
              StatusPill(
                  tone: StatusTone.success,
                  label: l10n.cartonLineDone,
                  dense: true)
            else
              FilledButton.tonalIcon(
                onPressed: canAdd ? onAdd : null,
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.cartonAddParcel),
              ),
          ],
        ),
      ),
    );
  }
}

class _CartonItemRow extends StatelessWidget {
  const _CartonItemRow({required this.item, this.onRemove});

  final CartonItem item;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName.isEmpty ? item.janCode : item.productName,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  [
                    if (item.lotCode != null) 'L:${item.lotCode}',
                    if (item.serialNumber != null) 'S/N:${item.serialNumber}',
                    if (item.lotCode == null && item.serialNumber == null)
                      l10n.pickItemNoLot,
                    '× ${item.quantity}',
                  ].join('  '),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              tooltip: l10n.pickItemRemove,
              icon: Icon(Icons.close, color: scheme.error),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

/// Renames a carton (0079) without touching what is inside it. A tiny
/// stateful dialog of its own, rather than a bare TextEditingController owned
/// by the caller — that controller would otherwise outlive the widget that
/// used it and get disposed while the pop transition still references it.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _label =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.cartonRenameTitle),
      content: TextField(
        controller: _label,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.cartonLabelHint),
        onSubmitted: (_) => Navigator.pop(context, _label.text.trim()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.actionCancel)),
        FilledButton(
            onPressed: () => Navigator.pop(context, _label.text.trim()),
            child: Text(l10n.actionSave)),
      ],
    );
  }
}

class _ParcelDraft {
  const _ParcelDraft(this.quantity, this.lotCode, this.serialNumber);
  final int quantity;
  final String? lotCode;
  final String? serialNumber;
}

class _PackDialog extends StatefulWidget {
  const _PackDialog({required this.line});

  final PackableLine line;

  @override
  State<_PackDialog> createState() => _PackDialogState();
}

class _PackDialogState extends State<_PackDialog> {
  late final TextEditingController _quantity =
      TextEditingController(text: widget.line.unpacked.toString());
  final TextEditingController _lotCode = TextEditingController();
  final TextEditingController _serial = TextEditingController();

  @override
  void dispose() {
    _quantity.dispose();
    _lotCode.dispose();
    _serial.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_quantity.text.trim());
    if (value == null || value <= 0) return;
    final lot = _lotCode.text.trim();
    final serial = _serial.text.trim();
    Navigator.pop(
      context,
      _ParcelDraft(value, lot.isEmpty ? null : lot, serial.isEmpty ? null : serial),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = widget.line.productName.isNotEmpty
        ? widget.line.productName
        : widget.line.janCode;

    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.line.janCode} · ${l10n.cartonUnpackedCount(widget.line.unpacked)}'),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _quantity,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: l10n.cartonPackQuantity),
            style: const TextStyle(fontFamily: AppFonts.mono),
            autofocus: true,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _lotCode,
            decoration: InputDecoration(
              labelText: l10n.pickLotCode,
              hintText: l10n.pickLotCodeHint,
            ),
            style: const TextStyle(fontFamily: AppFonts.mono),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _serial,
            decoration: InputDecoration(
              labelText: l10n.cartonSerialNumber,
              hintText: l10n.pickLotCodeHint,
            ),
            style: const TextStyle(fontFamily: AppFonts.mono),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.cartonAddParcel),
        ),
      ],
    );
  }
}
