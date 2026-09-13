import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../delivery/application/delivery_providers.dart';
import '../../delivery/domain/stock_item.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../application/sender_profile_controller.dart';
import '../application/shipment_providers.dart';
import '../data/shipment_print.dart';
import '../domain/carton.dart';
import '../domain/sender_profile.dart';
import '../domain/shipment.dart';
import '../domain/shipment_status.dart';
import 'carton_edit_screen.dart';
import 'sender_picker.dart';
import 'shipment_status_ui.dart';

/// One shipment: the overall list, the cartons it is split into, printing, and
/// confirming (which deducts stock) or undoing the shipment.
class ShipmentDetailScreen extends ConsumerStatefulWidget {
  const ShipmentDetailScreen({super.key, required this.shipmentId});

  final int shipmentId;

  @override
  ConsumerState<ShipmentDetailScreen> createState() =>
      _ShipmentDetailScreenState();
}

class _ShipmentDetailScreenState extends ConsumerState<ShipmentDetailScreen> {
  static const _printer = ShipmentPrinter();
  bool _busy = false;

  int get _id => widget.shipmentId;

  void _refresh() {
    ref.invalidate(shipmentDetailProvider(_id));
    ref.invalidate(shipmentsListProvider);
  }

  Future<void> _addCarton() async {
    setState(() => _busy = true);
    final result =
        await ref.read(shipmentRepositoryProvider).createCarton(_id);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) => _refresh(),
      failure: (f) => _snack(f.message, tone: StatusTone.danger),
    );
  }

  Future<void> _deleteCarton(Carton c) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.deleteCartonQ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.actionCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.actionDelete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final result =
        await ref.read(shipmentRepositoryProvider).deleteCarton(_id, c.id);
    if (!mounted) return;
    result.when(
      success: (_) => _refresh(),
      failure: (f) => _snack(f.message, tone: StatusTone.danger),
    );
  }

  Future<void> _confirmShip(Shipment s) async {
    final l10n = AppLocalizations.of(context);
    // Warn if any line exceeds stock on hand.
    List<StockItem> stock;
    try {
      stock = await ref.read(stockListProvider.future);
    } catch (_) {
      stock = const [];
    }
    final onHand = <String, int>{
      for (final it in stock) it.janCode: it.onHand,
    };
    final short = s.lines.any((l) => l.quantity > (onHand[l.janCode] ?? 0));
    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.shipConfirmQ),
        content: Text(short ? l10n.shipShortWarning : l10n.shipConfirmBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.actionCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.shipConfirmAction)),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    final result = await ref.read(shipmentRepositoryProvider).ship(_id);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) async {
        await HapticFeedback.mediumImpact();
        _refresh();
        ref.invalidate(stockListProvider);
        _snack(l10n.shipDone, tone: StatusTone.success);
      },
      failure: (f) => _snack(f.message, tone: StatusTone.danger),
    );
  }

  /// §18 — ask for the box size, show the resulting box count, then let the
  /// server do the division.
  Future<void> _autopack(Shipment s) async {
    final l10n = AppLocalizations.of(context);
    final units = await showDialog<int>(
      context: context,
      builder: (_) => _AutopackDialog(totalUnits: s.totalUnits),
    );
    if (units == null || !mounted) return;

    setState(() => _busy = true);
    final result = await ref
        .read(shipmentRepositoryProvider)
        .autopack(s.id, unitsPerCarton: units);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (r) {
        _refresh();
        _snack(l10n.autopackDone(r.cartonCount, r.unitsPerCarton),
            tone: StatusTone.success);
      },
      failure: (f) => _snack(f.message, tone: StatusTone.danger),
    );
  }

  /// §21 — the shipping desk's weight / carrier / tracking number.
  Future<void> _editLogistics(Shipment s) async {
    final draft = await showModalBottomSheet<_LogisticsDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LogisticsSheet(shipment: s),
    );
    if (draft == null || !mounted) return;

    setState(() => _busy = true);
    final result = await ref.read(shipmentRepositoryProvider).setLogistics(
          s.id,
          weightKg: draft.weightKg,
          carrier: draft.carrier,
          trackingNumber: draft.trackingNumber,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) => _refresh(),
      failure: (f) => _snack(f.message, tone: StatusTone.danger),
    );
  }

  Future<void> _cancelShip() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.shipCancelQ),
        content: Text(l10n.shipCancelBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.actionCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.shipCancelAction)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final result = await ref.read(shipmentRepositoryProvider).cancel(_id);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) {
        _refresh();
        ref.invalidate(stockListProvider);
        _snack(l10n.shipCancelledDone, tone: StatusTone.success);
      },
      failure: (f) => _snack(f.message, tone: StatusTone.danger),
    );
  }

  Future<void> _print(Future<void> Function() run) async {
    try {
      await run();
    } catch (e) {
      if (mounted) _snack('$e', tone: StatusTone.danger);
    }
  }

  /// Ask which sender fields to include, then print. Aborts if cancelled.
  Future<void> _printWith(
      Future<void> Function(List<SenderLine> sender) build) async {
    final profile = ref.read(senderProfileControllerProvider);
    final sender = await showSenderPicker(context, profile);
    if (sender == null || !mounted) return;
    await _print(() => build(sender));
  }

  void _snack(String message, {StatusTone tone = StatusTone.neutral}) {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    final (icon, bg) = switch (tone) {
      StatusTone.success => (Icons.check_circle, scheme.inverseSurface),
      StatusTone.warning => (Icons.warning_amber, scheme.inverseSurface),
      StatusTone.danger => (Icons.error_outline, scheme.error),
      _ => (Icons.info_outline, scheme.inverseSurface),
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(icon, size: 20, color: scheme.onInverseSurface),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: bg,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detail = ref.watch(shipmentDetailProvider(_id));

    return Scaffold(
      appBar: AppBar(
        title: Text(detail.valueOrNull?.shipmentNumber ?? l10n.featShipment),
        actions: [
          if (detail.valueOrNull != null)
            PopupMenuButton<String>(
              tooltip: l10n.printMenu,
              icon: const Icon(Icons.print_outlined),
              onSelected: (v) {
                final s = detail.value!;
                switch (v) {
                  case 'list':
                    _printWith((snd) => _printer.printOverall(s, sender: snd));
                  case 'slip':
                    _printWith(
                        (snd) => _printer.printDeliverySlip(s, sender: snd));
                  case 'cartons':
                    _printWith(
                        (snd) => _printer.printAllCartons(s, sender: snd));
                  case 'labels':
                    _printWith((snd) => _printer.printAllCartonLabels(s,
                        sender: snd,
                        warehouseName:
                            ref.read(activeWarehouseProvider)?.name));
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'list', child: Text(l10n.printOverall)),
                PopupMenuItem(value: 'slip', child: Text(l10n.printDeliverySlip)),
                if (detail.value!.cartons.isNotEmpty) ...[
                  PopupMenuItem(
                      value: 'cartons', child: Text(l10n.printAllCartons)),
                  PopupMenuItem(
                      value: 'labels', child: Text(l10n.printCartonLabels)),
                ],
              ],
            ),
        ],
      ),
      body: detail.when(
        data: (s) => _body(context, l10n, s),
        loading: () => LoadingView(message: l10n.loading),
        error: (error, _) => ErrorStateView(
          message: '$error',
          onRetry: () => ref.invalidate(shipmentDetailProvider(_id)),
        ),
      ),
      bottomNavigationBar: detail.valueOrNull == null
          ? null
          : _bottomBar(context, l10n, detail.value!),
    );
  }

  Widget _bottomBar(BuildContext context, AppLocalizations l10n, Shipment s) {
    final scheme = Theme.of(context).colorScheme;
    final shipped = s.status == ShipmentStatus.shipped;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            height: AppSpacing.minTouch,
            child: shipped
                ? OutlinedButton.icon(
                    onPressed: _busy ? null : _cancelShip,
                    icon: Icon(Icons.undo, color: scheme.error),
                    label: Text(l10n.shipCancelAction,
                        style: TextStyle(color: scheme.error)),
                  )
                : FilledButton.icon(
                    onPressed: _busy ? null : () => _confirmShip(s),
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.local_shipping_outlined),
                    label: Text(l10n.shipConfirmAction),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n, Shipment s) {
    final packed = s.packedByJan;
    final packedTotal = packed.values.fold(0, (a, b) => a + b);
    final shipped = s.status == ShipmentStatus.shipped;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      children: [
        _HeaderCard(shipment: s, packedTotal: packedTotal),

        const SizedBox(height: AppSpacing.lg),
        _SectionHeader(
          label: l10n.shipmentLinesSection,
          trailing: l10n.planPreviewCount(s.lineCount, s.totalUnits),
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: Column(
              children: [
                for (var i = 0; i < s.lines.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _LineRow(
                    name: s.lines[i].productName,
                    jan: s.lines[i].janCode,
                    spec: s.lines[i].spec,
                    quantity: s.lines[i].quantity,
                    packed: packed[s.lines[i].janCode] ?? 0,
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        _SectionHeader(
          label: l10n.cartonsSection,
          trailing:
              s.cartons.isEmpty ? null : l10n.cartonCountLabel(s.cartons.length),
          action: s.cartons.isEmpty
              ? null
              : TextButton.icon(
                  onPressed: () => _printWith(
                      (snd) => _printer.printAllCartons(s, sender: snd)),
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: Text(l10n.printAllCartons),
                ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (s.cartons.isEmpty && !shipped)
          _EmptyCartons(
            onAdd: _busy ? null : _addCarton,
            onAutopack: _busy || s.totalUnits <= 0 ? null : () => _autopack(s),
          )
        else
          ...s.cartons.map((c) => _CartonCard(
                carton: c,
                onEdit: shipped
                    ? null
                    : () async {
                        await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              CartonEditScreen(shipment: s, carton: c),
                        ));
                        _refresh();
                      },
                onDelete: shipped ? null : () => _deleteCarton(c),
                onPrint: () =>
                    _printWith((snd) => _printer.printCarton(s, c, sender: snd)),
                onPrintLabel: () => _printWith((snd) => _printer.printCartonLabel(
                      s,
                      c,
                      sender: snd,
                      warehouseName: ref.read(activeWarehouseProvider)?.name,
                    )),
              )),
        if (s.cartons.isNotEmpty && !shipped) ...[
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: _busy ? null : _addCarton,
            icon: const Icon(Icons.add_box_outlined),
            label: Text(l10n.addCarton),
          ),
        ],

        // §21's shipping block: what is going out, how heavy, with whom.
        const SizedBox(height: AppSpacing.lg),
        _SectionHeader(
          label: l10n.shipLogisticsSection,
          action: shipped
              ? null
              : TextButton.icon(
                  onPressed: _busy ? null : () => _editLogistics(s),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(l10n.actionEdit),
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _LogisticsCard(shipment: s),
      ],
    );
  }
}

/// Summary header: customer + reference + status, with a packing progress bar.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.shipment, required this.packedTotal});

  final Shipment shipment;
  final int packedTotal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ui = ShipmentStatusUi.of(l10n, shipment.status);
    final total = shipment.totalUnits;
    final ratio = total == 0 ? 0.0 : (packedTotal / total).clamp(0.0, 1.0);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusAvatar(tone: ui.tone, icon: ui.icon),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shipment.customerName ?? l10n.unknownSupplier,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (shipment.referenceNo != null &&
                          shipment.referenceNo!.isNotEmpty)
                        Text('${l10n.referenceNoLabel}: ${shipment.referenceNo}',
                            style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: AppFonts.mono, color: scheme.primary)),
                    ],
                  ),
                ),
                StatusPill(
                    tone: ui.tone, label: ui.label, icon: ui.icon, dense: true),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(l10n.packProgress(packedTotal, total),
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: AppFonts.mono,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A section heading with an optional trailing count and an optional action.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.trailing, this.action});

  final String label;
  final String? trailing;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Text(label,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(trailing!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        ],
        const Spacer(),
        if (action != null) action!,
      ],
    );
  }
}

