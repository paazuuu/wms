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
  return rawMessage;
}
