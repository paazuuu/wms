import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../stock_ops/presentation/stock_ops_ui.dart' show signed;
import '../application/shipment_providers.dart';
import '../domain/shipment_parcel.dart';

/// What left the building on this shipment, parcel by parcel (§0075) — the
/// read a recall starts from: which lots and serials went to this customer,
/// and when. A SHIP_CANCEL row is shown as it happened, not hidden — a
/// reversal is part of the answer, not noise.
class ShipmentParcelsScreen extends ConsumerWidget {
  const ShipmentParcelsScreen({super.key, required this.shipmentId});

  final int shipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(shipmentParcelsProvider(shipmentId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.shipmentParcelsTitle)),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(shipmentParcelsProvider(shipmentId)),
        ),
        data: (parcels) => parcels.isEmpty
            ? EmptyStateView(
                icon: Icons.local_shipping_outlined,
                title: l10n.shipmentParcelsEmpty,
                message: l10n.shipmentParcelsEmptyBody,
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: parcels.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) => _ParcelCard(parcel: parcels[i]),
              ),
      ),
    );
  }
}

class _ParcelCard extends StatelessWidget {
  const _ParcelCard({required this.parcel});

  final ShipmentParcel parcel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fmt = DateFormat('M/d HH:mm');
    final tone = parcel.isReversal ? StatusTone.danger : StatusTone.neutral;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    parcel.productName.isEmpty
                        ? parcel.janCode
                        : parcel.productName,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (parcel.isReversal) ...[
                  StatusPill(
                      tone: StatusTone.danger,
                      label: l10n.shipmentParcelReversalTag,
                      dense: true),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Text(
                  signed(parcel.quantity),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontFamily: AppFonts.mono,
                    color: tone == StatusTone.danger
                        ? scheme.error
                        : scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(parcel.janCode,
                style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: AppFonts.mono,
                    color: scheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: 2,
              children: [
                if (parcel.createdAt != null)
                  _Meta(
                      icon: Icons.schedule,
                      text: fmt.format(parcel.createdAt!)),
                if (parcel.lotCode != null)
                  _Meta(
                      icon: Icons.inventory_2_outlined,
                      text: parcel.expiryDate == null
                          ? 'L:${parcel.lotCode}'
                          : 'L:${parcel.lotCode} (${parcel.expiryDate})'),
                if (parcel.serialNumber != null)
                  _Meta(
                      icon: Icons.qr_code,
                      text: 'S/N:${parcel.serialNumber}'),
                if (parcel.binCode != null)
                  _Meta(icon: Icons.place_outlined, text: parcel.binCode!),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 2),
        Text(text,
            style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: AppFonts.mono, color: scheme.onSurfaceVariant)),
      ],
    );
  }
}
