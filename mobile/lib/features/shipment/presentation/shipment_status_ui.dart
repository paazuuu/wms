import 'package:flutter/material.dart';

import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/shipment_status.dart';

/// Maps a shipment's lifecycle status to a tone + icon + label.
class ShipmentStatusUi {
  const ShipmentStatusUi(this.tone, this.icon, this.label);

  final StatusTone tone;
  final IconData icon;
  final String label;

  static ShipmentStatusUi of(AppLocalizations l10n, ShipmentStatus status) =>
      switch (status) {
        ShipmentStatus.open => ShipmentStatusUi(
            StatusTone.info, Icons.outbox_outlined, l10n.shipmentStatusOpen),
        ShipmentStatus.packing => ShipmentStatusUi(StatusTone.warning,
            Icons.inventory_2_outlined, l10n.shipmentStatusPacking),
        ShipmentStatus.shipped => ShipmentStatusUi(
            StatusTone.success, Icons.local_shipping, l10n.shipmentStatusShipped),
        ShipmentStatus.cancelled => ShipmentStatusUi(
            StatusTone.neutral, Icons.block, l10n.shipmentStatusCancelled),
      };
}
