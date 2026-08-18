import 'package:flutter/material.dart';

import '../../../core/ui/status_pill.dart';
import '../domain/location.dart';

/// Single mapping from a location's active state to a [StatusTone] + icon, so
/// the list and detail screens render it identically.
class LocationStatusUi {
  const LocationStatusUi(this.tone, this.icon, this.label);

  final StatusTone tone;
  final IconData icon;
  final String label;

  static LocationStatusUi of(Location location) => location.isActive
      ? const LocationStatusUi(StatusTone.success, Icons.place, 'Active')
      : const LocationStatusUi(
          StatusTone.neutral, Icons.location_off_outlined, 'Inactive');
}
