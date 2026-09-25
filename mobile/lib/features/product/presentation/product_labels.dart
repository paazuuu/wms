import '../../../l10n/app_localizations.dart';
import '../domain/product.dart';

/// Localized name for a tracking mode. `UNTRACKED` is the default and says
/// nothing an operator needs, so [trackingModeLabel] is only asked for the
/// others — see [_ProductFacts].
String trackingModeLabel(AppLocalizations l10n, TrackingMode mode) =>
    switch (mode) {
      TrackingMode.untracked => l10n.trackUntracked,
      TrackingMode.lot => l10n.trackLot,
      TrackingMode.serial => l10n.trackSerial,
      TrackingMode.lotAndSerial => l10n.trackLotAndSerial,
      TrackingMode.expiry => l10n.trackExpiry,
    };

/// A number the operator will read as "12", not "12.000000".
String formatFactor(double value) =>
    value == value.roundToDouble() && value.abs() < 1e15
        ? value.toStringAsFixed(0)
        : value.toString();

/// Localized name for a serial's status (0060). Kept as a lookup on the code so
/// a status added by a later migration shows as itself rather than crashing.
String serialStatusLabel(AppLocalizations l10n, String status) =>
    switch (status) {
      'IN_STOCK' => l10n.serialInStock,
      'SHIPPED' => l10n.serialShipped,
      'RETURNED' => l10n.serialReturned,
      'SCRAPPED' => l10n.serialScrapped,
      'HOLD' => l10n.serialHold,
      _ => status,
    };

/// Localized name for a put-away rule (0063). The rule records intent; Phase B's
/// put-away suggestion is what will act on it.
String putawayRuleLabel(AppLocalizations l10n, String rule) => switch (rule) {
      'MANUAL' => l10n.putawayManual,
      'FIXED' => l10n.putawayFixed,
      'CONSOLIDATE' => l10n.putawayConsolidate,
      'NEAREST_EMPTY' => l10n.putawayNearestEmpty,
      _ => rule,
    };

/// Localized name for a picking rule (0074, §16) — the draw order
/// `pick_candidates` advises in, and what an operator sets here in advance.
String pickingRuleLabel(AppLocalizations l10n, String rule) => switch (rule) {
      'FIFO' => l10n.pickRuleFifo,
      'FEFO' => l10n.pickRuleFefo,
      'LIFO' => l10n.pickRuleLifo,
      'MANUAL' => l10n.pickRuleManual,
      _ => rule,
    };
