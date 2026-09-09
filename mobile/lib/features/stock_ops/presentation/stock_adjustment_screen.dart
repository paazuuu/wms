import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../application/stock_ops_providers.dart';
import '../domain/stock_ops.dart';
import 'stock_ops_ui.dart';

/// Reason-coded stock corrections.
///
/// Every entry posts through the ledger server-side, so the history below is
/// the audit trail rather than a convenience log: nothing here edits a quantity
/// in place (spec §17).
class StockAdjustmentScreen extends ConsumerStatefulWidget {
  const StockAdjustmentScreen({super.key});

  @override
  ConsumerState<StockAdjustmentScreen> createState() =>
      _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends ConsumerState<StockAdjustmentScreen> {
  bool _busy = false;

  void _snack(String message, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: danger ? Theme.of(context).colorScheme.error : null,
      ));
  }

  Future<void> _newAdjustment() async {
    final l10n = AppLocalizations.of(context);
    final warehouseId = ref.read(writeWarehouseIdProvider);
    if (warehouseId == null) {
      // Two or more warehouses and no active one: a movement must not be
      // guessed into a building.
      _snack(l10n.adjNeedsWarehouse, danger: true);
      return;
    }

    final draft = await showModalBottomSheet<_AdjustDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AdjustSheet(),
    );
    if (draft == null || !mounted) return;

    setState(() => _busy = true);
    final result = await ref.read(stockOpsRepositoryProvider).adjust(
          warehouseId: warehouseId,
          janCode: draft.janCode,
          delta: draft.delta,
          reason: draft.reason,
          note: draft.note,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (adjustment) {
        ref.invalidate(adjustmentListProvider);
        _snack(l10n.adjDone(signed(adjustment.quantityDelta)));
      },
      failure: (f) => _snack(f.message, danger: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(adjustmentListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adjTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _newAdjustment,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.tune),
        label: Text(_busy ? l10n.working : l10n.adjNew),
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(adjustmentListProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyStateView(
              icon: Icons.tune_outlined,
              title: l10n.adjEmpty,
              message: l10n.adjEmptyBody,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(adjustmentListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg,
                  AppSpacing.lg, AppSpacing.xxl * 2),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) => _AdjustmentCard(adjustment: list[i]),
            ),
          );
        },
      ),
    );
  }
}

class _AdjustmentCard extends StatelessWidget {
  const _AdjustmentCard({required this.adjustment});

  final StockAdjustment adjustment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final ui = AdjustReasonUi.of(l10n, adjustment.reason);
    final title = adjustment.productName.isNotEmpty
        ? adjustment.productName
        : adjustment.janCode;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            StatusAvatar(tone: ui.tone, icon: ui.icon),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    adjustment.note?.isNotEmpty == true
                        ? adjustment.note!
                        : adjustment.janCode,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFamily: adjustment.note?.isNotEmpty == true
                            ? null
                            : AppFonts.mono),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  signed(adjustment.quantityDelta),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: AppFonts.mono,
                    fontWeight: FontWeight.w600,
                    color: adjustment.quantityDelta < 0
                        ? scheme.error
                        : scheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                StatusPill(tone: ui.tone, label: ui.label, dense: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdjustDraft {
  const _AdjustDraft(this.janCode, this.delta, this.reason, this.note);
  final String janCode;
  final int delta;
  final AdjustReason reason;
  final String? note;
}

/// The entry form. Direction and magnitude are separate controls: a single
/// signed field invites a missing minus, and a missing minus doubles stock.
class _AdjustSheet extends StatefulWidget {
  const _AdjustSheet();

  @override
  State<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends State<_AdjustSheet> {
  final _jan = TextEditingController();
  final _quantity = TextEditingController();
  final _note = TextEditingController();
  bool _adding = false;
  AdjustReason _reason = AdjustReason.damage;
  String? _error;

  @override
  void dispose() {
    _jan.dispose();
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final jan = _jan.text.trim();
    final magnitude = int.tryParse(_quantity.text.trim()) ?? 0;
    if (jan.isEmpty) {
      setState(() => _error = l10n.adjJanRequired);
      return;
    }
    if (magnitude <= 0) {
      setState(() => _error = l10n.adjDeltaRequired);
      return;
    }
    Navigator.pop(
      context,
      _AdjustDraft(
        jan,
        _adding ? magnitude : -magnitude,
        _reason,
        _note.text.trim(),
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
            Text(l10n.adjNew, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _jan,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: l10n.adjJan),
              style: const TextStyle(fontFamily: AppFonts.mono),
            ),
            const SizedBox(height: AppSpacing.lg),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.remove),
                  label: Text(l10n.adjustRemove),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.adjustAdd),
                ),
              ],
              selected: {_adding},
              onSelectionChanged: (s) => setState(() => _adding = s.first),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _quantity,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: l10n.adjQuantity),
              style: const TextStyle(fontFamily: AppFonts.mono),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.adjReason, style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final r in AdjustReason.values)
                  ChoiceChip(
                    selected: _reason == r,
                    label: Text(AdjustReasonUi.of(l10n, r).label),
                    onSelected: (_) => setState(() => _reason = r),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _note,
              decoration: InputDecoration(labelText: l10n.adjNote),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
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
                child: Text(l10n.adjApply),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
