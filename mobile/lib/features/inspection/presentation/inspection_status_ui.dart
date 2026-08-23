import 'package:flutter/material.dart';

import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/inspection.dart';
import '../domain/inspection_item.dart';

/// Presentation mapping for [InspectionStatus] — a single source of truth so
/// the list, detail header and any future screen stay visually consistent.
class InspectionStatusUi {
  const InspectionStatusUi(this.tone, this.icon, this.label);
  final StatusTone tone;
  final IconData icon;
  final String label;

  static InspectionStatusUi of(AppLocalizations l10n, InspectionStatus status) =>
      switch (status) {
        InspectionStatus.passed => InspectionStatusUi(
            StatusTone.success, Icons.check_circle, l10n.inspectionPassed),
        InspectionStatus.failed => InspectionStatusUi(
            StatusTone.danger, Icons.cancel, l10n.inspectionFailed),
        InspectionStatus.pending => InspectionStatusUi(
            StatusTone.warning, Icons.hourglass_bottom, l10n.statusPending),
      };
}

/// Presentation mapping for a per-item [MatchResult].
class MatchResultUi {
  const MatchResultUi(this.tone, this.icon, this.label);
  final StatusTone tone;
  final IconData icon;
  final String label;

  static MatchResultUi of(AppLocalizations l10n, MatchResult result) =>
      switch (result) {
        MatchResult.ok =>
          MatchResultUi(StatusTone.success, Icons.check_circle, l10n.matchOk),
        MatchResult.ng =>
          MatchResultUi(StatusTone.danger, Icons.report, l10n.matchNg),
        MatchResult.pending => MatchResultUi(
            StatusTone.warning, Icons.hourglass_bottom, l10n.statusPending),
      };
}

/// Localized label for the inspection type code.
String inspectionTypeLabel(AppLocalizations l10n, String type) => switch (type) {
      'receiving' => l10n.typeReceiving,
      'shipping' => l10n.typeShipping,
      _ => type.isEmpty
          ? l10n.typeOther
          : '${type[0].toUpperCase()}${type.substring(1)}',
    };
