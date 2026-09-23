import 'package:flutter/material.dart';

import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/pick_wave.dart';

class PickWaveStatusUi {
  const PickWaveStatusUi(this.label, this.icon, this.tone);

  final String label;
  final IconData icon;
  final StatusTone tone;

  static PickWaveStatusUi of(AppLocalizations l10n, PickWaveStatus status) =>
      switch (status) {
        PickWaveStatus.open => PickWaveStatusUi(
            l10n.waveStatusOpen, Icons.hourglass_empty, StatusTone.neutral),
        PickWaveStatus.picking => PickWaveStatusUi(l10n.waveStatusPicking,
            Icons.shopping_cart_checkout_outlined, StatusTone.info),
        PickWaveStatus.done => PickWaveStatusUi(
            l10n.waveStatusDone, Icons.task_alt, StatusTone.success),
        PickWaveStatus.cancelled => PickWaveStatusUi(
            l10n.waveStatusCancelled, Icons.block, StatusTone.neutral),
      };
}
