import 'package:flutter/material.dart';

import '../../../core/ui/status_pill.dart';
import '../domain/inspection.dart';
import '../domain/inspection_item.dart';

/// Presentation mapping for [InspectionStatus] — a single source of truth so
/// the list, detail header and any future screen stay visually consistent.
class InspectionStatusUi {
  const InspectionStatusUi(this.tone, this.icon, this.label);
  final StatusTone tone;
  final IconData icon;
  final String label;

  static InspectionStatusUi of(InspectionStatus status) => switch (status) {
        InspectionStatus.passed =>
          const InspectionStatusUi(StatusTone.success, Icons.check_circle, 'Passed'),
        InspectionStatus.failed =>
          const InspectionStatusUi(StatusTone.danger, Icons.cancel, 'Failed'),
        InspectionStatus.pending => const InspectionStatusUi(
            StatusTone.warning, Icons.hourglass_bottom, 'Pending'),
      };
}

/// Presentation mapping for a per-item [MatchResult].
class MatchResultUi {
  const MatchResultUi(this.tone, this.icon, this.label);
  final StatusTone tone;
  final IconData icon;
  final String label;

  static MatchResultUi of(MatchResult result) => switch (result) {
        MatchResult.ok =>
          const MatchResultUi(StatusTone.success, Icons.check_circle, 'OK'),
        MatchResult.ng =>
          const MatchResultUi(StatusTone.danger, Icons.report, 'NG'),
        MatchResult.pending => const MatchResultUi(
            StatusTone.warning, Icons.hourglass_bottom, 'PENDING'),
      };
}

/// Human label for the inspection type code.
String inspectionTypeLabel(String type) => switch (type) {
      'receiving' => 'Receiving',
      'shipping' => 'Shipping',
      _ => type.isEmpty ? 'Other' : '${type[0].toUpperCase()}${type.substring(1)}',
    };
