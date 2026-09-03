import 'delivery_note_parser.dart' show isValidEan13;
import 'jan.dart';
import 'ocr_line.dart';

/// Parses the structured JSON returned by the backend's cloud vision OCR
/// (Gemini/Qwen) into [OcrLine]s. Because the model reads the whole printed
/// row, these lines carry a product name and a real quantity, unlike the
/// on-device parser which only recovers JANs.
///
/// Accepts either `{ "data": { "lines": [...] } }` or a bare `{ "lines": [...] }`.
/// Each entry must carry a plausible JAN (8 digits, or a 13-digit EAN that
/// passes its check digit) or it is dropped; duplicates keep the first.
List<OcrLine> parseVisionOcrResponse(Map<String, dynamic> json) {
  final data = json['data'];
  final rawLines = data is Map<String, dynamic> ? data['lines'] : json['lines'];
  if (rawLines is! List) return const [];

  final result = <OcrLine>[];
  final seen = <String>{};
  for (final entry in rawLines) {
    if (entry is! Map) continue;
    final jan =
        normalizeJan((entry['jan_code'] ?? entry['jan'] ?? '').toString());
    if (!isAcceptableJan(jan)) continue;
    if (!seen.add(jan)) continue;
    final name = (entry['product_name'] ?? '').toString().trim();
    result.add(OcrLine(
      janCode: jan,
      quantityHint: _asInt(entry['quantity']),
      productName: name,
      rawText: name,
    ));
  }
  return result;
}

/// A JAN we trust enough to seed a count: JAN-8, or a checksum-valid EAN-13.
bool isAcceptableJan(String jan) {
  if (RegExp(r'^\d{8}$').hasMatch(jan)) return true;
  if (jan.length == 13 && isValidEan13(jan)) return true;
  return false;
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}
