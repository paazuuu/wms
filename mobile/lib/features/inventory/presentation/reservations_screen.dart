import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../product/presentation/product_detail_screen.dart';
import '../application/inventory_providers.dart';
import '../domain/reservation.dart';

/// Localized name for a reservation's status (0064).
String reservationStatusLabel(AppLocalizations l10n, String status) =>
    switch (status) {
      'ACTIVE' => l10n.reservationStatusActive,
      'FULFILLED' => l10n.reservationStatusFulfilled,
      'RELEASED' => l10n.reservationStatusReleased,
      _ => status,
    };

/// Localized name for what a reservation is for.
String reservationRefLabel(AppLocalizations l10n, String type) =>
    switch (type) {
      'sales_order' => l10n.refSalesOrder,
      'shipment' => l10n.refShipment,
      'transfer' => l10n.refTransfer,
      'work_order' => l10n.refWorkOrder,
      'manual' => l10n.refManual,
      _ => type,
    };

/// Stock promised to orders, and which parcels will supply it (§6, 0064).
///
/// Two things on one screen because they are two halves of one question. The
/// reservations are the promises; the over-allocated section is where a promise
/// and reality have come apart — which is *allowed* to happen, because an
/// allocation never blocks a shipment, so it has to be visible somewhere.
class ReservationsScreen extends ConsumerWidget {
  const ReservationsScreen({super.key});

