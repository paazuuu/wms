import 'package:equatable/equatable.dart';

import 'delivery_plan.dart';
import 'delivery_plan_line.dart';
import 'jan.dart';

/// Where an actual count came from, so the UI can show how each line was
/// confirmed and the submission can record provenance.
enum CountSource {
  /// A barcode scanned with the handheld or camera.
  scan('scan'),

  /// Suggested by on-device OCR of the delivery note, then accepted.
  ocr('ocr'),

  /// Typed by the operator.
  manual('manual');

  const CountSource(this.wire);

  final String wire;
}

/// One parcel of a counted line, as §12's Receipt Item level (0067).
///
/// A pallet is not a number. Forty cartons on two lots with two expiry dates is
/// two parcels, and recording it as "40" throws away the part every later step
/// needs: QC inspects a parcel, put-away moves a parcel, a recall traces a
/// parcel.
///
/// Parcels are optional detail on top of the line's total, not a replacement for
/// it — which mirrors the server exactly. `reconcile_delivery_plan` takes
/// `actual_quantity` plus an optional `items` array and posts whatever the
/// parcels did not account for as one unspecified parcel. So an operator who just
/// counts still gets a receipt, and one who records lots gets a traceable one.
class ReceivedParcel extends Equatable {
  const ReceivedParcel({
    required this.quantity,
    this.lotCode,
    this.expiry,
    this.serialNumber,
    this.locationCode,
    this.statusCode,
    this.note,
  });

  final int quantity;
  final String? lotCode;
  final DateTime? expiry;
  final String? serialNumber;

  /// Where it was put, as the code printed on the rack.
  final String? locationCode;

  /// Only for a parcel that arrived in a worse state than the product's flag
  /// implies — DAMAGED for a wet carton. Naming a *better* status is refused by
  /// the server (0072), so the UI never offers one.
  final String? statusCode;
  final String? note;

  /// A serialised parcel is one unit, which the server enforces too.
  bool get isSerial => serialNumber != null && serialNumber!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'quantity': quantity,
        if (lotCode != null && lotCode!.isNotEmpty) 'lot_code': lotCode,
        if (expiry != null)
          'expiry': expiry!.toIso8601String().split('T').first,
        if (serialNumber != null && serialNumber!.isNotEmpty)
          'serial_number': serialNumber,
        if (locationCode != null && locationCode!.isNotEmpty)
          'location_code': locationCode,
        if (statusCode != null && statusCode!.isNotEmpty) 'status': statusCode,
        if (note != null && note!.isNotEmpty) 'note': note,
      };

  @override
  List<Object?> get props =>
      [quantity, lotCode, expiry, serialNumber, locationCode, statusCode, note];
}

/// A counted quantity for one JAN during a reconciliation session.
class CountedItem extends Equatable {
  const CountedItem({
    required this.janCode,
    required this.quantity,
    required this.source,
    this.parcels = const [],
  });

  final String janCode;
  final int quantity;
  final CountSource source;

  /// §12's parcels, when the operator recorded any. Their sum may be less than
  /// [quantity] — the rest goes in as one unattributed parcel — but never more,
  /// which the server refuses and [parcelledQuantity] lets the UI check first.
  final List<ReceivedParcel> parcels;

  int get parcelledQuantity => parcels.fold(0, (sum, p) => sum + p.quantity);

  /// How much of the count nobody has attributed to a lot or serial yet.
  int get unattributedQuantity => quantity - parcelledQuantity;

  /// The disagreement the server refuses: more in the parcels than on the line.
  bool get isOverParcelled => parcelledQuantity > quantity;

  CountedItem copyWith({
    int? quantity,
    CountSource? source,
    List<ReceivedParcel>? parcels,
  }) =>
      CountedItem(
        janCode: janCode,
        quantity: quantity ?? this.quantity,
        source: source ?? this.source,
        parcels: parcels ?? this.parcels,
      );

  @override
  List<Object?> get props => [janCode, quantity, source, parcels];
}

/// Outcome of comparing one JAN's planned vs. actual quantity.
enum ReconLineStatus {
  /// Expected, nothing counted yet.
  pending,

  /// Counted exactly the planned quantity.
  matched,

  /// Counted fewer than planned (partial / short delivery).
  shortfall,

  /// Counted more than planned.
  over,

  /// Counted but not on the plan at all (想定外).
  unexpected,
}

/// One row of the reconciliation view: a planned line, an unexpected arrival,
/// or a planned line still awaiting a count.
class ReconLine extends Equatable {
  const ReconLine({
    required this.janCode,
    required this.plannedQuantity,
    required this.actualQuantity,
    required this.status,
    this.alreadyReceived = 0,
    this.planLine,
    this.source,
    this.parcels = const [],
  });

  /// The matching plan line, or null when this arrival was unexpected.
  final DeliveryPlanLine? planLine;
  final String janCode;
  final int plannedQuantity;

  /// Received before this session, from earlier (split) deliveries.
  final int alreadyReceived;

  /// Counted in THIS session.
  final int actualQuantity;
  final ReconLineStatus status;
  final CountSource? source;

  /// §12's parcels recorded for this line, if any (0067).
  final List<ReceivedParcel> parcels;

  int get parcelledQuantity => parcels.fold(0, (sum, p) => sum + p.quantity);

