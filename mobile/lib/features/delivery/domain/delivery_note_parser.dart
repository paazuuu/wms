import 'ocr_line.dart';

/// Extracts JAN/EAN-13 codes from the recognized text of a delivery-note photo.
///
/// This is the testable brain of the OCR assist and is deliberately pure — it
/// takes the OCR text lines and returns the JANs it can trust. To avoid false
/// positives (the tax registration number, phone numbers, amounts), a candidate
/// must be exactly 13 digits AND pass the EAN-13 check digit. Duplicates are
/// collapsed, keeping the first occurrence.
List<OcrLine> parseDeliveryNoteText(List<String> textLines) {
  final result = <OcrLine>[];
  final seen = <String>{};
  // Exactly 13 digits, not part of a longer digit run.
  final thirteenDigits = RegExp(r'(?<!\d)\d{13}(?!\d)');

  for (final raw in textLines) {
    for (final match in thirteenDigits.allMatches(raw)) {
      final code = match.group(0)!;
      if (!isValidEan13(code)) continue;
      if (!seen.add(code)) continue;
      result.add(OcrLine(janCode: code, rawText: raw.trim()));
    }
  }
  return result;
}

/// Validates the EAN-13 check digit. Used to tell a real JAN apart from other
/// 13-digit numbers OCR might pick up on the sheet.
bool isValidEan13(String code) {
  if (code.length != 13) return false;
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    final digit = code.codeUnitAt(i) - 0x30;
    if (digit < 0 || digit > 9) return false;
    sum += digit * (i.isEven ? 1 : 3);
  }
  final check = (10 - (sum % 10)) % 10;
  final last = code.codeUnitAt(12) - 0x30;
  return check == last;
}
