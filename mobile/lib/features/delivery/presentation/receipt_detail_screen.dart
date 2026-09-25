import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../application/delivery_providers.dart';
import '../domain/receipt_detail.dart';
import '../domain/reconciliation.dart';
import 'parcel_sheet.dart';

/// One receipt, read back at all three of §12's levels (0067).
///
/// This screen is the reason the Item level exists. A week after a delivery,
/// "which lot did that bring, and where did it go" is a question somebody asks —
/// and before parcels were recorded the only answer was to find whoever was on
/// the dock. Each parcel shows the ledger row it posted, which is also the §5
/// argument on screen: the stock came from the movement, and the parcel only says
/// where the movement came from.
class ReceiptDetailScreen extends ConsumerWidget {
  const ReceiptDetailScreen({super.key, required this.reconciliationId});

  final int reconciliationId;

  Future<void> _addParcel(
      BuildContext context, WidgetRef ref, ReceiptLine line) async {
    final parcel = await showModalBottomSheet<ReceivedParcel>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ParcelSheet(
        janCode: line.janCode,
        productName: line.title,
      ),
    );
    if (parcel == null || !context.mounted) return;

    final l10n = AppLocalizations.of(context);
    final result =
        await ref.read(deliveryRepositoryProvider).recordReceiptItem(
              reconciliationId: reconciliationId,
              janCode: line.janCode,
              quantity: parcel.quantity,
              lineId: line.id,
              lotCode: parcel.lotCode,
              expiry: parcel.expiry,
              serialNumber: parcel.serialNumber,
              locationCode: parcel.locationCode,
              statusCode: parcel.statusCode,
              note: parcel.note,
            );
    if (!context.mounted) return;
    result.when(
      success: (_) => ref.invalidate(receiptDetailProvider(reconciliationId)),
      failure: (f) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(humanizeApiErrorMessage(l10n, f.message)),
          backgroundColor: Theme.of(context).colorScheme.error,
        )),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(receiptDetailProvider(reconciliationId));

    return Scaffold(
      appBar: AppBar(
        title: Text(async.valueOrNull?.referenceNo ?? l10n.receiptDetailTitle),
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () =>
              ref.invalidate(receiptDetailProvider(reconciliationId)),
        ),
        data: (receipt) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(receiptDetailProvider(reconciliationId)),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _Header(receipt: receipt),
              const SizedBox(height: AppSpacing.md),
              for (final line in receipt.lines) ...[
                _LineCard(
                  line: line,
                  onAddParcel: () => _addParcel(context, ref, line),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (receipt.unlinkedItems.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.receiptUnlinkedTitle,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.receiptUnlinkedBody,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final item in receipt.unlinkedItems)
                  _ParcelTile(item: item),
              ],
              if (receipt.lines.isEmpty && receipt.unlinkedItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xl),
                  child: EmptyStateView(
                    icon: Icons.inbox_outlined,
                    title: l10n.receiptEmpty,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.receipt});

  final ReceiptDetail receipt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final df = DateFormat('yyyy-MM-dd HH:mm');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    receipt.deliveryNumber ?? receipt.referenceNo ?? '—',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                StatusPill(
                    tone: StatusTone.neutral, label: receipt.status, dense: true),
              ],
            ),
            if (receipt.supplierName != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(receipt.supplierName!,
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.receiptTotalUnits(receipt.totalUnits)),
            // The figure that explains a receipt whose goods are on hand and
            // unusable — §13's held stock, at the point it was created.
            if (receipt.hasHeldStock) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Icon(Icons.pan_tool_outlined, size: 16, color: scheme.error),
                  const SizedBox(width: AppSpacing.xs),
                  Text(l10n.receiptHeldUnits(receipt.heldUnits),
                      style: TextStyle(color: scheme.error)),
                ],
              ),
            ],
            if (receipt.createdAt != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(df.format(receipt.createdAt!),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({required this.line, required this.onAddParcel});

  final ReceiptLine line;
  final VoidCallback onAddParcel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(line.title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                Text(
                  l10n.receiptLinePlannedActual(
                      line.plannedQuantity, line.actualQuantity),
                  style: theme.textTheme.bodyMedium,
                ),
                IconButton(
                  tooltip: l10n.receiptAddParcelTooltip,
                  icon: const Icon(Icons.add_box_outlined),
                  visualDensity: VisualDensity.compact,
                  onPressed: onAddParcel,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(line.janCode,
                style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: AppFonts.mono, color: scheme.onSurfaceVariant)),
            if (line.items.isEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.receiptLineNoParcels,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ] else ...[
              const Divider(height: AppSpacing.lg),
              for (final item in line.items) _ParcelTile(item: item),
            ],
          ],
        ),
      ),
    );
  }
}

/// One parcel. Compact on purpose: a receipt of thirty parcels should still be
/// scannable by eye, and the details that matter for picking one out are the lot,
/// the expiry and where it went.
class _ParcelTile extends StatelessWidget {
  const _ParcelTile({required this.item});

  final ReceiptItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final df = DateFormat('yyyy-MM-dd');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.isHeld ? Icons.pan_tool_outlined : Icons.inventory_2_outlined,
            size: 18,
            color: item.isHeld ? scheme.error : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${item.quantity}',
                        style: theme.textTheme.titleSmall),
                    const SizedBox(width: AppSpacing.sm),
                    if (item.lotCode != null)
                      Expanded(
                        child: Text(l10n.receiptParcelLot(item.lotCode!),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontFamily: AppFonts.mono),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      )
                    else if (item.serialNumber != null)
                      Expanded(
                        child: Text(item.serialNumber!,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontFamily: AppFonts.mono),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      )
                    else
                      // An unattributed parcel is the remainder the server posts
                      // when the operator recorded no lot. Named, not blank.
                      Expanded(
                        child: Text(l10n.receiptParcelUnattributed,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant)),
                      ),
                    if (item.isHeld)
                      StatusPill(
                          tone: StatusTone.warning,
                          label: item.statusName ?? item.statusCode,
                          dense: true),
                  ],
                ),
                if (item.expiry != null || item.locationCode != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (item.expiry != null)
                        l10n.receiptParcelExpiry(df.format(item.expiry!)),
                      if (item.locationCode != null) '→ ${item.locationCode}',
                    ].join('  '),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
                if (item.note != null) ...[
                  const SizedBox(height: 2),
                  Text(item.note!, style: theme.textTheme.bodySmall),
                ],
                // §5 on screen: the stock came from this movement, and the
                // parcel only records where the movement came from.
                if (item.movementId != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    l10n.receiptParcelMovement(item.movementId!),
                    style: theme.textTheme.labelSmall?.copyWith(
                        fontFamily: AppFonts.mono,
                        color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
