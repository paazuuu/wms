import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/export/csv_export.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../application/delivery_providers.dart';
import '../domain/stock_movement.dart';

/// Localized label + tone for a movement type. Increases read as positive,
/// decreases as informational, reversals as warnings.
({String label, StatusTone tone}) _movementUi(
    AppLocalizations l10n, String type) {
  return switch (type) {
    'OPENING' => (label: l10n.mvOpening, tone: StatusTone.neutral),
    'RECEIPT' => (label: l10n.mvReceipt, tone: StatusTone.success),
    'RECEIPT_CANCEL' => (label: l10n.mvReceiptCancel, tone: StatusTone.warning),
    'PUTAWAY' => (label: l10n.mvPutaway, tone: StatusTone.info),
    'PICK' => (label: l10n.mvPick, tone: StatusTone.info),
    'SHIP' => (label: l10n.mvShip, tone: StatusTone.info),
    'SHIP_CANCEL' => (label: l10n.mvShipCancel, tone: StatusTone.warning),
    'ADJUST' => (label: l10n.mvAdjust, tone: StatusTone.warning),
    'COUNT' => (label: l10n.mvCount, tone: StatusTone.neutral),
    'TRANSFER_IN' => (label: l10n.mvTransferIn, tone: StatusTone.success),
    'TRANSFER_OUT' => (label: l10n.mvTransferOut, tone: StatusTone.info),
    _ => (label: type, tone: StatusTone.neutral),
  };
}

/// The stock ledger for one JAN: every movement, newest first, each showing
/// before → after so "why did stock change" is answerable at a glance (spec §18).
///
/// Since 0061/0064 the screen opens with what the quantity currently *consists
/// of* — available, reserved, and anything held back — above the history of how
/// it got there. The two answer different questions and belong together: a
/// number that looks wrong is explained either by a movement or by a hold.
class StockLedgerScreen extends ConsumerWidget {
  const StockLedgerScreen({
    super.key,
    required this.janCode,
    this.productName = '',
    this.productId,
  });

  final String janCode;
  final String productName;

  /// Null for a JAN the product master does not know yet (0058): there is no
  /// position to fetch, and the screen says so instead of showing zeroes.
  final int? productId;

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final moves = ref.read(stockLedgerProvider(janCode)).valueOrNull ?? const [];
    final fmt = DateFormat('yyyy-MM-dd HH:mm:ss');
    try {
      final path = await exportCsv(
        fileName: 'stock_ledger_$janCode.csv',
        headers: const [
          'id',
          'created_at',
          'warehouse_name',
          'movement_type',
          'quantity',
          'quantity_before',
          'quantity_after',
          'reference_type',
          'reference_id',
          'note',
        ],
        rows: [
          for (final m in moves)
            [
              m.id,
              m.createdAt == null ? '' : fmt.format(m.createdAt!),
              m.warehouseName,
              m.movementType,
              m.quantity,
              m.quantityBefore,
              m.quantityAfter,
              m.referenceType ?? '',
              m.referenceId ?? '',
              m.note ?? '',
            ],
        ],
      );
      if (!context.mounted || path == null) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.auditExported)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(l10n.auditExportFailed),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final async = ref.watch(stockLedgerProvider(janCode));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.ledgerTitle, style: theme.textTheme.titleMedium),
            Text(
              productName.isNotEmpty ? productName : janCode,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.csvExportTitle,
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => _export(context, ref),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(stockLedgerProvider(janCode)),
        ),
        data: (moves) {
          // The position is worth showing even with no movements — stock can
          // have been held or promised without the quantity ever changing.
          final header = _PositionHeader(productId: productId);
          if (moves.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(stockLedgerProvider(janCode)),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  header,
                  const SizedBox(height: AppSpacing.lg),
                  EmptyStateView(
                    icon: Icons.history,
                    title: l10n.ledgerEmpty,
                    message: l10n.ledgerSubtitle,
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(stockLedgerProvider(janCode)),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: moves.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) => i == 0
                  ? header
                  : _MovementCard(move: moves[i - 1]),
            ),
          );
        },
      ),
    );
  }
}

