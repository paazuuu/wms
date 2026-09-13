import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/scan/barcode_scan_screen.dart';
import '../../../core/scan/scan_field.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../application/putaway_providers.dart';
import '../domain/putaway_task.dart';

/// §13's put-away confirm flow: scan the shelf, see what is already there,
/// confirm how many go in.
///
/// Two steps in one sheet because they are one thought for the operator —
/// "this box goes on that shelf". The location is scanned rather than picked
/// from a list: the shelf label is physically in front of them, and typing a
/// bin code is the slowest, most error-prone part of the job (§50).
class PutawayConfirmSheet extends ConsumerStatefulWidget {
  const PutawayConfirmSheet({
    super.key,
    required this.task,
    required this.warehouseId,
  });

  final PutawayTask task;
  final int warehouseId;

  @override
  ConsumerState<PutawayConfirmSheet> createState() => _PutawayConfirmSheetState();
}

class _PutawayConfirmSheetState extends ConsumerState<PutawayConfirmSheet> {
  late final TextEditingController _quantity =
      TextEditingController(text: '${widget.task.pendingQuantity}');
  BinLocation? _bin;
  bool _busy = false;
  String? _error;

  /// Generated once per resolved bin, not per tap: a double-tapped confirm
  /// must reuse the same key so the server replays instead of double-posting
  /// (§49). Reset whenever the operator scans a different location.
  String? _idempotencyKey;

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _resolveLocation(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    final l10n = AppLocalizations.of(context);

    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref
        .read(putawayRepositoryProvider)
        .binByCode(widget.warehouseId, trimmed);
    if (!mounted) return;
    setState(() => _busy = false);

    result.when(
      success: (bin) {
        if (bin == null) {
          setState(() {
            _bin = null;
            _idempotencyKey = null;
            _error = l10n.putawayBinNotFound(trimmed);
          });
          return;
        }
        if (!bin.isActive) {
          setState(() {
            _bin = null;
            _idempotencyKey = null;
            _error = l10n.putawayBinInactive(bin.binCode);
          });
          return;
        }
        HapticFeedback.mediumImpact();
        setState(() {
          _bin = bin;
          _error = null;
          _idempotencyKey = 'pa-${widget.warehouseId}-${widget.task.janCode}'
              '-${bin.binId}-${DateTime.now().microsecondsSinceEpoch}';
        });
      },
      failure: (f) => setState(() => _error = f.message),
    );
  }

  Future<void> _scanWithCamera() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
    );
    if (!mounted || code == null || code.isEmpty) return;
    await _resolveLocation(code);
  }

  Future<void> _confirm() async {
    final l10n = AppLocalizations.of(context);
    final bin = _bin;
    final key = _idempotencyKey;
    if (bin == null || key == null) return;

    final quantity = int.tryParse(_quantity.text.trim()) ?? 0;
    if (quantity <= 0) {
      setState(() => _error = l10n.putawayQuantityRequired);
      return;
    }
    if (quantity > widget.task.pendingQuantity) {
      setState(() => _error =
          l10n.putawayQuantityTooLarge(widget.task.pendingQuantity));
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(putawayRepositoryProvider).confirm(
          warehouseId: widget.warehouseId,
          janCode: widget.task.janCode,
          binId: bin.binId,
          quantity: quantity,
          idempotencyKey: key,
        );
    if (!mounted) return;
    setState(() => _busy = false);

    result.when(
      success: (res) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(l10n.putawayConfirmed(
                res.quantity, res.binCode, res.pendingAfter)),
          ));
      },
      failure: (f) => setState(() => _error = f.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bin = _bin;

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
            Text(widget.task.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(widget.task.janCode,
                style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: AppFonts.mono, color: scheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.lg),

            // Step 1 — scan the shelf.
            Text(l10n.putawayScanLocation, style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            ScanField(
              autofocusOnWide: true,
              hintText: widget.task.suggestedBinCode == null
                  ? l10n.putawayScanLocationHint
                  : l10n.putawaySuggested(widget.task.suggestedBinCode!),
              onSubmitted: _resolveLocation,
              trailing: [
                IconButton(
                  tooltip: l10n.putawayScanLocation,
                  icon: const Icon(Icons.photo_camera_outlined),
                  onPressed: _busy ? null : _scanWithCamera,
                ),
              ],
            ),

            if (bin != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.place, size: 18, color: scheme.primary),
                        const SizedBox(width: AppSpacing.xs),
                        Text(bin.binCode,
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontFamily: AppFonts.mono,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // §13's "現在:" readout — what is on that shelf right now,
                    // so a wrong shelf is obvious before confirming.
                    Text(l10n.putawayBinCurrent,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    if (bin.lines.isEmpty)
                      Text(l10n.putawayBinEmpty,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant))
                    else
                      for (final line in bin.lines)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  line.productName.isNotEmpty
                                      ? '${line.productName} (${line.janCode})'
                                      : line.janCode,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      fontFamily: AppFonts.mono,
                                      color: line.janCode == widget.task.janCode
                                          ? scheme.primary
                                          : scheme.onSurface),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text('${line.onHand}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      fontFamily: AppFonts.mono,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Step 2 — how many go in. Prefilled with everything pending,
              // because putting the whole received quantity on one shelf is
              // the common case; a split is the exception.
              Text(l10n.putawayThisTime, style: theme.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _quantity,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontFamily: AppFonts.mono),
                decoration: InputDecoration(
                  prefixText: '+ ',
                  suffixText: l10n.putawayOfPending(widget.task.pendingQuantity),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: scheme.error),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(_error!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.error)),
                  ),
                ],
              ),
            ],

            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              height: AppSpacing.minTouch,
              child: FilledButton.icon(
                onPressed: (_busy || bin == null) ? null : _confirm,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.done_all),
                label: Text(_busy ? l10n.working : l10n.putawayConfirm),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