/// Dashed-look placeholder inviting the operator to add the first carton.
class _EmptyCartons extends StatelessWidget {
  const _EmptyCartons({required this.onAdd, this.onAutopack});

  final VoidCallback? onAdd;

  /// §18's 箱数自動計算 — offered beside the manual "add a carton" because for
  /// anything but a two-item order it is the way a packer actually starts.
  final VoidCallback? onAutopack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: scheme.outlineVariant),
          color: scheme.surfaceContainerLow,
        ),
        child: Column(
          children: [
            Icon(Icons.add_box_outlined, color: scheme.primary, size: 28),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.addCarton,
                style: TextStyle(
                    color: scheme.primary, fontWeight: FontWeight.w600)),
            if (onAutopack != null) ...[
              const SizedBox(height: AppSpacing.sm),
              FilledButton.tonalIcon(
                onPressed: onAutopack,
                icon: const Icon(Icons.auto_awesome_motion_outlined, size: 18),
                label: Text(l10n.autopackAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.name,
    required this.jan,
    required this.spec,
    required this.quantity,
    required this.packed,
  });

  final String name;
  final String jan;
  final String? spec;
  final int quantity;
  final int packed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = packed >= quantity;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? jan : name,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  spec == null || spec!.isEmpty ? jan : '$jan · $spec',
                  style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: AppFonts.mono, color: scheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text('$packed/$quantity',
              style: theme.textTheme.titleSmall?.copyWith(
                  fontFamily: AppFonts.mono,
                  color: done ? scheme.tertiary : scheme.onSurface)),
        ],
      ),
    );
  }
}

