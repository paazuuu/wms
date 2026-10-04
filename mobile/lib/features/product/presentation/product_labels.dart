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

/// A weight in grams as an operator reads it: "10.5 g", or "1.25 kg" from a
/// kilogram up (0115).
String gramsText(double grams) {
  String trim(double v, int digits) {
    final s = v.toStringAsFixed(digits);
    return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
  }

  return grams.abs() >= 1000 ? '${trim(grams / 1000, 2)} kg' : '${trim(grams, 1)} g';
}

/// Where a product's weight came from (0115).
String weightSourceLabel(AppLocalizations l10n, String? source) => switch (source) {
      'web' => l10n.wtSourceWeb,
      'measured' => l10n.wtSourceMeasured,
      _ => l10n.wtSourceManual,
    };

/// A unit's name in this screen's language. The unit vocabulary (0059) stores
/// Japanese names (個, 箱, ケース); the code is the stable key, so a known code
/// is named by the app and an unknown one keeps its stored name.
String uomName(AppLocalizations l10n, String code, String stored) => switch (code.toUpperCase()) {
      'PCS' => l10n.uomPcs,
      'SET' => l10n.uomSet,
      'PACK' => l10n.uomPack,
      'BOX' => l10n.uomBox,
      'CASE' => l10n.uomCase,
      'BAG' => l10n.uomBag,
      'ROLL' => l10n.uomRoll,
      'SHEET' => l10n.uomSheet,
      'DOZEN' => l10n.uomDozen,
      'PALLET' => l10n.uomPallet,
      'KG' => 'kg',
      'G' => 'g',
      'L' => 'L',
      'ML' => 'mL',
      'M' => 'm',
      'CM' => 'cm',
      _ => stored,
    };

String _mm(double? v) => v == null ? '—' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1));

/// A product's outer size (0125) in this screen's language — "幅 100 ×
/// 奥行 50 × 高さ 20 mm" — then any other notation; null when nothing is
/// known.
String? sizeText(AppLocalizations l10n, {double? width, double? depth, double? height, String? note}) {
  final parts = [
    if (width != null || depth != null || height != null) l10n.specSizeValue(_mm(width), _mm(depth), _mm(height)),
    if (note != null && note.trim().isNotEmpty) note.trim(),
  ];
  return parts.isEmpty ? null : parts.join('　');
}

/// Size and weight on one short line for a card: "100×50×20 mm · 12 g".
String? specShort({double? weightG, double? width, double? depth, double? height, String? note}) {
  final parts = [
    if (width != null || depth != null || height != null) '${_mm(width)}×${_mm(depth)}×${_mm(height)} mm'
    else if (note != null && note.trim().isNotEmpty) note.trim(),
    if (weightG != null) gramsText(weightG),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Where a product's size came from (0125).
String sizeSourceLabel(AppLocalizations l10n, String? source) => switch (source) {
      'web' => l10n.wtSourceWeb,
      'measured' => l10n.wtSourceMeasured,
      'file' => l10n.specSourceFile,
      _ => l10n.wtSourceManual,
    };
