/// Which step of the floor a scan is happening in (§26).
///
/// The server keeps the real list in `scan_contexts`, because the ordering it
/// encodes — what each step expects, most likely first — is a business decision
/// and not a client constant. This enum is the set of codes the app knows how to
/// be in, so a screen names its context in one place and cannot typo it.
enum ScanContext {
  receiving('RECEIVING'),
  qc('QC'),
  putaway('PUTAWAY'),
  picking('PICKING'),
  packing('PACKING'),
  shipping('SHIPPING'),
  counting('COUNTING'),

  /// Search, and anything else with no particular step: everything is fair game
  /// and nothing is unexpected.
  lookup('LOOKUP');

  const ScanContext(this.code);

  final String code;

  static ScanContext? fromCode(dynamic value) {
    final code = (value ?? '').toString().toUpperCase();
    if (code.isEmpty) return null;
    for (final c in ScanContext.values) {
      if (c.code == code) return c;
    }
    return null;
  }
}
