import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/supply_chain.dart';

final _yen = NumberFormat('#,##0', 'ja');
final _yen2 = NumberFormat('#,##0.##', 'ja');

/// ¥ for totals: whole yen.
String scMoney(double v) => '${v < 0 ? '-' : ''}¥${_yen.format(v.abs().round())}';

/// ¥ for one unit: whole yen from ¥100, otherwise to the sen.
String scUnitMoney(double v) =>
    '${v < 0 ? '-' : ''}¥${v.abs() >= 100 ? _yen.format(v.abs().round()) : _yen2.format(v.abs())}';

/// A change: always signed.
String scSigned(double v, {bool unit = false}) {
  if (v.abs() < 0.005) return '±¥0';
  final s = unit ? scUnitMoney(v.abs()) : scMoney(v.abs());
  return '${v > 0 ? '+' : '-'}$s';
}

String scPercent(double? v, {int digits = 1}) => v == null ? '—' : '${(v * 100).toStringAsFixed(digits)}%';

String scSignedPoints(double? v) =>
    v == null ? '—' : '${v >= 0 ? '+' : ''}${(v * 100).toStringAsFixed(1)}pt';

String scNumber(double v) => v == v.roundToDouble() ? _yen.format(v) : _yen2.format(v);

/// "70%" from 0.7.
String scRate(double? r) => r == null ? '—' : '${(r * 100).toStringAsFixed(r * 100 == (r * 100).roundToDouble() ? 0 : 1)}%';

String scLineLabel(AppLocalizations l10n, String wire) => switch (wire) {
      'purchase' => l10n.scLinePurchase,
      'fx_impact' => l10n.scLineFx,
      'international_freight' => l10n.scLineIntlFreight,
      'insurance' => l10n.scLineInsurance,
      'customs_duty' => l10n.scLineDuty,
      'import_tax' => l10n.scLineImportTax,
      'customs_fee' => l10n.scLineCustomsFee,
      'port_fee' => l10n.scLinePortFee,
      'domestic_freight' => l10n.scLineDomesticFreight,
      'warehouse' => l10n.scLineWarehouse,
      'receiving' => l10n.scLineReceiving,
      'inspection' => l10n.scLineInspection,
      'packing' => l10n.scLinePacking,
      'labor' => l10n.scLineLabor,
      'overhead' => l10n.scLineOverhead,
      'other' => l10n.scLineOther,
      'revenue' => l10n.scLineRevenue,
      'sales_related' => l10n.scSalesRelated,
      _ => wire,
    };

String scCostLineLabel(AppLocalizations l10n, CostLine l) => scLineLabel(l10n, l.wire);

String scModeLabel(AppLocalizations l10n, String? mode) => switch (mode) {
      'sea' => l10n.scModeSea,
      'air' => l10n.scModeAir,
      'truck' => l10n.scModeTruck,
      'rail' => l10n.scModeRail,
      'courier' => l10n.scModeCourier,
      'internal' => l10n.scModeInternal,
      _ => mode ?? '—',
    };

const scModes = ['sea', 'air', 'truck', 'rail', 'courier', 'internal'];
const scNodeKinds = ['supplier', 'port', 'airport', 'customs', 'warehouse', 'dc', 'customer', 'hub'];

String scNodeKindLabel(AppLocalizations l10n, String kind) => switch (kind) {
      'supplier' => l10n.scKindSupplier,
      'port' => l10n.scKindPort,
      'airport' => l10n.scKindAirport,
      'customs' => l10n.scKindCustoms,
      'warehouse' => l10n.scKindWarehouse,
      'dc' => l10n.scKindDc,
      'customer' => l10n.scKindCustomer,
      'hub' => l10n.scKindHub,
      _ => kind,
    };

String scRiskLevelLabel(AppLocalizations l10n, RiskLevel l) => switch (l) {
      RiskLevel.low => l10n.scRiskLow,
      RiskLevel.medium => l10n.scRiskMedium,
      RiskLevel.high => l10n.scRiskHigh,
      RiskLevel.critical => l10n.scRiskCritical,
    };

String scRiskKindLabel(AppLocalizations l10n, String kind) => switch (kind) {
      'supplier' => l10n.scRiskKindSupplier,
      'node' => l10n.scRiskKindNode,
      'route' => l10n.scRiskKindRoute,
      _ => kind,
    };

String scEventKindLabel(AppLocalizations l10n, String kind) => switch (kind) {
      'supplier_stop' => l10n.scEvSupplierStop,
      'supplier_price' => l10n.scEvSupplierPrice,
      'supplier_delay' => l10n.scEvSupplierDelay,
      'route_stop' => l10n.scEvRouteStop,
      'mode_stop' => l10n.scEvModeStop,
      'port_stop' => l10n.scEvPortStop,
      'airport_stop' => l10n.scEvAirportStop,
      'customs_delay' => l10n.scEvCustomsDelay,
      'warehouse_capacity' => l10n.scEvWarehouseCapacity,
      'warehouse_stop' => l10n.scEvWarehouseStop,
      'domestic_stop' => l10n.scEvDomesticStop,
      'staff_shortage' => l10n.scEvStaffShortage,
      'cost_spike' => l10n.scEvCostSpike,
      _ => kind,
    };

