import '../domain/ocr_line.dart';
import 'delivery_note_scanner.dart';

/// Web build of the on-device scanner. ML Kit is Android/iOS-only, so on the web
/// there is no offline OCR — this returns nothing and the remote (Gemini)
/// scanner is the only OCR path. Keeps the same class name so the provider wires
/// up identically across platforms.
class MlKitDeliveryNoteScanner implements DeliveryNoteScanner {
  MlKitDeliveryNoteScanner();

  @override
  Future<List<OcrLine>> scan(String imagePath) async => const [];

  @override
  Future<void> dispose() async {}
}
