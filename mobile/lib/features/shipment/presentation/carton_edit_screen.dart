import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/status_pill.dart';
import '../application/shipment_providers.dart';
import '../domain/carton.dart';
import '../domain/shipment.dart';
import '../domain/shipment_line.dart';

/// Pack a carton: pick how many of each shipment line goes into this box. A line
/// can be split across several cartons; the remaining (unpacked) amount is shown
/// per line and packing more than the shipment quantity is warned about.
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
  late final TextEditingController _labelController;
  final Map<String, int> _qty = {}; // this carton's allocation, keyed by JAN
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.carton.label ?? '');
    for (final it in widget.carton.items) {
      _qty[it.janCode] = (_qty[it.janCode] ?? 0) + it.quantity;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  /// Units of [jan] packed in OTHER cartons (excludes this one).
  int _packedElsewhere(String jan) {
    final total = widget.shipment.packedByJan[jan] ?? 0;
    final here = widget.carton.items
        .where((it) => it.janCode == jan)
        .fold(0, (s, it) => s + it.quantity);
    return total - here;
  }

  int _remaining(ShipmentLine l) =>
      l.quantity - _packedElsewhere(l.janCode) - (_qty[l.janCode] ?? 0);

  void _set(ShipmentLine l, int value) {
    setState(() => _qty[l.janCode] = value < 0 ? 0 : value);
  }

  Future<void> _save() async {
    final items = <CartonItem>[];
    for (final l in widget.shipment.lines) {
      final q = _qty[l.janCode] ?? 0;
      if (q <= 0) continue;
      items.add(CartonItem(
        shipmentLineId: l.id,
        janCode: l.janCode,
        productName: l.productName,
        spec: l.spec,
        quantity: q,
      ));
    }
    setState(() => _busy = true);
    final result = await ref.read(shipmentRepositoryProvider).updateCarton(
          widget.shipment.id,
          widget.carton.id,
          label: _labelController.text.trim(),
          items: items,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) async {
        await HapticFeedback.mediumImpact();
        if (mounted) Navigator.of(context).pop();
      },
      failure: (f) {
        final scheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
              content: Text(f.message), backgroundColor: scheme.error));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final overpacked = widget.shipment.lines.any((l) => _remaining(l) < 0);
    final total = _qty.values.fold(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.cartonNoLabel(widget.carton.cartonNo)} · ${l10n.cartonEditTitle}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          TextField(
            controller: _labelController,
            decoration: InputDecoration(
              labelText: l10n.cartonLabelHint,
              prefixIcon: const Icon(Icons.label_outline),
            ),
          ),
          if (overpacked) ...[
            const SizedBox(height: AppSpacing.sm),
            StatusPill(
                tone: StatusTone.warning,
                label: l10n.overpackWarning,
                icon: Icons.warning_amber),
          ],
          const SizedBox(height: AppSpacing.md),
          ...widget.shipment.lines.map((l) => _PackRow(
                line: l,
                value: _qty[l.janCode] ?? 0,
                remaining: _remaining(l),
                onChanged: (v) => _set(l, v),
              )),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border:
              Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                StatusPill(
                  tone: StatusTone.neutral,
                  label: '${l10n.packThisCarton} $total',
                  icon: Icons.inventory_2_outlined,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: SizedBox(
                    height: AppSpacing.minTouch,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _save,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check),
                      label: Text(l10n.actionSave),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PackRow extends StatelessWidget {
  const _PackRow({
    required this.line,
    required this.value,
    required this.remaining,
    required this.onChanged,
  });

  final ShipmentLine line;
  final int value;
  final int remaining;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final over = remaining < 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.productName.isEmpty ? line.janCode : line.productName,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  '${line.janCode}  ·  ${l10n.packRemaining}: $remaining / ${line.quantity}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'FiraCode',
                    color: over ? scheme.error : scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 44,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontFamily: 'FiraCode')),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => onChanged(value + 1),
          ),
          // Fill the remaining amount in one tap.
          IconButton(
            tooltip: l10n.packRemaining,
            icon: const Icon(Icons.done_all),
            onPressed:
                remaining > 0 ? () => onChanged(value + remaining) : null,
          ),
        ],
      ),
    );
  }
}
