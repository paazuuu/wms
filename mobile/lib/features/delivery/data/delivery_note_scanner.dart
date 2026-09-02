import '../domain/ocr_line.dart';

/// Reads a delivery-note photo and returns the JANs found on it.
///
/// Kept as an interface so the assist can swap between the cloud vision OCR
/// (Gemini, via the backend — the priority path) and the on-device engine
/// (offline fallback), and so the pure parsers can be tested without either.
abstract class DeliveryNoteScanner {
  /// Recognizes the image at [imagePath] and extracts JAN candidates.
  Future<List<OcrLine>> scan(String imagePath);

  /// Releases any resources. Safe to call more than once.
  Future<void> dispose();
}
