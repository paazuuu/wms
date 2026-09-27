import '../../l10n/app_localizations.dart';

/// Every `has_permission()` guard across the RPCs raises this exact shape
/// (`raise exception 'not permitted: <code> required'`) — see any migration
/// under `supabase/migrations`. It reaches the client as the raw Postgres
/// message, optionally wrapped in `Exception: ...` when a repository
/// rethrows it for a read provider, so this checks containment, not equality.
final _notPermittedPattern = RegExp(r'not permitted: [\w.]+ required');

/// Turns a raw backend error into what the user should actually see (UI spec
/// §34 — no `PostgrestException`-shaped text on screen). Currently handles
/// the one case common enough to hit through the UI itself: a §37 menu entry
/// gated on a "view OR manage" pair lets a view-only user open a screen whose
/// write actions need the stronger permission, so its RPC's own permission
/// check is the first time that gap becomes visible. Anything else passes
/// through unchanged rather than guessing at a translation.
String humanizeApiErrorMessage(AppLocalizations l10n, String rawMessage) {
  if (_notPermittedPattern.hasMatch(rawMessage)) {
    return l10n.errorPermissionDenied;
  }
  // 0095–0097: an inspection is closed once, a receipt whose inspection closed
  // cannot be cancelled, and it takes no more goods for inspection. All are
  // reached by an ordinary tap (a second device, a stale screen), so they get
  // words rather than SQL.
  if (rawMessage.contains('receive these goods as a new receipt')) {
    return l10n.errorInspectionClosedReceiveNew;
  }
  if (rawMessage.contains('has a completed inspection')) {
    return l10n.errorReceiptInspected;
  }
  if (rawMessage.contains('is already completed')) {
    return l10n.errorInspectionCompleted;
  }
  return rawMessage;
}
