import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../product/presentation/product_detail_screen.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../application/inspection_providers.dart';
import '../domain/held_stock.dart';
import '../../product_library/presentation/product_thumb.dart';

/// Stock that is on hand and cannot ship: waiting for inspection (§13, 0068),
/// or held, quarantined, damaged, expired or blocked (0098).
///
/// Since 0098 it is also where held goods are dealt with: released as good
/// after a second look, moved to another hold, written off, or sent back to
/// the supplier. Goods waiting for inspection are decided by the inspection,
/// so those rows say so instead of offering a decision.
///
/// This screen exists because held stock is invisible in the numbers people
/// normally read. It counts toward on-hand and not toward available, so a product
/// can say "100 in stock" and ship nothing — and before 0068 that state was not
/// even possible, so nobody had a habit of looking for it. This is the list that
/// explains the gap, ordered by the expiry closest to running out.
class HeldStockScreen extends ConsumerWidget {
  /// Filter chips, in the order a warehouse meets them.
  static const statuses = ['QC_PENDING', 'HOLD', 'QUARANTINE', 'DAMAGED', 'EXPIRED', 'BLOCKED'];

  const HeldStockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final warehouseId = ref.watch(activeWarehouseIdProvider);

    if (warehouseId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.heldStockTitle)),
        body: EmptyStateView(
          icon: Icons.warehouse_outlined,
          title: l10n.heldStockNoWarehouse,
          message: l10n.heldStockEmptyBody,
        ),
      );
    }

    final async = ref.watch(heldStockProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.heldStockTitle)),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(heldStockProvider),
        ),
        data: (rows) {
          final filter = ref.watch(heldStatusFilterProvider);
          final chips = _StatusChips(selected: filter);
          if (rows.isEmpty) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                  child: chips,
                ),
                Expanded(
                  child: EmptyStateView(
                    icon: Icons.verified_outlined,
                    title: l10n.heldStockEmpty,
                    message: l10n.heldStockEmptyBody,
                  ),
                ),
              ],
            );
          }
          final total = rows.fold(0, (sum, r) => sum + r.quantity);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(heldStockProvider),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                chips,
                const SizedBox(height: AppSpacing.md),
                _TotalBar(parcels: rows.length, units: total),
                const SizedBox(height: AppSpacing.md),
                for (final row in rows) ...[
                  _HeldCard(row: row),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

String heldStatusLabel(AppLocalizations l10n, String code, [String? serverName]) =>
    switch (code) {
      'QC_PENDING' => l10n.heldStatusQcPending,
      'HOLD' => l10n.heldStatusHold,
      'QUARANTINE' => l10n.heldStatusQuarantine,
      'DAMAGED' => l10n.heldStatusDamaged,
      'EXPIRED' => l10n.heldStatusExpired,
      'BLOCKED' => l10n.heldStatusBlocked,
      _ => serverName ?? code,
    };

class _StatusChips extends ConsumerWidget {
  const _StatusChips({required this.selected});

  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    void pick(String? v) => ref.read(heldStatusFilterProvider.notifier).state = v;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        ChoiceChip(
          label: Text(l10n.filterAll),
          selected: selected == null,
          onSelected: (_) => pick(null),
        ),
        for (final code in HeldStockScreen.statuses)
          ChoiceChip(
            key: ValueKey('held-filter-$code'),
            label: Text(heldStatusLabel(l10n, code)),
            selected: selected == code,
            onSelected: (_) => pick(code),
          ),
      ],
    );
  }
}

/// The one number worth leading with: how much of the building's stock is
/// sitting there unable to move.
class _TotalBar extends StatelessWidget {
  const _TotalBar({required this.parcels, required this.units});

  final int parcels;
  final int units;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(Icons.pan_tool_outlined, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(l10n.heldStockTotal(units, parcels))),
          ],
        ),
      ),
    );
  }
}

class _HeldCard extends ConsumerWidget {
  const _HeldCard({required this.row});

  final HeldStock row;

