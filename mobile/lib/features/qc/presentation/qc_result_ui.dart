import 'package:flutter/material.dart';

import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/inspection.dart';

/// Localized label, tone and icon for a QC result, so the list, the detail
/// header and each line all read the same way.
class QcResultUi {
  const QcResultUi(this.label, this.tone, this.icon);

  final String label;
  final StatusTone tone;
  final IconData icon;

  static QcResultUi of(AppLocalizations l10n, QcResult result) =>
      switch (result) {
        QcResult.pending =>
          QcResultUi(l10n.qcResultPending, StatusTone.neutral, Icons.pending_outlined),
        QcResult.pass =>
          QcResultUi(l10n.qcResultPass, StatusTone.success, Icons.check_circle_outline),
        QcResult.fail =>
          QcResultUi(l10n.qcResultFail, StatusTone.danger, Icons.cancel_outlined),
        QcResult.partial =>
          QcResultUi(l10n.qcResultPartial, StatusTone.warning, Icons.rule),
        QcResult.hold =>
          QcResultUi(l10n.qcResultHold, StatusTone.info, Icons.pause_circle_outline),
      };
}
