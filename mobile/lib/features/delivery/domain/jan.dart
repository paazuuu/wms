/// Canonical JAN/EAN normalization.
///
/// The same product's barcode arrives written many different ways depending on
/// who typed it and how Excel stored it: full-width digits (４９０…), hyphens or
/// spaces between groups, a trailing ".0" when a spreadsheet kept it as a
/// number, or a dropped leading zero (12 digits instead of 13). Every JAN that
/// enters the system — scanned, OCR'd, typed, or imported — is passed through
/// [normalizeJan] so matching always compares one canonical form.
///
/// Rules:
///  - full-width digits ０-９ → ASCII 0-9 (and full-width period → '.')
///  - anything after a decimal point is dropped (Excel's "4902...037.0")
///  - every non-digit (hyphen, space, letter, symbol) is removed
///  - a 12-digit result is left-padded to 13 (UPC-A / lost leading zero)
String normalizeJan(String raw) {
  final mapped = StringBuffer();
  for (final r in raw.runes) {
    if (r >= 0xFF10 && r <= 0xFF19) {
      mapped.writeCharCode(r - 0xFF10 + 0x30); // full-width digit
    } else if (r == 0xFF0E) {
      mapped.writeCharCode(0x2E); // full-width period
    } else {
      mapped.writeCharCode(r);
    }
  }
  var s = mapped.toString();
  final dot = s.indexOf('.');
  if (dot >= 0) s = s.substring(0, dot);

  final digits = StringBuffer();
  for (final r in s.runes) {
    if (r >= 0x30 && r <= 0x39) digits.writeCharCode(r);
  }
  var out = digits.toString();
  if (out.length == 12) out = '0$out';
  return out;
}
