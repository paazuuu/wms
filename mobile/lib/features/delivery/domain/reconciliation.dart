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

/// A counted quantity for one JAN during a reconciliation session.
class CountedItem extends Equatable {
  const CountedItem({
    required this.janCode,
    required this.quantity,
    required this.source,
  });

  final String janCode;
  final int quantity;
  final CountSource source;

  CountedItem copyWith({int? quantity, CountSource? source}) => CountedItem(
        janCode: janCode,
        quantity: quantity ?? this.quantity,
        source: source ?? this.source,
      );

  @override
  List<Object?> get props => [janCode, quantity, source];
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

  /// Cumulative received including this session.
  int get receivedTotal => alreadyReceived + actualQuantity;

  /// Still outstanding (未納) after this session, never negative.
  int get remaining =>
      (plannedQuantity - receivedTotal).clamp(0, plannedQuantity);

  int get difference => receivedTotal - plannedQuantity;

  String get productName => planLine?.productName ?? '';

  @override
  List<Object?> get props =>
      [janCode, plannedQuantity, alreadyReceived, actualQuantity, status];
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
