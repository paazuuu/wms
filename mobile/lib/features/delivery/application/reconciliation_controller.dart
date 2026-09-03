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
  /// their planned quantity (a safe, reviewable default); JANs not on the plan
  /// surface as unexpected using the hint, or one unit. Existing counts win.
  void applyOcr(List<OcrLine> ocrLines) {
    final next = Map<String, CountedItem>.from(state.counts);
    for (final ocr in ocrLines) {
      final code = normalizeJan(ocr.janCode);
      if (code.isEmpty || next.containsKey(code)) continue;
      final planned = _planLines[code]?.plannedQuantity;
      final quantity = ocr.quantityHint ?? planned ?? 1;
      next[code] = CountedItem(
        janCode: code,
        quantity: quantity,
        source: CountSource.ocr,
      );
    }
    state = state.copyWith(counts: next);
  }

  void _put(String code, int quantity, CountSource source) {
    final next = Map<String, CountedItem>.from(state.counts);
    next[code] = CountedItem(janCode: code, quantity: quantity, source: source);
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
