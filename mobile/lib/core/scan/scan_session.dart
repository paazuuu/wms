/// Pure, framework-free bookkeeping for one scanning session (UI spec §11).
///
/// A camera decodes the same barcode dozens of times a second, and an operator
/// working a queue will sweep past a label they already did. Both produce the
/// same bug — one physical scan counted twice — so duplicate suppression is not
/// a nicety here, it is the difference between a trustworthy count and a wrong
/// one. Kept out of the widget so the timing rules can be unit-tested directly,
/// the same split as [ScanBuffer].
library;

/// What the session decided about one decoded code.
enum ScanOutcome {
  /// Accepted: new (or past the duplicate window) and the caller's validation
  /// passed.
  accepted,

  /// The same code, again, inside [ScanSession.duplicateWindow].
  duplicate,

  /// The caller's validation refused it — e.g. the wrong JAN for this task.
  rejected,
}

/// One entry of the session's scan history (newest first in
/// [ScanSession.history]).
class ScanEvent {
  const ScanEvent({
    required this.code,
    required this.at,
    required this.outcome,
    this.message,
  });

  final String code;
  final DateTime at;
  final ScanOutcome outcome;

  /// Why it was rejected, for the operator. Null for an accepted scan.
  final String? message;
}

/// Records what has been scanned and suppresses an immediate repeat.
///
/// The caller owns validation: [register] is told the outcome of its own check
/// via [rejectionMessage], and only decides duplicate-vs-new itself.
class ScanSession {
  ScanSession({
    this.duplicateWindow = const Duration(seconds: 3),
    this.historyLimit = 20,
  });

  /// How long the same code is ignored after being accepted. Long enough to
  /// cover a camera's repeat detections and a finger held on a trigger, short
  /// enough that deliberately scanning the same item twice still works —
  /// picking two of the same SKU is normal work, so this must not block it
  /// forever.
  final Duration duplicateWindow;

  /// Most-recent entries kept for the on-screen history. Old ones fall off.
  final int historyLimit;

  final List<ScanEvent> _history = [];
  final Map<String, DateTime> _acceptedAt = {};

  /// Newest first.
  List<ScanEvent> get history => List.unmodifiable(_history);

  /// The most recent scan, whatever its outcome.
  ScanEvent? get last => _history.isEmpty ? null : _history.first;

  /// How many scans this session has accepted.
  int get acceptedCount =>
      _history.where((e) => e.outcome == ScanOutcome.accepted).length;

  /// Classify [code] at [now].
  ///
  /// Pass [rejectionMessage] when the caller's own validation refused the code;
  /// a rejected scan is recorded in the history but never starts a duplicate
  /// window — the operator has to be able to retry the moment they fix
  /// whatever was wrong.
  ScanEvent register(String code, DateTime now, {String? rejectionMessage}) {
    final trimmed = code.trim();
    final ScanEvent event;
    if (rejectionMessage != null) {
      event = ScanEvent(
          code: trimmed,
          at: now,
          outcome: ScanOutcome.rejected,
          message: rejectionMessage);
    } else {
      final previous = _acceptedAt[trimmed];
      if (previous != null && now.difference(previous) < duplicateWindow) {
        event =
            ScanEvent(code: trimmed, at: now, outcome: ScanOutcome.duplicate);
      } else {
        _acceptedAt[trimmed] = now;
        event = ScanEvent(code: trimmed, at: now, outcome: ScanOutcome.accepted);
      }
    }
    _history.insert(0, event);
    if (_history.length > historyLimit) _history.removeLast();
    return event;
  }

  /// Forget the duplicate windows (not the history) — used when the operator
  /// moves to a different task and a repeat is genuinely new work.
  void allowRepeats() => _acceptedAt.clear();

  void clear() {
    _history.clear();
    _acceptedAt.clear();
  }
}
