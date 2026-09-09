import 'package:flutter/material.dart';

import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/pick_list.dart';

class PickListStatusUi {
  const PickListStatusUi(this.label, this.icon, this.tone);

  final String label;
  final IconData icon;
  final StatusTone tone;

  static PickListStatusUi of(AppLocalizations l10n, PickListStatus status) =>
      switch (status) {
        PickListStatus.picking => PickListStatusUi(l10n.pickStatusPicking,
            Icons.shopping_cart_checkout_outlined, StatusTone.info),
        PickListStatus.picked => PickListStatusUi(
            l10n.pickStatusPicked, Icons.task_alt, StatusTone.success),
        PickListStatus.cancelled => PickListStatusUi(
            l10n.pickStatusCancelled, Icons.block, StatusTone.neutral),
      };
}

class PickTaskStatusUi {
  const PickTaskStatusUi(this.label, this.tone);

  final String label;
  final StatusTone tone;

  static PickTaskStatusUi of(AppLocalizations l10n, PickTaskStatus status) =>
      switch (status) {
        PickTaskStatus.pending =>
          PickTaskStatusUi(l10n.pickTaskPending, StatusTone.neutral),
        PickTaskStatus.picked =>
          PickTaskStatusUi(l10n.pickTaskPicked, StatusTone.success),
        PickTaskStatus.short =>
          PickTaskStatusUi(l10n.pickTaskShort, StatusTone.danger),
        PickTaskStatus.over =>
          PickTaskStatusUi(l10n.pickTaskOver, StatusTone.warning),
      };
}