class _CartonCard extends StatelessWidget {
  const _CartonCard({
    required this.carton,
    required this.onEdit,
    required this.onDelete,
    required this.onPrint,
    required this.onPrintLabel,
  });

  final Carton carton;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// The contents list for this box.
  final VoidCallback onPrint;

  /// The box's own label (§17/§19), QR included.
  final VoidCallback onPrintLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = carton.label == null || carton.label!.isEmpty
        ? l10n.cartonNoLabel(carton.cartonNo)
        : '${l10n.cartonNoLabel(carton.cartonNo)} · ${carton.label}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 20, color: scheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                      child: Text(title, style: theme.textTheme.titleSmall)),
                  Text(l10n.planPreviewCount(
                      carton.items.length, carton.totalUnits),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
              if (carton.items.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  carton.items
                      .map((it) =>
                          '${it.productName.isEmpty ? it.janCode : it.productName}×${it.quantity}')
                      .join('  /  '),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onPrintLabel,
                    icon: const Icon(Icons.label_outline, size: 18),
                    label: Text(l10n.printThisLabel),
                  ),
                  TextButton.icon(
                    onPressed: onPrint,
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: Text(l10n.printThisCarton),
                  ),
                  if (onDelete != null)
                    IconButton(
                      tooltip: l10n.actionDelete,
                      icon: Icon(Icons.delete_outline, color: scheme.error),
                      onPressed: onDelete,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// §18's dialog: type the box size, see the box count before committing.
class _AutopackDialog extends StatefulWidget {
  const _AutopackDialog({required this.totalUnits});

  final int totalUnits;

  @override
  State<_AutopackDialog> createState() => _AutopackDialogState();
}

class _AutopackDialogState extends State<_AutopackDialog> {
  final TextEditingController _units = TextEditingController();

  @override
  void dispose() {
    _units.dispose();
    super.dispose();
  }

  int? get _perCarton {
    final v = int.tryParse(_units.text.trim());
    return v == null || v <= 0 ? null : v;
  }

  /// Ceiling division — the remainder still needs a box.
  int? get _boxes {
    final per = _perCarton;
    if (per == null) return null;
    return (widget.totalUnits + per - 1) ~/ per;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final per = _perCarton;
    final boxes = _boxes;
    final remainder =
        per == null ? null : widget.totalUnits - (boxes! - 1) * per;

    return AlertDialog(
      title: Text(l10n.autopackAction),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.autopackTotal(widget.totalUnits),
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _units,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontFamily: AppFonts.mono),
            decoration: InputDecoration(
              labelText: l10n.autopackPerCarton,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          // The計算 the spec says not to make the operator do, shown before
          // anything is created.
          if (boxes == null)
            Text(l10n.autopackHint,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant))
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.autopackBoxes(boxes),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    boxes == 1 || remainder == per
                        ? l10n.autopackEven(per!)
                        : l10n.autopackSplit(boxes - 1, per!, remainder!),
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: AppFonts.mono,
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: per == null ? null : () => Navigator.pop(context, per),
          child: Text(l10n.autopackConfirm),
        ),
      ],
    );
  }
}