/// On hand / available / reserved for one product, with the per-status and
/// per-lot parcels behind them (§5, 0061/0064).
class _PositionHeader extends ConsumerWidget {
  const _PositionHeader({required this.productId});

  final int? productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // A JAN with no product cannot have a position. Saying so is more useful
    // than four zeroes, because the fix is to register the product — after which
    // 0058's linking fills the history in by itself.
    if (productId == null) {
      return Card(
        color: scheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.link_off, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(l10n.stockNotLinkedToProduct,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ),
            ],
          ),
        ),
      );
    }

    final async = ref.watch(stockPositionProvider(productId!));
    return async.when(
      // Quiet while loading and quiet on failure: this is a supplement to the
      // ledger below it, and an error banner over the history would be louder
      // than the thing it is reporting.
      loading: () => const SizedBox(height: AppSpacing.xl),
      error: (_, __) => const SizedBox.shrink(),
      data: (position) {
        final nf = NumberFormat.decimalPattern();
        final interesting =
            position.parcels.where((p) => p.quantity != 0).toList();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.stockPositionTitle,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _Figure(
                        label: l10n.stockOnHandUnit,
                        value: nf.format(position.onHand)),
                    _Figure(
                      label: l10n.stockAvailable,
                      value: nf.format(position.available),
                      // The one number an outbound decision is made on, and the
                      // one that can be negative.
                      emphasise: true,
                      tone: position.isOverPromised ? scheme.error : null,
                    ),
                    if (position.reserved != 0)
                      _Figure(
                          label: l10n.stockReserved,
                          value: nf.format(position.reserved)),
                    if (position.allocated != 0)
                      _Figure(
                          label: l10n.stockAllocated,
                          value: nf.format(position.allocated)),
                    if (position.unavailable != 0)
                      _Figure(
                          label: l10n.stockUnavailable,
                          value: nf.format(position.unavailable)),
                  ],
                ),
                if (position.isOverPromised) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Icon(Icons.warning_amber_outlined,
                          size: 16, color: scheme.error),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(l10n.stockOverPromised,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.error)),
                      ),
                    ],
                  ),
                ],
                if (interesting.isNotEmpty) ...[
                  const Divider(height: AppSpacing.lg),
                  for (final parcel in interesting)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              parcel.lotCode == null
                                  ? parcel.statusName
                                  : '${parcel.statusName} · '
                                      '${l10n.stockPositionLot(parcel.lotCode!)}',
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(nf.format(parcel.quantity),
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontFamily: AppFonts.mono)),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    this.emphasise = false,
    this.tone,
  });

  final String label;
  final String value;
  final bool emphasise;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant)),
        Text(
          value,
          style: (emphasise
                  ? theme.textTheme.titleLarge
                  : theme.textTheme.titleMedium)
              ?.copyWith(
            fontFamily: AppFonts.mono,
            fontWeight: emphasise ? FontWeight.w700 : null,
            color: tone,
          ),
        ),
      ],
    );
  }
}

class _MovementCard extends StatelessWidget {
  const _MovementCard({required this.move});

  final StockMovement move;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final ui = _movementUi(l10n, move.movementType);
    final nf = NumberFormat.decimalPattern();
    final signed = '${move.isIncrease ? '+' : ''}${nf.format(move.quantity)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusPill(tone: ui.tone, label: ui.label, dense: true),
                const Spacer(),
                Text(
                  signed,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: AppFonts.mono,
                    fontWeight: FontWeight.w700,
                    color: move.isIncrease ? scheme.primary : scheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text(
                  '${nf.format(move.quantityBefore)} → ${nf.format(move.quantityAfter)}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontFamily: AppFonts.mono),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.ledgerBeforeAfter,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: 2,
              children: [
                if (move.createdAt != null)
                  Text(
                    DateFormat('yyyy/MM/dd HH:mm').format(move.createdAt!),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                if (move.warehouseName.isNotEmpty)
                  Text(
                    move.warehouseName,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                if (move.referenceType != null && move.referenceId != null)
                  Text(
                    '${move.referenceType} #${move.referenceId}',
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: AppFonts.mono, color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