  Future<void> _resolve(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final done = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DispositionSheet(row: row),
    );
    if (done == null || !context.mounted) return;
    ref.invalidate(heldStockProvider);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.dispDone(done))));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final df = DateFormat('yyyy-MM-dd');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProductDetailScreen(productId: row.productId),
        )),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProductThumb(productId: row.productId, janCode: row.janCode, productName: row.productName, size: 44),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(row.productName ?? row.janCode ?? '—',
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text(l10n.heldStockQuantity(row.quantity),
                      style: theme.textTheme.titleSmall),
                ],
              ),
              if (row.janCode != null && row.productName != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(row.janCode!,
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  StatusPill(
                      tone: row.awaitsInspection ? StatusTone.info : StatusTone.danger,
                      label: heldStatusLabel(l10n, row.statusCode, row.statusName),
                      dense: true),
                  if (row.lotCode != null)
                    StatusPill(
                        tone: StatusTone.neutral,
                        label: l10n.heldStockLot(row.lotCode!),
                        dense: true),
                  if (row.serialNumber != null)
                    StatusPill(
                        tone: StatusTone.neutral,
                        label: row.serialNumber!,
                        dense: true),
                  // An expiry that has already passed on stock that cannot ship
                  // is the worst square on this screen, so it is marked as such.
                  if (row.expiry != null)
                    StatusPill(
                        tone: row.isExpired
                            ? StatusTone.danger
                            : StatusTone.warning,
                        label: l10n.heldStockExpiry(df.format(row.expiry!)),
                        dense: true),
                  // How long it has been waiting turns a queue into a priority.
                  if (row.daysHeld != null)
                    StatusPill(
                        tone: row.daysHeld! >= 3
                            ? StatusTone.warning
                            : StatusTone.neutral,
                        label: l10n.heldStockDays(row.daysHeld!),
                        dense: true),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerRight,
                child: row.awaitsInspection
                    ? Text(l10n.heldAwaitsInspection,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant))
                    : FilledButton.tonalIcon(
                        key: ValueKey('held-resolve-${row.productId}-${row.statusCode}-${row.lotId}'),
                        onPressed: () => _resolve(context, ref),
                        icon: const Icon(Icons.rule_outlined, size: 18),
                        label: Text(l10n.heldDispose),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One decision on one bucket of held goods (0098). Pops the quantity done.
class DispositionSheet extends ConsumerStatefulWidget {
  const DispositionSheet({super.key, required this.row});

  final HeldStock row;

  @override
  ConsumerState<DispositionSheet> createState() => _DispositionSheetState();
}

class _DispositionSheetState extends ConsumerState<DispositionSheet> {
  late final _qty = TextEditingController(text: '${widget.row.quantity}');
  final _note = TextEditingController();
  HeldDisposition _action = HeldDisposition.release;
  bool _busy = false;

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  int get _quantity => int.tryParse(_qty.text.trim()) ?? 0;

  String _label(AppLocalizations l10n, HeldDisposition a) => switch (a) {
        HeldDisposition.release => l10n.dispRelease,
        HeldDisposition.hold => l10n.dispHold,
        HeldDisposition.quarantine => l10n.dispQuarantine,
        HeldDisposition.damaged => l10n.dispDamaged,
        HeldDisposition.scrap => l10n.dispScrap,
        HeldDisposition.returnToSupplier => l10n.dispReturn,
      };

  String? _error(AppLocalizations l10n) {
    if (_quantity > widget.row.quantity) return l10n.dispOverMax(widget.row.quantity);
    if (_action.needsReason && _note.text.trim().isEmpty) return l10n.dispReasonRequired;
    return null;
  }

  Future<void> _apply() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final result = await ref.read(inspectionRepositoryProvider).dispose(
          widget.row,
          _action,
          quantity: _quantity,
          note: _note.text,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (r) => Navigator.pop(context, r.quantity),
      failure: (f) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(humanizeApiErrorMessage(l10n, f.message)),
          backgroundColor: Theme.of(context).colorScheme.error,
        )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final row = widget.row;
    // Moving to the status it is already in is not a decision.
    final actions = [
      for (final a in HeldDisposition.values)
        if (a.toStatus != row.statusCode) a,
    ];
    final error = _error(l10n);
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.dispTitle(row.productName ?? row.janCode ?? '—'),
                style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(heldStatusLabel(l10n, row.statusCode, row.statusName),
                style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('disp-qty'),
              controller: _qty,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: l10n.dispQuantity, helperText: l10n.dispMax(row.quantity)),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final a in actions)
                  ChoiceChip(
                    key: ValueKey('disp-${a.wire}'),
                    label: Text(_label(l10n, a)),
                    selected: _action == a,
                    onSelected: (_) => setState(() => _action = a),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('disp-note'),
              controller: _note,
              decoration: InputDecoration(labelText: l10n.dispReason),
              onChanged: (_) => setState(() {}),
            ),
            if (error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(error,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              height: AppSpacing.minTouch,
              child: FilledButton(
                key: const ValueKey('disp-apply'),
                onPressed: _busy || error != null || _quantity <= 0 ? null : _apply,
                child: Text(l10n.dispConfirm),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
