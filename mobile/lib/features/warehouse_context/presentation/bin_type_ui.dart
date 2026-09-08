import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';

/// Localized label + tone for a bin type (spec §8). STAGING/QC_HOLD read as
/// "not normal pickable stock", so they carry a warning/danger tone.
class BinTypeUi {
  const BinTypeUi(this.label, this.tone);

  final String label;
  final StatusTone tone;

  static BinTypeUi of(AppLocalizations l10n, String binType) =>
      switch (binType) {
        'STAGING' => BinTypeUi(l10n.whBinStaging, StatusTone.warning),
        'PICKABLE' => BinTypeUi(l10n.whBinPickable, StatusTone.success),
        'PICKABLE_STAGING' =>
          BinTypeUi(l10n.whBinPickableStaging, StatusTone.info),
        'QC_HOLD' => BinTypeUi(l10n.whBinQcHold, StatusTone.danger),
        'SHIPPING' => BinTypeUi(l10n.whBinShipping, StatusTone.info),
        'RETURNS' => BinTypeUi(l10n.whBinReturns, StatusTone.warning),
        'DAMAGED' => BinTypeUi(l10n.whBinDamaged, StatusTone.danger),
        'VIRTUAL' => BinTypeUi(l10n.whBinVirtual, StatusTone.neutral),
        _ => BinTypeUi(binType, StatusTone.neutral),
      };
}
