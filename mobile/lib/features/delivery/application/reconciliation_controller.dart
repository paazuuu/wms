import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_result.dart';
import '../data/delivery_repository.dart';
import '../domain/delivery_plan.dart';
import '../domain/delivery_plan_line.dart';
import '../domain/jan.dart';
import '../domain/ocr_line.dart';
import '../domain/reconciliation.dart';

/// Live state of one reconciliation session: the plan being checked, the counts
/// gathered so far (keyed by JAN), and whether a submit is in flight.
class ReconciliationState {
  const ReconciliationState({
    required this.plan,
    this.counts = const {},
    this.submitting = false,
  });

  final DeliveryPlan plan;
  final Map<String, CountedItem> counts;
  final bool submitting;

  /// The computed comparison, derived fresh from [plan] and [counts].
  ReconciliationResult get result => buildReconciliation(plan, counts);

  ReconciliationState copyWith({
    Map<String, CountedItem>? counts,
    bool? submitting,
  }) =>
      ReconciliationState(
        plan: plan,
        counts: counts ?? this.counts,
        submitting: submitting ?? this.submitting,
      );
}

/// Drives a reconciliation session. Scanning is authoritative; OCR only seeds
/// JANs that have no count yet, so a scanned quantity is never overwritten.
class ReconciliationController extends StateNotifier<ReconciliationState> {
  ReconciliationController(this._repository, DeliveryPlan plan)
      : _planLines = {
          for (final l in plan.lines) normalizeJan(l.janCode): l,
        },
        super(ReconciliationState(plan: plan));

  final DeliveryRepository _repository;
  final Map<String, DeliveryPlanLine> _planLines;

  /// Count one more unit of [janCode] from a scan.
  void recordScan(String janCode) {
    final code = normalizeJan(janCode);
    if (code.isEmpty) return;
    final current = state.counts[code]?.quantity ?? 0;
    _put(code, current + 1, CountSource.scan);
  }

  /// Set an explicit quantity for [janCode]. Zero (or less) clears the count.
  void setQuantity(String janCode, int quantity,
      {CountSource source = CountSource.manual}) {
    final code = normalizeJan(janCode);
    if (code.isEmpty) return;
    if (quantity <= 0) {
      _remove(code);
    } else {
      _put(code, quantity, source);
    }
  }

  /// Remove a counted JAN entirely (e.g. an unexpected line keyed in error).
  void removeJan(String janCode) => _remove(normalizeJan(janCode));

  /// Seed counts from OCR of the delivery note. Planned JANs are pre-filled to
  /// the quantity still outstanding (so a partly-delivered line seeds only its
  /// remainder); JANs not on the plan surface as unexpected using the hint, or
  /// one unit. Existing counts win.
  void applyOcr(List<OcrLine> ocrLines) {
    final next = Map<String, CountedItem>.from(state.counts);
    for (final ocr in ocrLines) {
      final code = normalizeJan(ocr.janCode);
      if (code.isEmpty || next.containsKey(code)) continue;
      final line = _planLines[code];
      final outstanding = line == null
          ? null
          : (line.outstandingQuantity > 0
              ? line.outstandingQuantity
              : line.plannedQuantity);
      final quantity = ocr.quantityHint ?? outstanding ?? 1;
      next[code] = CountedItem(
        janCode: code,
        quantity: quantity,
        source: CountSource.ocr,
      );
    }
    state = state.copyWith(counts: next);
  }

  /// Record one parcel of [janCode] (§12, 0067).
  ///
  /// The line's total is raised to cover the parcels if it was lower, because a
  /// parcel the operator has in their hands is stock that arrived — and the
  /// server refuses a line whose parcels exceed it. Lowering the total is left to
  /// the operator: silently dropping a parcel to make the arithmetic work would
  /// lose a record of something physically present.
  void addParcel(String janCode, ReceivedParcel parcel) {
    final code = normalizeJan(janCode);
    if (code.isEmpty || parcel.quantity <= 0) return;
    final current = state.counts[code];
    final parcels = [...?current?.parcels, parcel];
    final parcelled = parcels.fold(0, (sum, p) => sum + p.quantity);
    final next = Map<String, CountedItem>.from(state.counts);
    next[code] = CountedItem(
      janCode: code,
      quantity: parcelled > (current?.quantity ?? 0)
          ? parcelled
          : current!.quantity,
      // A parcel is keyed in by hand even when the lot came off a scan, so the
      // line's provenance becomes manual unless it was already a scan.
      source: current?.source ?? CountSource.manual,
      parcels: parcels,
    );
    state = state.copyWith(counts: next);
  }

  /// Drop one parcel. The line's total is left alone: the operator may have
  /// mis-keyed the lot on a carton that did arrive.
  void removeParcel(String janCode, int index) {
    final code = normalizeJan(janCode);
    final current = state.counts[code];
    if (current == null || index < 0 || index >= current.parcels.length) return;
    final parcels = [...current.parcels]..removeAt(index);
    final next = Map<String, CountedItem>.from(state.counts);
    next[code] = current.copyWith(parcels: parcels);
    state = state.copyWith(counts: next);
  }

  void _put(String code, int quantity, CountSource source) {
    final next = Map<String, CountedItem>.from(state.counts);
    // Parcels survive a re-count: scanning two more units of a line whose lots
    // are already recorded should not throw the lots away.
    next[code] = CountedItem(
      janCode: code,
      quantity: quantity,
      source: source,
      parcels: state.counts[code]?.parcels ?? const [],
    );
    state = state.copyWith(counts: next);
  }

  void _remove(String code) {
    if (!state.counts.containsKey(code)) return;
    final next = Map<String, CountedItem>.from(state.counts)..remove(code);
    state = state.copyWith(counts: next);
  }

  /// Submit the reconciliation to the shared backend.
  Future<ApiResult<DeliveryPlan>> submit(
      {String? noteReference, bool complete = true}) async {
    state = state.copyWith(submitting: true);
    final entries = [
      for (final entry in state.counts.entries)
        ReconcileEntry(
          janCode: entry.key,
          actualQuantity: entry.value.quantity,
          source: entry.value.source,
          lineId: _planLines[entry.key]?.id,
          parcels: entry.value.parcels,
        ),
    ];
    final result = await _repository.reconcile(
      state.plan.id,
      entries: entries,
      noteReference: noteReference,
      complete: complete,
    );
    if (mounted) state = state.copyWith(submitting: false);
    return result;
  }
}