  /// Counted but not yet attributed to a lot or serial. Shown rather than
  /// hidden: it is the part of the line that will land as one unspecified parcel,
  /// and for a lot-tracked product that is a gap someone should close.
  int get unattributedQuantity => actualQuantity - parcelledQuantity;

  /// The disagreement the server refuses (0067), surfaced before the submit so
  /// the operator fixes the line rather than reading an error.
  bool get isOverParcelled => parcelledQuantity > actualQuantity;

  /// Cumulative received including this session.
  int get receivedTotal => alreadyReceived + actualQuantity;

  /// Still outstanding (未納) after this session, never negative.
  int get remaining =>
      (plannedQuantity - receivedTotal).clamp(0, plannedQuantity);

  int get difference => receivedTotal - plannedQuantity;

  String get productName => planLine?.productName ?? '';

  @override
  List<Object?> get props =>
      [janCode, plannedQuantity, alreadyReceived, actualQuantity, status, parcels];
}

/// A fully computed comparison of a plan against the counted items.
class ReconciliationResult extends Equatable {
  const ReconciliationResult({required this.lines});

  /// Plan lines first (in plan order), then any unexpected arrivals.
  final List<ReconLine> lines;

  int get matchedCount =>
      lines.where((l) => l.status == ReconLineStatus.matched).length;
  int get shortfallCount =>
      lines.where((l) => l.status == ReconLineStatus.shortfall).length;
  int get overCount =>
      lines.where((l) => l.status == ReconLineStatus.over).length;
  int get unexpectedCount =>
      lines.where((l) => l.status == ReconLineStatus.unexpected).length;
  int get pendingCount =>
      lines.where((l) => l.status == ReconLineStatus.pending).length;

  /// Number of planned lines that have been resolved (anything but pending).
  int get resolvedPlannedCount =>
      lines.where((l) => l.planLine != null).length - pendingCount;

  int get plannedLineCount => lines.where((l) => l.planLine != null).length;

  /// Total still outstanding (未納) across the plan after this session — the
  /// number of units that would carry over to a future delivery.
  int get outstandingTotal => lines.fold(0, (sum, l) => sum + l.remaining);

  /// True when at least one planned line is still short after this session, so
  /// the plan could be kept open as a partial delivery.
  bool get hasOutstanding => outstandingTotal > 0;

  /// True when every planned line matches and nothing unexpected arrived.
  bool get isClean =>
      pendingCount == 0 &&
      shortfallCount == 0 &&
      overCount == 0 &&
      unexpectedCount == 0;

  /// True when nothing at all remains outstanding or discrepant — the "ready to
  /// complete without warnings" state.
  bool get hasDiscrepancies =>
      shortfallCount > 0 || overCount > 0 || unexpectedCount > 0;

  /// True when any line claims more in its parcels than on the line itself. The
  /// server refuses such a receipt (0067), so the screen can stop the submit and
  /// point at the line instead.
  bool get hasOverParcelledLine => lines.any((l) => l.isOverParcelled);

  // Deliberately not here: a "this lot-tracked line has no parcels" warning.
  // The plan line does not carry the product's tracking mode, so the client
  // cannot tell which lines need one without another read — and 0071 already
  // raises a LOT_MISSING exception for exactly this case the moment the receipt
  // is posted. A guess here would be a worse version of a check that exists.

  @override
  List<Object?> get props => [lines];
}

/// Pure comparison: given an expected [plan] and the [counts] gathered so far
/// (keyed by JAN), produce the per-line statuses and totals. Plan order is
/// preserved; unexpected arrivals are appended in insertion order.
ReconciliationResult buildReconciliation(
  DeliveryPlan plan,
  Map<String, CountedItem> counts,
) {
  final lines = <ReconLine>[];
  final plannedJans = <String>{};
  // Match on the canonical JAN so formatting differences (hyphens, full-width
  // digits, a dropped leading zero) never cause a false "unexpected".
  final normCounts = <String, CountedItem>{
    for (final e in counts.entries) normalizeJan(e.key): e.value,
  };

  for (final planLine in plan.lines) {
    final nj = normalizeJan(planLine.janCode);
    plannedJans.add(nj);
    final counted = normCounts[nj];
    final actual = counted?.quantity ?? 0;
    lines.add(ReconLine(
      planLine: planLine,
      janCode: planLine.janCode,
      plannedQuantity: planLine.plannedQuantity,
      alreadyReceived: planLine.receivedQuantity,
      actualQuantity: actual,
      source: counted?.source,
      parcels: counted?.parcels ?? const [],
      status: _statusFor(
          planLine.plannedQuantity, planLine.receivedQuantity + actual),
    ));
  }

  for (final entry in normCounts.entries) {
    if (plannedJans.contains(entry.key)) continue;
    lines.add(ReconLine(
      janCode: entry.value.janCode,
      plannedQuantity: 0,
      actualQuantity: entry.value.quantity,
      source: entry.value.source,
      parcels: entry.value.parcels,
      status: ReconLineStatus.unexpected,
    ));
  }

  return ReconciliationResult(lines: lines);
}

/// Status of a planned line from its cumulative received quantity (earlier
/// deliveries plus this session).
ReconLineStatus _statusFor(int planned, int received) {
  if (received == 0) return ReconLineStatus.pending;
  if (received == planned) return ReconLineStatus.matched;
  if (received < planned) return ReconLineStatus.shortfall;
  return ReconLineStatus.over;
}