class _LogisticsDraft {
  const _LogisticsDraft(this.weightKg, this.carrier, this.trackingNumber);
  final double? weightKg;
  final String? carrier;
  final String? trackingNumber;
}

/// §21's readout. Unset fields say so rather than showing 0 kg or a blank line —
/// "not weighed yet" and "weighs nothing" are different facts.
class _LogisticsCard extends StatelessWidget {
  const _LogisticsCard({required this.shipment});

  final Shipment shipment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget row(IconData icon, String label, String? value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              Icon(icon, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Text(label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              const Spacer(),
              Text(
                value ?? l10n.shipLogisticsUnset,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: value == null ? null : AppFonts.mono,
                  fontWeight: value == null ? FontWeight.w400 : FontWeight.w600,
                  color: value == null ? scheme.onSurfaceVariant : scheme.onSurface,
                ),
              ),
            ],
          ),
        );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Column(
          children: [
            row(Icons.scale_outlined, l10n.shipWeight,
                shipment.weightKg == null
                    ? null
                    : l10n.shipWeightKg(shipment.weightKg!)),
            const Divider(height: 1),
            row(Icons.local_shipping_outlined, l10n.shipCarrier,
                shipment.carrier),
            const Divider(height: 1),
            row(Icons.receipt_long_outlined, l10n.shipTracking,
                shipment.trackingNumber),
          ],
        ),
      ),
    );
  }
}