/// A risk reason code (`level:high`, `sole_source:3`, …) in words.
String scReasonLabel(AppLocalizations l10n, String reason) {
  final i = reason.indexOf(':');
  final code = i < 0 ? reason : reason.substring(0, i);
  final arg = i < 0 ? '' : reason.substring(i + 1);
  return switch (code) {
    'level' => l10n.scReasonLevel(scRiskLevelLabel(l10n, RiskLevel.parse(arg))),
    'sole_source' => l10n.scReasonSole(arg),
    'event' => l10n.scReasonEvent(scEventKindLabel(l10n, arg)),
    'late_rate' => l10n.scReasonLate(arg),
    'defect_rate' => l10n.scReasonDefect(arg),
    'load_exceeded' => l10n.scReasonLoadExceeded,
    'load_busy' => l10n.scReasonLoadBusy,
    'no_alternative' => l10n.scReasonNoAlt,
    'long_lead' => l10n.scReasonLongLead(arg),
    'cross_border' => l10n.scReasonCrossBorder,
    _ => reason,
  };
}

String scLoadStatusLabel(AppLocalizations l10n, LoadStatus s) => switch (s) {
      LoadStatus.ok => l10n.scStatusOk,
      LoadStatus.busy => l10n.scStatusBusy,
      LoadStatus.exceeded => l10n.scStatusExceeded,
      LoadStatus.noCapacity => l10n.scStatusNoCapacity,
      LoadStatus.stopped => l10n.scStatusStopped,
    };

String scCategoryLabel(AppLocalizations l10n, String c) => switch (c) {
      'storage' => l10n.scCatStorage,
      'receiving' => l10n.scCatReceiving,
      'inspection' => l10n.scCatInspection,
      'packing' => l10n.scCatPacking,
      'picking' => l10n.scCatPicking,
      'shipping' => l10n.scCatShipping,
      'labor' => l10n.scCatLabor,
      'overhead' => l10n.scCatOverhead,
      'domestic_freight' => l10n.scCatDomesticFreight,
      'sales_related' => l10n.scCatSalesRelated,
      _ => l10n.scCatOther,
    };

String scBasisLabel(AppLocalizations l10n, String b) => switch (b) {
      'per_unit' => l10n.scBasisPerUnit,
      'per_unit_month' => l10n.scBasisPerUnitMonth,
      'per_carton' => l10n.scBasisPerCarton,
      'per_line' => l10n.scBasisPerLine,
      'per_order' => l10n.scBasisPerOrder,
      'per_hour' => l10n.scBasisPerHour,
      'percent_of_revenue' => l10n.scBasisPercentRevenue,
      'percent_of_purchase' => l10n.scBasisPercentPurchase,
      'fixed_monthly' => l10n.scBasisFixedMonthly,
      _ => b,
    };

String scRunKindLabel(AppLocalizations l10n, String k) => switch (k) {
      'baseline' => l10n.scRunKindBaseline,
      'scenario' => l10n.scRunKindScenario,
      'compare' => l10n.scRunKindCompare,
      'disruption' => l10n.scRunKindDisruption,
      'product' => l10n.scRunKindProduct,
      'purchase_check' => l10n.scRunKindPurchaseCheck,
      _ => k,
    };

/// A calculation note (`no_route`, `no_fx:USD`, …) in words.
String scNoteLabel(AppLocalizations l10n, String note) {
  final code = note.split(':').first;
  return switch (code) {
    'no_route' => l10n.scNoteNoRoute,
    'no_weight' => l10n.scNoteNoWeight,
    'no_volume' => l10n.scNoteNoVolume,
    'no_price' => l10n.scNoteNoPrice,
    'no_fx' => '${l10n.scNoteNoFx}${note.contains(':') ? ' (${note.split(':').last})' : ''}',
    'no_tariff_rule' => l10n.scNoteNoTariff,
    'fixed_cost_unallocated' => l10n.scNoteFixed,
    _ => note,
  };
}

/// A change field's "+10" (%) as a multiplier, or null when blank / zero.
double? scMultiplierFromPercent(String text) {
  final v = double.tryParse(text.trim().replaceAll('%', '').replaceAll('＋', '+').replaceAll('−', '-'));
  if (v == null || v == 0) return null;
  return 1 + v / 100;
}

String scPercentFromMultiplier(double? m) {
  if (m == null || m == 1) return '';
  // Rounded first: (1.2 - 1) × 100 is 20.000000000000004 in floating point.
  final p = ((m - 1) * 10000).round() / 100;
  return '${p > 0 ? '+' : ''}${p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toStringAsFixed(1)}';
}
