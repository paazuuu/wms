import 'package:flutter/material.dart';

import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/stock_ops.dart';

/// Presentation mapping for an adjustment reason. Kept out of the domain so the
/// enum stays a pure wire contract.
class AdjustReasonUi {
  const AdjustReasonUi(this.label, this.icon, this.tone);

  final String label;
  final IconData icon;
  final StatusTone tone;

  static AdjustReasonUi of(AppLocalizations l10n, AdjustReason reason) =>
      switch (reason) {
        AdjustReason.damage => AdjustReasonUi(
            l10n.reasonDamage, Icons.broken_image_outlined, StatusTone.danger),
        AdjustReason.loss => AdjustReasonUi(
            l10n.reasonLoss, Icons.search_off_outlined, StatusTone.danger),
        AdjustReason.found => AdjustReasonUi(
            l10n.reasonFound, Icons.emoji_objects_outlined, StatusTone.success),
        AdjustReason.correction => AdjustReasonUi(
            l10n.reasonCorrection, Icons.edit_outlined, StatusTone.info),
        AdjustReason.returned => AdjustReasonUi(
            l10n.reasonReturn, Icons.undo_outlined, StatusTone.info),
        AdjustReason.other =>
          AdjustReasonUi(l10n.reasonOther, Icons.more_horiz, StatusTone.neutral),
      };
}

class CountStatusUi {
  const CountStatusUi(this.label, this.icon, this.tone);

  final String label;
  final IconData icon;
  final StatusTone tone;

  static CountStatusUi of(AppLocalizations l10n, CountStatus status) =>
      switch (status) {
        CountStatus.counting => CountStatusUi(l10n.cntStatusCounting,
            Icons.playlist_add_check_outlined, StatusTone.info),
        CountStatus.completed => CountStatusUi(
            l10n.cntStatusCompleted, Icons.task_alt, StatusTone.success),
        CountStatus.cancelled => CountStatusUi(l10n.cntStatusCancelled,
            Icons.cancel_outlined, StatusTone.neutral),
      };
}

/// A signed quantity, formatted so the direction reads at a glance.
String signed(int value) => value > 0 ? '+$value' : '$value';

/// Tone for a signed delta: additions are informational, removals are the ones
/// worth noticing on a shelf.
StatusTone deltaTone(int value) => switch (value) {
      < 0 => StatusTone.danger,
      > 0 => StatusTone.success,
      _ => StatusTone.neutral,
    };
