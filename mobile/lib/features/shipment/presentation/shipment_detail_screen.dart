import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../delivery/application/delivery_providers.dart';
import '../../delivery/domain/stock_item.dart';
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
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'list', child: Text(l10n.printOverall)),
                PopupMenuItem(value: 'slip', child: Text(l10n.printDeliverySlip)),
                if (detail.value!.cartons.isNotEmpty)
                  PopupMenuItem(
                      value: 'cartons', child: Text(l10n.printAllCartons)),
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
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n, Shipment s) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ui = ShipmentStatusUi.of(l10n, s.status);
    final packed = s.packedByJan;
    final packedTotal = packed.values.fold(0, (a, b) => a + b);
    final shipped = s.status == ShipmentStatus.shipped;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // Header summary.
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
          StatusPill(tone: ui.tone, label: ui.label, icon: ui.icon, dense: true),
          StatusPill(
            tone: StatusTone.neutral,
            label: l10n.packProgress(packedTotal, s.totalUnits),
            icon: Icons.inventory_2_outlined,
            dense: true,
          ),
        ]),
        if (s.customerName != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(s.customerName!, style: theme.textTheme.titleMedium),
        ],
        if (s.referenceNo != null && s.referenceNo!.isNotEmpty)
          Text('${l10n.referenceNoLabel}: ${s.referenceNo}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontFamily: 'FiraCode', color: scheme.primary)),

        const SizedBox(height: AppSpacing.lg),
        Text(l10n.shipmentLinesSection,
            style: theme.textTheme.titleSmall
                ?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.sm),
        ...s.lines.map((l) => _LineRow(
              name: l.productName,
              jan: l.janCode,
              spec: l.spec,
              quantity: l.quantity,
              packed: packed[l.janCode] ?? 0,
            )),

        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: Text(l10n.cartonsSection,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ),
            if (s.cartons.isNotEmpty)
              TextButton.icon(
                onPressed: () =>
                    _printWith((snd) => _printer.printAllCartons(s, sender: snd)),
                icon: const Icon(Icons.print_outlined, size: 18),
                label: Text(l10n.printAllCartons),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
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
            )),
        const SizedBox(height: AppSpacing.sm),
        if (!shipped)
          OutlinedButton.icon(
            onPressed: _busy ? null : _addCarton,
            icon: const Icon(Icons.add_box_outlined),
            label: Text(l10n.addCarton),
          ),

        const SizedBox(height: AppSpacing.xl),
        if (shipped)
          OutlinedButton.icon(
            onPressed: _busy ? null : _cancelShip,
            icon: Icon(Icons.undo, color: scheme.error),
            label: Text(l10n.shipCancelAction,
                style: TextStyle(color: scheme.error)),
          )
        else
          FilledButton.icon(
            onPressed: _busy ? null : () => _confirmShip(s),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.local_shipping_outlined),
            label: Text(l10n.shipConfirmAction),
          ),
      ],
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
                      fontFamily: 'FiraCode', color: scheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text('$packed/$quantity',
              style: theme.textTheme.titleSmall?.copyWith(
                  fontFamily: 'FiraCode',
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
  });

  final Carton carton;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback onPrint;

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