/// Edit sheet for §21's three fields. The carrier is a free-text field with
/// suggestions rather than a closed list: a warehouse that ships with a local
/// carrier must not be forced to pick the wrong one.
class _LogisticsSheet extends StatefulWidget {
  const _LogisticsSheet({required this.shipment});

  final Shipment shipment;

  @override
  State<_LogisticsSheet> createState() => _LogisticsSheetState();
}

class _LogisticsSheetState extends State<_LogisticsSheet> {
  late final TextEditingController _weight = TextEditingController(
      text: widget.shipment.weightKg == null
          ? ''
          : _trimZeros(widget.shipment.weightKg!));
  late final TextEditingController _carrier =
      TextEditingController(text: widget.shipment.carrier ?? '');
  late final TextEditingController _tracking =
      TextEditingController(text: widget.shipment.trackingNumber ?? '');
  String? _error;

  static String _trimZeros(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : '$v';

  static const _carriers = ['ヤマト運輸', '佐川急便', '日本郵便', '西濃運輸', '福山通運'];

  @override
  void dispose() {
    _weight.dispose();
    _carrier.dispose();
    _tracking.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final raw = _weight.text.trim();
    double? weight;
    if (raw.isNotEmpty) {
      weight = double.tryParse(raw);
      if (weight == null || weight < 0) {
        setState(() => _error = l10n.shipWeightInvalid);
        return;
      }
    }
    Navigator.pop(
      context,
      _LogisticsDraft(
        weight,
        _carrier.text.trim().isEmpty ? null : _carrier.text.trim(),
        _tracking.text.trim().isEmpty ? null : _tracking.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.shipLogisticsSection, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _weight,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: const TextStyle(fontFamily: AppFonts.mono),
              decoration: InputDecoration(
                labelText: l10n.shipWeight,
                suffixText: 'kg',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _carrier,
              decoration: InputDecoration(
                labelText: l10n.shipCarrier,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final c in _carriers)
                  ActionChip(
                    label: Text(c),
                    onPressed: () => setState(() => _carrier.text = c),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _tracking,
              style: const TextStyle(fontFamily: AppFonts.mono),
              decoration: InputDecoration(
                labelText: l10n.shipTracking,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              height: AppSpacing.minTouch,
              child: FilledButton(
                onPressed: _submit,
                child: Text(l10n.actionSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
