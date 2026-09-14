import '../domain/ocr_line.dart';

/// Reads a delivery-note photo and returns the JANs found on it.
///
/// Kept as an interface so the assist can swap between the cloud vision OCR
/// (Gemini, via the backend — the priority path) and the on-device engine
/// (offline fallback), and so the pure parsers can be tested without either.
abstract class DeliveryNoteScanner {
  /// Recognizes the image at [imagePath] and extracts JAN candidates.
  ///
  /// [deliveryPlanId], when known, links the recorded AI call back to the
  /// plan it was read for — purely for traceability (spec §31's 納品書番号 on
  /// the AI review screen); it never changes what gets extracted.
  Future<List<OcrLine>> scan(String imagePath, {int? deliveryPlanId});

  /// Releases any resources. Safe to call more than once.
  Future<void> dispose();
}