  Future<void> _release(
      BuildContext context, WidgetRef ref, Reservation reservation) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.reservationReleaseQ),
        content: Text(l10n.reservationReleaseBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.reservationRelease),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final result = await ref
        .read(inventoryRepositoryProvider)
        .releaseReservation(reservation.id);
    if (!context.mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(reservationsProvider);
        ref.invalidate(overAllocatedProvider);
      },
      failure: (f) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(humanizeApiErrorMessage(l10n, f.message)),
          backgroundColor: Theme.of(context).colorScheme.error,
        )),
    );
  }

  Future<void> _fulfil(
      BuildContext context, WidgetRef ref, Reservation reservation) async {
    final quantity = await showDialog<int>(
      context: context,
      builder: (_) => _FulfilDialog(outstanding: reservation.outstanding),
    );
    if (quantity == null || !context.mounted) return;

    final l10n = AppLocalizations.of(context);
    final result = await ref
        .read(inventoryRepositoryProvider)
        .fulfilReservation(reservation.id, quantity: quantity);
    if (!context.mounted) return;
    result.when(
      success: (_) => ref.invalidate(reservationsProvider),
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
    final status = ref.watch(reservationStatusProvider);
    final async = ref.watch(reservationsProvider);
    final over = ref.watch(overAllocatedProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reservationsTitle),
        actions: [
          PopupMenuButton<String?>(
            initialValue: status,
            icon: const Icon(Icons.filter_list),
            onSelected: (v) =>
                ref.read(reservationStatusProvider.notifier).state = v,
            itemBuilder: (_) => [
              PopupMenuItem<String?>(
                  value: 'ACTIVE',
                  child: Text(l10n.reservationStatusActive)),
              PopupMenuItem<String?>(
                  value: 'FULFILLED',
                  child: Text(l10n.reservationStatusFulfilled)),
              PopupMenuItem<String?>(
                  value: 'RELEASED',
                  child: Text(l10n.reservationStatusReleased)),
              PopupMenuItem<String?>(
                  value: null, child: Text(l10n.reservationStatusAll)),
            ],
          ),
        ],
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(reservationsProvider),
        ),
        data: (reservations) {
          if (reservations.isEmpty && over.isEmpty) {
            return EmptyStateView(
              icon: Icons.bookmark_border,
              title: l10n.reservationsEmpty,
              message: l10n.reservationsEmptyBody,
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(reservationsProvider);
              ref.invalidate(overAllocatedProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                // First, because it is the only part of this screen that needs
                // someone to do something today.
                if (over.isNotEmpty) ...[
                  _OverAllocatedCard(rows: over),
                  const SizedBox(height: AppSpacing.md),
                ],
                for (final reservation in reservations) ...[
                  _ReservationCard(
                    reservation: reservation,
                    onRelease: () => _release(context, ref, reservation),
                    onFulfil: () => _fulfil(context, ref, reservation),
                  ),
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

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({
    required this.reservation,
    required this.onRelease,
    required this.onFulfil,
  });

  final Reservation reservation;
  final VoidCallback onRelease;
  final VoidCallback onFulfil;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final nf = NumberFormat.decimalPattern();
    final df = DateFormat('yyyy-MM-dd HH:mm');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProductDetailScreen(productId: reservation.productId),
        )),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(reservation.productName,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  // A lapsed reservation still reads ACTIVE in the database and
                  // holds nothing, so both facts are shown rather than one
                  // overwriting the other.
                  if (reservation.isExpired)
                    StatusPill(
                        tone: StatusTone.warning,
                        label: l10n.reservationLapsed,
                        dense: true)
                  else
                    StatusPill(
                      tone: reservation.isActive
                          ? StatusTone.info
                          : StatusTone.neutral,
                      label: reservationStatusLabel(l10n, reservation.status),
                      dense: true,
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                l10n.reservationFor(
                  reservationRefLabel(l10n, reservation.referenceType),
                  reservation.referenceId == null
                      ? ''
                      : '#${reservation.referenceId}',
                ),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                children: [
                  Text(l10n.reservationQuantity(nf.format(reservation.quantity)),
                      style: theme.textTheme.bodyMedium),
                  if (reservation.allocatedQuantity > 0)
                    Text(
                        l10n.reservationAllocated(
                            nf.format(reservation.allocatedQuantity)),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  // Worth naming: this part of the promise has no shelf behind
                  // it yet, so no picker can be sent for it.
                  if (reservation.isActive && reservation.unallocated > 0)
                    Text(
                        l10n.reservationUnallocated(
                            nf.format(reservation.unallocated)),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.tertiary)),
                  if (reservation.fulfilledQuantity > 0)
                    Text(
                        l10n.reservationFulfilled(
                            nf.format(reservation.fulfilledQuantity)),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
              if (reservation.expiresAt != null) ...[
                const SizedBox(height: 2),
                Text(df.format(reservation.expiresAt!),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
              if (reservation.allocations.isNotEmpty) ...[
                const Divider(height: AppSpacing.lg),
                Text(l10n.reservationAllocationsTitle,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.xs),
                for (final allocation in reservation.allocations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            [
                              if (allocation.lotCode != null)
                                l10n.stockPositionLot(allocation.lotCode!),
                              if (allocation.status != null) allocation.status!,
                            ].join(' · '),
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(nf.format(allocation.quantity),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontFamily: AppFonts.mono)),
                      ],
                    ),
                  ),
              ] else if (reservation.isActive) ...[
                const SizedBox(height: 2),
                Text(l10n.reservationNoAllocations,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
              if (reservation.isActive) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: onRelease,
                      child: Text(l10n.reservationRelease),
                    ),
                    // Only worth offering while something is still owed — a
                    // reservation already fully fulfilled has nothing left to
                    // mark.
                    if (reservation.outstanding > 0)
                      FilledButton.tonal(
                        onPressed: onFulfil,
                        child: Text(l10n.reservationFulfil),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Parcels promised to more than they hold. Shown only when it happens, with the
/// reason — otherwise it reads as a defect rather than as the deliberate
/// trade-off it is (a shipment must never be blocked by a plan).
class _OverAllocatedCard extends StatelessWidget {
  const _OverAllocatedCard({required this.rows});

  final List<OverAllocatedStock> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final nf = NumberFormat.decimalPattern();

    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_outlined,
                    size: 18, color: scheme.onErrorContainer),
                const SizedBox(width: AppSpacing.xs),
                Text(l10n.overAllocatedTitle,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: scheme.onErrorContainer)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.overAllocatedBody,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onErrorContainer)),
            const SizedBox(height: AppSpacing.sm),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.productName,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: scheme.onErrorContainer)),
                    Text(
                      l10n.overAllocatedRow(
                        nf.format(row.quantity),
                        nf.format(row.allocated),
                        nf.format(row.over),
                      ),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onErrorContainer),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Confirms recording a reservation as fulfilled, with a quantity — prefilled
/// with everything still outstanding, since that is the common case at
/// shipping time (`fulfil_reservation`'s own comment). Pops the quantity on
/// confirm, or null on cancel. Owns its own controller (the same shape
/// `_RenameDialog` uses elsewhere), so nothing disposes it while the pop
/// transition still needs it.
class _FulfilDialog extends StatefulWidget {
  const _FulfilDialog({required this.outstanding});

  final int outstanding;

  @override
  State<_FulfilDialog> createState() => _FulfilDialogState();
}

class _FulfilDialogState extends State<_FulfilDialog> {
  late final TextEditingController _quantity =
      TextEditingController(text: '${widget.outstanding}');
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.reservationFulfilTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.reservationFulfilBody),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _quantity,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.reservationFulfilQuantity,
              border: const OutlineInputBorder(),
              errorText: _error,
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
          onPressed: () {
            final quantity = int.tryParse(_quantity.text.trim());
            if (quantity == null || quantity <= 0) {
              setState(() => _error = l10n.parcelQuantityRequired);
              return;
            }
            Navigator.pop(context, quantity);
          },
          child: Text(l10n.reservationFulfil),
        ),
      ],
    );
  }
}
